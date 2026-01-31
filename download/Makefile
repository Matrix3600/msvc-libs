#
# MSVC-Libs 1.4
#
# Makefile (version for GNU make, Windows or Linux)
#
# -----------------------------------------------------------------------------
# Copyright 2025-2026 https://github.com/Matrix3600
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
define HELP
Usage: make [<parameter>...]

Parameters to choose which packages to download:
  default       (intel + sdk), (arm32 + sdk) or (arm64 + sdk), depending on
                your machine architecture. Implicit when no argument is
                specified.
  all           intel + arm64 + atl + atlarm64 + asan + sdk
                (arm32 is not included).
  intel         [VC.Tools.x86.x64]
  arm           arm32 + arm64
  x86           = intel
  x64           = intel
  arm32         [VC.Tools.ARM]
  arm64         [VC.Tools.ARM64]
  atl           [VC.ATL] + intel
  atlarm        atlarm32 + atlarm64
  atl32         = atl
  atl64         = atl
  atlarm32      [VC.ATL.ARM] + arm32
  atlarm64      [VC.ATL.ARM64] + arm64
  asan          [VC.ASAN]
  sdk           [Windows<winver>SDK.<sdkver>]
                See below for values of <sdkver>.

  vsver=x[.y]   Visual Studio version (15, 16.0 to 18.2) (default: 18).
                If only the major version is specified (e.g., 17), the
                latest unversioned MSVC packages are selected for this version.
                If a full version is specified (e.g., 17.5), the corresponding
                versioned MSVC packages are selected.
  sdkver=xxxxx  SDK version (19041,22621,26100)
                (default: 26100 (VS 17/18), 22621 (VS 16) or 19041 (VS 15)).
  preview       Download preview versions instead of release versions.
  lang=xx[-yy]  Preferred language code for packages available in multiple
                languages (default: LANG environment variable, or "en").

The downloaded packages are indicated in brackets.

arm32/atlarm32 and sdkver=19041 are no longer available in Visual Studio 18
and up.

Other parameters:
  help          Display this help message.
  onlydl        Download only, do not create the standalone library.
  nodl          Do not download anything. Stop if any package is missing.
  clean         Delete the "msvc-libs" directory of created standalone
                library, do not delete any downloaded files.
  clean-all     Delete all the directories created by this makefile.
  clean-dl      Delete all the download directories ("VC" and
                "Windows Kits").
  clean-msvc    Delete the "VC" directory.
  clean-sdk     Delete the "Windows Kits" directory.
  clean-atl     Delete the ATL download directory.
endef
#
# The unversioned packages are always the latest available.
# The standalone library is always created at the end, unless the "onlydl"
# parameter is specified.
#
# Note: Microsoft dropped support for 32-bit ARM in SDK 26100.
# If you request ARM32 with SDK >= 26100 and VS < 18, the makefile copies the
# ARM32 files from SDK 22621 into the new SDK.
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

ifndef NATIVEWIN
 SHELL := $(shell which bash)
endif

.DEFAULT_GOAL = intel_def
ifeq ($(OS),Windows_NT)
 ifeq (ARM64,$(PROCESSOR_ARCHITECTURE))
  .DEFAULT_GOAL = arm64_def
 else ifeq (ARM,$(PROCESSOR_ARCHITECTURE))
  .DEFAULT_GOAL = arm32_def
 endif
else
 ifneq (,$(filter aarch64% arm64%,$(shell uname -m 2>$(DEVNUL))))
  .DEFAULT_GOAL = arm64_def
 else ifneq (,$(filter arm%,$(shell uname -m 2>$(DEVNUL))))
  .DEFAULT_GOAL = arm32_def
 endif
endif

# -----------------------------------------------------------------------------

# Escape spaces
override undefine empty
override undefine space
empty :=
space := $(empty) $(empty)
ESC_SPACE = $(subst $(space),\ ,$(1))

# $(intcmp ...) function requires Make 4.4+ (2022-10).
# If 5th argument is missing or empty, it defaults to 4th.
ifeq (4.4,$(firstword $(sort $(MAKE_VERSION) 4.4)))
 INTCMP = $(intcmp $(1),$(2),$(3),$(4),$(or $(5),$(4)))
