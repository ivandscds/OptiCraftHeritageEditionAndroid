# android.cmake - Android (NDK) build branch for OptiCraft.
#
# Included from CMakeLists.txt when the NDK toolchain is active (it defines
# ANDROID), then the caller return()s so none of the desktop/PS2/Wii
# configuration runs. It reuses the desktop "pc" tree unchanged: SDL2 for
# window/input/audio, glad for the GL entry points, and gl4es to translate
# the fixed-function OpenGL 1.x calls onto the GLES 2.0 context SDL creates.
#
# Output: libmain.so (loaded by SDLActivity) plus libSDL2.so.

cmake_minimum_required(VERSION 3.21)

include(${CMAKE_SOURCE_DIR}/cmake/SourceSelection.cmake)

# Static third-party libs end up inside a shared library.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(MC_LOG_LEVEL "0" CACHE STRING "Unified diagnostic verbosity: 0=off, 1=info, 2=debug, 3=trace")
set_property(CACHE MC_LOG_LEVEL PROPERTY STRINGS 0 1 2 3)

# Same low-end tuning profile as the 32-bit desktop build (async chunk gen,
# bounded pathfinding, throttled entity AI). Off by default: phones are far
# faster than the hardware that profile was written for.
option(ANDROID_LEGACY_PROFILE "Enable the PC_LEGACY_BUILD tuning profile" OFF)

# --- Third-party dependencies -------------------------------------------------
foreach(_dep SDL2 SDL_net zlib glad gl4es)
    if(NOT EXISTS "${CMAKE_SOURCE_DIR}/external/${_dep}/CMakeLists.txt")
        message(FATAL_ERROR
            "external/${_dep} is empty or missing. See README-android.md for how to fetch it.")
    endif()
endforeach()

# SDLActivity loads libSDL2.so, so SDL must be the shared build here.
set(SDL_SHARED ON CACHE BOOL "Build the SDL shared library" FORCE)
set(SDL_STATIC OFF CACHE BOOL "Build the SDL static library" FORCE)
set(SDL_TEST OFF CACHE BOOL "Build the SDL test library" FORCE)
set(ZLIB_BUILD_EXAMPLES OFF CACHE BOOL "Build zlib examples" FORCE)
add_subdirectory(external/SDL2)

# gl4es as a static library: SDL owns the EGL/GLES context, gl4es is initialised
# from GLContext.cpp through include/gl4esinit.h (no loader, no constructors).
set(STATICLIB ON CACHE BOOL "" FORCE)
set(NO_LOADER ON CACHE BOOL "" FORCE)
set(NO_INIT_CONSTRUCTOR ON CACHE BOOL "" FORCE)
set(USE_ANDROID_LOG ON CACHE BOOL "" FORCE)
add_subdirectory(external/gl4es gl4es EXCLUDE_FROM_ALL)

add_subdirectory(external/glad EXCLUDE_FROM_ALL)
add_subdirectory(external/zlib EXCLUDE_FROM_ALL)

set(BUILD_SHARED_LIBS OFF)
set(SDL2NET_SAMPLES OFF CACHE BOOL "" FORCE)
add_subdirectory(external/SDL_net EXCLUDE_FROM_ALL)

# --- Sources -------------------------------------------------------------------
# Android is UNIX but not desktop Linux: take the pc tree and drop the Windows
# half. The pc/linux helpers (File, Resource, Runtime) are patched for Android.
mcbeta_collect_platform_sources(OPTICRAFT_SOURCES pc)
mcbeta_exclude_sources(OPTICRAFT_SOURCES "[/\\\\]pc[/\\\\]win32[/\\\\]")
mcbeta_select_platform_backends(OPTICRAFT_SOURCES PC PC PC)

set(OPTICRAFT_MINIZIP_SOURCES
    "${CMAKE_SOURCE_DIR}/external/zlib/contrib/minizip/ioapi.c"
    "${CMAKE_SOURCE_DIR}/external/zlib/contrib/minizip/unzip.c"
)

# --- Target --------------------------------------------------------------------
add_library(main SHARED
    ${OPTICRAFT_SOURCES}
    ${OPTICRAFT_MINIZIP_SOURCES}
)

target_compile_features(main PRIVATE cxx_std_17)
set_target_properties(main PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
)

target_compile_definitions(main PRIVATE
    MC_LINUX
    MC_LOG_LEVEL=${MC_LOG_LEVEL}
)
if(ANDROID_LEGACY_PROFILE)
    target_compile_definitions(main PRIVATE PC_LEGACY_BUILD=1)
endif()

target_compile_options(main PRIVATE
    $<$<CONFIG:Release>:-O2>
    -fno-math-errno
)

target_include_directories(main PRIVATE
    "${CMAKE_SOURCE_DIR}/src"
    "${CMAKE_SOURCE_DIR}/src/pc"
    "${CMAKE_SOURCE_DIR}/external/stb"
    "${CMAKE_SOURCE_DIR}/external/miniaudio"
    "${CMAKE_SOURCE_DIR}/external/zlib/contrib/minizip"
    "${CMAKE_SOURCE_DIR}/external/gl4es/include"
)

target_link_libraries(main PRIVATE
    glad
    GL                       # gl4es (static)
    SDL2::SDL2
    SDL2_net::SDL2_net-static
    zlibstatic
    log
    android
    dl
)
