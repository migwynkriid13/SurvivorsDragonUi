#pragma once

#include <cstdint>
#include <filesystem>
#include <functional>
#include <span>
#include <string>
#include <vector>

namespace sdui {
using Bytes = std::vector<std::uint8_t>;
using Download = std::function<Bytes(const std::wstring&, std::size_t)>;
inline constexpr wchar_t ManifestUrl[] =
    L"https://github.com/migwynkriid13/SurvivorsDragonUi/releases/latest/download/updater-manifest.json";
inline constexpr std::size_t ManifestLimit = 1024 * 1024;
inline constexpr std::size_t ArchiveLimit = 64 * 1024 * 1024;

std::string Sha256(std::span<const std::uint8_t> bytes);
bool SafeRelativePath(const std::string& name);
std::filesystem::path AddonDirectory(const std::filesystem::path& game);
// Existing addons are never replaced in the background. First-install permission
// requires an exclusive startup session with no addon directory at that time.
std::string StageUpdate(const std::filesystem::path& game, const Download& download,
                        bool allowFirstInstall = false);
// Startup activation uses local files only, with no network or worker wait.
// Caller owns the exclusive session lock; the callback is a CI failure fixture.
std::string ApplyPending(const std::filesystem::path& game,
                         const std::function<void()>& beforeActivate = {});
Bytes DownloadHttps(const std::wstring& url, std::size_t limit, std::uint64_t deadline);
void InitializeUpdater() noexcept;
} // namespace sdui
