#pragma once
#include <windows.h>
#include <filesystem>

namespace sdui::detail {
inline HANDLE OpenLock(const std::filesystem::path& game) {
    const auto path = game / L"SurvivorsDragonUi-updater.lock";
    const auto attributes = GetFileAttributesW(path.c_str());
    if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT)) return INVALID_HANDLE_VALUE;
    return CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
}

// Byte zero protects local activation. Shared game sessions never block the
// independent background downloader on byte one.
struct SessionLock {
    HANDLE file{INVALID_HANDLE_VALUE};
    OVERLAPPED range{};
    bool exclusive{};
    explicit SessionLock(const std::filesystem::path& game) : file(OpenLock(game)) {
        if (file == INVALID_HANDLE_VALUE) return;
        exclusive = LockFileEx(file, LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY,
            0, 1, 0, &range) != FALSE;
        if (!exclusive && !LockFileEx(file, 0, 0, 1, 0, &range)) {
            CloseHandle(file);
            file = INVALID_HANDLE_VALUE;
        }
    }
    ~SessionLock() { if (file != INVALID_HANDLE_VALUE) CloseHandle(file); }
    bool Share() noexcept {
        if (file == INVALID_HANDLE_VALUE) return false;
        if (!exclusive) return true;
        if (!UnlockFileEx(file, 0, 1, 0, &range) || !LockFileEx(file, 0, 0, 1, 0, &range)) return false;
        exclusive = false;
        return true;
    }
    bool KeepForGame() noexcept {
        if (!Share()) return false;
        file = INVALID_HANDLE_VALUE; // The OS releases the retained handle at process exit.
        return true;
    }
    SessionLock(const SessionLock&) = delete;
    SessionLock& operator=(const SessionLock&) = delete;
};

struct WorkerLock {
    HANDLE file{INVALID_HANDLE_VALUE};
    OVERLAPPED range{};
    explicit WorkerLock(const std::filesystem::path& game) : file(OpenLock(game)) {
        range.Offset = 1;
        if (file != INVALID_HANDLE_VALUE && !LockFileEx(file,
                LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &range)) {
            CloseHandle(file);
            file = INVALID_HANDLE_VALUE;
        }
    }
    ~WorkerLock() { if (file != INVALID_HANDLE_VALUE) CloseHandle(file); }
    WorkerLock(const WorkerLock&) = delete;
    WorkerLock& operator=(const WorkerLock&) = delete;
};
} // namespace sdui::detail
