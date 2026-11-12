# Install/export the existing targets; CMake remains the dependency source of truth.
# SPDX-License-Identifier: GPL-2.0-or-later
include(CMakePackageConfigHelpers)

# Clang stores CodeView in its objects rather than producing compiler PDBs.
# This Windows distribution promises standalone PDBs, so validate at configure time.
if(WIN32 AND NOT (CMAKE_C_COMPILER_ID STREQUAL "MSVC" AND
                 CMAKE_CXX_COMPILER_ID STREQUAL "MSVC"))
  message(FATAL_ERROR "The Windows C++ SDK requires MSVC cl.exe for compiler PDBs. "
    "Use a fresh CPP_DIST_BUILD_DIR with a Visual Studio generator.")
endif()

set(_bui_sdk_targets bui_core bui_gpu bui_kit bui_api)
foreach(_target bui_imgui bui_cimgui)
  if(TARGET ${_target})
    list(APPEND _bui_sdk_targets ${_target})
  endif()
endforeach()
foreach(_target IN LISTS _bui_sdk_targets)
  string(REGEX REPLACE "^bui_" "" _name "${_target}")
  set_target_properties(${_target} PROPERTIES EXPORT_NAME "${_name}")
endforeach()
install(TARGETS ${_bui_sdk_targets} EXPORT BUITargets
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT CppSDK)

