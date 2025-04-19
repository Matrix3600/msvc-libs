<# :: Do not remove
@echo off
::
:: make_msvc-libs.cmd
::
:: Copyright 2025 https://github.com/Matrix3600/msvc-libs
::
:: Build the repackaged MSVC/SDK headers and libraries.
::
:: Compatible with Linux for cross-compilation.
::
:: - Rename the files and directories to lowercase for compatibility
::   with case-sensitive systems (Linux).
:: - Rename the include directives in source files accordingly.
::

:: Visual Studio installation directory (if applicable),
:: e.g., C:\Program Files (x86)\Microsoft Visual Studio\2022\Community
:: If this parameter is not set, the script attempts to find it.
:: If the script cannot find it, modify and uncomment the line below:
:: set "VS_INSTALL_DIR=C:\Program Files (x86)\Microsoft Visual Studio\2022\Community"


setlocal DisableDelayedExpansion

set "exit_code=0"

set "msvc_dirname=msvc-libs"
set "config_file=make_msvc-libs_conf.txt"

set "interactive="
echo %cmdcmdline%| find /i "%~0" >nul
if not errorlevel 1 set "interactive=1"

set "scriptdir=%~dp0"
if "%scriptdir:~-1%"=="\" set "scriptdir=%scriptdir:~0,-1%"

cd /d "%scriptdir%"
if errorlevel 1 set "exit_code=10" & goto end

