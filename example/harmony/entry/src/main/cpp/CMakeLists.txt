cmake_minimum_required(VERSION 3.4.1)
project(rnoh_app)

# Enable CMP0079 policy to allow target_link_libraries on targets defined in subdirectories
cmake_policy(SET CMP0079 NEW)

# Limit parallel compilation jobs to prevent Out Of Memory (OOM) crashes on large C++ builds
set_property(GLOBAL PROPERTY JOB_POOLS compile_pool=2 link_pool=1)
set(CMAKE_JOB_POOL_COMPILE compile_pool)
set(CMAKE_JOB_POOL_LINK link_pool)

set(CMAKE_SKIP_BUILD_RPATH TRUE)
set(OH_MODULES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../oh_modules")
set(RNOH_CPP_DIR "${OH_MODULES_DIR}/@rnoh/react-native-openharmony/src/main/cpp")

add_subdirectory("${RNOH_CPP_DIR}" ./rn)

# Link missing hitrace ndk library to rnoh target
target_link_libraries(rnoh PUBLIC libhitrace_ndk.z.so)

# codegen-harmony 生成的 C++（RNMapsModule.cpp 等）。头文件以 "generated/..." 相对包含，
# 故把本 cpp 目录加入 include 路径。
file(GLOB_RECURSE GENERATED_CPP_FILES "./generated/*.cpp")

add_library(rnoh_app SHARED
    "./PackageProvider.cpp"
    ${GENERATED_CPP_FILES}
    "${RNOH_CPP_DIR}/RNOHAppNapiBridge.cpp"
)

target_include_directories(rnoh_app PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(rnoh_app PUBLIC rnoh)
