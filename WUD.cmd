@echo off
:: ==============================================================================
::  Windows Update Disabler (WUD) - All-In-One Version
::  Version 1.5
::
::  Features: Completely disable Windows automatic updates
::  Methods: Service + Registry + Group Policy + Task Scheduler
::  Support: Windows 10 / Windows 11
::
::  Usage: Run as Administrator
::         Or use PowerShell one-liner:
::         irm https://raw.githubusercontent.com/Dawncopper/WUD/main/WUD.ps1 | iex
:: ==============================================================================

setlocal EnableDelayedExpansion

:: ==================== Initialize ====================

set "_batf=%~f0"
set "_batp=%~dp0"

if "%~1"=="-el" set "_elev=1"

if exist %SystemRoot%\Sysnative\cmd.exe if not defined re1 (
    start %SystemRoot%\Sysnative\cmd.exe /c ""!_batf!" %* re1"
    exit /b
)

fltmc >nul 2>&1 || (
    if not defined _elev (
        echo Requesting administrator privileges...
        powershell.exe -nop -c "start cmd.exe -arg '/c \"\"!_batf!\" -el\"' -verb runas"
        exit /b
    )
    echo [ERROR] This script requires administrator privileges.
    echo Please right-click and run as administrator.
    pause
    exit /b 1
)

mode con cols=80 lines=40

set "_ver=1.5"

:: ==================== Main Menu ====================

:MainMenu
cls
title  Windows Update Disabler %_ver%
echo.
echo  ================================================================================
echo.
echo            Windows Update Disabler  v%_ver%
echo            Completely Disable Windows Automatic Updates
echo.
echo  ================================================================================
echo.
echo   Menu:
echo.
echo    [1]  One-Click Disable All (Recommended)
echo    [2]  Step-by-Step (Advanced)
echo    [3]  Restore Windows Update
echo    [4]  Check Current Status
echo    [5]  Disable Services Only
echo    [6]  Configure Group Policy Only
echo    [7]  Clean Task Scheduler Only
echo    [8]  Fix: Service Resurrection Issue
echo.
echo    [0]  Exit
echo.
echo  ================================================================================
echo.
echo   Note: Security updates will also be disabled.
echo   It is recommended to manually check security patches periodically.
echo.
set /p "_choice=  Enter option [0-8]: "

if "%_choice%"=="1" goto AllInOne
if "%_choice%"=="2" goto StepByStep
if "%_choice%"=="3" goto RestoreUpdates
if "%_choice%"=="4" goto CheckStatus
if "%_choice%"=="5" goto ServiceRegistryOnly
if "%_choice%"=="6" goto GroupPolicyOnly
if "%_choice%"=="7" goto TaskScheduleOnly
if "%_choice%"=="8" goto FixResurrection
if "%_choice%"=="0" goto Exit
echo  [ERROR] Invalid option.
timeout /t 2 >nul
goto MainMenu

:: ==================== One-Click Disable ====================

:AllInOne
cls
echo.
echo   Executing one-click disable Windows Update...
echo   ----------------------------------------------------------------
echo.

echo   [1/4] Disabling services...
call :DisableWUService
echo.

echo   [2/4] Modifying registry...
call :ModifyRegistry
echo.

echo   [3/4] Configuring group policy...
call :ConfigureGroupPolicy
echo.

echo   [4/4] Cleaning task scheduler...
call :CleanTaskSchedule
echo.

echo   ----------------------------------------------------------------
echo.
echo   [OK] All operations completed! Windows Update has been disabled.
echo.
echo   [!] Note: Security updates are also stopped.
echo   It is recommended to manually check security patches monthly.
echo.
pause
goto MainMenu

:: ==================== Step-by-Step ====================

:StepByStep
cls
echo.
echo  ================================================================================
echo            Step-by-Step - Advanced Mode
echo  ================================================================================
echo.
echo    [1]  Step 1: Disable Windows Update Services
echo    [2]  Step 2: Modify Registry (Block resurrection)
echo    [3]  Step 3: Configure Group Policy
echo    [4]  Step 4: Clean Task Scheduler
echo    [5]  Execute All (Same as one-click mode)
echo    [0]  Back to Main Menu
echo.
set /p "_step=  Select step: "

