#!/usr/bin/env bash

#
# make_msvc-libs.sh
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
# Build the repackaged MSVC/SDK headers and libraries.
#
# Compatible with Windows and Linux for cross-compilation.
#
# - Rename the files and directories to lowercase for compatibility
#   with case-sensitive systems (Linux).
# - Rename the include directives in source files accordingly.
#
# Options:
#   -i  Include the directories specified in the configuration file, but do
#       not cause any error if they do not exist.
#   -l  Force selection of local subdirectories for the source (located in
#       the same directory as this script).
#   -q  Do not ask for confirmation before starting.
#

# This script searches for root directories containing source files ("VC" and
# "Windows Kits") in the same directory as this script. Subdirectories are
# found automatically.
# If the source files are in a custom location, you must specify their path and
# the version of the tools (MSVC and SDK). In this case, modify and uncomment
# the three variables below (all three):
# VCToolsInstallDir="<custom_location_of_MSVC>/VC/Tools/MSVC/14.44.35128"
# WindowsSdkDir="<custom_location_of_SDK>/Windows Kits/10"
# WindowsSDKVersion="10.0.26100.0"


main() {

msvc_dirname="msvc-libs"
config_file="make_msvc-libs_conf.txt"

interactive=false
if [ -z "$SHLVL" ] || [ "$SHLVL" = 1 ]; then interactive=true; fi

opt_include=0
opt_local=0
opt_quiet=0

while [[ $# -gt 0 ]]; do
	if [[ $1 =~ ^[/-]. ]]; then
		arg=${1:1}
		while [[ -n $arg ]]; do
			opt=${arg:0:1}
			case $opt in
				i) opt_include=1;;
				l) opt_local=1;;
				q) opt_quiet=1;;
				*)
					echo "ERROR: Invalid option $opt."
					exit_script 1
			esac
			arg=${arg:1}
		done	
	else	
		echo "ERROR: Invalid argument."
		exit_script 1
	fi
	shift
done

script_dir=$(cd -- "$(dirname -- "$0")" &>/dev/null && pwd)

cd "$script_dir"
if [ $? != 0 ]; then exit_script 10; fi

echo

if [ ! -f "$script_dir/$config_file" ]; then
	echo "ERROR: Configuration file not found: \"$config_file\"."
	exit_script 2
fi

search_path
case $? in
0) ;;
2) error_msvc_path;;
3) error_sdk_path;;
*) error_path
esac

MSVC_CRT_PATH=$VCToolsInstallDir
MSVC_SDK_INCLUDE_PATH="$WindowsSdkDir/Include/$WindowsSDKVersion"
MSVC_SDK_LIB_PATH="$WindowsSdkDir/Lib/$WindowsSDKVersion"

if [ ! -f "$MSVC_CRT_PATH/include/stdarg.h" ]; then	error_msvc_path; fi

if [ ! -f "$MSVC_SDK_INCLUDE_PATH/um/Windows.h" ] && \
	[ ! -f "$MSVC_SDK_INCLUDE_PATH/um/windows.h" ]; then error_sdk_path; fi

msvc_dirpath="$script_dir/$msvc_dirname"

if [ -e "$msvc_dirpath" ]; then
	echo "The \"$msvc_dirname\" directory already exists."
	echo "Please delete or rename it."
	exit_script 11
fi

echo "This script creates a repackaged standalone MSVC/SDK library from the"
echo "Visual Studio library."
echo
echo "The directory \"$msvc_dirname\" will be created in:"
echo "$script_dir"

if [ "$opt_quiet" = 0 ]; then
	echo
	read -rsn1 -p "Press any key to continue..."
	echo
fi

echo

mkdir "$msvc_dirname"
if [ $? != 0 ]; then exit_script 10; fi
cd "$msvc_dirname"
if [ $? != 0 ]; then exit_script 10; fi

linenum=0

