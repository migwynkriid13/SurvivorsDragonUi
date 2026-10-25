#include <windows.h>
#include <zlib.h>
#include <nlohmann/json.hpp>

#include "update.hpp"
#include "coordination.hpp"

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
    explicit Release(std::string text = "first", char commit = 'a', bool compressed = true,
                     std::string version = "1.0.0-survivors")
        : files{{"SurvivorsDragonUi.toc", "## Interface: 11200\n## Version: " + version + "\ncore/core.lua\n"},
                {"core/core.lua", std::move(text)}} {
        zip = Zip(files, compressed);
        manifest = {{"schema", 1}, {"repository", "migwynkriid13/SurvivorsDragonUi"},
            {"tag", "build-" + std::string(40, commit)}, {"version", version},
            {"archive", {{"size", zip.size()}, {"sha256", std::string(64, '0')}}}, {"files", Json::array()}};
        // Deliberately unused SHA values: the runtime must install and compare
        // release markers without hashing the ZIP or the installed payload.
        for (const auto& [name, data] : files) {
            manifest["files"].push_back({{"path", name}, {"size", data.size()},
                                       {"sha256", std::string(64, '0')}});
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
    fs::path storage = game / L"benilla-config" / L"SurvivorsDragonUi-updater";
    fs::path work = storage / L"download" / L"SurvivorsDragonUi";
    fs::path pending = storage / L"pending" / L"SurvivorsDragonUi";
    fs::path backup = storage / L"backup" / L"SurvivorsDragonUi";
    Install() { fs::create_directories(game); }
    ~Install() { std::error_code error; fs::remove_all(game, error); }
};

// Exercise the production startup flow with an immediate fixture transport.
std::string InstallRelease(const fs::path& game, const sdui::Download& transport,
                           const std::function<void()>& beforeActivate = {}) {
    return sdui::UpdateAtStartup(game, transport, sdui::StartupDownloadBudgetMs,
                                [] { return std::uint64_t{}; }, beforeActivate);
}

void InstallAndLatest() {
    Install install;
    Release first;
    Write(install.addons / L"OtherAddon" / L"keep.lua", "other addon");
    Write(install.game / L"benilla-config" / L"SavedVariables" / L"keep.lua", "settings");
    Write(install.game / L"AzerothSurvivors.exe", "unchanged executable");
    Write(install.game / L"avrt.dll", "unchanged updater");
    InstallRelease(install.game, first.Transport());
    Check(Read(install.live / L"core/core.lua") == "first", "Missing first install");
    Check(fs::exists(install.live / L".sdui-release.json"), "Missing installation receipt");
    Check(InstallRelease(install.game, first.Transport()).starts_with("Already current"), "Latest not detected");
    Check(first.archiveRequests == 1, "Latest unnecessarily downloaded the ZIP");
    Write(install.game / L"AzerothSurvivors.exe", "new game version");
    InstallRelease(install.game, first.Transport());
    Check(first.archiveRequests == 1, "EXE changes triggered an addon download");
    Check(Read(install.game / L"AzerothSurvivors.exe") == "new game version", "Modified game executable");
    Check(Read(install.game / L"avrt.dll") == "unchanged updater", "Replaced updater DLL");
    Check(Read(install.addons / L"OtherAddon/keep.lua") == "other addon", "Modified sibling addon");
    Check(Read(install.game / L"benilla-config/SavedVariables/keep.lua") == "settings", "Modified settings");
}

void UpdateAndMissingToc() {
    Install install;
    Release first, second("second", 'b', false);
    InstallRelease(install.game, first.Transport());
    Write(install.live / L"retired.lua", "retired file");
    InstallRelease(install.game, second.Transport());
    Check(Read(install.live / L"core/core.lua") == "second", "Update not activated");
    Check(Read(install.backup / L"core/core.lua") == "first", "Previous copy not retained");
    Check(!fs::exists(install.live / L"retired.lua"), "Retired runtime file survived");
    Write(install.live / L"core/core.lua", "damage");
    InstallRelease(install.game, second.Transport());
    Check(Read(install.live / L"core/core.lua") == "damage", "Current-version startup scanned or repaired local files");
    Check(second.archiveRequests == 1, "Local changes caused a repeated ZIP download");
    fs::remove(install.live / L"SurvivorsDragonUi.toc");
    InstallRelease(install.game, second.Transport());
    Check(fs::exists(install.live / L"SurvivorsDragonUi.toc"), "Missing TOC not repaired");
}

void ReleaseMarkerFastPath() {
    Install install;
    Release first;
    InstallRelease(install.game, first.Transport());
    // Deny all sharing on a payload file: current-version startup must not open
    // it for a hash, size check or content read, or start another ZIP download.
    const auto file = CreateFileW((install.live / L"core/core.lua").c_str(), GENERIC_READ,
        0, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    Check(file != INVALID_HANDLE_VALUE, "Cannot lock the payload fixture against reads");
    try {
        Check(InstallRelease(install.game, first.Transport()).starts_with("Already current"),
              "Current detection tried to read a payload file");
    } catch (...) {
        CloseHandle(file);
        throw;
    }
    CloseHandle(file);
    Check(first.archiveRequests == 1, "Current marker triggered another ZIP download");
    fs::remove(install.live / L".sdui-release.json");
    InstallRelease(install.game, first.Transport());
    Check(first.archiveRequests == 2, "An untracked manual install did not acquire a release marker");
    InstallRelease(install.game, first.Transport());
    Check(first.archiveRequests == 2, "Restored release marker did not skip the ZIP");
}

void OfflineAndRecovery() {
    Install install;
    Release first;
    const sdui::Download offline = [](const auto&, auto) -> Bytes { throw std::runtime_error("offline"); };
    Fails([&] { InstallRelease(install.game, offline); });
    Check(!fs::exists(install.live), "Offline first install fabricated an addon");
    InstallRelease(install.game, first.Transport());
    Fails([&] { InstallRelease(install.game, offline); });
    Check(Read(install.live / L"core/core.lua") == "first", "Offline removed an existing addon");
    Release second("second", 'b');
    const auto online = second.Transport();
    const sdui::Download interrupted = [&](const auto& url, auto limit) -> Bytes {
        if (url == sdui::ManifestUrl) return online(url, limit);
        throw std::runtime_error("archive transfer interrupted");
    };
    Fails([&] { InstallRelease(install.game, interrupted); });
    Check(Read(install.live / L"core/core.lua") == "first", "Interrupted download damaged live files");
    fs::create_directories(install.backup.parent_path());
    fs::rename(install.live, install.backup);
    Fails([&] { InstallRelease(install.game, offline); });
    Check(Read(install.live / L"core/core.lua") == "first", "Offline interrupted-swap recovery failed");
}

void RejectBadDownloads() {
    Install install;
    Release first;
    InstallRelease(install.game, first.Transport());
    const auto unchanged = [&] {
        Check(Read(install.live / L"core/core.lua") == "first", "Invalid download changed live files");
    };
    Release corrupt("second", 'b', false);
    corrupt.zip[30 + std::string("SurvivorsDragonUi/SurvivorsDragonUi.toc").size()] ^= 1;
    Fails([&] { InstallRelease(install.game, corrupt.Transport()); }); unchanged();
    Release wrongFile("second", 'b');
    wrongFile.manifest["files"][0]["size"] = 1;
    Fails([&] { InstallRelease(install.game, wrongFile.Transport()); }); unchanged();
    Release truncated("second", 'b');
    truncated.zip.resize(30);
    truncated.manifest["archive"]["size"] = truncated.zip.size();
    Fails([&] { InstallRelease(install.game, truncated.Transport()); }); unchanged();
    Release extra("second", 'b');
    extra.files["../escape.lua"] = "escape";
    extra.zip = Zip(extra.files);
    extra.manifest["archive"]["size"] = extra.zip.size();
    Fails([&] { InstallRelease(install.game, extra.Transport()); }); unchanged();
    Check(!fs::exists(install.addons / L"escape.lua"), "Archive escaped the addon directory");
    Release unsafe("second", 'b');
    unsafe.manifest["files"][0]["path"] = "../escape.lua";
    Fails([&] { InstallRelease(install.game, unsafe.Transport()); }); unchanged();
    Release duplicate("second", 'b');
    auto entry = duplicate.manifest["files"][0];
    entry["path"] = "SURVIVORSDRAGONUI.TOC";
    duplicate.manifest["files"].push_back(entry);
    Fails([&] { InstallRelease(install.game, duplicate.Transport()); }); unchanged();
    Release huge("second", 'b');
    huge.manifest["files"][0]["size"] = 1024ull * 1024 * 1024;
    Fails([&] { InstallRelease(install.game, huge.Transport()); }); unchanged();
}

void RollbackActivationFailure() {
    Install install;
    Release first, second("second", 'b');
    InstallRelease(install.game, first.Transport());
    Fails([&] {
        InstallRelease(install.game, second.Transport(), [] { throw std::runtime_error("activation failed"); });
    });
    Check(Read(install.live / L"core/core.lua") == "first", "Failed activation did not roll back");
    InstallRelease(install.game, second.Transport());
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
    Fails([&] { InstallRelease(install.game, first.Transport()); });
    Check(Read(outside / L"keep.lua") == "keep", "Followed addon directory link");
    fs::remove(install.live);
}

void Paths() {
    for (const auto* name : {"../x", "a/../../x", "a\\b", "C:/x", "/x", "a:x", "a/", "a//b",
                             "CON", "a/NUL.lua", "a./x", ".sdui-release.json", "a/LPT1.txt"}) {
        Check(!sdui::SafeRelativePath(name), "Accepted unsafe Windows path");
    }
    Check(sdui::SafeRelativePath("media/tex/actionbars/Gryphon.tga"), "Rejected runtime path");
}

void StagingAndRecovery() {
    Install install;
    Release first, second("second", 'b');
    sdui::StageUpdate(install.game, first.Transport());
    Check(!fs::exists(install.live), "Staging published an unactivated addon");
    sdui::ApplyPending(install.game);
    Check(Read(install.live / L"core/core.lua") == "first", "Offline activation failed");
    sdui::StageUpdate(install.game, second.Transport());
    Check(Read(install.live / L"core/core.lua") == "first", "Staging changed installed addon files");
    Check(sdui::StageUpdate(install.game, second.Transport()).starts_with("Already downloaded"),
          "Completed pending download not detected");
    Check(second.archiveRequests == 1, "Repeated pending ZIP download");
    const auto pending = install.pending;
    fs::remove(pending / L"SurvivorsDragonUi.toc");
    Fails([&] { sdui::ApplyPending(install.game); });
    Check(Read(install.live / L"core/core.lua") == "first", "Pending addon without its TOC activated");
    InstallRelease(install.game, second.Transport());
    Check(Read(install.live / L"core/core.lua") == "second", "Completed update not activated");
    sdui::StageUpdate(install.game, first.Transport());
    Write(pending / L".sdui-release.json", "broken receipt");
    InstallRelease(install.game, first.Transport());
    Check(Read(install.live / L"core/core.lua") == "first", "Corrupt pending receipt blocked online replacement");
    sdui::StageUpdate(install.game, second.Transport());
    const auto work = install.work;
    fs::rename(pending, work);
    sdui::ApplyPending(install.game);
    Check(Read(install.live / L"core/core.lua") == "second", "Completed interrupted staging not recovered");
}

void RefuseDowngrade() {
    Install install;
    Release old("old", 'a'), newer("new", 'b', true, "1.1.0-survivors");
    InstallRelease(install.game, newer.Transport());
    Check(sdui::StageUpdate(install.game, old.Transport()).starts_with("Installed addon is newer"),
          "Remote older release was accepted");
    Check(old.archiveRequests == 0, "Downloaded older ZIP");
    Release pending("pending", 'c', true, "1.2.0-survivors");
    sdui::StageUpdate(install.game, pending.Transport());
    Write(install.live / L"SurvivorsDragonUi.toc", "## Version: 1.3.0-survivors\n");
    Write(install.live / L"core/core.lua", "manual latest");
    sdui::ApplyPending(install.game);
    Check(Read(install.live / L"core/core.lua") == "manual latest", "Stale pending update downgraded a manual install");
}

void CanonicalFirstInstall() {
    Install install;
    Release first, second("second", 'b', true, "1.1.0-survivors");
    Write(install.addons / L"SurvivorsDragonUiX" / L"keep.lua", "renamed user copy");
    const auto transport = first.Transport();
    const sdui::Download observe = [&](const auto& url, auto limit) {
        Check(!fs::exists(install.live), "An incomplete addon directory appeared during download");
        return transport(url, limit);
    };
    Check(InstallRelease(install.game, observe).find("Activated downloaded addon") != std::string::npos,
          "Startup did not report the fresh installation");
    Check(sdui::AddonDirectory(install.game) == install.live, "Wrong shared addon directory");
    Check(Read(install.live / L"core/core.lua") == "first", "Fresh download needs another launch to install");
    Check(fs::exists(install.live / L"SurvivorsDragonUi.toc"), "Canonical TOC missing");
    Check(!fs::exists(install.pending), "Fresh installation left a pending addon");
    Check(Read(install.live / L".sdui-release.json").find("build-") != std::string::npos,
          "Fresh installation lost its completed release receipt");
    const auto secondTransport = second.Transport();
    InstallRelease(install.game, [&](const auto& url, auto limit) {
        Check(Read(install.live / L"core/core.lua") == "first", "Download changed the installed addon prematurely");
        return secondTransport(url, limit);
    });
    Check(Read(install.live / L"core/core.lua") == "second", "Startup returned before the update was installed");
    Check(!fs::exists(install.pending), "Startup left the new version waiting for another launch");
    for (const auto& entry : fs::directory_iterator(install.addons)) {
        const auto name = entry.path().filename();
        Check(name == L"SurvivorsDragonUi" || name == L"SurvivorsDragonUiX",
              "Updater exposed a temporary folder in AddOns");
    }
    Check(Read(install.backup / L"core/core.lua") == "first", "Rollback copy is not stored outside AddOns");
    Check(Read(install.addons / L"SurvivorsDragonUiX" / L"keep.lua") == "renamed user copy",
          "Renamed user addon was modified");
}

void StartupDownloadDeadline() {
    Install install;
    Release first, second("second", 'b', true, "1.1.0-survivors");
    const sdui::Download offline = [](const auto&, auto) -> Bytes { throw std::runtime_error("offline"); };
    Fails([&] { InstallRelease(install.game, offline); });
    Check(!fs::exists(install.live), "Offline fresh install created a fake addon directory");
    Release corrupt;
    corrupt.zip.back() ^= 1;
    Fails([&] { InstallRelease(install.game, corrupt.Transport()); });
    Check(!fs::exists(install.live), "Bad first download published an incomplete addon");

    // Advance a monotonic clock instead of sleeping. Metadata and ZIP must
    // share one deadline; giving each request ten seconds would fail these cases.
    const auto timed = [&](Release& release, std::uint64_t metadataMs, std::uint64_t zipMs) {
        std::uint64_t tick = 500;
        const auto deadline = tick + sdui::StartupDownloadBudgetMs;
        const auto transport = release.Transport();
        return sdui::UpdateAtStartup(install.game, [&](const auto& url, auto limit) {
            tick += url == sdui::ManifestUrl ? metadataMs : zipMs;
            return transport(url, limit);
        }, deadline, [&] { return tick; });
    };
    Fails([&] { timed(first, 4500, 5500); });
    Check(!fs::exists(install.live) && !fs::exists(install.pending) && !fs::exists(install.work),
          "A first download finishing at the deadline was installed or staged");
    const auto archives = first.archiveRequests;
    Fails([&] { timed(first, 10000, 0); });
    Check(first.archiveRequests == archives, "Expired metadata still started the ZIP download");
    timed(first, 4000, 5999);
    Check(Read(install.live / L"core/core.lua") == "first", "In-budget first install did not finish before startup returned");

    Fails([&] { timed(second, 6000, 4001); });
    Check(Read(install.live / L"core/core.lua") == "first", "Late update replaced the existing addon");
    Check(!fs::exists(install.pending) && !fs::exists(install.work), "Late ZIP was retained for activation");
    sdui::ApplyPending(install.game);
    Check(Read(install.live / L"core/core.lua") == "first", "Timed-out download activated after startup");
    timed(second, 6000, 3999);
    Check(Read(install.live / L"core/core.lua") == "second", "In-budget update required another game launch");
    Check(Read(install.backup / L"core/core.lua") == "first", "Startup update lost the rollback copy");
    int requests{};
    Fails([&] {
        sdui::UpdateAtStartup(install.game, [&](const auto&, auto) -> Bytes {
            ++requests;
            return {};
        }, 10000, [] { return std::uint64_t{10000}; });
    });
    Check(requests == 0, "An exhausted startup budget still made a request");
}

void LegacyFolderMigration() {
    Install install;
    Release first;
    sdui::StageUpdate(install.game, first.Transport());
    fs::create_directories(install.addons);
    const auto legacyPending = install.addons / L".SurvivorsDragonUi-update";
    const auto legacyWork = install.addons / L".SurvivorsDragonUi-download";
    fs::rename(install.pending, legacyPending);
    Write(legacyWork / L"partial.lua", "interrupted old extraction");
    sdui::ApplyPending(install.game);
    Check(Read(install.live / L"core/core.lua") == "first", "Legacy pending update was not activated offline");
    Check(!fs::exists(legacyPending) && !fs::exists(legacyWork), "Legacy updater folders remain under AddOns");
    Check(Read(install.work / L"partial.lua") == "interrupted old extraction", "Legacy work was discarded instead of moved");
    fs::remove_all(install.live);
    const auto legacyBackup = install.addons / L".SurvivorsDragonUi-backup";
    Write(legacyBackup / L"core/core.lua", "previous addon");
    sdui::ApplyPending(install.game);
    Check(Read(install.live / L"core/core.lua") == "previous addon", "Legacy backup failed offline recovery");
    Check(!fs::exists(legacyBackup), "Legacy backup name was not retired");
}

void RecoveryOutsideAddOns() {
    Install install;
    Write(install.backup / L"core/core.lua", "previous complete addon");
    Check(!fs::exists(install.addons), "Recovery fixture already has an AddOns parent");
    sdui::ApplyPending(install.game);
    Check(Read(install.live / L"core/core.lua") == "previous complete addon",
          "External backup did not recreate the missing AddOns parent");
}

void SessionLocks() {
    Install install;
    {
        sdui::detail::SessionLock first(install.game);
        Check(first.file != INVALID_HANDLE_VALUE && first.exclusive, "Cannot acquire exclusive startup ownership");
        HANDLE contender = sdui::detail::OpenLock(install.game);
        OVERLAPPED range{};
        Check(contender != INVALID_HANDLE_VALUE, "Cannot open competing startup lock");
        const bool acquired = LockFileEx(contender, LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &range) != FALSE;
        CloseHandle(contender);
        Check(!acquired, "A competing game could start reading files during startup activation");
        Check(first.Share(), "Cannot register first game session");
        sdui::detail::SessionLock second(install.game);
        Check(second.file != INVALID_HANDLE_VALUE && !second.exclusive, "Active game failed to prevent updates");
    }
    sdui::detail::SessionLock next(install.game);
    Check(next.file != INVALID_HANDLE_VALUE && next.exclusive, "Closed game sessions still prevent updates");
}

void ActualRelease(const fs::path& dist) {
    Install install;
    int archives{};
    const sdui::Download transport = [&](const std::wstring& url, std::size_t) {
        if (url == sdui::ManifestUrl) return BytesOf(Read(dist / L"updater-manifest.json"));
        ++archives;
        return BytesOf(Read(dist / L"SurvivorsDragonUi.zip"));
    };
    InstallRelease(install.game, transport);
    Check(fs::exists(install.live / L"SurvivorsDragonUi.toc"), "Actual release TOC is missing");
    Check(InstallRelease(install.game, transport).starts_with("Already current"), "Actual release not current");
    Check(archives == 1, "Actual release ZIP downloaded twice");
    std::cout << "Installed the complete release ZIP without hashing payload files or executing Lua.\n";
}
} // namespace

int main(int argc, char* argv[]) {
    try {
        if (argc == 3 && std::string(argv[1]) == "--release") {
            ActualRelease(fs::absolute(argv[2]));
            return 0;
        }
        StagingAndRecovery(); std::cout << "Completed staging, local activation and interrupted extraction recovery\n";
        CanonicalFirstInstall(); std::cout << "Canonical first install and updater storage outside AddOns\n";
        StartupDownloadDeadline(); std::cout << "Shared ten-second startup deadline, late-download refusal and same-launch activation\n";
        LegacyFolderMigration(); std::cout << "Legacy staging and backup folder migration\n";
        RecoveryOutsideAddOns(); std::cout << "Backup recovery without an existing AddOns parent\n";
        RefuseDowngrade(); std::cout << "Older remote and pending releases do not downgrade\n";
        SessionLocks(); std::cout << "Exclusive startup and shared game sessions prevent live-file replacement\n";
        Paths(); std::cout << "Safe relative paths\n";
        InstallAndLatest(); std::cout << "First install, latest detection, EXE independence and sibling isolation\n";
        UpdateAndMissingToc(); std::cout << "Update, stored ZIP, metadata-only current detection and missing TOC recovery\n";
        ReleaseMarkerFastPath(); std::cout << "Current release skips payload reads and restores a missing release marker once\n";
        OfflineAndRecovery(); std::cout << "Offline first/existing install and interrupted-swap recovery\n";
        RejectBadDownloads(); std::cout << "Invalid ZIP CRC, headers, paths, duplicates and size bounds\n";
        RollbackActivationFailure(); std::cout << "Activation rollback and retry\n";
        RejectReparsePoints(); std::cout << "Directory-link refusal\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
