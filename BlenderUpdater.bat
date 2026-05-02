@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  Blender Auto-Updater
::  Checks your installed Blender version against the latest,
::  downloads and installs the update if needed, and sends
::  a Windows toast notification either way.
:: ============================================================

:: --- Configuration ---
set "LATEST_VERSION=5.1.1"
set "MAJOR_MINOR=5.1"
set "DOWNLOAD_URL=https://download.blender.org/release/Blender5.1/blender-5.1.1-windows-x64.msi"
set "INSTALLER_NAME=blender-5.1.1-windows-x64.msi"
set "TEMP_DIR=%TEMP%\BlenderUpdate"
set "LOG_FILE=%TEMP%\BlenderUpdater.log"

:: -------------------------------------------------------
:: 1. Find the installed Blender executable
:: -------------------------------------------------------
echo [%date% %time%] Starting Blender Updater >> "%LOG_FILE%"

set "BLENDER_EXE="

:: Check ALL version subfolders under "Blender Foundation" (covers 4.2, 4.5, 5.0, 5.1, etc.)
for %%B in (
    "%ProgramFiles%\Blender Foundation"
    "%ProgramFiles(x86)%\Blender Foundation"
    "%LOCALAPPDATA%\Programs\Blender Foundation"
) do (
    if exist "%%~B" (
        for /d %%S in ("%%~B\Blender*") do (
            if exist "%%~S\blender.exe" (
                set "BLENDER_EXE=%%~S\blender.exe"
                goto :found_blender
            )
        )
        :: Also check directly inside "Blender Foundation" (no version subfolder)
        if exist "%%~B\blender.exe" (
            set "BLENDER_EXE=%%~B\blender.exe"
            goto :found_blender
        )
    )
)

:: Search in PATH
for /f "delims=" %%F in ('where blender.exe 2^>nul') do (
    set "BLENDER_EXE=%%F"
    goto :found_blender
)

:: Search common custom install locations
for %%D in (
    "C:\Blender"
    "D:\Blender"
    "C:\Apps\Blender"
    "C:\Program Files\Blender"
    "D:\Program Files\Blender Foundation\Blender 4.2"
    "D:\Program Files\Blender Foundation\Blender 5.1"
) do (
    if exist "%%~D\blender.exe" (
        set "BLENDER_EXE=%%~D\blender.exe"
        goto :found_blender
    )
)

:: Last resort: deep search inside Program Files for blender.exe (slow but thorough)
echo  [~] Doing deep search for blender.exe, please wait...
for /f "delims=" %%F in ('dir /s /b "%ProgramFiles%\blender.exe" 2^>nul') do (
    set "BLENDER_EXE=%%F"
    goto :found_blender
)
for /f "delims=" %%F in ('dir /s /b "%ProgramFiles(x86)%\blender.exe" 2^>nul') do (
    set "BLENDER_EXE=%%F"
    goto :found_blender
)

:not_found
echo Blender not found on this system. >> "%LOG_FILE%"
call :notify "Blender Updater" "Blender is not installed or could not be found. Please install it from blender.org."
echo.
echo  [!] Blender installation not found.
echo      Please install Blender from: https://www.blender.org/download/
echo.
pause
goto :end

:found_blender
echo Found Blender at: "%BLENDER_EXE%" >> "%LOG_FILE%"

:: -------------------------------------------------------
:: 2. Get installed version
:: -------------------------------------------------------
set "INSTALLED_VERSION="
for /f "tokens=*" %%V in ('"%BLENDER_EXE%" --version 2^>nul ^| findstr /i "Blender"') do (
    :: Output is like: "Blender 5.0.1"
    for /f "tokens=2" %%N in ("%%V") do (
        set "INSTALLED_VERSION=%%N"
        goto :got_version
    )
)

:got_version
if "%INSTALLED_VERSION%"=="" (
    echo Could not determine installed version. >> "%LOG_FILE%"
    set "INSTALLED_VERSION=Unknown"
)

echo Installed version: %INSTALLED_VERSION% >> "%LOG_FILE%"
echo Latest version:    %LATEST_VERSION%    >> "%LOG_FILE%"

echo.
echo  Installed : %INSTALLED_VERSION%
echo  Latest    : %LATEST_VERSION%
echo.