else
 # Alternative for older versions
 ifdef NATIVEWIN
  INTCMP = $(shell if $(or $(strip $(1)),0) lss $(or $(strip $(2)),0) \
    (echo;$(3)) else if $(or $(strip $(1)),0) gtr $(or $(strip $(2)),0) \
    (echo;$(or $(5),$(4))) else echo;$(4))
 else
  INTCMP = $(shell [ "$(1)" -lt "$(2)" ] && echo "$(3)" || \
    { [ "$(1)" -gt "$(2)" ] && echo "$(or $(5),$(4))" || echo "$(4)"; })
 endif
endif

# -----------------------------------------------------------------------------

PYTHON = python3
ifeq (,$(shell $(PYTHON) --version 2>$(DEVNUL)))
 PYTHON = python
 ifeq (,$(shell $(PYTHON) --version 2>$(DEVNUL)))
  $(error ERROR: Python was not found. Please install it)
 endif
endif

ifdef NATIVEWIN
 PWRSHELL = pwsh.exe
 ifeq (,$(shell $(PWRSHELL) --version 2>nul))
  PWRSHELL = powershell.exe
  override undefine version
  version = $(or $(shell \
    $(PWRSHELL) -c "$$PSVersionTable.PSVersion.Major" 2>nul),0)
  ifeq (,$(call INTCMP,$(version),3,,1))
   $(error ERROR: PowerShell 3 or higher is required)
  endif
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
# Read parameters
# -----------------------------------------------------------------------------

ifdef lang
 DL_LANG := $(lang)
 override undefine lang
else
 ifdef LANG
  DL_LANG := $(subst _,-,$(firstword $(subst ., ,$(LANG))))
 endif
endif

# Minimum and maximum major versions of Visual Studio supported
VS_MIN_MAJOR_VERSION = 15
VS_MAX_MAJOR_VERSION = 18

# List of Visual Studio versions
VS_VERSIONS_1 = 16.0  16.1  16.2  16.3  16.4  16.5  16.6  16.7  16.8
VS_VERSIONS_2 = 16.9  16.10 16.11 17.0  17.1  17.2  17.3  17.4  17.5  17.6 \
  17.7  17.8  17.9  17.10 17.11 17.12 17.13 17.14 18.0
# List of corresponding MSVC Build Tools versions
VC_VERSIONS_1 = 14.20 14.21 14.22 14.23 14.24 14.25 14.26 14.27 14.28
VC_VERSIONS_2 = 14.28 14.29 14.29 14.30 14.31 14.32 14.33 14.34 14.35 14.36 \
  14.37 14.38 14.39 14.40 14.41 14.42 14.43 14.44 14.50

# List of VS version groups having the same Build Tools package version
VS_VERSION_GROUPS = 18.0/18.1/18.2

# VSVER_TO_VSVER_GROUP: Search for VS version group from VS version
override undefine _group
_group = $(if $(filter $1,$2),$(firstword $2))
VSVER_TO_VSVER_GROUP = $(if $2,$(or $\
  $(call _group,$1,$(subst /, ,$(firstword $2))),$\
  $(call VSVER_TO_VSVER_GROUP,$1,$(wordlist 2,$(words $2),$2))))

# VSVER_TO_VCVER: Convert Visual Studio version to MSVC Build Tools version
VSVER_TO_VCVER = $(call LOOKUP,$1,$(VS_VERSIONS_1) $(VS_VERSIONS_2),$\
  $(VC_VERSIONS_1) $(VC_VERSIONS_2))

# LOOKUP: Find an element in a list and return the corresponding element in
# another list.
override undefine _pos
override undefine pos
_pos = $(if $(filter $1,$2),$(call _pos,$1,\
         $(wordlist 2,$(words $2),$2),x $3),$3)
pos = $(words $(call _pos,$1,$2))
LOOKUP = $(word $(call pos,$1,$2),$3)

# By default, select the latest unversioned packages for the latest major
# version of Visual Studio
VC_TOOLS_VER = Tools
VC_VERSION =
VC_PREFIX =
VS_MAJOR_VERSION = $(VS_MAX_MAJOR_VERSION)

