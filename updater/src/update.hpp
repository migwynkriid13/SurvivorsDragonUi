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
inline constexpr std::uint64_t StartupDownloadBudgetMs = 10000;

std::string Sha256(std::span<const std::uint8_t> bytes);
bool SafeRelativePath(const std::string& name);
std::filesystem::path AddonDirectory(const std::filesystem::path& game);
// Callers own the exclusive startup session lock while staging or activating.
std::string StageUpdate(const std::filesystem::path& game, const Download& download);
// Activation and recovery use local files only. The callback is a CI failure fixture.
std::string ApplyPending(const std::filesystem::path& game,
                         const std::function<void()>& beforeActivate = {});
// One absolute deadline covers metadata and ZIP transfer. Local verification and
// atomic activation finish before returning to the game's original entrypoint.
std::string UpdateAtStartup(const std::filesystem::path& game, const Download& download,
                           std::uint64_t deadline, const std::function<std::uint64_t()>& now,
                           const std::function<void()>& beforeActivate = {});
Bytes DownloadHttps(const std::wstring& url, std::size_t limit, std::uint64_t deadline);
void InitializeUpdater() noexcept;
} // namespace sdui
