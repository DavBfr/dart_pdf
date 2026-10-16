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

# Resolve the pdfium release this plugin downloads.
#
# Inputs, set by the caller before including this file:
#
# * PRINTING_FLUTTER_OS - the FLUTTER_TARGET_PLATFORM prefix: windows or linux
# * PRINTING_PDFIUM_OS - the pdfium release name for that OS: win or linux
#
# Output: PRINTING_PDFIUM_URL

if(NOT DEFINED PRINTING_FLUTTER_OS OR NOT DEFINED PRINTING_PDFIUM_OS)
  message(
    FATAL_ERROR
      "PRINTING_FLUTTER_OS and PRINTING_PDFIUM_OS must be set before including pdfium.cmake"
    )
endif()

# Namespaced, because the CMake cache is shared with every other plugin in the
# app. A plain set(PDFIUM_VERSION ... CACHE ...) is a no-op once another pdfium
# plugin has defined it, so printing silently built against that plugin's
# release - or failed to configure at all.
set(PRINTING_PDFIUM_VERSION "5200"
    CACHE STRING "Version of pdfium used by the printing plugin")

# Not every app scaffold defines FLUTTER_TARGET_PLATFORM, and dereferencing it
# unquoted when it is missing made string(REPLACE) fail with too few arguments.
set(_printing_pdfium_arch "x64")
if(NOT "${FLUTTER_TARGET_PLATFORM}" STREQUAL "")
  string(REPLACE "${PRINTING_FLUTTER_OS}-"
                 ""
                 _printing_pdfium_arch
                 "${FLUTTER_TARGET_PLATFORM}")
endif()

set(PRINTING_PDFIUM_ARCH "${_printing_pdfium_arch}"
    CACHE STRING "Architecture of pdfium used by the printing plugin")

if(PRINTING_PDFIUM_VERSION STREQUAL "latest")
  set(
    PRINTING_PDFIUM_URL
    "https://github.com/bblanchon/pdfium-binaries/releases/latest/download/pdfium-${PRINTING_PDFIUM_OS}-${PRINTING_PDFIUM_ARCH}.tgz"
    )
else()
  set(
    PRINTING_PDFIUM_URL
    "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/${PRINTING_PDFIUM_VERSION}/pdfium-${PRINTING_PDFIUM_OS}-${PRINTING_PDFIUM_ARCH}.tgz"
    )
endif()

unset(_printing_pdfium_arch)