ifdef vsver
 override undefine vs_ver_list
 vs_ver_list := $(subst ., ,$(vsver))
 ifeq (1,$(words $(vs_ver_list)))
  # Select the latest unversioned packages for the specified major version of
  # Visual Studio
  ifneq (,$(or $(call INTCMP,$(vsver),$(VS_MIN_MAJOR_VERSION),1,),$\
     $(call INTCMP,$(vsver),$(VS_MAX_MAJOR_VERSION),,,1)))
   $(error ERROR: Visual Studio $(vsver) is not supported)
  endif
  VS_MAJOR_VERSION := $(vsver)
 else
  ifneq (2,$(words $(vs_ver_list)))
   $(error ERROR: $(vsver) is not a valid version (x.x))
  endif

  override undefine base_vsver
  base_vsver := $(or $\
    $(call VSVER_TO_VSVER_GROUP,$(vsver),$(VS_VERSION_GROUPS)),$(vsver))

  ifeq (,$(filter $(base_vsver),$(VS_VERSIONS_1) $(VS_VERSIONS_2)))
   $(error ERROR: $(base_vsver) is not a supported version of Visual Studio)
  endif

  override undefine vc_ver
  vc_ver := $(call VSVER_TO_VCVER,$(base_vsver))

  ifneq (,$(filter $(base_vsver),$(VS_VERSIONS_1)))
   VC_TOOLS_VER := $(vc_ver)
  else
   VC_TOOLS_VER := $(vc_ver).$(base_vsver)
  endif
  VC_VERSION := $(VC_TOOLS_VER).
  override undefine vc_ver_list
  vc_ver_list := $(subst ., ,$(vc_ver))
  VC_PREFIX := $(subst $(space),.,$(wordlist 1,2,$(vc_ver_list))).

  ifeq (16.11,$(vsver))
   VS_MAJOR_VERSION = 17
  else
   VS_MAJOR_VERSION := $(firstword $(vs_ver_list))
  endif
 endif

 override undefine vsver
endif

VS15_SDK_VERSIONS = 19041
VS16_SDK_VERSIONS = 19041 22621
VS17_SDK_VERSIONS = 19041 22621 26100
VS18_SDK_VERSIONS = 22621 26100

ifdef sdkver
 ifeq (,$(filter $(sdkver),$(VS$(VS_MAJOR_VERSION)_SDK_VERSIONS)))
  $(error ERROR: SDK $(sdkver) is not supported by Visual Studio $\
    $(VS_MAJOR_VERSION))
 endif
 SDK_VERSION := $(sdkver)
 override undefine sdkver
else
 SDK_VERSION := $(lastword $(VS$(VS_MAJOR_VERSION)_SDK_VERSIONS))
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

override undefine gdv_wdir
override undefine gdv_version

define GET_DIR_VERSION
ifdef NATIVEWIN
 gdv_wdir := $$(subst /,\,$(1))
 gdv_version := $$(shell $$(PWRSHELL) -c "Get-ChildItem '$$(gdv_wdir)' \
   -Directory -Name | Where-Object { $$$$_ -match '^\d+(\.\d+){0,3}$$$$' } | \
   Sort-Object { $$$$($$$$_ -replace '^\d+$$$$','$$$$&.0') -as [version] } | \
   Select-Object -Last 1" 2>nul)
else
 gdv_version := $$(shell { cd "$(1)" && ls -dv -- */ | tail -n 1; \
   } 2>/dev/null)
 gdv_version := $$(gdv_version:%/=%)
endif
endef