if "%_step%"=="1" (
    cls
    echo.
    call :DisableWUService
    echo.
    pause
    goto StepByStep
)
if "%_step%"=="2" (
    cls
    echo.
    call :ModifyRegistry
    echo.
    pause
    goto StepByStep
)
if "%_step%"=="3" (
    cls
    echo.
    call :ConfigureGroupPolicy
    echo.
    pause
    goto StepByStep
)
if "%_step%"=="4" (
    cls
    echo.
    call :CleanTaskSchedule
    echo.
    pause
    goto StepByStep
)
if "%_step%"=="5" goto AllInOne
if "%_step%"=="0" goto MainMenu
echo  [ERROR] Invalid option.
timeout /t 2 >nul
goto StepByStep

:: ==================== Restore Updates ====================

:RestoreUpdates
cls
echo.
echo   Restoring Windows Update...
echo   ----------------------------------------------------------------
echo.

echo   [1/4] Restoring services...
call :RestoreWUService
echo.

echo   [2/4] Restoring registry...
call :RestoreRegistry
echo.

echo   [3/4] Restoring group policy...
call :RestoreGroupPolicy
echo.

echo   [4/4] Restoring task scheduler...
call :RestoreTaskSchedule
echo.

echo   ----------------------------------------------------------------
echo.
echo   [OK] Windows Update has been restored!
echo   It is recommended to restart the computer.
echo.
pause
goto MainMenu

:: ==================== Check Status ====================

:CheckStatus
set "_cs_score=0"
set "_cs_total=6"
set "_cs_fail="
cls
echo.
echo   Current Windows Update Status
echo   ================================================================================
echo.

echo   [1] SERVICE STATUS
echo.

:: Windows Update Service - use PowerShell for reliable output
for /f "delims=" %%a in ('powershell.exe -nop -c "(Get-Service wuauserv -ErrorAction SilentlyContinue).Status" 2^>nul') do set "_wu_state=%%a"
for /f "delims=" %%a in ('powershell.exe -nop -c "(Get-Service wuauserv -ErrorAction SilentlyContinue).StartType" 2^>nul') do set "_wu_start=%%a"
if "!_wu_state!"=="" set "_wu_state=Not Found"
if "!_wu_start!"=="" set "_wu_start=N/A"

if "!_wu_state!"=="Stopped" (
    echo     Windows Update Service:  STOPPED [OK]
    set /a "_cs_score+=1"
) else if "!_wu_state!"=="Running" (
    echo     Windows Update Service:  RUNNING [FAIL]
    set "_cs_fail=!_cs_fail!  - wuauserv is running^"
) else (
    echo     Windows Update Service:  !_wu_state!
)

if "!_wu_start!"=="Disabled" (
    echo     Startup Type:            DISABLED [OK]
    set /a "_cs_score+=1"
) else if "!_wu_start!"=="Automatic" (
    echo     Startup Type:            AUTOMATIC [FAIL]
    set "_cs_fail=!_cs_fail!  - wuauserv startup is Automatic^"
) else if "!_wu_start!"=="Manual" (
    echo     Startup Type:            MANUAL [FAIL]
    set "_cs_fail=!_cs_fail!  - wuauserv startup is Manual^"
) else (
    echo     Startup Type:            !_wu_start!
)

echo.

:: UsoSvc Service
for /f "delims=" %%a in ('powershell.exe -nop -c "(Get-Service UsoSvc -ErrorAction SilentlyContinue).Status" 2^>nul') do set "_uso_state=%%a"
for /f "delims=" %%a in ('powershell.exe -nop -c "(Get-Service UsoSvc -ErrorAction SilentlyContinue).StartType" 2^>nul') do set "_uso_start=%%a"
if "!_uso_state!"=="" set "_uso_state=Not Found"
if "!_uso_start!"=="" set "_uso_start=N/A"

if "!_uso_state!"=="Stopped" (
    echo     UsoSvc Service:          STOPPED [OK]
    set /a "_cs_score+=1"
) else if "!_uso_state!"=="Running" (
    echo     UsoSvc Service:          RUNNING [FAIL]
    set "_cs_fail=!_cs_fail!  - UsoSvc is running^"
) else (
    echo     UsoSvc Service:          !_uso_state!
)

if "!_uso_start!"=="Disabled" (
    echo     Startup Type:            DISABLED [OK]
    set /a "_cs_score+=1"
) else if "!_uso_start!"=="Automatic" (
    echo     Startup Type:            AUTOMATIC [FAIL]
    set "_cs_fail=!_cs_fail!  - UsoSvc startup is Automatic^"
) else if "!_uso_start!"=="Manual" (
    echo     Startup Type:            MANUAL [FAIL]
    set "_cs_fail=!_cs_fail!  - UsoSvc startup is Manual^"
) else (
    echo     Startup Type:            !_uso_start!
)

echo.
echo   [2] REGISTRY STATUS
echo.

