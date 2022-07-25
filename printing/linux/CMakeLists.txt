# Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "printing")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PDFIUM_VERSION "5200" CACHE STRING "Version of pdfium used")
set(PDFIUM_ARCH "x64" CACHE STRING "Architecture of pdfium used")

if(${PDFIUM_VERSION} STREQUAL "latest")
  set(
    PDFIUM_URL
    "https://github.com/bblanchon/pdfium-binaries/releases/latest/download/pdfium-linux-${PDFIUM_ARCH}.tgz"
    )
else()
  set(
    PDFIUM_URL
    "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/${PDFIUM_VERSION}/pdfium-linux-${PDFIUM_ARCH}.tgz"
    )
endif()

# Download pdfium
include(../windows/DownloadProject.cmake)
download_project(PROJ
                 pdfium
                 URL
                 ${PDFIUM_URL})

# This value is used when generating builds using this plugin, so it must not be
# changed
set(PLUGIN_NAME "printing_plugin")

include(${pdfium_SOURCE_DIR}/PDFiumConfig.cmake)

# System-level dependencies.
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTKUnixPrint
                  REQUIRED
                  IMPORTED_TARGET
                  gtk+-unix-print-3.0)

add_library(${PLUGIN_NAME} SHARED
            "printing_plugin.cc"
            "include/printing/printing_plugin.h"
            "print_job.cc"
            "print_job.h")

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME}
                           INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME}
                      PRIVATE PkgConfig::GTK PkgConfig::GTKUnixPrint)
target_link_libraries(${PLUGIN_NAME} PRIVATE pdfium)
get_filename_component(PDFium_lib_path "${PDFium_LIBRARY}" DIRECTORY)
set_target_properties(${PLUGIN_NAME}
                      PROPERTIES SKIP_BUILD_RPATH
                                 FALSE
                                 BUILD_WITH_INSTALL_RPATH
                                 TRUE
                                 INSTALL_RPATH
                                 "$ORIGIN:${PDFium_lib_path}")

# List of absolute paths to libraries that should be bundled with the plugin
set(printing_bundled_libraries "${PDFium_LIBRARY}" PARENT_SCOPE)
