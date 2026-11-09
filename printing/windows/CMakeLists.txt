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
# endpoint still serves the same file. Both are checked against a pinned SHA-256.
set(PRINTING_PDFIUM_ASSET_ID "")
set(PRINTING_PDFIUM_SHA256 "")
if(PDFIUM_VERSION STREQUAL "5200")
  if(PDFIUM_ARCH STREQUAL "x64")
    set(PRINTING_PDFIUM_ASSET_ID "72589899")
    set(PRINTING_PDFIUM_SHA256 "8e900c3e5103ae9a3aa7800653e804575c687d132fcfb4deda7bb2ce04aca8d2")
  elseif(PDFIUM_ARCH STREQUAL "x86")
    set(PRINTING_PDFIUM_ASSET_ID "72589858")
    set(PRINTING_PDFIUM_SHA256 "dce27ae3904ecd3739b86d8b1d7484f48069689071accccf1dac18215eba2768")
  elseif(PDFIUM_ARCH STREQUAL "arm64")
    set(PRINTING_PDFIUM_ASSET_ID "72589877")
    set(PRINTING_PDFIUM_SHA256 "0fe0eddf65e92cbc72e0d92fdd552f132c430fdb2b4ab97fed18685bc70cadd8")
  endif()
endif()

set(PRINTING_PDFIUM_URL_HASH "")
if(PRINTING_PDFIUM_ASSET_ID)
  set(PRINTING_PDFIUM_URL_HASH URL_HASH "SHA256=${PRINTING_PDFIUM_SHA256}")
  set(PRINTING_PDFIUM_ARCHIVE
      "${CMAKE_BINARY_DIR}/pdfium-win-${PDFIUM_ARCH}-${PDFIUM_VERSION}-asset.tgz")
  set(_pdfium_archive_sha256 "")
  if(EXISTS "${PRINTING_PDFIUM_ARCHIVE}")
    file(SHA256 "${PRINTING_PDFIUM_ARCHIVE}" _pdfium_archive_sha256)
  endif()

  if(NOT "${_pdfium_archive_sha256}" STREQUAL "${PRINTING_PDFIUM_SHA256}")
    set(PRINTING_PDFIUM_HTTP_HEADERS HTTPHEADER "Accept: application/octet-stream"
        HTTPHEADER "X-GitHub-Api-Version: 2022-11-28")
    if(NOT "$ENV{GITHUB_TOKEN}" STREQUAL "")
      list(APPEND PRINTING_PDFIUM_HTTP_HEADERS HTTPHEADER
           "Authorization: Bearer $ENV{GITHUB_TOKEN}")
    endif()
    file(DOWNLOAD
         "https://api.github.com/repos/bblanchon/pdfium-binaries/releases/assets/${PRINTING_PDFIUM_ASSET_ID}"
         "${PRINTING_PDFIUM_ARCHIVE}"
         ${PRINTING_PDFIUM_HTTP_HEADERS}
         TLS_VERIFY ON
         TIMEOUT 180
         STATUS _api_download_status)
    set(_pdfium_archive_sha256 "")
    if(EXISTS "${PRINTING_PDFIUM_ARCHIVE}")
      file(SHA256 "${PRINTING_PDFIUM_ARCHIVE}" _pdfium_archive_sha256)
    endif()
  endif()

  if("${_pdfium_archive_sha256}" STREQUAL "${PRINTING_PDFIUM_SHA256}")
    set(PDFIUM_URL "${PRINTING_PDFIUM_ARCHIVE}")
  else()
    message(STATUS "PDFium release API download failed or did not match (${_api_download_status}); trying original URL")
    file(REMOVE "${PRINTING_PDFIUM_ARCHIVE}")
  endif()
endif()

# Download pdfium
include(../windows/DownloadProject.cmake)
download_project(PROJ
                 pdfium
                 URL
                 ${PDFIUM_URL}
                 ${PRINTING_PDFIUM_URL_HASH})

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
