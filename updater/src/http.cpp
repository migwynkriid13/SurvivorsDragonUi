#include <windows.h>
#include <winhttp.h>
#include <process.h>

#include "update.hpp"
#include "coordination.hpp"
#include "version.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <fstream>
#include <memory>
#include <stdexcept>

namespace sdui {
namespace {
struct Internet {
    HINTERNET handle{};
    explicit Internet(HINTERNET value) : handle(value) {
        if (!handle) throw std::runtime_error("HTTPS is unavailable");
    }
    ~Internet() { WinHttpCloseHandle(handle); }
    Internet(const Internet&) = delete;
    Internet& operator=(const Internet&) = delete;
};

void Check(BOOL success) {
    if (!success) throw std::runtime_error("HTTPS request failed (offline, timeout or server error)");
}

void Timeout(HINTERNET handle, std::uint64_t deadline) {
    const auto now = GetTickCount64();
    if (now >= deadline) throw std::runtime_error("Update download time budget expired");
    const auto timeout = static_cast<int>(std::min<std::uint64_t>(1500, deadline - now));
    Check(WinHttpSetTimeouts(handle, timeout, timeout, timeout, timeout));
}

// The callback context and read buffer outlive cancellation. The owner and
// request handle each hold a reference until HANDLE_CLOSING, the last callback.
struct RequestState {
    std::atomic<unsigned> references{1};
    std::atomic<DWORD> status{};
    std::atomic<DWORD> error{};
    std::atomic<DWORD> received{};
    HANDLE completed{};
    std::array<std::uint8_t, 32768> buffer{};
    RequestState() {
        completed = CreateEventW(nullptr, FALSE, FALSE, nullptr);
        if (!completed) throw std::runtime_error("Cannot create HTTPS completion event");
    }
    void AddRef() noexcept { references.fetch_add(1); }
    void Release() noexcept {
        if (references.fetch_sub(1) == 1) { CloseHandle(completed); delete this; }
    }
    static void CALLBACK Callback(HINTERNET, DWORD_PTR context, DWORD notification,
                                  LPVOID information, DWORD length) noexcept {
        auto* self = reinterpret_cast<RequestState*>(context);
        if (!self) return;
        self->AddRef();
        if (notification == WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING) {
            self->Release(); // The handle's reference.
        } else if (notification == WINHTTP_CALLBACK_STATUS_REQUEST_ERROR) {
            const auto* result = static_cast<const WINHTTP_ASYNC_RESULT*>(information);
            self->error.store(result ? result->dwError : ERROR_GEN_FAILURE);
            self->status.store(notification);
            SetEvent(self->completed);
        } else if (notification == WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE ||
                   notification == WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE ||
                   notification == WINHTTP_CALLBACK_STATUS_READ_COMPLETE) {
            if (notification == WINHTTP_CALLBACK_STATUS_READ_COMPLETE) self->received.store(length);
            self->status.store(notification);
            SetEvent(self->completed);
        }
        self->Release(); // This callback's reference.
    }
};

struct Request {
    HINTERNET handle{};
    RequestState* state{};
    Request(HINTERNET connection, const std::wstring& path) : state(new RequestState) {
        try {
            handle = WinHttpOpenRequest(connection, L"GET", path.c_str(), nullptr,
                WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE | WINHTTP_FLAG_REFRESH);
            Check(handle != nullptr);
            DWORD_PTR context = reinterpret_cast<DWORD_PTR>(state);
            Check(WinHttpSetOption(handle, WINHTTP_OPTION_CONTEXT_VALUE, &context, sizeof(context)));
            if (WinHttpSetStatusCallback(handle, &RequestState::Callback,
                    WINHTTP_CALLBACK_FLAG_ALL_COMPLETIONS | WINHTTP_CALLBACK_FLAG_HANDLES, 0) ==
                WINHTTP_INVALID_STATUS_CALLBACK) throw std::runtime_error("Cannot register HTTPS callback");
            state->AddRef(); // Released only by HANDLE_CLOSING.
        } catch (...) {
            if (handle) WinHttpCloseHandle(handle);
            state->Release();
            throw;
        }
    }
    ~Request() {
        // Closing an asynchronous request cancels pending work. No wait under a
        // loader lock or call against a closed synchronous handle is required.
        WinHttpCloseHandle(handle);
        state->Release();
    }
    void Begin() {
        ResetEvent(state->completed);
        state->error.store(ERROR_SUCCESS);
        state->status.store(0);
    }
    void Wait(BOOL started, DWORD expected, std::uint64_t deadline) {
        if (!started && GetLastError() != ERROR_IO_PENDING) Check(FALSE);
        const auto now = GetTickCount64();
        if (now >= deadline || WaitForSingleObject(state->completed,
                static_cast<DWORD>(deadline - now)) != WAIT_OBJECT_0) {
            throw std::runtime_error("Update download time budget expired");
        }
        if (state->error.load() || state->status.load() != expected) Check(FALSE);
    }
    Request(const Request&) = delete;
    Request& operator=(const Request&) = delete;
};

bool AllowedHost(const std::wstring& host) {
    return host == L"github.com" || host == L"release-assets.githubusercontent.com" ||
           host == L"objects.githubusercontent.com";
}

void Log(const std::filesystem::path& game, const std::string& message) noexcept {
    try {
        const auto path = game / L"SurvivorsDragonUi-updater.log";
        // Do not follow a user-created log junction/symlink.
        const auto attributes = GetFileAttributesW(path.c_str());
        if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT)) return;
        std::ofstream output(path, std::ios::trunc);
        output << "SurvivorsDragonUi updater " SDUI_UPDATER_VERSION "\n" << message << '\n';
    } catch (...) {}
}