:: wuauserv Start
set "_reg_wu=Unknown"
reg query "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start >nul 2>&1
if errorlevel 1 (
    echo     wuauserv\Start:          NOT FOUND [FAIL]
    set "_cs_fail=!_cs_fail!  - wuauserv registry not found^"
) else (
    for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start 2^>nul ^| findstr /i "Start"') do set "_reg_wu=%%a"
    if "!_reg_wu!"=="0x4" (
        echo     wuauserv\Start:          DISABLED [OK]
    ) else if "!_reg_wu!"=="0x2" (
        echo     wuauserv\Start:          AUTOMATIC [FAIL]
        set "_cs_fail=!_cs_fail!  - wuauserv\Start is 0x2 (Auto)^"
    ) else if "!_reg_wu!"=="0x3" (
        echo     wuauserv\Start:          MANUAL [FAIL]
        set "_cs_fail=!_cs_fail!  - wuauserv\Start is 0x3 (Manual)^"
    ) else (
        echo     wuauserv\Start:          !_reg_wu!
    )
)

:: UsoSvc Start
set "_reg_uso=Unknown"
reg query "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start >nul 2>&1
if errorlevel 1 (
    echo     UsoSvc\Start:            NOT FOUND [FAIL]
    set "_cs_fail=!_cs_fail!  - UsoSvc registry not found^"
) else (
    for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start 2^>nul ^| findstr /i "Start"') do set "_reg_uso=%%a"
    if "!_reg_uso!"=="0x4" (
        echo     UsoSvc\Start:            DISABLED [OK]
    ) else if "!_reg_uso!"=="0x2" (
        echo     UsoSvc\Start:            AUTOMATIC [FAIL]
        set "_cs_fail=!_cs_fail!  - UsoSvc\Start is 0x2 (Auto)^"
    ) else if "!_reg_uso!"=="0x3" (
        echo     UsoSvc\Start:            MANUAL [FAIL]
        set "_cs_fail=!_cs_fail!  - UsoSvc\Start is 0x3 (Manual)^"
    ) else (
        echo     UsoSvc\Start:            !_reg_uso!
    )
)

echo.
echo   [3] GROUP POLICY STATUS
echo.

set "_gp_auto=Unknown"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate >nul 2>&1
if errorlevel 1 (
    echo     Auto Update Policy:      NOT CONFIGURED [FAIL]
    set "_cs_fail=!_cs_fail!  - NoAutoUpdate policy not set^"
) else (
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate 2^>nul ^| findstr /i "NoAutoUpdate"') do set "_gp_auto=%%a"
    if "!_gp_auto!"=="0x1" (
        echo     Auto Update Policy:      DISABLED [OK]
    ) else (
        echo     Auto Update Policy:      !_gp_auto! [FAIL]
        set "_cs_fail=!_cs_fail!  - NoAutoUpdate is !_gp_auto! (should be 0x1)^"
    )
)

echo.
echo   [4] TASK SCHEDULER STATUS
echo.

:: Check if any update-related scheduled tasks are NOT disabled
set "_active_tasks="
for /f "delims=" %%t in ('powershell.exe -nop -c "Get-ScheduledTask -TaskPath '\Microsoft\Windows\WindowsUpdate\' -ErrorAction SilentlyContinue | Where-Object {$_.State -ne 'Disabled'} | Select-Object -ExpandProperty TaskName" 2^>nul') do (
    set "_active_tasks=!_active_tasks! %%t"
)
if "!_active_tasks!"=="" (
    echo     Update Tasks:            ALL DISABLED [OK]
) else (
    echo     Update Tasks:            NOT FULLY DISABLED [FAIL]
    echo     Active tasks:!_active_tasks!
    set "_cs_fail=!_cs_fail!  - Scheduled tasks still active:!_active_tasks!^"
)

echo.
echo   ================================================================================
echo.

:: Summary
set /a "_cs_fail_count=_cs_total - _cs_score"
echo   RESULT: !_cs_score! / !_cs_total! PASSED, !_cs_fail_count! FAILED
echo.
if !_cs_score! EQU !_cs_total! (
    echo     [FULLY DISABLED] Windows Update is completely disabled.
    echo     No automatic updates will occur.
) else (
    echo     [NOT FULLY DISABLED] The following issues were found:
    echo !_cs_fail!
    echo.
    echo     Recommend: Run option [1] One-Click Disable, then reboot.
)

echo.
echo   ================================================================================
echo.
pause
goto MainMenu

:: ==================== Service Only ====================