define CLEAN_VERSION
$(call GET_DIR_VERSION,$(1))
ifneq (,$$(gdv_version))
 ifeq ($$(gdv_version),$(2))
  $$(error ERROR: Failed to delete directory $(1)/$(2))
 endif
 # If this directory does not contain a "lib", "include", "atlmfc" or "bin"
 # sub-directory, or does not start with VC_PREFIX, delete it.
 ifeq (,$$(and \
    $$(wildcard $(addprefix $(1)/$$(gdv_version)/,$(addsuffix /.,$\
      lib include atlmfc bin))),$\
    $$(filter $(VC_PREFIX)%,$$(gdv_version))))
  $$(info Deleting directory $(1)/$$(gdv_version) ...)
  ifdef NATIVEWIN
   gdv_wdir := $$(subst /,\,$(1))\$$(gdv_version)
   $$(shell rd /s/q "$$(gdv_wdir)" >nul)
  else
   $$(shell rm -rf "$(1)/$$(gdv_version)" >/dev/null)
  endif
  # To avoid an infinite loop in case of rd/rm failure, gdv_version is passed
  # as an additional argument and tested at the next level.
  $$(eval $$(call CLEAN_VERSION,$(1),$$(gdv_version)))
 endif
endif
endef

define DO_UPDATE_VERSION
$(call CLEAN_VERSION,$(CRT_ROOT_DIR))
$(call GET_DIR_VERSION,$(CRT_ROOT_DIR))
CRT_VERSION := $$(gdv_version)
endef
UPDATE_VERSION = $(eval $(DO_UPDATE_VERSION))

define DO_CHECK_VERSION
$(call CLEAN_VERSION,$(CRT_ROOT_DIR))
$(call GET_DIR_VERSION,$(CRT_ROOT_DIR))
ifneq (,$$(CRT_VERSION))
 ifneq (,$$(gdv_version))
  ifneq ($$(gdv_version),$$(CRT_VERSION))
   $$(error ERROR: MSVC version changed from $$(CRT_VERSION) to $$(gdv_version).\
     Delete the "VC" directory and run "make" again)
  endif
 endif
endif
endef
CHECK_VERSION = $(eval $(DO_CHECK_VERSION))

$(UPDATE_VERSION)

SDK_FULL_VER = 10.0.$(SDK_VERSION).0
SDK_INC_DIR = $(SDK_DIR)/10/Include/$(SDK_FULL_VER)
SDK_LIB_DIR = $(SDK_DIR)/10/Lib/$(SDK_FULL_VER)

# Last SDK version with 32-bit ARM support
SDKARM32_VERSION = 22621
SDKARM32_FULL_VER = 10.0.$(SDKARM32_VERSION).0
SDKARM32_INC_DIR = $(SDK_DIR)/10/Include/$(SDKARM32_FULL_VER)
SDKARM32_LIB_DIR = $(SDK_DIR)/10/Lib/$(SDKARM32_FULL_VER)

# -----------------------------------------------------------------------------
# Packages
# -----------------------------------------------------------------------------

CRT_LIB_X86 = $(CRT_ROOT_DIR)/$(CRT_VERSION)/lib/x86/pgobootrun.lib
CRT_LIB_X64 = $(CRT_ROOT_DIR)/$(CRT_VERSION)/lib/x64/pgobootrun.lib
CRT_LIB_ARM32 = $(CRT_ROOT_DIR)/$(CRT_VERSION)/lib/arm/pgobootrun.lib
CRT_LIB_ARM64 = $(CRT_ROOT_DIR)/$(CRT_VERSION)/lib/arm64/pgobootrun.lib
CRT_LIB_ATL_X86 = $(ATL_DIR)/lib/x86/
CRT_LIB_ATL_X64 = $(ATL_DIR)/lib/x64/
CRT_LIB_ATL_ARM32 = $(ATL_DIR)/lib/arm/
CRT_LIB_ATL_ARM64 = $(ATL_DIR)/lib/arm64/

ifndef VC_PREFIX
 CRT_LIB_ASAN = $(CRT_ROOT_DIR)/$(CRT_VERSION)/include/sanitizer
else
 CRT_LIB_ASAN =
endif

SDK_LIB = $(call ESC_SPACE,$(SDK_LIB_DIR))/
SDK_LIB_ARM32 = $(call ESC_SPACE,$(SDK_LIB_DIR))/um/arm/

SDKARM32_LIB = $(call ESC_SPACE,$(SDKARM32_LIB_DIR))/um/arm/

DEFAULT_CRT_PACKAGES = $(CRT_LIB_X86) $(CRT_LIB_X64)
ifeq (arm32_def,$(.DEFAULT_GOAL))
 DEFAULT_CRT_PACKAGES = $(CRT_LIB_ARM32)
