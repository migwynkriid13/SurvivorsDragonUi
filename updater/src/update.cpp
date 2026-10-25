#include <windows.h>
#include <bcrypt.h>
#include <zlib.h>
#include <nlohmann/json.hpp>

#include "update.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <charconv>
#include <fstream>
#include <map>
#include <optional>
#include <set>
#include <stdexcept>
#include <string_view>
#include <utility>

namespace sdui {
namespace {
namespace fs = std::filesystem;
using Json = nlohmann::json;
constexpr std::size_t FileLimit = 32 * 1024 * 1024;
constexpr std::size_t TotalLimit = 256 * 1024 * 1024;
constexpr char Addon[] = "SurvivorsDragonUi";

void Require(bool value, const char* reason) {
    if (!value) throw std::runtime_error(reason);
}

// Refuse junctions/symlinks both in managed trees and their existing parents.
void Guard(const fs::path& path) {
    auto current = path.root_path();
    for (const auto& part : path.relative_path()) {
        current /= part;
        const auto attributes = GetFileAttributesW(current.c_str());
        if (attributes == INVALID_FILE_ATTRIBUTES) {
            const auto error = GetLastError();
            Require(error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND,
                    "Cannot inspect updater path");
        } else {
            Require(!(attributes & FILE_ATTRIBUTE_REPARSE_POINT), "Refusing a reparse point");
        }
    }
}

void ClearTree(const fs::path& path) {
    Guard(path);
    if (!fs::exists(path)) return;
    for (const auto& entry : fs::recursive_directory_iterator(path)) Guard(entry.path());
    fs::remove_all(path);
}

Bytes Read(const fs::path& path, std::size_t limit) {
    Guard(path);
    const auto size = fs::file_size(path);
    Require(size <= limit, "File exceeds size limit");
    std::ifstream input(path, std::ios::binary);
    Require(input.is_open(), "Cannot read file");
    Bytes bytes(static_cast<std::size_t>(size));
    input.read(reinterpret_cast<char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    Require(!input.fail(), "Incomplete local file");
    return bytes;
}

void Write(const fs::path& path, const Bytes& bytes) {
    Guard(path);
    fs::create_directories(path.parent_path());
    const auto file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW,
                                  FILE_ATTRIBUTE_NORMAL, nullptr);
    Require(file != INVALID_HANDLE_VALUE, "Cannot create staged file");
    DWORD written{};
    const bool complete = WriteFile(file, bytes.data(), static_cast<DWORD>(bytes.size()),
                                    &written, nullptr) && written == bytes.size() &&
                          FlushFileBuffers(file);
    CloseHandle(file);
    Require(complete, "Cannot finish staged file");
}

bool Hex(const std::string& value, std::size_t size) {
    return value.size() == size && std::all_of(value.begin(), value.end(), [](char c) {
        return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
    });
}

std::string Lower(std::string value) {
    for (auto& c : value) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return value;
}

struct File {
    std::size_t size{};
    std::string hash;
};
using Files = std::map<std::string, File>;
struct Manifest {
    Json receipt;
    std::string tag;
    std::string archiveHash;
    std::size_t archiveSize{};
    Files files;
};

using Version = std::array<std::uint32_t, 3>;
std::optional<Version> ParseVersion(std::string_view text) {
    constexpr std::string_view suffix = "-survivors";
    if (!text.ends_with(suffix)) return std::nullopt;
    text.remove_suffix(suffix.size());
    Version parts{};
    for (std::size_t i = 0; i < parts.size(); ++i) {
        const auto dot = text.find('.');
        const auto field = text.substr(0, dot);
        const auto result = std::from_chars(field.data(), field.data() + field.size(), parts[i]);
        if (field.empty() || result.ec != std::errc{} || result.ptr != field.data() + field.size()) return std::nullopt;
        if (i + 1 < parts.size()) {
            if (dot == std::string_view::npos) return std::nullopt;
            text.remove_prefix(dot + 1);
        } else if (dot != std::string_view::npos) return std::nullopt;
    }
    return parts;
}

bool NewerInstalled(const fs::path& live, const Manifest& manifest) {
    const auto toc = live / L"SurvivorsDragonUi.toc";
    Guard(toc);
    if (!fs::is_regular_file(toc)) return false;
    const auto bytes = Read(toc, ManifestLimit);
    const std::string text(bytes.begin(), bytes.end());
    std::size_t line{};
    while (line < text.size()) {
        const auto end = text.find('\n', line);
        auto value = std::string_view(text).substr(line, end == std::string::npos ? end : end - line);
        constexpr std::string_view prefix = "## Version:";
        if (value.starts_with(prefix)) {
            value.remove_prefix(prefix.size());
            while (!value.empty() && (value.front() == ' ' || value.front() == '\t')) value.remove_prefix(1);
            while (!value.empty() && (value.back() == '\r' || value.back() == ' ')) value.remove_suffix(1);
            const auto current = ParseVersion(value);
            const auto published = ParseVersion(manifest.receipt.at("version").get<std::string>());
            return current && published && *current > *published;
        }
        if (end == std::string::npos) break;
        line = end + 1;
    }
    return false;
}

struct Paths {
    fs::path live, work, pending, backup;
    fs::path legacyWork, legacyPending, legacyBackup;
    explicit Paths(const fs::path& game) {
        const auto addons = game / L"benilla-config" / L"AddOns";
        const auto storage = game / L"benilla-config" / L"SurvivorsDragonUi-updater";
        live = AddonDirectory(game);
        work = storage / L"download" / Addon;
        pending = storage / L"pending" / Addon;
        backup = storage / L"backup" / Addon;
        legacyWork = addons / L".SurvivorsDragonUi-download";
        legacyPending = addons / L".SurvivorsDragonUi-update";
        legacyBackup = addons / L".SurvivorsDragonUi-backup";
        for (const auto* path : {&live, &work, &pending, &backup, &legacyWork, &legacyPending, &legacyBackup}) Guard(*path);
    }
};

// Only startup with an exclusive session lock migrates the old updater paths.
// Keep any existing destination intact rather than overwriting a second copy.
void MigrateLegacy(const Paths& paths) {
    for (const auto& [oldPath, newPath] : {
            std::pair{paths.legacyWork, paths.work}, std::pair{paths.legacyPending, paths.pending},
            std::pair{paths.legacyBackup, paths.backup}}) {
        if (fs::exists(oldPath) && !fs::exists(newPath)) {
            fs::create_directories(newPath.parent_path());
            fs::rename(oldPath, newPath);
        }
    }
}

Manifest Parse(const Bytes& bytes) {
    Require(!bytes.empty() && bytes.size() <= ManifestLimit, "Invalid manifest size");
    const auto json = Json::parse(bytes);
    Require(json.at("schema") == 1 &&
            json.at("repository") == "migwynkriid13/SurvivorsDragonUi", "Wrong release manifest");
    Manifest result;
    result.receipt = json;
    result.tag = json.at("tag").get<std::string>();
    Require(result.tag.starts_with("build-") && Hex(result.tag.substr(6), 40), "Invalid release tag");
    const auto version = json.at("version").get<std::string>();
    Require(ParseVersion(version).has_value(), "Invalid addon version");
    result.archiveHash = json.at("archive").at("sha256").get<std::string>();
    result.archiveSize = json.at("archive").at("size").get<std::size_t>();
    Require(Hex(result.archiveHash, 64) && result.archiveSize > 0 &&
            result.archiveSize <= ArchiveLimit, "Invalid archive identity");
    const auto& files = json.at("files");
    Require(files.is_array() && !files.empty() && files.size() <= 4096, "Invalid file population");
    std::set<std::string> names;
    std::size_t total{};
    for (const auto& entry : files) {
        const auto name = entry.at("path").get<std::string>();
        File file{entry.at("size").get<std::size_t>(), entry.at("sha256").get<std::string>()};
        Require(SafeRelativePath(name) && names.insert(Lower(name)).second,
                "Unsafe or duplicate manifest path");
        Require(file.size <= FileLimit && Hex(file.hash, 64), "Invalid file identity");
        total += file.size;
        Require(total <= TotalLimit, "Release exceeds expanded size limit");
        result.files.emplace(name, std::move(file));
    }
    Require(result.files.contains("SurvivorsDragonUi.toc"), "Release is missing the addon TOC");
    // A file must never also be the parent directory of another file.
    for (const auto& name : names) {
        auto slash = name.find('/');
        while (slash != std::string::npos) {
            Require(!names.contains(name.substr(0, slash)), "Conflicting manifest paths");
            slash = name.find('/', slash + 1);
        }
    }
    return result;
}

std::uint32_t U16(const Bytes& bytes, std::size_t offset) {
    Require(offset <= bytes.size() && bytes.size() - offset >= 2, "Truncated ZIP");
    return bytes[offset] | (std::uint32_t(bytes[offset + 1]) << 8);
}
std::uint32_t U32(const Bytes& bytes, std::size_t offset) {
    return U16(bytes, offset) | (U16(bytes, offset + 2) << 16);
}
std::string Name(const Bytes& bytes, std::size_t offset, std::size_t length) {
    Require(offset <= bytes.size() && length <= bytes.size() - offset, "Truncated ZIP name");
    return std::string(reinterpret_cast<const char*>(bytes.data() + offset), length);
}

// Read only ordinary single-disk ZIP entries produced by scripts/package.py.
// The manifest is the complete allowlist; ZIP64, links and extra files are refused.
void Extract(const Bytes& zip, const Manifest& manifest, const fs::path& stage) {
    Require(zip.size() == manifest.archiveSize && Sha256(zip) == manifest.archiveHash,
            "Archive SHA-256 mismatch");
    Require(zip.size() >= 22, "Truncated ZIP directory");
    auto end = zip.size() - 22;
    const auto earliest = end > 65535 ? end - 65535 : 0;
    while (U32(zip, end) != 0x06054b50 || end + 22 + U16(zip, end + 20) != zip.size()) {
        Require(end > earliest, "Missing ZIP directory");
        --end;
    }
    const auto count = U16(zip, end + 10);
    const auto directorySize = U32(zip, end + 12);
    const auto directory = U32(zip, end + 16);
    Require(!U16(zip, end + 4) && !U16(zip, end + 6) &&
            U16(zip, end + 8) == count && count == manifest.files.size() &&
            std::uint64_t(directory) + directorySize == end, "Unsupported ZIP directory");
    std::size_t cursor = directory;
    std::set<std::string> seen;
    for (std::size_t index = 0; index < count; ++index) {
        Require(U32(zip, cursor) == 0x02014b50, "Invalid ZIP entry");
        const auto flags = U16(zip, cursor + 8);
        const auto method = U16(zip, cursor + 10);
        const auto crc = U32(zip, cursor + 16);
        const auto packed = U32(zip, cursor + 20);
        const auto size = U32(zip, cursor + 24);
        const auto nameSize = U16(zip, cursor + 28);
        const auto extraSize = U16(zip, cursor + 30);
        const auto commentSize = U16(zip, cursor + 32);
        const auto attributes = U32(zip, cursor + 38);
        const auto local = U32(zip, cursor + 42);
        const auto name = Name(zip, cursor + 46, nameSize);
        constexpr std::string_view prefix = "SurvivorsDragonUi/";
        Require(name.starts_with(prefix), "ZIP escapes addon directory");
        const auto relative = name.substr(prefix.size());
        const auto record = manifest.files.find(relative);
        Require(record != manifest.files.end() && seen.insert(relative).second,
                "Unlisted or duplicate ZIP entry");
        const auto unixType = (attributes >> 16) & 0170000;
        Require((unixType == 0 || unixType == 0100000) && !(attributes & 0x10) &&
                !U16(zip, cursor + 34) && !(flags & ~0x0808) &&
                (method == 0 || method == 8) && size == record->second.size,
                "Unsupported ZIP entry type");
        Require(U32(zip, local) == 0x04034b50 && U16(zip, local + 6) == flags &&
                U16(zip, local + 8) == method && U16(zip, local + 26) == nameSize &&
                Name(zip, std::size_t(local) + 30, nameSize) == name, "ZIP header mismatch");
        const std::size_t data = std::size_t(local) + 30 + nameSize + U16(zip, local + 28);
        Require(data <= directory && packed <= directory - data, "ZIP data overlaps directory");
        Bytes output(size ? size : 1);
        if (method == 0) {
            Require(packed == size, "Invalid stored ZIP size");
            std::copy_n(zip.begin() + data, size, output.begin());
        } else {
            z_stream stream{};
            stream.next_in = const_cast<Bytef*>(zip.data() + data);
            stream.avail_in = packed;
            stream.next_out = output.data();
            stream.avail_out = static_cast<uInt>(output.size());
            Require(inflateInit2(&stream, -MAX_WBITS) == Z_OK, "Cannot initialize ZIP decoder");
            const auto status = inflate(&stream, Z_FINISH);
            inflateEnd(&stream);
            Require(status == Z_STREAM_END && stream.total_in == packed && stream.total_out == size,
                    "Incomplete or oversized ZIP entry");
        }
        output.resize(size);
        Require(crc32(0, output.data(), static_cast<uInt>(output.size())) == crc &&
                Sha256(output) == record->second.hash, "ZIP file checksum mismatch");
        Write(stage / fs::path(relative), output);
        cursor += 46 + nameSize + extraSize + commentSize;
        Require(cursor <= end, "ZIP directory overflow");
    }
    Require(cursor == end && seen.size() == manifest.files.size(), "Incomplete ZIP population");
}

bool Matches(const fs::path& live, const Manifest& manifest) {
    for (const auto& [name, file] : manifest.files) {
        const auto path = live / fs::path(name);
        Guard(path);
        if (!fs::is_regular_file(path) || fs::file_size(path) != file.size ||
            Sha256(Read(path, FileLimit)) != file.hash) return false;
    }
    return true;
}

Manifest Ready(const fs::path& directory) {
    const auto manifest = Parse(Read(directory / L".sdui-release.json", ManifestLimit));
    Require(Matches(directory, manifest), "Pending addon failed verification");
    return manifest;
}

std::string FinishDownload(const Paths& paths, const Manifest& manifest, bool allowFirstInstall) {
    if (allowFirstInstall && !fs::exists(paths.live)) {
        // All bytes and the receipt are ready before the canonical directory
        // appears. A concurrent destination is never removed or overwritten.
        Ready(paths.pending);
        fs::create_directories(paths.live.parent_path());
        if (!MoveFileW(paths.pending.c_str(), paths.live.c_str())) {
            // MoveFileW refuses an existing destination, including an empty
            // directory created after the earlier existence check.
            if (fs::exists(paths.live)) return "Downloaded; ready for the next launch: " + manifest.tag;
            throw std::runtime_error("Cannot install SurvivorsDragonUi; verified download retained for the next launch");
        }
        return "Installed: SurvivorsDragonUi (" + manifest.tag + "). Enable it in the game's AddOns menu.";
    }
    return "Downloaded; ready for the next launch: " + manifest.tag;
}
} // namespace

std::filesystem::path AddonDirectory(const std::filesystem::path& game) {
    return game / L"benilla-config" / L"AddOns" / Addon;
}

std::string Sha256(std::span<const std::uint8_t> bytes) {
    Require(bytes.size() <= TotalLimit, "Hash input exceeds size limit");
    BCRYPT_ALG_HANDLE algorithm{};
    Require(BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) >= 0,
            "SHA-256 is unavailable");
    std::array<std::uint8_t, 32> digest{};
    const auto status = BCryptHash(algorithm, nullptr, 0, const_cast<PUCHAR>(bytes.data()),
                                   static_cast<ULONG>(bytes.size()), digest.data(),
                                   static_cast<ULONG>(digest.size()));
    BCryptCloseAlgorithmProvider(algorithm, 0);
    Require(status >= 0, "SHA-256 failed");
    constexpr char hex[] = "0123456789abcdef";
    std::string result;
    for (const auto byte : digest) {
        result += hex[byte >> 4];
        result += hex[byte & 15];
    }
    return result;
}