:ServiceRegistryOnly
cls
echo.
echo   Disabling update services and modifying registry...
echo.
call :DisableWUService
echo.
call :ModifyRegistry
echo.
echo   [OK] Services and registry configured!
echo.
pause
goto MainMenu

:: ==================== Group Policy Only ====================

:GroupPolicyOnly
cls
echo.
echo   Configuring group policy...
echo.
call :ConfigureGroupPolicy
echo.
echo   [OK] Group policy configured!
echo   Note: Group policy only works on Windows Pro/Enterprise.
echo.
pause
goto MainMenu

:: ==================== Task Scheduler Only ====================

:TaskScheduleOnly
cls
echo.
echo   Cleaning task scheduler...
echo.
call :CleanTaskSchedule
echo.
echo   [OK] Task scheduler cleaned!
echo.
pause
goto MainMenu

:: ==================== Fix Resurrection ====================

:FixResurrection
cls
echo.
echo   Fixing service resurrection issue...
echo   ----------------------------------------------------------------
echo.
echo   Diagnosing...
echo.

set "_services=wuauserv UsoSvc WaaSMedicSvc UsoClient bits cryptsvc"
for %%s in (%_services%) do (
    echo   Checking service: %%s
    sc query %%s >nul 2>&1 && (
        for /f "tokens=3" %%a in ('sc query %%s ^| findstr /i "STATE"') do (
            if "%%a"=="RUNNING" (
                echo       - Running, stopping...
                net stop %%s >nul 2>&1
            )
        )
        echo       Setting startup type to disabled...
        sc config %%s start= disabled >nul 2>&1
        echo       - Disabled
    ) || (
        echo       - Service not found, skipping
    )
)

echo.
echo   Fixing registry resurrection mechanism...
echo.

reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo   [OK] Service startup types set to disabled

echo   Fixing FailureActions...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v FailureActions /t REG_BINARY /d 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v FailureActions /t REG_BINARY /d 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 /f >nul 2>&1
echo   [OK] FailureActions reset (auto-recovery disabled)

echo.
echo   Cleaning task scheduler...
echo.
call :CleanTaskSchedule

echo.
echo   ----------------------------------------------------------------
echo.
echo   [OK] Fix completed! Services will not auto-resurrect.
echo   It is recommended to restart the computer.
echo.
pause
goto MainMenu

:: ==================== Functions ====================

:: ---------- Disable Windows Update Services ----------
:DisableWUService
echo   Stopping Windows Update service...
net stop wuauserv >nul 2>&1
sc config wuauserv start= disabled >nul 2>&1
echo     [OK] Windows Update service disabled

echo   Stopping UsoSvc service...
net stop UsoSvc >nul 2>&1
sc config UsoSvc start= disabled >nul 2>&1
echo     [OK] UsoSvc service disabled

echo   Stopping Windows Update Medic Service...
net stop WaaSMedicSvc >nul 2>&1
sc config WaaSMedicSvc start= disabled >nul 2>&1
echo     [OK] Windows Update Medic Service disabled

echo   Stopping Update Orchestrator Service...
net stop UsoClient >nul 2>&1
sc config UsoClient start= disabled >nul 2>&1
echo     [OK] Update Orchestrator Service disabled

echo   Setting recovery options to "No Action"...
sc failure wuauserv reset= 0 actions= // >nul 2>&1
sc failure UsoSvc reset= 0 actions= // >nul 2>&1
sc failure WaaSMedicSvc reset= 0 actions= // >nul 2>&1
echo     [OK] All service recovery actions set to "No Action"
goto :eof

:: ---------- Modify Registry ----------
:ModifyRegistry
echo   Modifying wuauserv\Start to 4 (Disabled)...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo     [OK] wuauserv\Start = 4

echo   Modifying UsoSvc\Start to 4 (Disabled)...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo     [OK] UsoSvc\Start = 4

echo   Modifying WaaSMedicSvc\Start to 4 (Disabled)...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo     [OK] WaaSMedicSvc\Start = 4

echo   Modifying UsoClient\Start to 4 (Disabled)...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoClient" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo     [OK] UsoClient\Start = 4

echo   Resetting UsoSvc\FailureActions...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v FailureActions /t REG_BINARY /d 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 /f >nul 2>&1
echo     [OK] UsoSvc\FailureActions reset

echo   Resetting wuauserv\FailureActions...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v FailureActions /t REG_BINARY /d 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 /f >nul 2>&1
echo     [OK] wuauserv\FailureActions reset

echo   Disabling Windows Update Delivery Optimization...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f >nul 2>&1
echo     [OK] Delivery Optimization disabled
goto :eof

