cmake_minimum_required(VERSION 3.10)

project(box2d_wrapper VERSION 1.0 LANGUAGES C)
option(BUILD_SHARED_LIBS "Build shared libraries" ON)

file(GLOB_RECURSE BOX2D_SOURCES
    ${CMAKE_SOURCE_DIR}/box2d/src/*.c
    ${CMAKE_SOURCE_DIR}/box2d/src/*.h
)

file(GLOB_RECURSE BOX2D_HEADERS
    ${CMAKE_SOURCE_DIR}/box2d/include/box2d/*.h
)

set(LIBRARY_NAME box2d) # name change here

add_library(${LIBRARY_NAME} SHARED
    ${BOX2D_HEADERS}
    ${BOX2D_SOURCES}
    box2d_extension.h
    box2d_extension.c
)

target_include_directories(${LIBRARY_NAME} PUBLIC
    ${CMAKE_SOURCE_DIR}/box2d/include
    ${CMAKE_SOURCE_DIR}/box2d/src
)

set_target_properties(${LIBRARY_NAME} PROPERTIES LINKER_LANGUAGE C)

if (MSVC)
    target_compile_options(${LIBRARY_NAME} PRIVATE /experimental:c11atomics /std:c17)
endif()