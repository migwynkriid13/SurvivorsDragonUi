#include <windows.h>
#include <zlib.h>
#include <nlohmann/json.hpp>

#include "update.hpp"

#include <fstream>
#include <iostream>
#include <iterator>
#include <map>
#include <stdexcept>

namespace {
namespace fs = std::filesystem;
using sdui::Bytes;
using Json = nlohmann::json;
using Contents = std::map<std::string, std::string>;

void Check(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}
template<class Work> void Fails(Work work) {
    bool failed{};
    try { work(); } catch (const std::exception&) { failed = true; }
    Check(failed, "Expected the operation to fail");
}
Bytes BytesOf(const std::string& text) { return Bytes(text.begin(), text.end()); }
void U16(Bytes& bytes, std::uint32_t value) {
    bytes.push_back(static_cast<std::uint8_t>(value));
    bytes.push_back(static_cast<std::uint8_t>(value >> 8));
}
void U32(Bytes& bytes, std::uint32_t value) { U16(bytes, value); U16(bytes, value >> 16); }
std::string Read(const fs::path& path) {
    std::ifstream stream(path, std::ios::binary);
    Check(stream.is_open(), "Missing installed file");
    return std::string(std::istreambuf_iterator<char>(stream), std::istreambuf_iterator<char>());
}
void Write(const fs::path& path, const std::string& text) {
    fs::create_directories(path.parent_path());
    std::ofstream(path, std::ios::binary) << text;
}

// Independent ZIP fixture writer, covering both stored and raw-DEFLATE files.
Bytes Zip(const Contents& files, bool deflate = true) {
    Bytes bytes, central;
    for (const auto& [relative, text] : files) {
        const auto name = "SurvivorsDragonUi/" + relative;
        const auto input = BytesOf(text);
        auto packed = input;
        if (deflate) {
            z_stream stream{};
            Check(deflateInit2(&stream, 9, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY) == Z_OK,
                  "Fixture compressor unavailable");
            packed.resize(compressBound(static_cast<uLong>(input.size())));
            stream.next_in = const_cast<Bytef*>(input.data());
            stream.avail_in = static_cast<uInt>(input.size());
            stream.next_out = packed.data();
            stream.avail_out = static_cast<uInt>(packed.size());
            Check(::deflate(&stream, Z_FINISH) == Z_STREAM_END, "Cannot compress fixture");
            packed.resize(stream.total_out);
            deflateEnd(&stream);
        }
        const auto crc = crc32(0, input.data(), static_cast<uInt>(input.size()));
        const auto offset = static_cast<std::uint32_t>(bytes.size());
        U32(bytes, 0x04034b50); U16(bytes, 20); U16(bytes, 0); U16(bytes, deflate ? 8 : 0);
        U16(bytes, 0); U16(bytes, 0); U32(bytes, crc);
        U32(bytes, static_cast<std::uint32_t>(packed.size()));
        U32(bytes, static_cast<std::uint32_t>(input.size()));
        U16(bytes, static_cast<std::uint32_t>(name.size())); U16(bytes, 0);
        bytes.insert(bytes.end(), name.begin(), name.end());
        bytes.insert(bytes.end(), packed.begin(), packed.end());
        U32(central, 0x02014b50); U16(central, 20); U16(central, 20);
        U16(central, 0); U16(central, deflate ? 8 : 0); U16(central, 0); U16(central, 0);
        U32(central, crc); U32(central, static_cast<std::uint32_t>(packed.size()));
        U32(central, static_cast<std::uint32_t>(input.size()));
        U16(central, static_cast<std::uint32_t>(name.size()));
        U16(central, 0); U16(central, 0); U16(central, 0); U16(central, 0); U32(central, 0);
        U32(central, offset);
        central.insert(central.end(), name.begin(), name.end());
    }
    const auto directory = static_cast<std::uint32_t>(bytes.size());
    bytes.insert(bytes.end(), central.begin(), central.end());
    U32(bytes, 0x06054b50); U16(bytes, 0); U16(bytes, 0);
    U16(bytes, static_cast<std::uint32_t>(files.size())); U16(bytes, static_cast<std::uint32_t>(files.size()));
    U32(bytes, static_cast<std::uint32_t>(central.size())); U32(bytes, directory); U16(bytes, 0);
    return bytes;
}

struct Release {
    Contents files;
    Bytes zip;
    Json manifest;
    int archiveRequests{};
    explicit Release(std::string text = "first", char commit = 'a', bool compressed = true)
        : files{{"SurvivorsDragonUi.toc", "## Interface: 11200\n## Version: 1.0.0-survivors\ncore/core.lua\n"},
                {"core/core.lua", std::move(text)}} {
        zip = Zip(files, compressed);
        manifest = {{"schema", 1}, {"repository", "migwynkriid13/SurvivorsDragonUi"},
            {"tag", "build-" + std::string(40, commit)}, {"version", "1.0.0-survivors"},
            {"archive", {{"size", zip.size()}, {"sha256", sdui::Sha256(zip)}}}, {"files", Json::array()}};
        for (const auto& [name, data] : files) {
            manifest["files"].push_back({{"path", name}, {"size", data.size()},
                                       {"sha256", sdui::Sha256(BytesOf(data))}});
        }
    }
    sdui::Download Transport() {
        return [this](const std::wstring& url, std::size_t limit) {
            if (url == sdui::ManifestUrl) {
                Check(limit == sdui::ManifestLimit, "Wrong manifest bound");
                return BytesOf(manifest.dump());
            }
            const auto tag = manifest.at("tag").get<std::string>();
            const auto expected = std::wstring(L"https://github.com/migwynkriid13/SurvivorsDragonUi/releases/download/") +
                std::wstring(tag.begin(), tag.end()) + L"/SurvivorsDragonUi.zip";
            Check(url == expected && limit == sdui::ArchiveLimit, "Archive is not pinned to the manifest release");
            ++archiveRequests;
            return zip;
        };
    }
};

struct Install {
    fs::path game = fs::temp_directory_path() / (L"sdui-ci-" + std::to_wstring(GetCurrentProcessId()) +
        L"-" + std::to_wstring(GetTickCount64()));
    fs::path addons = game / L"benilla-config" / L"AddOns";
    fs::path live = addons / L"SurvivorsDragonUi";
    fs::path backup = addons / L".SurvivorsDragonUi-backup";
    Install() { fs::create_directories(game); }
    ~Install() { std::error_code error; fs::remove_all(game, error); }
};

void InstallAndLatest() {
    Install install;
    Release first;
    Write(install.addons / L"OtherAddon" / L"keep.lua", "other addon");
    Write(install.game / L"benilla-config" / L"SavedVariables" / L"keep.lua", "settings");
    Write(install.game / L"AzerothSurvivors.exe", "unchanged executable");
    Write(install.game / L"avrt.dll", "unchanged updater");
    sdui::Update(install.game, first.Transport());
    Check(Read(install.live / L"core/core.lua") == "first", "Missing first install");
    Check(fs::exists(install.live / L".sdui-release.json"), "Missing installation receipt");
    Check(sdui::Update(install.game, first.Transport()).starts_with("Already current"), "Latest not detected");
    Check(first.archiveRequests == 1, "Latest unnecessarily downloaded the ZIP");
    Write(install.game / L"AzerothSurvivors.exe", "new game version");
    sdui::Update(install.game, first.Transport());
    Check(first.archiveRequests == 1, "EXE changes triggered an addon download");
    Check(Read(install.game / L"AzerothSurvivors.exe") == "new game version", "Modified game executable");
    Check(Read(install.game / L"avrt.dll") == "unchanged updater", "Replaced updater DLL");
    Check(Read(install.addons / L"OtherAddon/keep.lua") == "other addon", "Modified sibling addon");
    Check(Read(install.game / L"benilla-config/SavedVariables/keep.lua") == "settings", "Modified settings");
}

void UpdateAndRepair() {
    Install install;
    Release first, second("second", 'b', false);
    sdui::Update(install.game, first.Transport());
    Write(install.live / L"retired.lua", "retired file");
    sdui::Update(install.game, second.Transport());
    Check(Read(install.live / L"core/core.lua") == "second", "Update not activated");
    Check(Read(install.backup / L"core/core.lua") == "first", "Previous copy not retained");
    Check(!fs::exists(install.live / L"retired.lua"), "Retired runtime file survived");
    Write(install.live / L"core/core.lua", "damage");
    sdui::Update(install.game, second.Transport());
    Check(Read(install.live / L"core/core.lua") == "second", "Same-version corruption not repaired");
    fs::remove(install.live / L"SurvivorsDragonUi.toc");
    sdui::Update(install.game, second.Transport());
    Check(fs::exists(install.live / L"SurvivorsDragonUi.toc"), "Missing TOC not repaired");
}

void OfflineAndRecovery() {
    Install install;
    Release first;
    const sdui::Download offline = [](const auto&, auto) -> Bytes { throw std::runtime_error("offline"); };
    Fails([&] { sdui::Update(install.game, offline); });
    Check(!fs::exists(install.live), "Offline first install fabricated an addon");
    sdui::Update(install.game, first.Transport());
    Fails([&] { sdui::Update(install.game, offline); });
    Check(Read(install.live / L"core/core.lua") == "first", "Offline removed an existing addon");
    Release second("second", 'b');
    const auto online = second.Transport();
    const sdui::Download interrupted = [&](const auto& url, auto limit) -> Bytes {
        if (url == sdui::ManifestUrl) return online(url, limit);
        throw std::runtime_error("archive transfer interrupted");
    };
    Fails([&] { sdui::Update(install.game, interrupted); });
    Check(Read(install.live / L"core/core.lua") == "first", "Interrupted download damaged live files");
    fs::rename(install.live, install.backup);
    Fails([&] { sdui::Update(install.game, offline); });
    Check(Read(install.live / L"core/core.lua") == "first", "Offline interrupted-swap recovery failed");
}

void RejectBadDownloads() {
    Install install;
    Release first;
    sdui::Update(install.game, first.Transport());
    const auto unchanged = [&] {
        Check(Read(install.live / L"core/core.lua") == "first", "Invalid download changed live files");
    };
    Release corrupt("second", 'b');
    corrupt.zip.back() ^= 1;
    Fails([&] { sdui::Update(install.game, corrupt.Transport()); }); unchanged();
    Release wrongFile("second", 'b');
    wrongFile.manifest["files"][0]["sha256"] = std::string(64, '0');
    Fails([&] { sdui::Update(install.game, wrongFile.Transport()); }); unchanged();
    Release truncated("second", 'b');
    truncated.zip.resize(30);
    truncated.manifest["archive"] = {{"size", truncated.zip.size()}, {"sha256", sdui::Sha256(truncated.zip)}};
    Fails([&] { sdui::Update(install.game, truncated.Transport()); }); unchanged();
    Release extra("second", 'b');
    extra.files["../escape.lua"] = "escape";
    extra.zip = Zip(extra.files);
    extra.manifest["archive"] = {{"size", extra.zip.size()}, {"sha256", sdui::Sha256(extra.zip)}};
    Fails([&] { sdui::Update(install.game, extra.Transport()); }); unchanged();
    Check(!fs::exists(install.addons / L"escape.lua"), "Archive escaped the addon directory");
    Release unsafe("second", 'b');
    unsafe.manifest["files"][0]["path"] = "../escape.lua";
    Fails([&] { sdui::Update(install.game, unsafe.Transport()); }); unchanged();
    Release duplicate("second", 'b');
    auto entry = duplicate.manifest["files"][0];
    entry["path"] = "SURVIVORSDRAGONUI.TOC";
    duplicate.manifest["files"].push_back(entry);
    Fails([&] { sdui::Update(install.game, duplicate.Transport()); }); unchanged();
    Release huge("second", 'b');
    huge.manifest["files"][0]["size"] = 1024ull * 1024 * 1024;
    Fails([&] { sdui::Update(install.game, huge.Transport()); }); unchanged();
}

void RollbackActivationFailure() {
    Install install;
    Release first, second("second", 'b');
    sdui::Update(install.game, first.Transport());
    Fails([&] {
        sdui::Update(install.game, second.Transport(), [] { throw std::runtime_error("activation failed"); });
    });
    Check(Read(install.live / L"core/core.lua") == "first", "Failed activation did not roll back");
    sdui::Update(install.game, second.Transport());
    Check(Read(install.live / L"core/core.lua") == "second", "Cannot retry after rollback");
}

void RejectReparsePoints() {
    Install install;
    Release first;
    const auto outside = install.game / L"outside";
    Write(outside / L"keep.lua", "keep");
    fs::create_directories(install.addons);
    HANDLE token{};
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &token)) {
        TOKEN_PRIVILEGES privilege{};
        privilege.PrivilegeCount = 1;
        if (LookupPrivilegeValueW(nullptr, SE_CREATE_SYMBOLIC_LINK_NAME, &privilege.Privileges[0].Luid)) {
            privilege.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
            AdjustTokenPrivileges(token, FALSE, &privilege, 0, nullptr, nullptr);
        }
        CloseHandle(token);
    }
    Check(CreateSymbolicLinkW(install.live.c_str(), outside.c_str(),
        SYMBOLIC_LINK_FLAG_DIRECTORY | SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE) != 0,
        "CI runner must permit the directory-link fixture");
    Fails([&] { sdui::Update(install.game, first.Transport()); });
    Check(Read(outside / L"keep.lua") == "keep", "Followed addon directory link");
    fs::remove(install.live);
}

