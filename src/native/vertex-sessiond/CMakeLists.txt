cmake_minimum_required(VERSION 3.22)
project(vertex-sessiond LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(vertex-sessiond src/vertex-sessiond.cpp)

target_compile_options(vertex-sessiond PRIVATE
    -Wall
    -Wextra
    -Wpedantic
)

install(TARGETS vertex-sessiond RUNTIME DESTINATION libexec/vertex)