struct BackgroundWork { std::filesystem::path game; };

unsigned __stdcall DownloadInBackground(void* context) noexcept {
    std::unique_ptr<BackgroundWork> work(static_cast<BackgroundWork*>(context));
    try {
        detail::WorkerLock lock(work->game);
        if (lock.file == INVALID_HANDLE_VALUE) return 0;
        const auto deadline = GetTickCount64() + 12000;
        Log(work->game, StageUpdate(work->game, [deadline](const auto& url, auto limit) {
            return DownloadHttps(url, limit, deadline);
        }));
    } catch (const std::exception& error) {
        Log(work->game, std::string("Background update skipped: ") + error.what());
    } catch (...) {
        Log(work->game, "Background update skipped: unexpected failure.");
    }
    return 0;
}
} // namespace

Bytes DownloadHttps(const std::wstring& initial, std::size_t limit, std::uint64_t deadline) {
    Internet session(WinHttpOpen(SDUI_UPDATER_USER_AGENT,
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, WINHTTP_FLAG_ASYNC));
    Timeout(session.handle, deadline);
    DWORD protocols = WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2;
    Check(WinHttpSetOption(session.handle, WINHTTP_OPTION_SECURE_PROTOCOLS, &protocols, sizeof(protocols)));
    auto url = initial;
    for (int redirect = 0; redirect < 6; ++redirect) {
        URL_COMPONENTS parts{};
        parts.dwStructSize = sizeof(parts);
        parts.dwHostNameLength = parts.dwUrlPathLength = parts.dwExtraInfoLength = static_cast<DWORD>(-1);
        parts.dwUserNameLength = parts.dwPasswordLength = static_cast<DWORD>(-1);
        Check(WinHttpCrackUrl(url.c_str(), 0, 0, &parts));
        const std::wstring host(parts.lpszHostName, parts.dwHostNameLength);
        if (parts.nScheme != INTERNET_SCHEME_HTTPS || parts.nPort != INTERNET_DEFAULT_HTTPS_PORT ||
            parts.dwUserNameLength || parts.dwPasswordLength || !AllowedHost(host)) {
            throw std::runtime_error("Refusing untrusted download URL");
        }
        auto path = std::wstring(parts.lpszUrlPath, parts.dwUrlPathLength);
        if (parts.dwExtraInfoLength) path.append(parts.lpszExtraInfo, parts.dwExtraInfoLength);
        Internet connection(WinHttpConnect(session.handle, host.c_str(), parts.nPort, 0));
        Request request(connection.handle, path);
        DWORD disabled = WINHTTP_DISABLE_REDIRECTS | WINHTTP_DISABLE_COOKIES | WINHTTP_DISABLE_AUTHENTICATION;
        Check(WinHttpSetOption(request.handle, WINHTTP_OPTION_DISABLE_FEATURE, &disabled, sizeof(disabled)));
        Timeout(request.handle, deadline);
        request.Begin();
        request.Wait(WinHttpSendRequest(request.handle, L"Cache-Control: no-cache\r\n", static_cast<DWORD>(-1),
            WINHTTP_NO_REQUEST_DATA, 0, 0, reinterpret_cast<DWORD_PTR>(request.state)),
            WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE, deadline);
        Timeout(request.handle, deadline);
        request.Begin();
        request.Wait(WinHttpReceiveResponse(request.handle, nullptr),
            WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE, deadline);
        DWORD status{}, size = sizeof(status);
        Check(WinHttpQueryHeaders(request.handle, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
            WINHTTP_HEADER_NAME_BY_INDEX, &status, &size, WINHTTP_NO_HEADER_INDEX));
        if (status == 301 || status == 302 || status == 303 || status == 307 || status == 308) {
            std::array<wchar_t, 8192> location{};
            size = static_cast<DWORD>(sizeof(location));
            Check(WinHttpQueryHeaders(request.handle, WINHTTP_QUERY_LOCATION, WINHTTP_HEADER_NAME_BY_INDEX,
                location.data(), &size, WINHTTP_NO_HEADER_INDEX));
            url.assign(location.data(), size / sizeof(wchar_t));
            while (!url.empty() && url.back() == L'\0') url.pop_back();
            continue;
        }
        if (status != 200) throw std::runtime_error("Release download is unavailable");
        Bytes bytes;
        for (;;) {
            Timeout(request.handle, deadline);
            request.Begin();
            request.Wait(WinHttpReadData(request.handle, request.state->buffer.data(),
                static_cast<DWORD>(request.state->buffer.size()), nullptr),
                WINHTTP_CALLBACK_STATUS_READ_COMPLETE, deadline);
            const auto received = request.state->received.load();
            if (!received) return bytes;
            if (received > limit - bytes.size()) throw std::runtime_error("Download exceeds size limit");
            bytes.insert(bytes.end(), request.state->buffer.begin(), request.state->buffer.begin() + received);
        }
    }
    throw std::runtime_error("Too many download redirects");
}

