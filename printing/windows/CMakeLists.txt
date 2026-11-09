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

cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "printing")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PDFIUM_VERSION "5200" CACHE STRING "Version of pdfium used")
string(REPLACE "windows-" "" TARGET_ARCH ${FLUTTER_TARGET_PLATFORM})
set(PDFIUM_ARCH ${TARGET_ARCH} CACHE STRING "Architecture of pdfium used")

if(${PDFIUM_VERSION} STREQUAL "latest")
  set(
    PDFIUM_URL
    "https://github.com/bblanchon/pdfium-binaries/releases/latest/download/pdfium-win-${PDFIUM_ARCH}.tgz"
    )
else()
  set(
    PDFIUM_URL
    "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/${PDFIUM_VERSION}/pdfium-win-${PDFIUM_ARCH}.tgz"
    )
endif()

# The /releases/download/ CDN can return 504 while the GitHub REST asset
# endpoint still serves the exact same pinned Chromium/PDFium build.
# Use the original URL for unsupported versions and as a fallback.
set(PRINTING_PDFIUM_ASSET_ID "")
if(PDFIUM_VERSION STREQUAL "5200")
  if(PDFIUM_ARCH STREQUAL "x64")
    set(PRINTING_PDFIUM_ASSET_ID "72589899")
  elseif(PDFIUM_ARCH STREQUAL "x86")
    set(PRINTING_PDFIUM_ASSET_ID "72589858")
  elseif(PDFIUM_ARCH STREQUAL "arm64")
    set(PRINTING_PDFIUM_ASSET_ID "72589877")
  endif()
endif()

if(PRINTING_PDFIUM_ASSET_ID)
  set(PRINTING_PDFIUM_ARCHIVE
      "${CMAKE_BINARY_DIR}/pdfium-win-${PDFIUM_ARCH}-${PDFIUM_VERSION}-asset.tgz")
  set(PRINTING_PDFIUM_HTTP_HEADERS HTTPHEADER "Accept: application/octet-stream"
      HTTPHEADER "X-GitHub-Api-Version: 2022-11-28")
  if(DEFINED ENV{GITHUB_TOKEN} AND NOT "$ENV{GITHUB_TOKEN}" STREQUAL "")
    list(APPEND PRINTING_PDFIUM_HTTP_HEADERS HTTPHEADER
         "Authorization: Bearer $ENV{GITHUB_TOKEN}")
  endif()

  # An HTTP 200 may contain JSON metadata instead of a binary archive.
  # Never send such a body to ExternalProject_Add for extraction.
  if(EXISTS "${PRINTING_PDFIUM_ARCHIVE}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar tf "${PRINTING_PDFIUM_ARCHIVE}"
                    RESULT_VARIABLE _cached_archive_status OUTPUT_QUIET ERROR_QUIET)
    if(NOT _cached_archive_status EQUAL 0)
      file(REMOVE "${PRINTING_PDFIUM_ARCHIVE}")
    endif()
  endif()
  if(NOT EXISTS "${PRINTING_PDFIUM_ARCHIVE}")
    file(DOWNLOAD
         "https://api.github.com/repos/bblanchon/pdfium-binaries/releases/assets/${PRINTING_PDFIUM_ASSET_ID}"
         "${PRINTING_PDFIUM_ARCHIVE}"
         ${PRINTING_PDFIUM_HTTP_HEADERS}
         TLS_VERIFY ON
         TIMEOUT 180
         STATUS _api_download_status)
    list(GET _api_download_status 0 _api_code)
    if(NOT _api_code EQUAL 0)
      message(STATUS "PDFium release API unavailable: ${_api_download_status}; trying original URL")
      file(REMOVE "${PRINTING_PDFIUM_ARCHIVE}")
    endif()
  endif()
  if(EXISTS "${PRINTING_PDFIUM_ARCHIVE}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar tf "${PRINTING_PDFIUM_ARCHIVE}"
                    RESULT_VARIABLE _archive_status OUTPUT_QUIET ERROR_QUIET)
    if(_archive_status EQUAL 0)
      set(PDFIUM_URL "${PRINTING_PDFIUM_ARCHIVE}")
    else()
      message(STATUS "PDFium REST response is not an archive; trying original URL")
      file(REMOVE "${PRINTING_PDFIUM_ARCHIVE}")
    endif()
  endif()
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

add_library(${PLUGIN_NAME} SHARED
            "printing.cpp"
            "printing.h"
            "printing_plugin.cpp"
            "include/printing/printing_plugin.h"
            "print_job.cpp"
            "print_job.h")

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME}
                           INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME}
                      PRIVATE pdfium flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin
set(printing_bundled_libraries "${PDFium_LIBRARY}" PARENT_SCOPE)
