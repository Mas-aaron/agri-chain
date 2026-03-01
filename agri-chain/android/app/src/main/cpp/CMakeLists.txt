cmake_minimum_required(VERSION 3.10.2)
project(mindspore-jni)

set(MINDSPORELITE_VERSION mindspore-lite-1.7.0-android-aarch64)

# Set the path to the extracted MindSpore Lite directory
set(MINDSPORELITE_DIR ${CMAKE_SOURCE_DIR}/${MINDSPORELITE_VERSION})

# include directories
include_directories(${MINDSPORELITE_DIR}/runtime/include)
include_directories(${MINDSPORELITE_DIR}/runtime/include/mindapi/include)
include_directories(${MINDSPORELITE_DIR}/runtime/include/dataset)
include_directories(${MINDSPORELITE_DIR}/runtime/include/dataset/lite_cv)
include_directories(${MINDSPORELITE_DIR}/runtime/third_party)

# Note: The include directories structure requires the parent of `include` so internal `#include "include/...` works.
include_directories(${MINDSPORELITE_DIR}/runtime)
include_directories(${MINDSPORELITE_DIR}/runtime/include)

# Import the precompiled shared library
add_library(mindspore-lite SHARED IMPORTED)
set_target_properties(mindspore-lite PROPERTIES IMPORTED_LOCATION
        ${MINDSPORELITE_DIR}/runtime/lib/libmindspore-lite.so)

# Find standard Android libraries
find_library(log-lib log)
find_library(jnigraphics-lib jnigraphics)
find_library(android-lib android)

# Build our JNI wrapper
add_library(mindspore_jni SHARED
        mindspore_jni.cpp)

# Link
target_link_libraries(mindspore_jni
        mindspore-lite
        ${jnigraphics-lib}
        ${android-lib}
        ${log-lib})
