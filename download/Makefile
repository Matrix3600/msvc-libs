#
# MSVC-Libs 1.0
#
# Makefile (version for GNU make, Windows or Linux)
#
# -----------------------------------------------------------------------------
# Copyright 2025 https://github.com/Matrix3600
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# -----------------------------------------------------------------------------
#
# Download and build the repackaged MSVC/SDK headers and libraries.
#
# Compatible with Windows and Linux for cross-compilation.
#
# - Download the Visual Studio library using the "vsdownload.py" script created
#   by Martin Storsjo (https://github.com/mstorsjo/msvc-wine).
#
#   The original files are downloaded from the Microsoft servers. You need to
#   accept the license https://go.microsoft.com/fwlink/?LinkId=2179911 .
#
# - Rename the files and directories to lowercase for compatibility with
#   case-sensitive systems (Linux).
# - Rename the include directives in source files accordingly.
#
# Specify one or more arguments to the "make" command line to choose the
# contents of the library to build (see below).
#
# Parameters:
#   default       (intel + sdk) or (arm + sdk), depending on your machine
#                 architecture.
#                 Implicit when no argument is specified.
#   all           intel + arm + atl + atlarm + sdk
#   intel         [VC.Tools.x86.x64]
#   arm           arm32 + arm64
#   x86           = intel
#   x64           = intel
#   arm32         [VC.Tools.ARM]
#   arm64         [VC.Tools.ARM64]
#   atl           [VC.ATL] + intel
#   atlarm        atlarm32 + atlarm64
#   atl32         = atl
#   atl64         = atl
#   atlarm32      [VC.ATL.ARM] + arm32
#   atlarm64      [VC.ATL.ARM64] + arm64
#   sdk           [Windows11SDK.22621]
#   onlydl        Download only, do not create the standalone library.
#   nodl          Do not download anything. Stop if any package is missing.
#   msvc-libs     Build the repackaged standalone library (msvc-libs
#                 directory). Implicit if "onlydl" is not specified.
#   lang=xx[-yy]  Preferred language code for packages available in multiple
#                 languages (default: LANG environment variable, or "en").
#   clean         Delete the "msvc-libs" directory of created standalone
#                 library, do not delete any downloaded files.
#   clean-all     Delete all the directories created by this makefile.
#   clean-dl      Delete all the download directories ("VC" and
#                 "Windows Kits").
#   clean-msvc    Delete the "VC" directory.
#   clean-sdk     Delete the "Windows Kits" directory.
#   clean-atl     Delete the ATL download directory.
#
# The downloaded packages are indicated in brackets.
# The unversioned packages are always the latest available.
# The standalone library is always created at the end, unless the "onlydl"
# parameter is specified.
#
# *** Requirements ***
#
# - On Windows, the download directory (where the Makefile is located) must
#   have a short path (less than 38 characters), otherwise the packages
#   extraction will fail. This is due to the Windows path length limitation.
#
# - The following must be installed:
#   * Python 3, to run the download script.
#   * On Linux, a recent version of these packages:
#     o msitools (0.98+)
#     o libgcab-1.0-0 (1.2+)
#

ifdef lang
 DL_LANG := $(lang)
 override undefine lang
else
 ifdef LANG
  DL_LANG := $(subst _,-,$(firstword $(subst ., ,$(LANG))))
 endif
endif

# -----------------------------------------------------------------------------
# Detect system and check required files
# -----------------------------------------------------------------------------

NATIVEWIN =
DEVNUL = /dev/null
ifeq ($(OS),Windows_NT)
 ifeq ($(shell echo $$PPID),$$PPID)
  NATIVEWIN = 1
  DEVNUL = nul
 endif
endif

.DEFAULT_GOAL = intel_def
ifeq ($(OS),Windows_NT)
 ifneq (,$(filter ARM%,$(PROCESSOR_ARCHITECTURE)))
  .DEFAULT_GOAL = arm_def
 endif
else
 ifneq (,$(filter aarch64% arm%,$(shell uname -m 2>$(DEVNUL))))
  .DEFAULT_GOAL = arm_def
 endif
endif

PYTHON = python3
ifeq (,$(shell $(PYTHON) --version 2>$(DEVNUL)))
 PYTHON = python
 ifeq (,$(shell $(PYTHON) --version 2>$(DEVNUL)))
  $(error ERROR: Python was not found. Please install it)
 endif
endif

VSDOWNLOAD_SCRIPT = vsdownload.py
ifdef NATIVEWIN
 MSVC_LIBS_SCRIPT = make_msvc-libs.cmd
else
 MSVC_LIBS_SCRIPT = make_msvc-libs.sh
endif
MSVC_LIBS_CONFIG = make_msvc-libs_conf.txt

ifeq (,$(wildcard $(VSDOWNLOAD_SCRIPT)))
 $(error ERROR: The download script "$(VSDOWNLOAD_SCRIPT)" was not found. \
  Please place it in this directory)
endif

ifeq (,$(wildcard $(MSVC_LIBS_SCRIPT)))
 $(error ERROR: The script "$(MSVC_LIBS_SCRIPT)" was not found. \
  Please place it in this directory)