:: ---------- Configure Group Policy ----------
:ConfigureGroupPolicy
echo   Creating group policy registry paths...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /f >nul 2>&1

echo   Disabling auto update (NoAutoUpdate = 1)...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul 2>&1
echo     [OK] Auto update disabled

echo   Setting auto update notification to "Disabled" (AUOptions = 1)...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 1 /f >nul 2>&1
echo     [OK] Update notification disabled

echo   Disabling Windows Update access...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /t REG_DWORD /d 1 /f >nul 2>&1
echo     [OK] Windows Update access disabled

echo   Disabling "Restart to update" prompt...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f >nul 2>&1
echo     [OK] "Restart to update" prompt disabled

echo   Disabling update scope detection...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v UseWUServer /t REG_DWORD /d 1 /f >nul 2>&1
echo     [OK] Configured to use internal WSUS (blocks Microsoft update servers)
goto :eof

:: ---------- Clean Task Scheduler ----------
:CleanTaskSchedule
set "_wutasks=0"
set "_disabled=0"

for /f "delims=" %%t in ('schtasks /query /tn "Microsoft\Windows\WindowsUpdate" /fo LIST 2^>nul ^| findstr /i "TaskName"') do (
    set "_wutasks=1"
)

if "%_wutasks%"=="0" (
    echo   No WindowsUpdate scheduled tasks found.
    goto :eof
)

echo   Disabling WindowsUpdate scheduled tasks...

set "_taskList=Scheduled Start"
for %%t in (%_taskList%) do (
    schtasks /change /tn "Microsoft\Windows\WindowsUpdate\%%t" /disable >nul 2>&1 && (
        echo     [OK] Disabled: %%t
        set /a "_disabled+=1"
    ) || (
        echo     - Not found: %%t
    )
)

powershell.exe -nop -c "Get-ScheduledTask -TaskPath '\Microsoft\Windows\WindowsUpdate\' -ErrorAction SilentlyContinue | ForEach-Object { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue; Write-Host ('    [OK] Disabled: ' + $_.TaskName) }" 2>nul

echo   [OK] All WindowsUpdate scheduled tasks disabled.
goto :eof

:: ---------- Restore Services ----------
:RestoreWUService
echo   Restoring Windows Update service...
sc config wuauserv start= demand >nul 2>&1
sc failure wuauserv reset= 86400 actions= restart/60000/restart/120000/restart/14400000 >nul 2>&1
echo     [OK] Windows Update service restored

echo   Restoring UsoSvc service...
sc config UsoSvc start= demand >nul 2>&1
sc failure UsoSvc reset= 86400 actions= restart/60000/restart/120000/restart/14400000 >nul 2>&1
echo     [OK] UsoSvc service restored

echo   Restoring Windows Update Medic Service...
sc config WaaSMedicSvc start= demand >nul 2>&1
echo     [OK] Windows Update Medic Service restored

echo   Restoring Update Orchestrator Service...
sc config UsoClient start= demand >nul 2>&1
echo     [OK] Update Orchestrator Service restored
goto :eof

:: ---------- Restore Registry ----------
:RestoreRegistry
echo   Restoring wuauserv\Start to 3 (Manual)...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
echo     [OK] wuauserv\Start = 3

echo   Restoring UsoSvc\Start to 3 (Manual)...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
echo     [OK] UsoSvc\Start = 3

echo   Restoring WaaSMedicSvc\Start to 3 (Manual)...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
echo     [OK] WaaSMedicSvc\Start = 3

echo   Restoring UsoClient\Start to 3 (Manual)...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoClient" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
echo     [OK] UsoClient\Start = 3

echo   Deleting custom FailureActions...
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v FailureActions /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v FailureActions /f >nul 2>&1
echo     [OK] FailureActions restored to default
goto :eof

:: ---------- Restore Group Policy ----------
:RestoreGroupPolicy
echo   Deleting Windows Update group policies...
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /f >nul 2>&1
echo     [OK] Group policy restored to default
goto :eof

:: ---------- Restore Task Scheduler ----------
:RestoreTaskSchedule
echo   Enabling WindowsUpdate scheduled tasks...
powershell.exe -nop -c "Get-ScheduledTask -TaskPath '\Microsoft\Windows\WindowsUpdate\' -ErrorAction SilentlyContinue | ForEach-Object { Enable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue; Write-Host ('    [OK] Enabled: ' + $_.TaskName) }" 2>nul
echo   [OK] Scheduled tasks restored.
goto :eof

:: ==================== Exit ====================

:Exit
endlocal
exit /b 0
