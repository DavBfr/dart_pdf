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
string(REPLACE "linux-" "" TARGET_ARCH ${FLUTTER_TARGET_PLATFORM})
set(PDFIUM_ARCH ${TARGET_ARCH} CACHE STRING "Architecture of pdfium used")
set(PRINTING_PDFIUM_DIR "$ENV{PRINTING_PDFIUM_DIR}" CACHE PATH
    "Existing pdfium build to use instead of downloading one")

if(PRINTING_PDFIUM_DIR)
  set(pdfium_SOURCE_DIR ${PRINTING_PDFIUM_DIR})
elseif(${PDFIUM_VERSION} STREQUAL "latest")
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

if(NOT PRINTING_PDFIUM_DIR)
  # Download pdfium
  include(../windows/DownloadProject.cmake)
  download_project(PROJ
                   pdfium
                   URL
                   ${PDFIUM_URL})
endif()

# This value is used when generating builds using this plugin, so it must not be
# changed
set(PLUGIN_NAME "printing_plugin")

# Never link the printing plugin against an application's libpdfium.so.
# An application may load another PDFium build (e.g. through pdfrx), while
# printing ships the pinned Chromium 5200 headers and binary. Two uncoordinated
# sets of PDFium globals in the ELF base namespace are unsafe even if renamed.
set(PRINTING_PDFIUM_SOURCE
    "${pdfium_SOURCE_DIR}/lib/libpdfium.so")
set(PRINTING_PDFIUM_INCLUDE
    "${pdfium_SOURCE_DIR}/include")
if(NOT EXISTS "${PRINTING_PDFIUM_SOURCE}" OR
   NOT EXISTS "${PRINTING_PDFIUM_INCLUDE}/fpdfview.h")
  message(FATAL_ERROR
      "Pinned printing PDFium is incomplete at ${pdfium_SOURCE_DIR}")
endif()

# A separate file name is used only to give the isolated runtime loader a
# stable exact path; the real isolation is dlmopen(LM_ID_NEWLM), not the name.
set(PRINTING_PRIVATE_PDFIUM
    "${CMAKE_CURRENT_BINARY_DIR}/libpdfium_printing.so")
configure_file("${PRINTING_PDFIUM_SOURCE}"
               "${PRINTING_PRIVATE_PDFIUM}" COPYONLY)

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
            "print_job.h"
            "pdfium_isolate.cc"
            "pdfium_isolate.h")

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
                      CXX_VISIBILITY_PRESET hidden
                      BUILD_WITH_INSTALL_RPATH TRUE
                      INSTALL_RPATH "$ORIGIN")
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME}
                           INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include"
                           PRIVATE "${PRINTING_PDFIUM_INCLUDE}")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter
                      PkgConfig::GTK PkgConfig::GTKUnixPrint
                      ${CMAKE_DL_LIBS})
# Do not add "pdfium" to target_link_libraries or to the standard bundle.
# The custom loader resolves a fixed symbol set from the private PDFium in a
# separate ELF namespace, ensuring neither version interposes on the other.

# The Flutter runner installs these files next to libprinting_plugin.so.
set(printing_bundled_libraries "${PRINTING_PRIVATE_PDFIUM}" PARENT_SCOPE)