void PathsAndHashes() {
    Check(sdui::Sha256(BytesOf("abc")) ==
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA-256 mismatch");
    for (const auto* name : {"../x", "a/../../x", "a\\b", "C:/x", "/x", "a:x", "a/", "a//b",
                             "CON", "a/NUL.lua", "a./x", ".sdui-release.json", "a/LPT1.txt"}) {
        Check(!sdui::SafeRelativePath(name), "Accepted unsafe Windows path");
    }
    Check(sdui::SafeRelativePath("media/tex/actionbars/Gryphon.tga"), "Rejected runtime path");
}

void ActualRelease(const fs::path& dist) {
    Install install;
    int archives{};
    const sdui::Download transport = [&](const std::wstring& url, std::size_t) {
        if (url == sdui::ManifestUrl) return BytesOf(Read(dist / L"updater-manifest.json"));
        ++archives;
        return BytesOf(Read(dist / L"SurvivorsDragonUi.zip"));
    };
    sdui::Update(install.game, transport);
    Check(fs::exists(install.live / L"SurvivorsDragonUi.toc"), "Actual release TOC is missing");
    Check(sdui::Update(install.game, transport).starts_with("Already current"), "Actual release not current");
    Check(archives == 1, "Actual release ZIP downloaded twice");
    std::cout << "Installed and verified the complete release ZIP without executing Lua.\n";
}
} // namespace

int main(int argc, char* argv[]) {
    try {
        if (argc == 3 && std::string(argv[1]) == "--release") {
            ActualRelease(fs::absolute(argv[2]));
            return 0;
        }
        PathsAndHashes(); std::cout << "Paths and SHA-256\n";
        InstallAndLatest(); std::cout << "First install, latest detection, EXE independence and sibling isolation\n";
        UpdateAndRepair(); std::cout << "Update, stored ZIP and same-version repair\n";
        OfflineAndRecovery(); std::cout << "Offline first/existing install and interrupted-swap recovery\n";
        RejectBadDownloads(); std::cout << "Invalid hashes, ZIPs, paths, duplicates and size bounds\n";
        RollbackActivationFailure(); std::cout << "Activation rollback and retry\n";
        RejectReparsePoints(); std::cout << "Directory-link refusal\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