endif

ifeq (,$(wildcard $(MSVC_LIBS_CONFIG)))
 $(error ERROR: The configuration file "$(MSVC_LIBS_CONFIG)" was not found. \
  Please place it in this directory)
endif

# -----------------------------------------------------------------------------
# Check downloaded packages
# -----------------------------------------------------------------------------

override undefine MSVC_DIR
override undefine SDK_DIR
override undefine MSVC_LIBS_DIR
override undefine ATL_DIR

MSVC_DIR = VC
SDK_DIR = Windows Kits
MSVC_LIBS_DIR = msvc-libs

CRT_ROOT_DIR = VC/Tools/MSVC
CRT_VERSION =

ATL_DIR = $(CRT_ROOT_DIR)/$(CRT_VERSION)/atlmfc

# Escape spaces
override undefine empty
override undefine space
empty :=
space := $(empty) $(empty)
ESC_SPACE = $(subst $(space),\ ,$(1))

override undefine wdir
override undefine version

define GET_DIR_VERSION
ifdef NATIVEWIN
 wdir := $$(subst /,\,$(1))
 version := $$(lastword $$(shell dir "$$(wdir)" /b/a:d 2>nul))
else
 version := $$(shell { cd "$(1)" && ls -d -- */ | tail -n 1; \
  } 2>/dev/null)
 version := $$(version:%/=%)
endif
endef

define DO_UPDATE_VERSION
$(call GET_DIR_VERSION,$(CRT_ROOT_DIR))
CRT_VERSION := $$(version)
endef
UPDATE_VERSION = $(eval $(DO_UPDATE_VERSION))

define DO_CHECK_VERSION
$(call GET_DIR_VERSION,$(CRT_ROOT_DIR))
ifneq (,$$(CRT_VERSION))
 ifneq (,$$(version))
  ifneq ($$(version),$$(CRT_VERSION))
   $$(error ERROR: MSVC version changed from $$(CRT_VERSION) to $$(version).\
    Delete the "VC" directory and run "make" again)
  endif
 endif
endif
endef
CHECK_VERSION = $(eval $(DO_CHECK_VERSION))

$(UPDATE_VERSION)

# -----------------------------------------------------------------------------
# Packages
# -----------------------------------------------------------------------------

CRT_LIB_X86 = $(CRT_ROOT_DIR)/$(CRT_VERSION)/lib/x86/pgobootrun.lib
CRT_LIB_X64 = $(CRT_ROOT_DIR)/$(CRT_VERSION)/lib/x64/pgobootrun.lib
CRT_LIB_ARM = $(CRT_ROOT_DIR)/$(CRT_VERSION)/lib/arm/pgobootrun.lib
CRT_LIB_ARM64 = $(CRT_ROOT_DIR)/$(CRT_VERSION)/lib/arm64/pgobootrun.lib
CRT_LIB_ATL_X86 = $(ATL_DIR)/lib/x86/
CRT_LIB_ATL_X64 = $(ATL_DIR)/lib/x64/
CRT_LIB_ATL_ARM = $(ATL_DIR)/lib/arm/
CRT_LIB_ATL_ARM64 = $(CRT_ROOT_DIR)/$(CRT_VERSION)/atlmfc/lib/arm64/

SDK_ALL = $(call ESC_SPACE,Windows Kits/)

DEFAULT_CRT_PACKAGES = $(CRT_LIB_X86) $(CRT_LIB_X64)
ifeq (arm_def,$(.DEFAULT_GOAL))
 DEFAULT_CRT_PACKAGES = $(CRT_LIB_ARM) $(CRT_LIB_ARM64)
endif