:: -------------------------------------------------------
:: 3. Compare versions
:: -------------------------------------------------------
if "%INSTALLED_VERSION%"=="%LATEST_VERSION%" goto :already_up_to_date

:: Simple string comparison won't handle 5.1 vs 5.1.0, so also check without patch
set "INSTALLED_SHORT=%INSTALLED_VERSION%"
:: Strip trailing .0 for comparison (5.1.0 -> 5.1)
if "%INSTALLED_VERSION%"=="%MAJOR_MINOR%.0" goto :already_up_to_date

goto :needs_update

:: -------------------------------------------------------
:: 4a. Already up to date
:: -------------------------------------------------------
:already_up_to_date
echo Blender is already up to date. >> "%LOG_FILE%"
echo  [OK] Blender %INSTALLED_VERSION% is already up to date!
echo.
call :notify "Blender is up to date!" "You already have Blender %INSTALLED_VERSION% — the latest version. No update needed."
goto :end

:: -------------------------------------------------------
:: 4b. Update available — download and install
:: -------------------------------------------------------
:needs_update
echo Update available: %INSTALLED_VERSION% ^-^> %LATEST_VERSION% >> "%LOG_FILE%"
echo  [*] Update available: %INSTALLED_VERSION% ^-^> %LATEST_VERSION%
echo.
echo  Downloading Blender %LATEST_VERSION%...
echo  From: %DOWNLOAD_URL%
echo.

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

:: Download with PowerShell (built-in on all modern Windows)
powershell -NoProfile -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
    "$wc = New-Object System.Net.WebClient; " ^
    "$wc.DownloadFile('%DOWNLOAD_URL%', '%TEMP_DIR%\%INSTALLER_NAME%')"

if not exist "%TEMP_DIR%\%INSTALLER_NAME%" (
    echo Download failed. >> "%LOG_FILE%"
    echo  [!] Download failed. Please check your internet connection.
    call :notify "Blender Update Failed" "Could not download Blender %LATEST_VERSION%. Check your internet connection and try again."
    goto :end
)

echo Download complete. Starting installer... >> "%LOG_FILE%"
echo  Download complete! Starting installer...
echo  (You may see a UAC prompt — click Yes to allow installation.)
echo.

:: Run the MSI installer silently — /passive shows progress bar but no prompts
msiexec /i "%TEMP_DIR%\%INSTALLER_NAME%" /passive /norestart

if %ERRORLEVEL% EQU 0 (
    echo Installation successful. >> "%LOG_FILE%"
    echo  [OK] Blender %LATEST_VERSION% installed successfully!
    call :notify "Blender Updated!" "Blender has been updated from %INSTALLED_VERSION% to %LATEST_VERSION%. Enjoy the new version!"
    :: Clean up installer
    del /q "%TEMP_DIR%\%INSTALLER_NAME%" 2>nul
) else (
    echo Installation failed with error %ERRORLEVEL%. >> "%LOG_FILE%"
    echo  [!] Installation failed (error code: %ERRORLEVEL%).
    call :notify "Blender Install Failed" "The installer exited with an error. Try running it manually from: %TEMP_DIR%\%INSTALLER_NAME%"
)

goto :end

:: -------------------------------------------------------
:: Subroutine: Windows Toast Notification via PowerShell
:: -------------------------------------------------------
:notify
set "_TITLE=%~1"
set "_MSG=%~2"
powershell -NoProfile -WindowStyle Hidden -Command ^
    "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null; " ^
    "$template = [Windows.UI.Notifications.ToastTemplateType]::ToastText02; " ^
    "$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($template); " ^
    "$nodes = $xml.GetElementsByTagName('text'); " ^
    "$nodes.Item(0).AppendChild($xml.CreateTextNode('!_TITLE!')) | Out-Null; " ^
    "$nodes.Item(1).AppendChild($xml.CreateTextNode('!_MSG!')) | Out-Null; " ^
    "$toast = [Windows.UI.Notifications.ToastNotification]::new($xml); " ^
    "$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Blender Updater'); " ^
    "$notifier.Show($toast);"
goto :eof

:end
echo.
echo  Log saved to: %LOG_FILE%
echo.
pause
endlocal