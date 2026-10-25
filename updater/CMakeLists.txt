cmake_minimum_required(VERSION 3.25)
project(SurvivorsDragonUiUpdater VERSION 1.0.0 LANGUAGES C CXX)

if(NOT WIN32 OR NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "Build the Windows x64 updater with MSVC.")
endif()
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
enable_language(RC)
include(FetchContent)
# Immutable upstream commits; linked statically, with no runtime dependencies.
set(JSON_BuildTests OFF CACHE BOOL "" FORCE)
set(JSON_Install OFF CACHE BOOL "" FORCE)
FetchContent_Declare(json
    GIT_REPOSITORY https://github.com/nlohmann/json.git
    GIT_TAG 55f93686c01528224f448c19128836e7df245f72) # v3.12.0
set(ZLIB_BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(ZLIB_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(ZLIB_BUILD_STATIC ON CACHE BOOL "" FORCE)
set(ZLIB_INSTALL OFF CACHE BOOL "" FORCE)
FetchContent_Declare(zlib
    GIT_REPOSITORY https://github.com/madler/zlib.git
    GIT_TAG da607da739fa6047df13e66a2af6b8bec7c2a498) # v1.3.2
FetchContent_MakeAvailable(json zlib)

add_library(updater_core STATIC src/update.cpp src/http.cpp)
target_link_libraries(updater_core PUBLIC nlohmann_json::nlohmann_json zlibstatic bcrypt winhttp)
target_include_directories(updater_core PUBLIC src)
configure_file(resources.rc.in "${CMAKE_CURRENT_BINARY_DIR}/updater-resources.rc" @ONLY)
add_library(SurvivorsDragonUiUpdater SHARED src/dllmain.cpp src/avrt_proxy.cpp src/avrt_proxy.def
    "${CMAKE_CURRENT_BINARY_DIR}/updater-resources.rc")
target_link_libraries(SurvivorsDragonUiUpdater PRIVATE updater_core user32)
set_target_properties(SurvivorsDragonUiUpdater PROPERTIES OUTPUT_NAME avrt)

include(CTest)
set(owned_targets updater_core SurvivorsDragonUiUpdater)
if(BUILD_TESTING)
    add_executable(UpdaterTests tests/update_tests.cpp)
    target_link_libraries(UpdaterTests PRIVATE updater_core advapi32)
    add_test(NAME addon-update-transactions COMMAND UpdaterTests)
    add_executable(UpdaterStartupProbe tests/startup_probe.cpp)
    target_link_libraries(UpdaterStartupProbe PRIVATE SurvivorsDragonUiUpdater)
    add_test(NAME avrt-startup-handoff COMMAND UpdaterStartupProbe)
    set_tests_properties(addon-update-transactions avrt-startup-handoff PROPERTIES TIMEOUT 30)
    list(APPEND owned_targets UpdaterTests UpdaterStartupProbe)
endif()
foreach(target IN LISTS owned_targets)
    target_compile_features(${target} PRIVATE cxx_std_20)
    set_target_properties(${target} PROPERTIES CXX_EXTENSIONS OFF)
    target_compile_definitions(${target} PRIVATE UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN
        _WIN32_WINNT=0x0A00 WINVER=0x0A00)
    target_compile_options(${target} PRIVATE /W4 /permissive- /utf-8 /EHsc)
endforeach()
