cmake_minimum_required(VERSION 3.24)

get_filename_component(repo "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(test_dir "${repo}/bin/arm64-fetchcontent-test")
file(READ "${repo}/utils/arm64/CMakeLists.txt" source)
string(REGEX MATCH
    "include\\(FetchContent\\).*FetchContent_MakeAvailable\\([^)]*\\)"
    population "${source}")
if(population STREQUAL "")
    message(FATAL_ERROR "Could not locate the ARM64 dependency population block.")
endif()

file(MAKE_DIRECTORY "${test_dir}/src")
file(WRITE "${test_dir}/src/CMakeLists.txt"
    "cmake_minimum_required(VERSION 3.24)\n"
    "project(ARM64DependencyPopulationTest LANGUAGES NONE)\n"
    "${population}\n"
    [=[
get_property(upstream_targets DIRECTORY PROPERTY BUILDSYSTEM_TARGETS)
get_property(upstream_directories DIRECTORY PROPERTY SUBDIRECTORIES)
if(upstream_targets OR upstream_directories)
    message(FATAL_ERROR "Dependency population unexpectedly configured an upstream project.")
endif()

foreach(dependency IN ITEMS vigem_native vigem_managed faker_native faker_managed sharposc)
    if(NOT IS_DIRECTORY "${${dependency}_SOURCE_DIR}")
        message(FATAL_ERROR "Sources were not populated for ${dependency}.")
    endif()
endforeach()
if(NOT EXISTS "${vigem_native_SOURCE_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "The ViGEmClient fixture must include its upstream CMake project.")
endif()
if(NOT EXISTS "${vigem_native_SOURCE_DIR}/src/ViGEmClient.cpp"
    OR NOT EXISTS "${faker_native_SOURCE_DIR}/FakerInputDll/fakerinputclient.cpp"
    OR NOT EXISTS "${vigem_managed_SOURCE_DIR}/ViGEmClient/ViGEmClient.cs"
    OR NOT EXISTS "${faker_managed_SOURCE_DIR}/FakerInputWrapper/FakerInput.cs"
    OR NOT EXISTS "${sharposc_SOURCE_DIR}/SharpOSC/OscMessage.cs")
    message(FATAL_ERROR "Expected native or managed dependency source files are missing.")
endif()

# The ARM64 wrapper must remain free to define its own shared library target.
add_library(ViGEmClient SHARED IMPORTED)
message(STATUS "ARM64 dependency population passed: five source trees, no upstream targets, no ViGEmClient collision.")
]=])

execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${test_dir}/src" -B "${test_dir}/build"
    RESULT_VARIABLE result)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "ARM64 dependency population regression test failed: ${result}")
endif()