PACKAGES =
ifneq (,$(filter all intel intel_def x86 x64 atl atl32 atl64,$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_X86) $(CRT_LIB_X64)
endif
ifneq (,$(filter all arm arm_def arm32 atlarm atlarm32,$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_ARM)
endif
ifneq (,$(filter all arm arm_def arm64 atlarm atlarm64,$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_ARM64)
endif
ifneq (,$(filter all atl atl32 atl64,$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_ATL_X86) $(CRT_LIB_ATL_X64)
endif
ifneq (,$(filter all atlarm atlarm32,$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_ATL_ARM)
endif
ifneq (,$(filter all atlarm atlarm64,$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_ATL_ARM64)
endif
ifneq (,$(filter default,$(MAKECMDGOALS)))
 PACKAGES += $(DEFAULT_CRT_PACKAGES)
endif

# All the above targets download the required CRT packages
ifndef PACKAGES
 PACKAGES += $(DEFAULT_CRT_PACKAGES)
endif

# The SDK is required to build the library
PACKAGES += $(SDK_ALL)

MAKE_LIB = msvc-libs
ifneq (,$(filter onlydl,$(MAKECMDGOALS)))
 MAKE_LIB =
endif
NO_DL =
ifneq (,$(filter nodl,$(MAKECMDGOALS)))
 NO_DL = 1
endif

# -----------------------------------------------------------------------------
# Targets
# -----------------------------------------------------------------------------

.PHONY: all intel arm x86 x64 arm32 arm64 \
  atl atlarm atl32 atl64 atlarm32 atlarm64 \
  sdk default onlydl nodl msvc-libs \
  clean-all clean-dl clean-msvc clean-sdk clean clean-atl \
  intel_def arm_def

default: $(.DEFAULT_GOAL)

all: atl atlarm sdk
intel_def: intel sdk
arm_def: arm sdk
intel: $(CRT_LIB_X86) $(CRT_LIB_X64) $(MAKE_LIB)
arm: arm32 arm64
x86 x64: intel
arm32: $(CRT_LIB_ARM) $(MAKE_LIB)
arm64: $(CRT_LIB_ARM64) $(MAKE_LIB)

atl: $(CRT_LIB_ATL_X86) $(CRT_LIB_ATL_X64) intel
atlarm: atlarm32 atlarm64
atl32 atl64: atl
atlarm32: $(CRT_LIB_ATL_ARM) arm32
atlarm64: $(CRT_LIB_ATL_ARM64) arm64

sdk: $(SDK_ALL) $(MAKE_LIB)

msvc-libs: $(MSVC_LIBS_DIR)/

clean-all: clean clean-dl
clean-dl: clean-msvc clean-sdk

# -----------------------------------------------------------------------------
# Rules
# -----------------------------------------------------------------------------

DOWNLOAD_OPTIONS = --accept-license --skip-recommended
ifdef DL_LANG
 DOWNLOAD_OPTIONS += --language $(DL_LANG)
endif

.DELETE_ON_ERROR:

override undefine cmd_flag_prereq
cmd_flag_prereq =
ifeq (,$(filter-out onlydl nodl,$(MAKECMDGOALS)))
 cmd_flag_prereq = default
endif

define CMD_FLAG_RULE
$(1): $(cmd_flag_prereq)
ifeq (,$(cmd_flag_prereq))
	@echo >$(DEVNUL)
endif
endef

$(eval $(call CMD_FLAG_RULE,onlydl))
$(eval $(call CMD_FLAG_RULE,nodl))


override undefine dir
override undefine wdir

define CLEAN_DIR_RULE
$(1): dir := $$(patsubst /,,$$(subst \,/,$(2)))
$(1): wdir := $$(patsubst \,,$$(subst /,\,$(2)))
$(1):
ifdef NATIVEWIN
	if exist "$$(wdir)\" rd /s/q "$$(wdir)"
else
	rm -rf "$$(dir)"
endif
endef

$(eval $(call CLEAN_DIR_RULE,clean,$(MSVC_LIBS_DIR)))
$(eval $(call CLEAN_DIR_RULE,clean-msvc,$(MSVC_DIR)))
$(eval $(call CLEAN_DIR_RULE,clean-sdk,$(SDK_DIR)))
ifdef CRT_VERSION
$(eval $(call CLEAN_DIR_RULE,clean-atl,$(ATL_DIR)))
endif


define DOWNLOAD_RULE
$$($(1)): ; $$(CHECK_VERSION)
ifndef NO_DL
	$$(info )$$(info *** Downloading $(2) ...)$$(info )
	$$(PYTHON) vsdownload.py $$(DOWNLOAD_OPTIONS) \
		"Microsoft.VisualStudio.Component.$(2)" --dest .
else
	$$(error Package needed: $(2))
endif
endef

$(CRT_LIB_X86): $(CRT_LIB_X64)
$(CRT_LIB_ATL_X86): $(CRT_LIB_ATL_X64)

$(eval $(call DOWNLOAD_RULE,CRT_LIB_X64,VC.Tools.x86.x64))
$(eval $(call DOWNLOAD_RULE,CRT_LIB_ARM,VC.Tools.ARM))
$(eval $(call DOWNLOAD_RULE,CRT_LIB_ARM64,VC.Tools.ARM64))
$(eval $(call DOWNLOAD_RULE,CRT_LIB_ATL_X64,VC.ATL))
$(eval $(call DOWNLOAD_RULE,CRT_LIB_ATL_ARM,VC.ATL.ARM))
$(eval $(call DOWNLOAD_RULE,CRT_LIB_ATL_ARM64,VC.ATL.ARM64))
$(eval $(call DOWNLOAD_RULE,SDK_ALL,Windows11SDK.22621))


$(MSVC_LIBS_DIR)/: dir := $(patsubst /,,$(subst \,/,$(MSVC_LIBS_DIR)))
$(MSVC_LIBS_DIR)/: wdir := $(patsubst \,,$(subst /,\,$(MSVC_LIBS_DIR)))

$(MSVC_LIBS_DIR)/: $(PACKAGES) ; $(CHECK_VERSION)
ifdef NATIVEWIN
	if exist "$(wdir)\" rd /s/q "$(wdir)"
	make_msvc-libs.cmd -ilq
else
	rm -rf "$(dir)"
	@chmod u+x make_msvc-libs.sh
	./make_msvc-libs.sh -ilq
endif