# Keep each module's include tree separate, including blenlib's inline implementations.
foreach(_module core gpu kit)
  install(DIRECTORY "${BUI_SOURCE_DIR}/${_module}/include/"
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/bui/${_module}" COMPONENT CppSDK)
endforeach()
install(DIRECTORY "${BUI_SOURCE_DIR}/core/intern/"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/bui/core/intern" COMPONENT CppSDK
  FILES_MATCHING PATTERN "*.h" PATTERN "*_inline.c" PATTERN "*_inline.cc")
install(DIRECTORY "${BUI_SOURCE_DIR}/types/dna/include/"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/bui/dna" COMPONENT CppSDK)
install(FILES "${BUI_SOURCE_DIR}/api/bui_c_api.h"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/bui/api" COMPONENT CppSDK)
if(TARGET bui_imgui)
  install(FILES "${BUI_SOURCE_DIR}/bindings/imgui/imgui_impl_bui.h"
    "${BUI_SOURCE_DIR}/bindings/imgui/extern/imgui/misc/cpp/imgui_stdlib.h"
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/bui/imgui" COMPONENT CppSDK)
  install(DIRECTORY "${BUI_SOURCE_DIR}/bindings/imgui/extern/imgui/"
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/bui/imgui" COMPONENT CppSDK
    FILES_MATCHING PATTERN "*.h" PATTERN "backends" EXCLUDE
    PATTERN "examples" EXCLUDE PATTERN "misc" EXCLUDE)
  install(DIRECTORY "${BUI_SOURCE_DIR}/bindings/imgui/c/"
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/bui/cimgui" COMPONENT CppSDK
    FILES_MATCHING PATTERN "*.h")
endif()

# A static archive has no linker PDB. Ship every compiler PDB its objects refer
# to, including object libraries folded into core/kit. Give them unique names
# and install beside the .lib files so the consumer's linker can locate them.
set(_bui_symbol_targets ${_bui_sdk_targets} bui_core_cxx)
foreach(_target bui_jpeg bui_webp)
  if(TARGET ${_target})
    list(APPEND _bui_symbol_targets ${_target})
  endif()
endforeach()
if(MSVC)
  set(_bui_symbol_dir "${CMAKE_BINARY_DIR}/sdk-symbols/$<CONFIG>")
  foreach(_target IN LISTS _bui_symbol_targets)
    target_compile_options(${_target} PRIVATE /Zi /FS)
    set_target_properties(${_target} PROPERTIES
      COMPILE_PDB_NAME "${_target}"
      COMPILE_PDB_OUTPUT_DIRECTORY "${_bui_symbol_dir}")
    # Deliberately not OPTIONAL: a package missing required symbols must fail.
    install(FILES "${_bui_symbol_dir}/${_target}.pdb"
      DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT CppSDK)
  endforeach()
endif()

set(_bui_cmake_dir "${CMAKE_INSTALL_LIBDIR}/cmake/BUI")
configure_package_config_file("${CMAKE_CURRENT_LIST_DIR}/BUIConfig.cmake.in"
  "${CMAKE_BINARY_DIR}/BUIConfig.cmake" INSTALL_DESTINATION "${_bui_cmake_dir}")
write_basic_package_version_file("${CMAKE_BINARY_DIR}/BUIConfigVersion.cmake"
  VERSION ${BUI_VERSION} COMPATIBILITY SameMajorVersion)
install(EXPORT BUITargets NAMESPACE bui:: DESTINATION "${_bui_cmake_dir}" COMPONENT CppSDK)
install(FILES "${CMAKE_BINARY_DIR}/BUIConfig.cmake" "${CMAKE_BINARY_DIR}/BUIConfigVersion.cmake"
  DESTINATION "${_bui_cmake_dir}" COMPONENT CppSDK)
install(FILES "${BUI_SOURCE_DIR}/LICENSE" "${BUI_SOURCE_DIR}/THIRD_PARTY_NOTICES.md"
  DESTINATION "${CMAKE_INSTALL_DATADIR}/licenses/BUI" COMPONENT CppSDK)

set(BUI_CPP_DIST_DIR "${BUI_SOURCE_DIR}/dist/cpp" CACHE PATH "C/C++ SDK archive output directory")
set(CPACK_PACKAGE_NAME BUI)
set(CPACK_PACKAGE_VERSION ${BUI_VERSION})
set(CPACK_PACKAGE_VENDOR "BUI contributors")
set(CPACK_GENERATOR ZIP)
set(CPACK_PACKAGE_DIRECTORY "${BUI_CPP_DIST_DIR}")
set(CPACK_INSTALL_CMAKE_PROJECTS "${CMAKE_BINARY_DIR};${PROJECT_NAME};CppSDK;/")
include(CPack)

set(_bui_sdk_arch "${CMAKE_CXX_COMPILER_ARCHITECTURE_ID}")
if(NOT _bui_sdk_arch)
  set(_bui_sdk_arch "${CMAKE_SYSTEM_PROCESSOR}")
endif()
set(_bui_package_name "bui-${BUI_VERSION}-${CMAKE_SYSTEM_NAME}-${_bui_sdk_arch}-${CMAKE_CXX_COMPILER_ID}")
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/BUI-SDK-$<CONFIG>.txt" CONTENT
"BUI ${BUI_VERSION} C/C++ SDK
Platform: ${CMAKE_SYSTEM_NAME} ${_bui_sdk_arch}
Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}
Configuration: $<CONFIG>

Set CMAKE_PREFIX_PATH to this directory, then use:
  find_package(BUI CONFIG REQUIRED)
  target_link_libraries(myapp PRIVATE bui::kit)
Other targets: bui::core, bui::gpu, bui::api; bui::imgui and bui::cimgui when enabled.

Use a compatible compiler, target architecture and runtime configuration.
On Windows, keep all packaged PDBs beside the .lib files. These compiler PDBs
include symbols for the object libraries embedded in the archives. Your
application's linker generates the application PDB.

License and third-party notices: share/licenses/BUI/.
")
install(FILES "${CMAKE_BINARY_DIR}/BUI-SDK-$<CONFIG>.txt"
  DESTINATION . RENAME README.txt COMPONENT CppSDK)
add_custom_target(dist-cpp
  COMMAND "${CMAKE_CPACK_COMMAND}" --config "${CMAKE_BINARY_DIR}/CPackConfig.cmake"
    -C "$<CONFIG>" -G ZIP -B "${BUI_CPP_DIST_DIR}"
    -D "CPACK_PACKAGE_FILE_NAME=${_bui_package_name}-$<CONFIG>"
  DEPENDS ${_bui_sdk_targets} bui_core_cxx
  COMMENT "Packaging C/C++ SDK with headers, CMake targets and compiler symbols"
  VERBATIM)
