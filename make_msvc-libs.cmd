<# :: Do not remove
@echo off
::
:: make_msvc-libs.cmd
::
:: ----------------------------------------------------------------------------
:: Copyright 2025 https://github.com/Matrix3600
::
:: Licensed under the Apache License, Version 2.0 (the "License");
:: you may not use this file except in compliance with the License.
:: You may obtain a copy of the License at
::
::   http://www.apache.org/licenses/LICENSE-2.0
::
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the License is distributed on an "AS IS" BASIS,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
:: See the License for the specific language governing permissions and
:: limitations under the License.
:: ----------------------------------------------------------------------------
::
:: Build the repackaged MSVC/SDK headers and libraries.
::
:: Compatible with Windows and Linux for cross-compilation.
::
:: - Rename the files and directories to lowercase for compatibility
::   with case-sensitive systems (Linux).
:: - Rename the include directives in source files accordingly.
::
:: Options:
::   /i   Include the directories specified in the configuration file, but do
::        not cause any error if they do not exist.
::   /l   Force selection of local subdirectories for the source (located in
::        the same directory as this script).
::   /q   Do not ask for confirmation before starting.
::

:: Visual Studio installation directory (if applicable),
:: e.g., C:\Program Files\Microsoft Visual Studio\2022\Community.
:: If this parameter is not set, the script attempts to find it.
:: If the script cannot find it, modify and uncomment the line below:
:: set "VS_INSTALL_DIR=C:\Program Files\Microsoft Visual Studio\2022\Community"

setlocal DisableDelayedExpansion
set "exit_code=0"

set "msvc_dirname=msvc-libs"
set "config_file=make_msvc-libs_conf.txt"

set "interactive="
echo %cmdcmdline%| find /i "%~0" >nul
if not errorlevel 1 set "interactive=1"

