# BUI stable C API — a thin facade for hosts and language bindings.
# SPDX-License-Identifier: GPL-2.0-or-later

add_library(bui_api STATIC bui_c_api.c)
target_include_directories(bui_api PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/bui/api>)
# BUI_kit.h, for its version macros only (the facade does not link the kit)
target_include_directories(bui_api PRIVATE ${BUI_SOURCE_DIR}/kit/include)
target_link_libraries(bui_api PUBLIC bui_gpu)