void InitializeUpdater() noexcept {
    std::filesystem::path game;
    try {
        std::array<wchar_t, 32768> executable{};
        const auto length = GetModuleFileNameW(nullptr, executable.data(), static_cast<DWORD>(executable.size()));
        if (!length || length >= executable.size()) return;
        const std::filesystem::path exe(std::wstring(executable.data(), length));
        if (CompareStringOrdinal(exe.filename().c_str(), -1, L"AzerothSurvivors.exe", -1, TRUE) != CSTR_EQUAL) return;
        game = exe.parent_path();
        detail::SessionLock lock(game);
        if (lock.file == INVALID_HANDLE_VALUE) {
            Log(game, "Skipped: installation is not writable or cannot be locked.");
            return;
        }
        if (lock.exclusive) {
            try { Log(game, ApplyPending(game)); }
            catch (const std::exception& error) {
                Log(game, std::string("Pending activation skipped: ") + error.what());
            } catch (...) { Log(game, "Pending activation skipped: unexpected failure."); }
        }
        if (!lock.KeepForGame()) {
            Log(game, "Skipped: cannot retain the game session lock.");
            return;
        }
        auto work = std::make_unique<BackgroundWork>(BackgroundWork{game});
        const auto worker = _beginthreadex(nullptr, 0, &DownloadInBackground, work.get(), 0, nullptr);
        if (!worker) {
            Log(game, "Skipped: cannot start optional background worker.");
            return;
        }
        work.release();
        CloseHandle(reinterpret_cast<HANDLE>(worker));
        // Never join the downloader or wait for network activity at startup.
    } catch (...) {
        if (!game.empty()) Log(game, "Skipped: cannot initialize optional updater.");
    }
}
} // namespace sdui
