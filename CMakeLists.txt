cmake_minimum_required(VERSION 2.8)
include(cmake/rust.cmake)

project(test-core-graphics)

add_subdirectory(deps/rust-core-foundation)
add_subdirectory(deps/rust-core-graphics)

add_rust_dependencies(rust-core-foundation)
add_rust_dependencies(rust-core-graphics)

rust_binary(lib.rs)
