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

# Checks that cmake/pdfium.cmake resolves the release this plugin expects, no
# matter what another plugin in the same app has already put in the shared CMake
# cache. LANGUAGES NONE, so it needs no compiler and runs on any host:
#
#   cmake -S printing/test/cmake -B <build dir>

cmake_minimum_required(VERSION 3.10)
project(printing_pdfium_cmake_test LANGUAGES NONE)

set(PDFIUM_CMAKE "${CMAKE_CURRENT_LIST_DIR}/../../cmake/pdfium.cmake")

function(expect_equal what actual expected)
  if(NOT "${actual}" STREQUAL "${expected}")
    message(FATAL_ERROR "${what}: expected '${expected}', got '${actual}'")
  endif()
  message(STATUS "ok - ${what}")
endfunction()

function(expect_contains what actual fragment)
  string(FIND "${actual}" "${fragment}" position)
  if(position EQUAL -1)
    message(FATAL_ERROR "${what}: '${actual}' does not contain '${fragment}'")
  endif()
  message(STATUS "ok - ${what}")
endfunction()

# A plugin loaded before printing poisons the shared cache. printing used to
# read these, so it resolved another plugin's pdfium release.
set(PDFIUM_VERSION "4636" CACHE STRING "another plugin's pdfium")
set(PDFIUM_ARCH "arm64" CACHE STRING "another plugin's arch")

# 1. windows-x64, with the cache poisoned.
set(FLUTTER_TARGET_PLATFORM "windows-x64")
set(PRINTING_FLUTTER_OS "windows")
set(PRINTING_PDFIUM_OS "win")
include("${PDFIUM_CMAKE}")

expect_equal("the version is not taken from another plugin"
             "${PRINTING_PDFIUM_VERSION}" "5200")
expect_contains("the url names the pinned release" "${PRINTING_PDFIUM_URL}"
                "/chromium/5200/")
expect_contains("the url names the target arch" "${PRINTING_PDFIUM_URL}"
                "pdfium-win-x64.tgz")
expect_equal("printing writes no PDFIUM_VERSION cache entry"
             "$CACHE{PDFIUM_VERSION}" "4636")

# 2. The arch comes from FLUTTER_TARGET_PLATFORM, not from the cached
# PDFIUM_ARCH. The cache entry PRINTING_PDFIUM_ARCH is already set by the
# include above, so read the url rather than the variable.
expect_contains("the arch is not taken from another plugin"
                "${PRINTING_PDFIUM_URL}" "-x64.tgz")

# 3. FLUTTER_TARGET_PLATFORM undefined falls back to x64 instead of failing
# string(REPLACE) with too few arguments.
unset(FLUTTER_TARGET_PLATFORM)
unset(PRINTING_PDFIUM_ARCH CACHE)
include("${PDFIUM_CMAKE}")
expect_equal("an undefined target platform means x64" "${PRINTING_PDFIUM_ARCH}"
             "x64")

# 4. linux-arm64.
set(FLUTTER_TARGET_PLATFORM "linux-arm64")
set(PRINTING_FLUTTER_OS "linux")
set(PRINTING_PDFIUM_OS "linux")
unset(PRINTING_PDFIUM_ARCH CACHE)
include("${PDFIUM_CMAKE}")
expect_contains("linux-arm64 resolves the arm64 release"
                "${PRINTING_PDFIUM_URL}" "pdfium-linux-arm64.tgz")

# 5. 'latest' uses the release channel and still honours the arch.
unset(PRINTING_PDFIUM_VERSION CACHE)
set(PRINTING_PDFIUM_VERSION "latest" CACHE STRING "" FORCE)
include("${PDFIUM_CMAKE}")
expect_contains("latest uses the latest channel" "${PRINTING_PDFIUM_URL}"
                "releases/latest/download/pdfium-linux-arm64.tgz")

message(STATUS "printing pdfium cmake: all checks passed")
