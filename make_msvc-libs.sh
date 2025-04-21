#!/bin/bash

#
# make_msvc-libs.sh
#
#	Copyright 2025 https://github.com/Matrix3600/msvc-libs
#
# Build the repackaged MSVC/SDK headers and libraries.
#
# Compatible with Linux for cross-compilation.
#
# - Rename the files and directories to lowercase for compatibility
#   with case-sensitive systems (Linux).
# - Rename the include directives in source files accordingly.
#

# This script searches for root directories containing source files ("VC" and
# "Windows Kits") in the same directory as this script. Subdirectories are
# found automatically.
# If the source files are in a custom location, you must specify their path and
# the version of the tools (MSVC and SDK). In this case, modify and uncomment
# the three variables below (all three):
# VCToolsInstallDir="<custom_location_of_MSVC>/VC/Tools/MSVC/14.43.34808"
# WindowsSdkDir="<custom_location_of_SDK>/Windows Kits/10"
# WindowsSDKVersion="10.0.22621.0"


main() {

msvc_dirname="msvc-libs"
config_file="make_msvc-libs_conf.txt"

interactive=false
if [ -z "$SHLVL" ] || [ "$SHLVL" = 1 ]; then interactive=true; fi

scriptdir=$(cd -- "$(dirname -- "$0")" &>/dev/null && pwd)

cd "$scriptdir"
if [ $? != 0 ]; then exit_script 10; fi

echo

if [ ! -f "$scriptdir/$config_file" ]; then
	echo "Configuration file not found: $config_file ."
	exit_script 2
fi

search_path
if [ $? != 0 ]; then
	echo "The Visual Studio library could not be found."
	exit_script 3
fi

MSVC_CRT_PATH=$VCToolsInstallDir
MSVC_SDK_INCLUDE_PATH="$WindowsSdkDir/Include/$WindowsSDKVersion"
MSVC_SDK_LIB_PATH="$WindowsSdkDir/Lib/$WindowsSDKVersion"

if [ ! -f "$MSVC_CRT_PATH/include/stdarg.h" ]; then
	echo "ERROR: MSVC library not found."
	exit_script 3
fi

if [ ! -f "$MSVC_SDK_INCLUDE_PATH/um/Windows.h" ] && \
	[ ! -f "$MSVC_SDK_INCLUDE_PATH/um/windows.h" ]; then
	echo "ERROR: Windows SDK library not found."
	exit_script 3
fi

msvc_dirpath="$scriptdir/$msvc_dirname"

if [ -e "$msvc_dirpath" ]; then
	echo "The \"$msvc_dirname\" directory already exists."
	echo "Please delete or rename it."
	exit_script 11
fi

echo "This script creates a repackaged standalone MSVC/SDK library from the"
echo "Visual Studio library."
echo
echo "The directory \"$msvc_dirname\" will be created in"
echo "$scriptdir ."
echo
read -rsn1 -p "Press any key to continue..."
echo
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
		IFS="|" read -r opt type source <<< "$line"
		opt=$(trim "$opt")
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

		case $opt in
		0)
			options=""
			subdirs="";;
		1)
			options="r"
			subdirs="/*";;
		*)
			error_config $linenum
		esac

		source=${source//\\/\/}	# Replace \ by /
		source=${source#/}	# Remove leading /
		source=${source%/}	# Remove trailing /
		if [ "$source" = "." ]; then source=""; fi
		if [ -n "$source" ]; then source="/${source//..}"; fi	# Remove ..

		echo Copying "[$type]$source$subdirs" to "$destdir$source" ...

		mkdir -p "$destdir$source"
		if [ $? != 0 ]; then error_copy; fi

		if [ "$opt" = 1 ]; then
			cp -rf "$sourcedir$source/." "$destdir$source"
		else
			find "$sourcedir$source" -maxdepth 1 -type f -print0 | \
				while IFS= read -r -d '' file; do
					cp -f "$file" "$destdir$source"
					if [ $? != 0 ]; then return 1; fi
				done
		fi
		if [ $? != 0 ]; then error_copy; fi
	fi
done 3<"$scriptdir/$config_file"


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
	if [ -n "$VCToolsInstallDir" ] && [ -n "$WindowsSdkDir" ] && \
			[ -n "$WindowsSDKVersion" ]; then
		# Remove trailing /
		VCToolsInstallDir=${VCToolsInstallDir%/}
		WindowsSdkDir=${WindowsSdkDir%/}
		WindowsSDKVersion=${WindowsSDKVersion%/}
		return 0
	fi

	local msvc_crt_source="VC/Tools/MSVC"
	local msvc_sdk_source="Windows Kits"

	if [ -d "$msvc_crt_source" ] && [ -d "$msvc_sdk_source" ]; then
		local version="$(cd "$msvc_crt_source" && ls -d -- */ | tail -n 1)"
		version=${version%/}
		if [ -z "$version" ]; then return 1; fi
		VCToolsInstallDir="$scriptdir/$msvc_crt_source/$version"

		version="$(cd "$msvc_sdk_source" && ls -d -- */ | tail -n 1)"
		version=${version%/}
		if [ -z "$version" ]; then return 1; fi
		WindowsSdkDir="$scriptdir/$msvc_sdk_source/$version"

		version="$(cd "$msvc_sdk_source/$version/Include" && ls -d -- */ | tail -n 1)"
		version=${version%/}
		if [ -z "$version" ]; then return 1; fi
		WindowsSDKVersion=$version

		return 0
	fi

	return 1
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
	if $interactive; then
		echo
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
