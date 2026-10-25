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
// Throws before activation on malformed, incomplete or untrusted input.
// Caller owns the installation lock; fake transport is used only by CI tests.
std::string Update(const std::filesystem::path& game, const Download& download,
                   const std::function<void()>& beforeActivate = {});
Bytes DownloadHttps(const std::wstring& url, std::size_t limit, std::uint64_t deadline);
void InitializeUpdater() noexcept;
} // namespace sdui
