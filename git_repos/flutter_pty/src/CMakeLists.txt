# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(flutter_pty_library VERSION 0.0.1 LANGUAGES C)

add_library(flutter_pty SHARED
  "flutter_pty.c"
)

set_target_properties(flutter_pty PROPERTIES
  PUBLIC_HEADER flutter_pty.h
  OUTPUT_NAME "flutter_pty"
)

target_compile_definitions(flutter_pty PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size.
  target_link_options(flutter_pty PRIVATE "-Wl,-z,max-page-size=16384")
endif()