echo(

set "opt_include=0"
set "opt_local=0"
set "opt_quiet=0"

for %%a in (%*) do (
	call :parse_arg "%%~a"
	if errorlevel 1 (
		set "exit_code=1"
		goto end
	)
)
goto args_end

:parse_arg
set "arg=%~1"
if not "%arg:~0,1%"=="/" if not "%arg:~0,1%"=="-" goto argument
if "%arg:~1%"=="" goto argument
set "arg=%arg:~1%"
:opt_loop
if not defined arg exit /b 0
set "opt=%arg:~0,1%"
if "%opt%"=="i" (set "opt_include=1"
) else if "%opt%"=="l" (set "opt_local=1"
) else if "%opt%"=="q" (set "opt_quiet=1"
) else (
	echo ERROR: Invalid option %opt%.
	exit /b 1
)
set "arg=%arg:~1%"
goto opt_loop

:argument
echo ERROR: Invalid argument.
exit /b 1

:args_end

set "script_dir=%~dp0"
if "%script_dir:~-1%"=="\" set "script_dir=%script_dir:~0,-1%"

cd /d "%script_dir%"
if errorlevel 1 set "exit_code=10" & goto end

set "pwsh_exec=pwsh.exe"
"%pwsh_exec%" -version >nul 2>&1
if %errorlevel% equ 0 goto pwsh_ok
set "pwsh_exec=powershell.exe"
set "pwsh_ver=0"
for /f %%i in ('%pwsh_exec% -c "$PSVersionTable.PSVersion.Major" 2^>nul') do (
	set /a "pwsh_ver=%%i" 2>nul
)
if %pwsh_ver% lss 3 goto error_powershell
:pwsh_ok

if not exist "%script_dir%\%config_file%" (
	echo ERROR: Configuration file not found: "%config_file%".
	set "exit_code=2"
	goto end
)

call :search_path
if %errorlevel% equ 2 goto error_msvc_path
if %errorlevel% equ 3 goto error_sdk_path
if errorlevel 1 goto error_path

set "MSVC_CRT_PATH=%VCToolsInstallDir%"
set "MSVC_SDK_INCLUDE_PATH=%WindowsSdkDir%\Include\%WindowsSDKVersion%"
set "MSVC_SDK_LIB_PATH=%WindowsSdkDir%\Lib\%WindowsSDKVersion%"

if not exist "%MSVC_CRT_PATH%\include\stdarg.h" goto error_msvc_path
if not exist "%MSVC_SDK_INCLUDE_PATH%\um\windows.h" goto error_sdk_path

set "msvc_dirpath=%script_dir%\%msvc_dirname%"

if exist "%msvc_dirpath%" (
	echo The "%msvc_dirname%" directory already exists.
	echo Please delete or rename it.
	set "exit_code=11"
	goto end
)

echo This script creates a repackaged standalone MSVC/SDK library from the
echo Visual Studio library.
echo(
echo The directory "%msvc_dirname%" will be created in:
echo %script_dir%

if "%opt_quiet%"=="0" (
	echo(
	echo Press any key to continue...
	pause >nul
)
echo(

mkdir "%msvc_dirpath%
if errorlevel 1 set "exit_code=10" & goto end

pushd "%msvc_dirpath%"
if errorlevel 1 set "exit_code=10" & goto end

setlocal EnableDelayedExpansion

set "linenum=0"

for /f "tokens=1-3 usebackq eol=# delims=|" %%i in (
		"%script_dir%\%config_file%") do (
	set /a linenum += 1
	set "recurs=%%~i"
	set "type=%%~j"
	set "source=%%~k"
	call :trim recurs & call :trim type & call :trim source

	set "sourcedir="
	set "destdir="
	if "!type!"=="CRT" (
		set "sourcedir=%MSVC_CRT_PATH%"
		set "destdir=crt"
	) else if "!type!"=="SDK_INCLUDE" (
		set "sourcedir=%MSVC_SDK_INCLUDE_PATH%"
		set "destdir=sdk\include"
	) else if "!type!"=="SDK_LIB" (
		set "sourcedir=%MSVC_SDK_LIB_PATH%"
		set "destdir=sdk\lib"
	) else goto error_config

	if not "!recurs!"=="0" if not "!recurs!"=="1" goto error_config

	if defined source set "source=!source:/=\!"
	if defined source if "!source:~0,1!"=="\" set "source=!source:~1!"
	if defined source if "!source:~-1!"=="\" set "source=!source:~0,-1!"
	if defined source if "!source!"=="." set "source="
	if defined source set "source=\!source:..=!"
	if defined source (
		set "msg_source=[!type!]!source!"
		set "copy_source=!sourcedir!!source!\*"
		set "copy_dest=!destdir!!source!"
	) else (
		set "msg_source=[!type!]"
		set "copy_source=!sourcedir!\*"
		set "copy_dest=!destdir!"
	)

	if exist "!copy_source!" (
		if "!recurs!"=="0" (
			echo Copying "!msg_source!" to "!copy_dest!" ...
			xcopy /qy "!copy_source!" "!copy_dest!\"
		) else (
			echo Copying "!msg_source!\*" to "!copy_dest!" ...
			xcopy /qys "!copy_source!" "!copy_dest!\"
		)
		if errorlevel 1 goto error_copy
	) else if "%opt_include%"=="0" (
			echo Directory not found "!msg_source!".
			goto error_copy
	)
)

set "version="
for /f "delims=" %%D in ("%VCToolsInstallDir%") do set "version=%%~nxD"
(
	echo CRT %version%
	echo SDK %WindowsSDKVersion%
) >version.txt

endlocal

popd

set args="%msvc_dirpath%"
set args=%args:"=\"%
set args=%args:'=''%

"%pwsh_exec%" -c ^"Invoke-Expression ('^& {' + ^
	[io.file]::ReadAllText(\"%~f0\") + '} %args%')"
set "exit_code=%errorlevel%"
if %exit_code% neq 0 goto end

echo(
echo Done.
echo(
echo Move the "%msvc_dirname%" directory to the final location and set the
echo MSVC_LIBS_PATH environment variable to it to use it.

:end
if "%opt_quiet%"=="0" if defined interactive (
	echo(
	echo Press any key to exit...
	pause >nul
)
exit /b %exit_code%


:search_path
if "%opt_local%"=="1" goto search_path_2
if "%VCToolsInstallDir%"=="" goto search_path_1
if "%WindowsSdkDir%"=="" goto search_path_1
if "%WindowsSDKVersion%"=="" goto search_path_1
goto vs_env_vars_ok

:search_path_1
if "%VS_INSTALL_DIR%"=="" goto search_path_2
set "my_vsinstalldir=%VS_INSTALL_DIR%"
goto installdir_ok

:search_path_2
set "msvc_crt_source=VC\Tools\MSVC"
set "msvc_sdk_source=Windows Kits"

set "search_code=2"
if not exist "%msvc_crt_source%\" goto search_path_3
set "search_code=3"
if not exist "%msvc_sdk_source%\" goto search_path_3
set "search_code=2"
call :get_latest_version_dirname version "%msvc_crt_source%"
if "%version%"=="" goto search_path_3
set "VCToolsInstallDir=%script_dir%\%msvc_crt_source%\%version%"
set "search_code=3"
call :get_latest_version_dirname version "%msvc_sdk_source%"
if "%version%"=="" goto search_path_3
set "WindowsSdkDir=%script_dir%\%msvc_sdk_source%\%version%"
call :get_latest_version_dirname version "%WindowsSdkDir%\Include"
if "%version%"=="" goto search_path_3
set "WindowsSDKVersion=%version%"
echo Using local source.
echo(
exit /b 0

:get_latest_version_dirname <out_var_name> <path>
setlocal EnableDelayedExpansion
set "v="
for /f "delims=" %%i in ('dir "%~2" /b/a:d') do (
	set "chk=" & for /f "delims=0123456789." %%j in ("%%i") do set "chk=%%j"
	if not defined chk (
		call :cmp_version "%%i" "!v!"
		if !errorlevel! equ 0 set "v=%%i"
	)
)
endlocal & set "%~1=%v%"
exit /b 0
:cmp_version <v1> <v2>
if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 0
set "v1=0" & set "v2=0"
for /f "tokens=1* delims=." %%i in ("%~1") do (set "v1=%%i" & set "r1=%%j")
for /f "tokens=1* delims=." %%i in ("%~2") do (set "v2=%%i" & set "r2=%%j")
if %v1% neq 0 for /f "tokens=* delims=0" %%i in ("%v1%") do set "v1=%%i"
if %v2% neq 0 for /f "tokens=* delims=0" %%i in ("%v2%") do set "v2=%%i"
if %v1% lss %v2% (exit /b 1) else if %v1% gtr %v2% exit /b 0
call :cmp_version "%r1%" "%r2%"
exit /b %errorlevel%

:search_path_3
if "%opt_local%"=="1" exit /b %search_code%
:search_path_4
call :get_vsinstalldir ^
	HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall ^
	InstallLocation
if %errorlevel% neq 0 exit /b 1

:installdir_ok
if "%my_vsinstalldir:~-1%"=="\" set "my_vsinstalldir=%my_vsinstalldir:~0,-1%"
set "VsDevCmd=%my_vsinstalldir%\Common7\Tools\VsDevCmd.bat"

if not exist "%VsDevCmd%" exit /b 1
:: Get the Visual Studio environment variables
:: 1=Do NOT send telemetry
set "VSCMD_SKIP_SENDTELEMETRY=1"
call "%VsDevCmd%" >nul

if "%VCToolsInstallDir%"=="" exit /b 1
if "%WindowsSdkDir%"=="" exit /b 1
if "%WindowsSDKVersion%"=="" exit /b 1

:vs_env_vars_ok
if "%VCToolsInstallDir:~-1%"=="\" set "VCToolsInstallDir=%VCToolsInstallDir:~0,-1%"
if "%WindowsSdkDir:~-1%"=="\" set "WindowsSdkDir=%WindowsSdkDir:~0,-1%"
if "%WindowsSDKVersion:~-1%"=="\" set "WindowsSDKVersion=%WindowsSDKVersion:~0,-1%"
echo Using Visual Studio environment.
echo(
exit /b 0

:get_vsinstalldir
set my_vsinstalldir=
for /f "tokens=2*" %%i in ('^(reg query "%~1" /s /v "%~2" ^| ^
	find "Microsoft Visual Studio"^) 2^>nul') do set "my_vsinstalldir=%%~j"
if "%my_vsinstalldir%"=="" exit /b 1
exit /b 0


:error_powershell
echo ERROR: This script requires PowerShell 3 or higher.
set "exit_code=20"
goto end

:error_msvc_path
echo ERROR: MSVC library not found.
set "exit_code=3"
goto end

:error_sdk_path
echo ERROR: Windows SDK library not found.
set "exit_code=3"
goto end

:error_path
echo The Visual Studio installation location could not be found.
echo Please run this script from the "Developer Command Prompt for VS"
echo using the Start menu shortcut.
set "exit_code=3"
goto end

:error_config
echo(
echo ERROR: Invalid configuration file on enabled data line %linenum%.
set "exit_code=2"
goto end

:error_copy
echo(
echo ERROR: Copying files failed.
set "exit_code=4"
goto end


::
:: trim <var_name>
:: Remove leading and trailing spaces in variable <var_name>
::
:trim
setLocal
call :trimSub %%%~1%%
endLocal & set "%~1=%tempvar%"
exit /b
:trimSub
set "tempvar=%*"
exit /b


###############################################################################
Start of PowerShell section                                                  #>

<#
	Rename all files and subdirectories to lowercase.
	Rename filenames to lowercase in include directives.

param (
	# Root directory
	[Parameter(Mandatory=$true, Position=0)]
	[string]$rootDirectory,
)
#>

$ErrorActionPreference = 'Stop'
$powerShellVersion = $PSVersionTable.PSVersion.Major

if ($Args.Length -ne 1) { exit 21 }
$rootDirectory = $Args[0]

Write-Host


#
# Rename all files and subdirectories to lowercase.
#
try {
	Get-ChildItem -LiteralPath $rootDirectory -Recurse |
			Where { $_.Name -cne $_.Name.ToLower() } |
			Sort-Object | ForEach-Object {
		$tn = "$($_.Name)-temp"
		$tfn = "$($_.FullName)-temp"
		$nn = $_.Name.ToLower()
		Rename-Item -LiteralPath $_.FullName -NewName $tn
		Rename-Item -LiteralPath $tfn -NewName $nn -Force

		$relFilename = $_.FullName.Replace( "$($rootDirectory)\", '' )
		Write-Host "Renamed '$($relFilename)' as '$($nn)'"
	}
}
catch {
	Write-Host $_
	Write-Host
	Write-Host "ERROR: Renaming of files failed."
	exit 5
}


#
# Rename filenames to lowercase in include directives.
#

function ProcessIncludeFile( $fileInfo )
{
	if ($fileInfo.GetType().Name -ne 'FileInfo') { return }

	$relFilename = $fileInfo.FullName.Replace( "$($rootDirectory)\", '' )

	$count = 0
	$content = (Get-Content $fileInfo.FullName) | ForEach-Object {

		if ($powerShellVersion -ge 6) {
			# Version >= 6
			$line = $_ -replace '(#include\s*[<"])([^">]*)([>"])',
				{ "$($_.Groups[1].Value)$($_.Groups[2].Value.ToLower())$($_.Groups[3].Value)" }
		}
		else {
			# Version < 6
			if ($_ -match '(#include\s*[<"])([^">]*)([>"])') {
				$line = $_.Replace( $Matches[0], "$($Matches[1])$($Matches[2].ToLower())$($Matches[3])" )
			}
			else { $line = $_ }
		}

		if ($line -cne $_) { $count++ }
		$line
	}

	if ($count -ne 0) {
		Set-Content -value $content -path $fileInfo.FullName
		Write-Host "'$($relFilename)'"
	}
}

$crtIncludeDirectory = $rootDirectory + '\crt\include'
$crtAtlMfcIncludeDirectory = $rootDirectory + '\crt\atlmfc\include'
$sdkIncludeDirectory = $rootDirectory + '\sdk\include'

try {
	if (Test-Path -path $crtIncludeDirectory) {
		Write-Host "`nProcessing CRT include directory ...`n"
		Get-ChildItem -LiteralPath $crtIncludeDirectory -Recurse | Sort-Object |
			ForEach-Object { ProcessIncludeFile( $_ ) }
	}
	if (Test-Path -path $crtAtlMfcIncludeDirectory) {
		Write-Host "`nProcessing CRT AtlMfc include directory ...`n"
		Get-ChildItem -LiteralPath $crtAtlMfcIncludeDirectory -Recurse | Sort-Object |
			ForEach-Object { ProcessIncludeFile( $_ ) }
	}
	if (Test-Path -path $sdkIncludeDirectory) {
		Write-Host "`nProcessing SDK include directory ...`n"
		Get-ChildItem -LiteralPath $sdkIncludeDirectory -Recurse | Sort-Object |
			ForEach-Object { ProcessIncludeFile( $_ ) }
	}
}
catch {
	Write-Host $_
	Write-Host
	Write-Host "ERROR: Renaming of includes failed."
	exit 6
}

exit 0
