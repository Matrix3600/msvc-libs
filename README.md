MSVC-Libs
=========

These scripts create a repackaged standalone MSVC/SDK library from the Visual
Studio library.

They run on Windows or Linux.

The standalone MSVC/SDK library is useful for compiling projects on Linux 
targeting Windows.

It can also be used on Windows, without the need to have Visual Studio
installed.

Note that the Visual Studio library is not redistributable, so neither is the
repackaged version.


Why
---

The generated executables and libraries are compatible with Visual Studio 
binaries (*-pc-windows-msvc).

This is not the case with executables created with GNU or MinGW based tools
(*-windows-gnu or *-mingw64-gnu).

The library is compatible with toolchains like the free software LLVM,
including a modern and flexible compiler (Clang) that often produces
smaller executables than GCC or Visual Studio.

Every file of the library must be referenced everywhere by an identical name.
On case-sensitive systems like Linux, mixing case can cause endless problems,
so it's best to use all-lowercase filenames.

The Visual Studio library was designed for Windows, so it didn't take this into
account; the filenames have a mix of lower and upper case letters, sometimes
without obvious logic.

Headers compilation fails on Linux because the case of the files does not match
the case of the filenames in the "include" directives.


How
---

The scripts copy the Visual Studio library files, then make some adjustments:

- The names of all files are converted to lowercase.

- Include directives are modified accordingly to include lowercase filenames.



Requirements
------------

If Visual Studio is installed, the scripts are immediately usable.

Otherwise, the original files are downloadable from the Microsoft servers.

Follow these [instructions](/download_vslib.md) to download the Visual Studio
MSVC/SDK library.

Later, after creating the standalone library, you will be able to delete the
download directory and its contents.



Configuration
-------------

The scripts use a very simple text configuration file.

You can specify which directories you want to include in the library.

The default configuration reduces the size of the library and allows you
to build programs using the MSVCRT library. If you want to use UCRT, 
uncomment the line corresponding to `SDK_LIB`, `ucrt`.


Running the script
------------------

The script must know where the Visual Studio library is located.

There are two possibilities:

- Visual Studio is installed.  
The script attempts to detect the Visual Studio installation directory,
but it may not work for you. In this case, you can:

  * Either specify this installation directory in the variable at the beginning
  of the script;
  * Either open the "_Developer Command Prompt for VS_" via the Start menu
  shortcut. It sets the necessary environment variables automatically.

- Visual Studio is not installed.  
If you downloaded the files as shown above, simply place the script and its 
configuration file in the download directory. 
Otherwise, you must specify the path and version of the tools (MSVC and SDK)
in the variables at the beginning of the script.

Choose the `make_msvc-libs` script (`.cmd` or `.sh`) that matches your system
(Windows or Linux). The configuration file should be next to the script.

Then run (you can also double-click on the script):

	# On Linux:
	chmod u+x make_msvc-libs.sh
	./make_msvc-libs.sh
	
	:: On Windows:
	make_msvc-libs.cmd

This creates the repackaged version in a new `msvc-libs` subdirectory.
Move it to the final location and set the `MSVC_LIBS_PATH` environment 
variable to it to use it.



Using the MSVC-Libs library
---------------------------

### LLVM toolchain
You can use the LLVM toolchain, available for free on all platforms.

Go to <https://github.com/llvm/llvm-project/releases> and download the latest
file that matches your __development__ system's architecture, for example:  

- Windows Intel/AMD 64-bit  
`LLVM-<version>-win64.exe`

- Windows on Arm64  
`LLVM-<version>-woa64.exe` (maybe not the latest version)

- Linux Intel/AMD 64-bit   
`LLVM-<version>-Linux-X64.tar.xz`

- Linux on Arm64  
`LLVM-<version>-Linux-ARM64.tar.xz`

Extract its contents to a folder, and add its `bin` subdirectory to your PATH.


### LLVM compiler and linker in MSVC mode

The names of the tools in MSVC mode are `clang-cl` for the C compiler and 
`lld-link` for the linker.

`clang-cl` is equivalent to `clang --driver-mode=cl`.  
`lld-link` is equivalent to `lld -flavor link`.

If `clang-cl` or `lld-link` is not available, but the `clang` or `lld`
binary is, you can copy it or create a symbolic link under the name
`clang-cl` or `lld-link`. The binaries are identical, but their behaviour
depends on their names.


### Environment variables

To avoid having to specify the headers and libraries paths each time you use
the compiler and linker, it is recommended to set the environment variables
used by them.

If you use a makefile:

	MSVC_CRT_PATH = $(MSVC_LIBS_PATH)/crt
	MSVC_SDK_INCLUDE_PATH = $(MSVC_LIBS_PATH)/sdk/include
	MSVC_SDK_LIB_PATH = $(MSVC_LIBS_PATH)/sdk/lib

	# C Compiler
	export INCLUDE = $(MSVC_CRT_PATH)/include;$(MSVC_SDK_INCLUDE_PATH)/ucrt;$\
		$(MSVC_SDK_INCLUDE_PATH)/um;$(MSVC_SDK_INCLUDE_PATH)/shared
	export CL = -Wno-microsoft-anon-tag -Wno-pragma-pack -Wno-unknown-pragmas \
		-Wno-ignored-pragma-intrinsic

	# Linker
	# For x86
	export LIB = $(MSVC_CRT_PATH)/lib/x86;$(MSVC_SDK_LIB_PATH)/um/x86
	# For x64
	export LIB = $(MSVC_CRT_PATH)/lib/x64;$(MSVC_SDK_LIB_PATH)/um/x64


If you use a shell script:

	MSVC_CRT_PATH="$MSVC_LIBS_PATH/crt"
	MSVC_SDK_INCLUDE_PATH="$MSVC_LIBS_PATH/sdk/include"
	MSVC_SDK_LIB_PATH="$MSVC_LIBS_PATH/sdk/lib"

	# C Compiler
	export INCLUDE="$MSVC_CRT_PATH/include;$MSVC_SDK_INCLUDE_PATH/ucrt"
	INCLUDE+=";$MSVC_SDK_INCLUDE_PATH/um;$MSVC_SDK_INCLUDE_PATH/shared"
	export CL="-Wno-microsoft-anon-tag -Wno-pragma-pack -Wno-unknown-pragmas"
	CL+=" -Wno-ignored-pragma-intrinsic"

	# Linker
	# For x86
	export LIB="$MSVC_CRT_PATH/lib/x86;$MSVC_SDK_LIB_PATH/um/x86"
	# For x64
	export LIB="$MSVC_CRT_PATH/lib/x64;$MSVC_SDK_LIB_PATH/um/x64"

The `INCLUDE` variable contains the search paths of the header files used by
the compiler, separated by semicolons.  
The `LIB` variable contains the search paths of the libraries used by the
linker, separated by semicolons.  
The `CL` variable contains compiler options. The above options may be useful
to hide some warning messages.