echo(

if not exist "%scriptdir%\%config_file%" (
	echo Configuration file not found: "%config_file%" .
	set "exit_code=2"
	goto end
)

call :search_path
if errorlevel 1 goto error_path

set "MSVC_CRT_PATH=%VCToolsInstallDir%"
set "MSVC_SDK_INCLUDE_PATH=%WindowsSdkDir%\Include\%WindowsSDKVersion%"
set "MSVC_SDK_LIB_PATH=%WindowsSdkDir%\Lib\%WindowsSDKVersion%"

if not exist "%MSVC_CRT_PATH%\include\stdarg.h" (
	echo ERROR: MSVC library not found.
	set "exit_code=3"
	goto end
)

if not exist "%MSVC_SDK_INCLUDE_PATH%\um\windows.h" (
	echo ERROR: Windows SDK library not found.
	set "exit_code=3"
	goto end
)

set "msvc_dirpath=%scriptdir%\%msvc_dirname%"

if exist "%msvc_dirpath%" (
	echo The "%msvc_dirname%" directory already exists.
	echo Please delete or rename it.
	set "exit_code=11"
	goto end
)

echo This script creates a repackaged standalone MSVC/SDK library from the
echo Visual Studio library.
echo(
echo The directory "%msvc_dirname%" will be created in
echo %scriptdir% .
echo(
pause
echo(

mkdir "%msvc_dirpath%
if errorlevel 1 set "exit_code=10" & goto end

pushd "%msvc_dirpath%"
if errorlevel 1 set "exit_code=10" & goto end

setlocal EnableDelayedExpansion

set "linenum=0"

for /f "tokens=1-3 usebackq eol=# delims=|" %%i in (
		"%scriptdir%\%config_file%") do (
	set /a linenum += 1
	set "opt=%%~i"
	set "type=%%~j"
	set "source=%%~k"
	call :trim opt & call :trim type & call :trim source

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

	if "!opt!"=="0" (
		set "options="
		set "subdirs="
	) else if "!opt!"=="1" (
		set "options=s"
		set "subdirs=\*"
	) else goto error_config

	set "source=!source:/=\!"
	if "!source:~0,1!"=="\" set "source=!source:~1!"
	if "!source:~-1!"=="\" set "source=!source:~0,-1!"
	if "!source!"=="." set "source="
	if "!source!" neq "" set "source=\!source:..=!"
	set "dest=!destdir!!source!"
	call echo Copying "[!type!]!source!!subdirs!" to "!dest!" ...
	call xcopy /qy!options! "!sourcedir!!source!\*" "!dest!\"
	if errorlevel 1 goto error_copy
)

endlocal

popd

set "pwsh_exec=pwsh.exe"
set "pwsh_version=7"
"%pwsh_exec%" -version >nul 2>&1
if %errorlevel% equ 0 goto pwsh_ok
set "pwsh_exec=powershell.exe"
set "pwsh_version=5"
:pwsh_ok

set args="%msvc_dirpath%" "%pwsh_version%"
set args=%args:"=\"%
set args=%args:'=''%

"%pwsh_exec%" -c ^"Invoke-Expression ('^& {' + [io.file]::ReadAllText(\"%~f0\") + '} %args%')"

if %errorlevel% equ 0 (
	echo(
	echo Done.
	echo(
	echo Move the "%msvc_dirname%" directory to the final location and set the
	echo MSVC_LIBS_PATH environment variable to it to use it.
) else (
	echo(
	echo ERROR: The renaming of the files failed.
	set "exit_code=5"
	goto end
)

:end
if defined interactive (
	echo(
	pause
)
exit /b %exit_code%


:search_path
if "%VCToolsInstallDir%"=="" goto search_path_1
if "%WindowsSdkDir%"=="" goto search_path_1
if "%WindowsSDKVersion%"=="" goto search_path_1
goto vs_env_vars_ok

:search_path_1
if "%VS_INSTALL_DIR%"=="" goto search_path_2
set "my_vsinstalldir=%VS_INSTALL_DIR%"
goto installdir_ok

:search_path_2
if not exist "Windows Kits\" goto search_path_3
if not exist "VC\Tools\MSVC\" goto search_path_3
set "version="
for /f %%i in ('dir VC\Tools\MSVC /b/a:d') do set "version=%%i"
if "%version%"=="" goto search_path_3
set "VCToolsInstallDir=%scriptdir%\VC\Tools\MSVC\%version%"
set "version="
for /f %%i in ('dir "Windows Kits" /b/a:d') do set "version=%%i"
if "%version%"=="" goto search_path_3
set "WindowsSdkDir=%scriptdir%\Windows Kits\%version%"
set "version="
for /f %%i in ('dir "%WindowsSdkDir%\Include" /b/a:d') do set "version=%%i"
if "%version%"=="" goto search_path_3
set "WindowsSDKVersion=%version%"
exit /b 0

:search_path_3
call :get_vsinstalldir ^
	HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\6487e3bb ^
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
exit /b 0

:get_vsinstalldir
set my_vsinstalldir=
for /f "tokens=2*" %%i in ('reg query "%~1" /v "%~2" 2^>nul') do set "my_vsinstalldir=%%~j"
if "%my_vsinstalldir%"=="" exit /b 1
exit /b 0


:error_config
echo(
echo ERROR: Invalid configuration file on enabled data line %linenum%.
set "exit_code=2"
goto end

:error_path
echo The Visual Studio installation location could not be found.
echo Please run this script from the "Developer Command Prompt for VS"
echo using the Start menu shortcut.
set "exit_code=3"
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

	# powerShellVersion
	[Parameter(Mandatory=$true, Position=1)]
	[int]$powerShellVersion
)
#>

if ($Args.Length -ne 2) { exit 1 }
$rootDirectory = $Args[0]
$powerShellVersion = $Args[1]

Write-Host


#
# Rename all files and subdirectories to lowercase.
#

Get-ChildItem -LiteralPath $rootDirectory -Recurse |
Where { $_.Name -cne $_.Name.ToLower() } | ForEach-Object {
	$tn = "$($_.Name)-temp"
	$tfn = "$($_.FullName)-temp"
	$nn = $_.Name.ToLower()
	Rename-Item -LiteralPath $_.FullName -NewName $tn
	Rename-Item -LiteralPath $tfn -NewName $nn -Force

	$relFilename = $_.FullName.Replace( "$($rootDirectory)\", '' )
	Write-Host "Renamed '$($relFilename)' as '$($nn)'"
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

exit 0
