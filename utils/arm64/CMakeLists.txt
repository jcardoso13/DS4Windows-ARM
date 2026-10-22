cmake_minimum_required(VERSION 3.24)
project(DS4WindowsArm64Dependencies LANGUAGES CXX RC)

if(NOT MSVC OR NOT CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
    message(FATAL_ERROR "Use Visual Studio with -A ARM64 to build native Windows ARM64 dependencies.")
endif()

include(FetchContent)
FetchContent_Declare(vigem_native
    URL https://github.com/nefarius/ViGEmClient/archive/b66d02d57e32cc8595369c53418b843e958649b4.tar.gz
    URL_HASH SHA256=c2bc824cc96ed18cf0620b734ae552474f107e7e680485e5c0cb63e675d9f72a)
FetchContent_Declare(vigem_managed
    URL https://github.com/nefarius/ViGEm.NET/archive/2197a9a6200a1cc4cbefc19e4ef6c9bbb63ff567.tar.gz
    URL_HASH SHA256=e311e0dbb2fcdc35b88f06fbf5d6c714d186976479f59df7880ee6455e0abccc)
FetchContent_Declare(faker_native
    URL https://github.com/Ryochan7/FakerInputDll/archive/194f8752a5135765645986e7050f2ce5102f9ced.tar.gz
    URL_HASH SHA256=002eacc1bee29a578c242200da1c7aa72afb50a3e0e59a2ee4b241c144f7bd33)
FetchContent_Declare(faker_managed
    URL https://github.com/Ryochan7/FakerInputWrapper/archive/34c9f43825f6279ccd6dff8d062773993ce84889.tar.gz
    URL_HASH SHA256=7301da01c1b50e1b5e2b3aa30ecf2530491b6fff7ed9d3491fec6d2eaba009c3)
FetchContent_Declare(sharposc
    URL https://github.com/ValdemarOrn/SharpOSC/archive/06cfec49a4b2870f2edc00241bffda0f28b74708.tar.gz
    URL_HASH SHA256=aeec845a009a550a5c81fccf1ead4a816402251225fd7b8c2bdc9d404df00fcf)
FetchContent_MakeAvailable(vigem_native vigem_managed faker_native faker_managed sharposc)

get_filename_component(libs "${CMAKE_CURRENT_SOURCE_DIR}/../../DS4Windows/libs/ARM64" ABSOLUTE)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")

add_library(ViGEmClient SHARED
    "${vigem_native_SOURCE_DIR}/src/ViGEmClient.cpp"
    "${vigem_native_SOURCE_DIR}/src/ViGEmClient.rc")
target_include_directories(ViGEmClient PRIVATE "${vigem_native_SOURCE_DIR}/include")
target_compile_definitions(ViGEmClient PRIVATE WIN32_LEAN_AND_MEAN VIGEM_DYNAMIC VIGEM_EXPORTS UNICODE _UNICODE)
target_compile_features(ViGEmClient PRIVATE cxx_std_17)
target_link_libraries(ViGEmClient PRIVATE setupapi)
set_target_properties(ViGEmClient PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${libs}/Nefarius.ViGEm.Client")

add_library(FakerInputDll SHARED
    "${faker_native_SOURCE_DIR}/FakerInputDll/fakerinputclient.cpp"
    "${faker_native_SOURCE_DIR}/FakerInputDll/dllmain.cpp"
    "${faker_native_SOURCE_DIR}/FakerInputDll/FakerInputDll.rc")
target_compile_definitions(FakerInputDll PRIVATE FAKERINPUTLIB_EXPORTS UNICODE _UNICODE)
target_link_libraries(FakerInputDll PRIVATE hid setupapi)
set_target_properties(FakerInputDll PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${libs}/FakerInputWrapper")

find_program(DOTNET_EXECUTABLE dotnet REQUIRED)
function(add_managed_dependency name source)
    add_custom_target(${name} ALL
        COMMAND "${DOTNET_EXECUTABLE}" build "${CMAKE_CURRENT_SOURCE_DIR}/ManagedDependency.csproj"
            --configuration Release
            "-p:DependencyName=${name}"
            "-p:DependencySourceDir=${source}"
            "-p:BaseIntermediateOutputPath=${CMAKE_CURRENT_BINARY_DIR}/obj/${name}/"
            "-p:OutputPath=${libs}/${name}/"
        VERBATIM)
endfunction()

# Build ViGEm without Costura's x86/x64-only embedded native DLL loader.
add_managed_dependency(Nefarius.ViGEm.Client "${vigem_managed_SOURCE_DIR}/ViGEmClient")
add_managed_dependency(FakerInputWrapper "${faker_managed_SOURCE_DIR}/FakerInputWrapper")
add_managed_dependency(SharpOSC "${sharposc_SOURCE_DIR}/SharpOSC")
