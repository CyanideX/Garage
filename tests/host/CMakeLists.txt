cmake_minimum_required(VERSION 3.20)
project(GarageHostChecks LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(XU "${CMAKE_CURRENT_SOURCE_DIR}/../../../XUtils/v2/red4ext/plugins/XUtils")
set(RED4EXT_SDK_ROOT "${XU}/build/_deps/red4extsdk-src" CACHE PATH "RED4ext.SDK checkout")

# Cloud.cpp on its own: its helpers clash with TrackJson.cpp's in one translation unit
add_executable(verify_v3 verify_v3.cpp "${XU}/src/Motion/Cloud.cpp")
target_include_directories(verify_v3 PRIVATE "${XU}/src" "${XU}/tests" "${RED4EXT_SDK_ROOT}/include")
target_compile_definitions(verify_v3 PRIVATE XUTILS_HOST_TEST=1)
if(MSVC)
    target_compile_options(verify_v3 PRIVATE /EHsc /permissive- /Zc:preprocessor)
    target_compile_definitions(verify_v3 PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()
