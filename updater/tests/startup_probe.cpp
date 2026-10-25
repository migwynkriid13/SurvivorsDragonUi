#include <windows.h>
#include <avrt.h>

#include <array>
#include <iostream>
#include <string>

// This tiny EXE imports the drop-in DLL exactly as a normal Windows program
// does. Its different filename prevents addon writes or network access.
int main() {
    std::array<wchar_t, 32768> path{};
    const auto length = GetSystemDirectoryW(path.data(), static_cast<UINT>(path.size()));
    if (!length || length >= path.size()) return 1;
    const auto system = LoadLibraryExW((std::wstring(path.data()) + L"\\avrt.dll").c_str(),
                                      nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!system) return 2;
    const auto real = reinterpret_cast<decltype(&AvRevertMmThreadCharacteristics)>(
        GetProcAddress(system, "AvRevertMmThreadCharacteristics"));
    if (!real) return 3;
    SetLastError(ERROR_NOT_READY);
    const auto expected = real(nullptr);
    const auto expectedError = GetLastError();
    SetLastError(ERROR_NOT_READY);
    const auto actual = AvRevertMmThreadCharacteristics(nullptr);
    const auto actualError = GetLastError();
    if (actual != expected || actualError != expectedError || actualError == ERROR_NOT_READY) return 4;
    std::cout << "Entrypoint resumed and AVRT forwards to the system library.\n";
    return 0;
}