bool SafeRelativePath(const std::string& name) {
    if (name.empty() || name.size() > 240) return false;
    std::size_t start{};
    while (start < name.size()) {
        const auto slash = name.find('/', start);
        const auto part = name.substr(start, slash == std::string::npos ? slash : slash - start);
        if (part.empty() || part.front() == '.' || part.back() == '.') return false;
        for (const unsigned char c : part) {
            if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                  (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.')) return false;
        }
        const auto base = Lower(part.substr(0, part.find('.')));
        if (base == "con" || base == "prn" || base == "aux" || base == "nul" ||
            (base.size() == 4 && (base.starts_with("com") || base.starts_with("lpt")) &&
             base[3] >= '1' && base[3] <= '9')) return false;
        if (slash == std::string::npos) return true;
        start = slash + 1;
    }
    return false;
}

std::string StageUpdate(const fs::path& game, const Download& download, bool allowFirstInstall) {
    const Paths paths(game);
    const auto manifest = Parse(download(ManifestUrl, ManifestLimit));
    if (NewerInstalled(paths.live, manifest)) return "Installed addon is newer than the latest release; skipped.";
    if (Matches(paths.live, manifest)) return "Already current: " + manifest.tag;
    if (fs::is_regular_file(paths.pending / L".sdui-release.json") && Matches(paths.pending, manifest)) {
        if (allowFirstInstall && !fs::exists(paths.live)) return FinishDownload(paths, manifest, true);
        return "Already downloaded; ready for the next launch: " + manifest.tag;
    }
    const auto archiveUrl = std::wstring(L"https://github.com/migwynkriid13/SurvivorsDragonUi/releases/download/") +
        std::wstring(manifest.tag.begin(), manifest.tag.end()) + L"/SurvivorsDragonUi.zip";
    const auto zip = download(archiveUrl, ArchiveLimit);
    // Network and extraction touch only private staging; the running game's
    // addon and any previously completed pending update remain available.
    ClearTree(paths.work);
    fs::create_directories(paths.work);
    try {
        Extract(zip, manifest, paths.work);
        const auto receipt = manifest.receipt.dump(2) + "\n";
        Write(paths.work / L".sdui-release.json", Bytes(receipt.begin(), receipt.end()));
        ClearTree(paths.pending);
        fs::create_directories(paths.pending.parent_path());
        fs::rename(paths.work, paths.pending);
    } catch (...) {
        try { ClearTree(paths.work); } catch (...) {}
        throw;
    }
    return FinishDownload(paths, manifest, allowFirstInstall);
}

std::string ApplyPending(const fs::path& game, const std::function<void()>& beforeActivate) {
    const Paths paths(game);
    MigrateLegacy(paths);
    // Recovery and activation have no transport parameter: they work offline.
    if (!fs::exists(paths.live) && fs::exists(paths.backup)) {
        fs::create_directories(paths.live.parent_path());
        fs::rename(paths.backup, paths.live);
    }
    // The receipt is written only after every extracted file has been flushed.
    // Recover a completed staging rename interrupted before it became pending.
    if (!fs::exists(paths.pending) && fs::is_regular_file(paths.work / L".sdui-release.json")) {
        Ready(paths.work);
        fs::create_directories(paths.pending.parent_path());
        fs::rename(paths.work, paths.pending);
    }
    if (!fs::exists(paths.pending)) return "No downloaded addon update to activate.";
    const auto manifest = Ready(paths.pending);
    if (NewerInstalled(paths.live, manifest) || Matches(paths.live, manifest)) {
        ClearTree(paths.pending);
        return "Kept the current addon; discarded a redundant or older pending update.";
    }
    ClearTree(paths.backup);
    const bool hadLive = fs::exists(paths.live);
    if (hadLive) {
        fs::create_directories(paths.backup.parent_path());
        fs::rename(paths.live, paths.backup);
    }
    try {
        if (beforeActivate) beforeActivate();
        fs::create_directories(paths.live.parent_path());
        fs::rename(paths.pending, paths.live);
    } catch (...) {
        if (hadLive) fs::rename(paths.backup, paths.live);
        throw;
    }
    return "Activated downloaded addon: " + manifest.tag;
}
} // namespace sdui