else ifeq (arm64_def,$(.DEFAULT_GOAL))
 DEFAULT_CRT_PACKAGES = $(CRT_LIB_ARM64)
endif

override undefine arm32_targets
override undefine atlarm32_targets
arm32_targets = arm32 arm32_def atlarm32
atlarm32_targets = atlarm32
ifeq (,$(call INTCMP,$(VS_MAJOR_VERSION),18,,1))
 arm32_targets += arm atlarm
 atlarm32_targets += atlarm
endif

PACKAGES =
SDK_PACKAGES =
ifneq (,$(filter all intel intel_def x86 x64 atl atl32 atl64,$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_X86) $(CRT_LIB_X64)
endif
ifneq (,$(filter $(arm32_targets),$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_ARM32)
 SDK_PACKAGES += $(SDK_LIB_ARM32)
endif
ifneq (,$(filter all arm arm64 arm64_def atlarm atlarm64,$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_ARM64)
endif
ifneq (,$(filter all atl atl32 atl64,$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_ATL_X86) $(CRT_LIB_ATL_X64)
endif
ifneq (,$(filter $(atlarm32_targets),$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_ATL_ARM32)
 SDK_PACKAGES += $(SDK_LIB_ARM32)
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

# Additional targets that do not download the required CRT packages
ifneq (,$(filter all asan,$(MAKECMDGOALS)))
 PACKAGES += $(CRT_LIB_ASAN)
endif

# The SDK is required to build the library
SDK_PACKAGES += $(SDK_LIB)

PACKAGES += $(SDK_PACKAGES)

# -----------------------------------------------------------------------------
# Targets
# -----------------------------------------------------------------------------

override undefine target_list
target_list = all intel arm x86 x64 arm32 arm64 atl atlarm atl32 atl64 \
  atlarm32 atlarm64 asan sdk default intel_def arm32_def arm64_def
$(foreach target,$(target_list),$(eval END_$(target)=))

ifeq (,$(filter onlydl,$(MAKECMDGOALS)))
 END_$(or $(lastword $(filter $(target_list),$(MAKECMDGOALS))),\
   $(.DEFAULT_GOAL)) = $(MSVC_LIBS_DIR)/
endif
NO_DL := $(if $(filter nodl,$(MAKECMDGOALS)),1)
PREVIEW := $(if $(filter preview,$(MAKECMDGOALS)),1)

INTEL_PACKAGES = $(CRT_LIB_X86) $(CRT_LIB_X64)
ATL_PACKAGES = $(CRT_LIB_ATL_X86) $(CRT_LIB_ATL_X64) $(INTEL_PACKAGES)
ATLARM32_PACKAGES = $(CRT_LIB_ATL_ARM32) $(CRT_LIB_ARM32)
ATLARM64_PACKAGES = $(CRT_LIB_ATL_ARM64) $(CRT_LIB_ARM64)

.PHONY: $(target_list) onlydl nodl preview help \
  clean clean-all clean-dl clean-msvc clean-sdk clean-atl

default: $(.DEFAULT_GOAL) $(END_default)

all: $(ATL_PACKAGES) $(ATLARM64_PACKAGES) $(CRT_LIB_ASAN) \
  $(SDK_PACKAGES) $(END_all)
intel_def: $(INTEL_PACKAGES) $(SDK_PACKAGES) $(END_intel_def)
arm32_def: $(CRT_LIB_ARM32) $(SDK_PACKAGES) $(END_arm32_def)
arm64_def: $(CRT_LIB_ARM64) $(SDK_PACKAGES) $(END_arm64_def)
intel: $(INTEL_PACKAGES) $(END_intel)
x86: $(INTEL_PACKAGES) $(END_x86)
x64: $(INTEL_PACKAGES) $(END_x64)
arm32: $(CRT_LIB_ARM32) $(END_arm32)
arm64: $(CRT_LIB_ARM64) $(END_arm64)

atl: $(ATL_PACKAGES) $(END_atl)
atl32: $(ATL_PACKAGES) $(END_atl32)
atl64: $(ATL_PACKAGES) $(END_atl64)
atlarm32: $(ATLARM32_PACKAGES) $(END_atlarm32)
atlarm64: $(ATLARM64_PACKAGES) $(END_atlarm64)

asan: $(CRT_LIB_ASAN) $(END_asan)

ifeq (,$(call INTCMP,$(VS_MAJOR_VERSION),18,,1))
arm: $(CRT_LIB_ARM32) $(CRT_LIB_ARM64) $(END_arm)
atlarm: $(ATLARM32_PACKAGES) $(ATLARM64_PACKAGES) $(END_atlarm)
else
arm: $(CRT_LIB_ARM64) $(END_arm)
atlarm: $(ATLARM64_PACKAGES) $(END_atlarm)
endif

sdk: $(SDK_PACKAGES) $(END_sdk)

clean-all: clean clean-dl
clean-dl: clean-msvc clean-sdk

help:
	@:$(info $(HELP))

# -----------------------------------------------------------------------------
# Rules
# -----------------------------------------------------------------------------

DOWNLOAD_OPTIONS = --accept-license --skip-recommended
DOWNLOAD_OPTIONS += --major $(VS_MAJOR_VERSION)

ifdef PREVIEW
 DOWNLOAD_OPTIONS += --preview
endif

ifdef DL_LANG
 DOWNLOAD_OPTIONS += --language $(DL_LANG)
endif

override undefine sdkwinver
sdkwinver := $(call INTCMP,$(SDK_VERSION),22000,10,11)
SDK_PACKAGE := Windows$(sdkwinver)SDK.$(SDK_VERSION)

sdkwinver := $(call INTCMP,$(SDKARM32_VERSION),22000,10,11)
SDKARM32_PACKAGE := Windows$(sdkwinver)SDK.$(SDKARM32_VERSION)

.DELETE_ON_ERROR:

override undefine cmd_flag_prereq
cmd_flag_prereq := $(if $(filter-out onlydl nodl preview,$(MAKECMDGOALS)),,default)

define CMD_FLAG_RULE
$(1): $(cmd_flag_prereq) ; $(if $(cmd_flag_prereq),,@:)
endef

$(eval $(call CMD_FLAG_RULE,onlydl))
$(eval $(call CMD_FLAG_RULE,nodl))
$(eval $(call CMD_FLAG_RULE,preview))

#
# Clean directories
#
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

#
# Download packages
#
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

define ERROR_PACKAGE_NOT_AVAILABLE
$$($(1)):
	$$(error ERROR: The $(2) package is not available for this version of Visual Studio)
endef

$(CRT_LIB_X86): $(CRT_LIB_X64)
$(CRT_LIB_ATL_X86): $(CRT_LIB_ATL_X64)

$(eval $(call DOWNLOAD_RULE,CRT_LIB_X64,VC.$(VC_TOOLS_VER).x86.x64))
$(eval $(call DOWNLOAD_RULE,CRT_LIB_ARM64,VC.$(VC_TOOLS_VER).ARM64))
$(eval $(call DOWNLOAD_RULE,CRT_LIB_ATL_X64,VC.$(VC_VERSION)ATL))
$(eval $(call DOWNLOAD_RULE,CRT_LIB_ATL_ARM64,VC.$(VC_VERSION)ATL.ARM64))
ifndef VC_PREFIX
 $(eval $(call DOWNLOAD_RULE,CRT_LIB_ASAN,VC.ASAN))
endif
$(eval $(call DOWNLOAD_RULE,SDK_LIB,$(SDK_PACKAGE)))

ifeq (,$(call INTCMP,$(VS_MAJOR_VERSION),18,,1))
 $(eval $(call DOWNLOAD_RULE,CRT_LIB_ARM32,VC.$(VC_TOOLS_VER).ARM))
 $(eval $(call DOWNLOAD_RULE,CRT_LIB_ATL_ARM32,VC.$(VC_VERSION)ATL.ARM))
else
 $(eval $(call ERROR_PACKAGE_NOT_AVAILABLE,CRT_LIB_ARM32,VC.$(VC_TOOLS_VER).ARM))
 $(eval $(call ERROR_PACKAGE_NOT_AVAILABLE,CRT_LIB_ATL_ARM32,VC.$(VC_VERSION)ATL.ARM))
endif

ifneq ($(SDK_VERSION),$(SDKARM32_VERSION))
 $(eval $(call DOWNLOAD_RULE,SDKARM32_LIB,$(SDKARM32_PACKAGE)))
endif

#
# Build library
#
$(MSVC_LIBS_DIR)/: private dir := $(patsubst /,,$(subst \,/,$(MSVC_LIBS_DIR)))
$(MSVC_LIBS_DIR)/: private wdir := $(patsubst \,,$(subst /,\,$(MSVC_LIBS_DIR)))

$(MSVC_LIBS_DIR)/: $(PACKAGES) ; $(CHECK_VERSION)
ifdef NATIVEWIN
	if exist "$(wdir)\" rd /s/q "$(wdir)"
	make_msvc-libs.cmd -ilq
else
	rm -rf "$(dir)"
	@chmod u+x make_msvc-libs.sh
	./make_msvc-libs.sh -ilq
endif

#
# Arm32 support for SDK 26100+ and Visual Studio < 18
#
ifneq (,$(and $(call INTCMP,$(SDK_VERSION),26100,,1),$\
   $(call INTCMP,$(VS_MAJOR_VERSION),18,1,)))
 ifdef NATIVEWIN
  override undefine wdir_lib
  override undefine wdir_arm32_lib
  override undefine wdir_inc
  override undefine wdir_arm32_inc
$(SDK_LIB_ARM32): wdir_arm32_lib := $(subst /,\,$(SDKARM32_LIB_DIR))
$(SDK_LIB_ARM32): wdir_lib := $(subst /,\,$(SDK_LIB_DIR))
$(SDK_LIB_ARM32): wdir_arm32_inc := $(subst /,\,$(SDKARM32_INC_DIR))
$(SDK_LIB_ARM32): wdir_inc := $(subst /,\,$(SDK_INC_DIR))
 endif

$(SDK_LIB_ARM32): $(SDKARM32_LIB) $(SDK_LIB)
	$(info )$(info *** Adding ARM32 files to SDK $(SDK_VERSION) ...)$(info )
 ifdef NATIVEWIN
	xcopy /qsy "$(wdir_arm32_lib)\ucrt\arm\*" "$(wdir_lib)\ucrt\arm\" >nul
	xcopy /qsy "$(wdir_arm32_lib)\um\arm\*" "$(wdir_lib)\um\arm\" >nul
	copy /y "$(wdir_arm32_inc)\shared\k?arm.h" "$(wdir_inc)\shared\" >nul
	copy /y "$(wdir_arm32_inc)\shared\kxarmunw.h" "$(wdir_inc)\shared\" >nul
	@for %%f in (clfsmgmt.lib drt.lib drtprov.lib drttransport.lib elfapi.lib \
	 MSAJApi.lib p2p.lib p2pgraph.lib) do del "$(wdir_lib)\um\arm\%%f"
 else
	@mkdir -p "$(SDK_LIB_DIR)/ucrt/arm"
	cp -rf "$(SDKARM32_LIB_DIR)/ucrt/arm/" "$(SDK_LIB_DIR)/ucrt/"
	@mkdir -p "$(SDK_LIB_DIR)/um/arm"
	cp -rf "$(SDKARM32_LIB_DIR)/um/arm/" "$(SDK_LIB_DIR)/um/"
	@mkdir -p "$(SDK_INC_DIR)/shared"
	cp -f "$(SDKARM32_INC_DIR)"/shared/k?arm.h "$(SDK_INC_DIR)/shared"
	cp -f "$(SDKARM32_INC_DIR)"/shared/kxarmunw.h "$(SDK_INC_DIR)/shared"
	@for f in clfsmgmt.lib drt.lib drtprov.lib drttransport.lib elfapi.lib \
	 MSAJApi.lib p2p.lib p2pgraph.lib; do rm -f "$(SDK_LIB_DIR)/um/arm/$$f"; done
 endif
else
 $(SDK_LIB_ARM32): $(SDK_LIB)
endif