while IFS= read -r line <&3
do
	((linenum++))
	line=${line%%#*}	# Remove comments
	line=$(trim "$line")
	if [ -n "$line" ]; then
		IFS="|" read -r recurs type source <<< "$line"
		recurs=$(trim "$recurs")
		type=$(trim "$type")
		source=$(trim "${source}")

		sourcedir=""
		destdir=""

		case $type in
		CRT)
			sourcedir=$MSVC_CRT_PATH
			destdir="crt";;
		SDK_INCLUDE)
			sourcedir=$MSVC_SDK_INCLUDE_PATH
			destdir="sdk/include";;
		SDK_LIB)
			sourcedir=$MSVC_SDK_LIB_PATH
			destdir="sdk/lib";;
		*)
			error_config $linenum
		esac

		case $recurs in
		0)
			subdirs="";;
		1)
			subdirs="/*";;
		*)
			error_config $linenum
		esac

		source=${source//\\/\/}	# Replace \ by /
		source=${source#/}	# Remove leading /
		source=${source%/}	# Remove trailing /
		if [ "$source" = "." ]; then source=""; fi
		if [ -n "$source" ]; then source="/${source//..}"; fi	# Remove ..

		if [ -d "$sourcedir$source" ]; then
			echo Copying \"[$type]$source$subdirs\" to \"$destdir$source\" ...

			mkdir -p "$destdir$source"
			if [ $? != 0 ]; then error_copy; fi

			if [ "$recurs" = 1 ]; then
				cp -rf "$sourcedir$source/." "$destdir$source"
			else
				find "$sourcedir$source" -maxdepth 1 -type f -print0 | \
					while IFS= read -r -d '' file; do
						cp -f "$file" "$destdir$source"
						if [ $? != 0 ]; then return 1; fi
					done
			fi
			if [ $? != 0 ]; then error_copy; fi
		elif [ "$opt_include" = 0 ]; then
			echo Directory not found \"[$type]$source\".
			error_copy;
		fi	
	fi
done 3<"$script_dir/$config_file"

sdk_ver_bin="$WindowsSdkDir/bin/$WindowsSDKVersion/x64/certmgr.exe"
sdk_version=$({ strings -del "$sdk_ver_bin" | grep -A1 'ProductVersion' | \
    tail -n 1; } 2>/dev/null)
if [ -z "$sdk_version" ]; then sdk_version=$WindowsSDKVersion; fi

{
	echo CRT ${VCToolsInstallDir##*/}
	echo SDK $sdk_version
} >version.txt


#
# Rename all files and subdirectories to lowercase.
#

echo

rename_file() {
	n=${1##*/}
	if [ "$n" != "." ]; then
        nn=$(tr "[:upper:]" "[:lower:]" <<< "$n")
		t=${1%/*}/$nn
		if [ "$n" != "$nn" ]; then
			mv -f "$1" "$t" && echo "Renamed '${1#./}' as '$nn'"
		fi
	fi
}

find . -depth -print0 | while IFS= read -r -d '' file; do
	rename_file "$file"
	if [ $? != 0 ]; then return 1; fi
done
if [ $? != 0 ]; then error_rename_files; fi


#
# Rename filenames to lowercase in include directives.
#

function rename_includes()
{
	find "$1" -type f -print0 | while IFS= read -r -d '' file; do
		sed -i -b -e 's/\(#include\s*[<"]\)\([^">]*\)\([>"]\)/\1\L\2\3/g' "$file"
		if [ $? != 0 ]; then return 1; fi
	done
}

crtIncludeDirectory="crt/include"
crtAtlMfcIncludeDirectory="crt/atlmfc/include"
sdkIncludeDirectory="sdk/include"

echo

if [ -d "$crtIncludeDirectory" ]; then
	echo; echo "Processing CRT include directory ..."; echo
	rename_includes "$crtIncludeDirectory"
	if [ $? != 0 ]; then error_rename_includes; fi
fi

if [ -d "$crtAtlMfcIncludeDirectory" ]; then
	echo; echo "Processing CRT AtlMfc include directory ..."; echo
	rename_includes "$crtAtlMfcIncludeDirectory"
	if [ $? != 0 ]; then error_rename_includes; fi
fi

if [ -d "$sdkIncludeDirectory" ]; then
	echo; echo "Processing SDK include directory ..."; echo
	rename_includes "$sdkIncludeDirectory"
	if [ $? != 0 ]; then error_rename_includes; fi
fi

echo
echo "Done."
echo
echo "Move the \"$msvc_dirname\" directory to the final location and set the"
echo "MSVC_LIBS_PATH environment variable to it to use it."

}

search_path() {
	if [ "$opt_local" = 0 ] && [ -n "$VCToolsInstallDir" ] && \
		[ -n "$WindowsSdkDir" ] && [ -n "$WindowsSDKVersion" ]; then
		# Remove trailing /
		VCToolsInstallDir=${VCToolsInstallDir%/}
		WindowsSdkDir=${WindowsSdkDir%/}
		WindowsSDKVersion=${WindowsSDKVersion%/}
		echo "Using Visual Studio environment."
		echo
		return 0
	fi

	search_local_path
	local ret_code=$?
	if [ $ret_code = 0 ]; then return 0
	elif [ "$opt_local" = 1 ]; then return $ret_code
	fi
	return 1
}

search_local_path() {
	local msvc_crt_source="VC/Tools/MSVC"
	local msvc_sdk_source="Windows Kits"
	
	if [ ! -d "$msvc_crt_source" ]; then return 2; fi
	if [ ! -d "$msvc_sdk_source" ]; then return 3; fi
	local version="$({ cd "$msvc_crt_source" && ls -dv -- */ | tail -n 1; } \
		2>/dev/null)"
	version=${version%/}
	if [ -z "$version" ]; then return 2; fi
	VCToolsInstallDir="$script_dir/$msvc_crt_source/$version"

	version="$({ cd "$msvc_sdk_source" && ls -dv -- */ | tail -n 1; } \
		2>/dev/null)"
	version=${version%/}
	if [ -z "$version" ]; then return 3; fi
	WindowsSdkDir="$script_dir/$msvc_sdk_source/$version"

	version="$({ cd "$msvc_sdk_source/$version/Include" && ls -dv -- */ | \
		tail -n 1; } 2>/dev/null)"
	version=${version%/}
	if [ -z "$version" ]; then return 3; fi
	WindowsSDKVersion=$version

	echo "Using local source."
	echo

	return 0
}


error_msvc_path() {
	echo "ERROR: MSVC library not found."
	exit_script 3
}

error_sdk_path() {
	echo "ERROR: Windows SDK library not found."
	exit_script 3
}

error_path() {
	echo "ERROR: The Visual Studio library could not be found."
	exit_script 3
}

error_config() {
	echo
	echo "ERROR: Invalid configuration file on line $1."
	exit_script 2
}

error_copy() {
	echo
	echo "ERROR: Copying files failed."
	exit_script 4
}

error_rename_files() {
	echo
	echo "ERROR: Renaming of files failed."
	exit_script 5
}

error_rename_includes() {
	echo
	echo "ERROR: Renaming of includes failed."
	exit_script 6
}

exit_script() {
	if [ "$opt_quiet" = 0 ] && $interactive; then
		echo
		read -d '' -t1
		read -rsn1 -p "Press any key to exit..."
		echo
	fi
	exit $1
}


trim() {
	local var="$1"
	# Remove leading whitespace characters
	var="${var#"${var%%[![:space:]]*}"}"
	# Remove trailing whitespace characters
	var="${var%"${var##*[![:space:]]}"}"
	printf '%s' "$var"
}


main "$@"

exit_script 0
