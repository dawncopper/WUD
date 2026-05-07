@echo off
:: ==============================================================================
::  Windows Update Disabler (WUD) - All-In-One Version
::  Version 1.3
::
::  功能: 彻底关闭 Windows 自动更新
::  方法: 服务禁用 + 注册表修改 + 组策略配置 + 任务计划清理
::  适配: Windows 10 / Windows 11
::
::  用法: 以管理员身份运行此脚本
::        或通过 PowerShell 一键执行:
::        irm https://raw.githubusercontent.com/Dawncopper/WUD/main/WUD.ps1 | iex
:: ==============================================================================

:: 防止变量污染
setlocal EnableDelayedExpansion

:: 设置 UTF-8 代码页以支持中文显示
chcp 65001 >nul 2>&1

:: ==================== 初始化 ====================

:: 脚本自身路径
set "_batf=%~f0"
set "_batp=%~dp0"

:: 检查是否已提权（-el 标记）
if "%~1"=="-el" set "_elev=1"

:: 架构位数自动切换（x86 进程在 x64 系统上时，自动重启为 Sysnative 的 x64 cmd）
if exist %SystemRoot%\Sysnative\cmd.exe if not defined re1 (
    start %SystemRoot%\Sysnative\cmd.exe /c ""!_batf!" %* re1"
    exit /b
)

:: 管理员权限检测
fltmc >nul 2>&1 || (
    if not defined _elev (
        echo 正在请求管理员权限...
        powershell.exe -nop -c "start cmd.exe -arg '/c \"\"!_batf!\" -el\"' -verb runas"
        exit /b
    )
    echo [错误] 此脚本需要管理员权限，请右键以管理员身份运行。
    pause
    exit /b 1
)

:: 禁用 QuickEdit 防止误触暂停
mode con cols=80 lines=40

:: ANSI 转义字符 - 使用 findstr 安全检测
for /F "delims=#" %%E in ('"prompt #$E# & for %%E in (1) do rem"') do set "esc=%%E"
if not defined esc set "esc="

:: 颜色定义
set "_Red=41;97m"
set "_Green=42;97m"
set "_Yellow=43;97m"
set "_Blue=44;97m"
set "_Gray=100;97m"
set "_White=47;97m"
set "_Cyan=46;97m"

:: 版本号
set "_ver=1.3"

:: ==================== 主菜单 ====================

:MainMenu
cls
title  Windows Update Disabler %_ver%
echo.
echo  %esc%[%_Cyan%================================================================================%esc%[0m
echo  %esc%[%_Cyan%|%esc%[0m                                                                           %esc%[%_Cyan%|%esc%[0m
echo  %esc%[%_Cyan%|%esc%[0m           %esc%[%_White% Windows Update Disabler  v%_ver% %esc%[0m                          %esc%[%_Cyan%|%esc%[0m
echo  %esc%[%_Cyan%|%esc%[0m           %esc%[%_Gray% 彻底关闭 Windows 自动更新工具 %esc%[0m                        %esc%[%_Cyan%|%esc%[0m
echo  %esc%[%_Cyan%|%esc%[0m                                                                           %esc%[%_Cyan%|%esc%[0m
echo  %esc%[%_Cyan%================================================================================%esc%[0m
echo.
echo  %esc%[%_White%  操作菜单:%esc%[0m
echo.
echo     %esc%[%_Green%[1]%esc%[0m  一键彻底关闭 Windows 更新（推荐）
echo     %esc%[%_Green%[2]%esc%[0m  分步执行（高级用户）
echo     %esc%[%_Green%[3]%esc%[0m  恢复 Windows 更新
echo     %esc%[%_Green%[4]%esc%[0m  检查当前更新状态
echo     %esc%[%_Green%[5]%esc%[0m  仅禁用更新服务（服务+注册表）
echo     %esc%[%_Green%[6]%esc%[0m  仅配置组策略
echo     %esc%[%_Green%[7]%esc%[0m  仅清理任务计划
echo     %esc%[%_Green%[8]%esc%[0m  修复：更新服务复活问题
echo.
echo     %esc%[%_Red%[0]%esc%[0m  退出
echo.
echo  %esc%[%_Cyan%================================================================================%esc%[0m
echo.
echo  %esc%[%_Gray%  提示: 安全更新也会被禁用，建议定期手动检查安全补丁。%esc%[0m
echo.
set /p "_choice=  请输入选项 [0-8]: "

if "%_choice%"=="1" goto AllInOne
if "%_choice%"=="2" goto StepByStep
if "%_choice%"=="3" goto RestoreUpdates
if "%_choice%"=="4" goto CheckStatus
if "%_choice%"=="5" goto ServiceRegistryOnly
if "%_choice%"=="6" goto GroupPolicyOnly
if "%_choice%"=="7" goto TaskScheduleOnly
if "%_choice%"=="8" goto FixResurrection
if "%_choice%"=="0" goto Exit
echo  [错误] 无效选项，请重新输入。
timeout /t 2 >nul
goto MainMenu

:: ==================== 一键彻底关闭 ====================

:AllInOne
cls
echo.
echo  %esc%[%_Yellow%  正在执行一键彻底关闭 Windows 更新...%esc%[0m
echo  %esc%[%_Gray%  ----------------------------------------------------------------%esc%[0m
echo.

echo  %esc%[%_Cyan%  [1/4] 禁用更新服务...%esc%[0m
call :DisableWUService
echo.

echo  %esc%[%_Cyan%  [2/4] 修改注册表...%esc%[0m
call :ModifyRegistry
echo.

echo  %esc%[%_Cyan%  [3/4] 配置组策略...%esc%[0m
call :ConfigureGroupPolicy
echo.

echo  %esc%[%_Cyan%  [4/4] 清理任务计划...%esc%[0m
call :CleanTaskSchedule
echo.

echo  %esc%[%_Gray%  ----------------------------------------------------------------%esc%[0m
echo.
echo  %esc%[%_Green%  [OK] 所有操作已完成！Windows 更新已被彻底关闭。%esc%[0m
echo.
echo  %esc%[%_Yellow%  [!] 注意: 安全更新也已停止，建议每月手动检查一次安全补丁。%esc%[0m
echo.
pause
goto MainMenu

:: ==================== 分步执行 ====================

:StepByStep
cls
echo.
echo  %esc%[%_Cyan%===================================================================%esc%[0m
echo  %esc%[%_Cyan%|%esc%[0m           %esc%[%_White% 分步执行 - 高级用户模式 %esc%[0m                          %esc%[%_Cyan%|%esc%[0m
echo  %esc%[%_Cyan%===================================================================%esc%[0m
echo.
echo     %esc%[%_Green%[1]%esc%[0m  第一步: 禁用 Windows Update 服务
echo     %esc%[%_Green%[2]%esc%[0m  第二步: 修改注册表（堵死复活机制）
echo     %esc%[%_Green%[3]%esc%[0m  第三步: 配置组策略
echo     %esc%[%_Green%[4]%esc%[0m  第四步: 清理任务计划
echo     %esc%[%_Green%[5]%esc%[0m  执行全部（等同于一键模式）
echo     %esc%[%_Red%[0]%esc%[0m  返回主菜单
echo.
set /p "_step=  请选择要执行的步骤: "

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
echo  [错误] 无效选项。
timeout /t 2 >nul
goto StepByStep

:: ==================== 恢复更新 ====================

:RestoreUpdates
cls
echo.
echo  %esc%[%_Yellow%  正在恢复 Windows 更新...%esc%[0m
echo  %esc%[%_Gray%  ----------------------------------------------------------------%esc%[0m
echo.

echo  %esc%[%_Cyan%  [1/4] 恢复更新服务...%esc%[0m
call :RestoreWUService
echo.

echo  %esc%[%_Cyan%  [2/4] 恢复注册表...%esc%[0m
call :RestoreRegistry
echo.

echo  %esc%[%_Cyan%  [3/4] 恢复组策略...%esc%[0m
call :RestoreGroupPolicy
echo.

echo  %esc%[%_Cyan%  [4/4] 恢复任务计划...%esc%[0m
call :RestoreTaskSchedule
echo.

echo  %esc%[%_Gray%  ----------------------------------------------------------------%esc%[0m
echo.
echo  %esc%[%_Green%  [OK] Windows 更新已恢复！%esc%[0m
echo  %esc%[%_Yellow%  建议重启电脑以确保所有更改生效。%esc%[0m
echo.
pause
goto MainMenu

:: ==================== 检查状态 ====================

:CheckStatus
cls
echo.
echo  %esc%[%_Cyan%  当前 Windows 更新状态检查%esc%[0m
echo  %esc%[%_Gray%  ----------------------------------------------------------------%esc%[0m
echo.

echo  %esc%[%_White%  [服务状态]%esc%[0m
for /f "tokens=3" %%a in ('sc query wuauserv ^| findstr /i "STATE"') do (
    if "%%a"=="RUNNING" (
        echo    Windows Update 服务:    %esc%[%_Green%[运行中]%esc%[0m
    ) else if "%%a"=="STOPPED" (
        echo    Windows Update 服务:    %esc%[%_Yellow%[已停止]%esc%[0m
    ) else (
        echo    Windows Update 服务:    %esc%[%_Red%[%%a]%esc%[0m
    )
)

for /f "tokens=3" %%a in ('sc query wuauserv ^| findstr /i "START_TYPE" 2^>nul') do (
    echo    启动类型:              %%a
)

echo.
for /f "tokens=3" %%a in ('sc query UsoSvc ^| findstr /i "STATE" 2^>nul') do (
    if "%%a"=="RUNNING" (
        echo    UsoSvc 服务:          %esc%[%_Green%[运行中]%esc%[0m
    ) else if "%%a"=="STOPPED" (
        echo    UsoSvc 服务:          %esc%[%_Yellow%[已停止]%esc%[0m
    ) else (
        echo    UsoSvc 服务:          %esc%[%_Red%[%%a]%esc%[0m
    )
)

echo.
echo  %esc%[%_White%  [注册表状态]%esc%[0m
reg query "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start 2>nul | findstr /i "Start" >nul && (
    for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start 2^>nul ^| findstr /i "Start"') do (
        if "%%a"=="0x4" (
            echo    wuauserv\Start:      %esc%[%_Green%4 (已禁用)%esc%[0m
        ) else if "%%a"=="0x2" (
            echo    wuauserv\Start:      %esc%[%_Yellow%2 (自动)%esc%[0m
        ) else if "%%a"=="0x3" (
            echo    wuauserv\Start:      %esc%[%_Yellow%3 (手动)%esc%[0m
        ) else (
            echo    wuauserv\Start:      %%a
        )
    )
) || echo    wuauserv\Start:      %esc%[%_Red%未找到%esc%[0m

reg query "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start 2>nul | findstr /i "Start" >nul && (
    for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start 2^>nul ^| findstr /i "Start"') do (
        if "%%a"=="0x4" (
            echo    UsoSvc\Start:        %esc%[%_Green%4 (已禁用)%esc%[0m
        ) else if "%%a"=="0x2" (
            echo    UsoSvc\Start:        %esc%[%_Yellow%2 (自动)%esc%[0m
        ) else (
            echo    UsoSvc\Start:        %%a
        )
    )
) || echo    UsoSvc\Start:        %esc%[%_Red%未找到%esc%[0m

echo.
echo  %esc%[%_White%  [组策略状态]%esc%[0m
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate 2>nul | findstr /i "NoAutoUpdate" >nul && (
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate 2^>nul ^| findstr /i "NoAutoUpdate"') do (
        if "%%a"=="0x1" (
            echo    自动更新策略:        %esc%[%_Green%已禁用%esc%[0m
        ) else (
            echo    自动更新策略:        %%a
        )
    )
) || echo    自动更新策略:        %esc%[%_Yellow%未配置%esc%[0m

echo.
echo  %esc%[%_White%  [任务计划状态]%esc%[0m
set "_taskCount=0"
for /f %%a in ('schtasks /query /tn "Microsoft\Windows\WindowsUpdate\Scheduled Start" 2^>nul ^| findstr /i "Scheduled Start"') do set "_taskCount=1"
if "%_taskCount%"=="0" (
    echo    WindowsUpdate 任务:   %esc%[%_Green%已禁用或不存在%esc%[0m
) else (
    echo    WindowsUpdate 任务:   %esc%[%_Yellow%可能仍处于活动状态%esc%[0m
)

echo.
echo  %esc%[%_Gray%  ----------------------------------------------------------------%esc%[0m
echo.
pause
goto MainMenu

:: ==================== 仅禁用服务+注册表 ====================

:ServiceRegistryOnly
cls
echo.
echo  %esc%[%_Yellow%  正在禁用更新服务并修改注册表...%esc%[0m
echo.
call :DisableWUService
echo.
call :ModifyRegistry
echo.
echo  %esc%[%_Green%  [OK] 服务和注册表配置完成！%esc%[0m
echo.
pause
goto MainMenu

:: ==================== 仅配置组策略 ====================

:GroupPolicyOnly
cls
echo.
echo  %esc%[%_Yellow%  正在配置组策略...%esc%[0m
echo.
call :ConfigureGroupPolicy
echo.
echo  %esc%[%_Green%  [OK] 组策略配置完成！%esc%[0m
echo  %esc%[%_Yellow%  注意: 组策略仅对 Windows Pro/Enterprise 版本有效。%esc%[0m
echo.
pause
goto MainMenu

:: ==================== 仅清理任务计划 ====================

:TaskScheduleOnly
cls
echo.
echo  %esc%[%_Yellow%  正在清理任务计划...%esc%[0m
echo.
call :CleanTaskSchedule
echo.
echo  %esc%[%_Green%  [OK] 任务计划清理完成！%esc%[0m
echo.
pause
goto MainMenu

:: ==================== 修复复活问题 ====================

:FixResurrection
cls
echo.
echo  %esc%[%_Yellow%  正在修复更新服务复活问题...%esc%[0m
echo  %esc%[%_Gray%  ----------------------------------------------------------------%esc%[0m
echo.
echo  %esc%[%_Cyan%  诊断中...%esc%[0m
echo.

set "_services=wuauserv UsoSvc WaaSMedicSvc UsoClient bits cryptsvc"
for %%s in (%_services%) do (
    echo  检查服务: %%s
    sc query %%s >nul 2>&1 && (
        for /f "tokens=3" %%a in ('sc query %%s ^| findstr /i "STATE"') do (
            if "%%a"=="RUNNING" (
                echo    %esc%[%_Red%    - 正在运行，正在停止...%esc%[0m
                net stop %%s >nul 2>&1
            )
        )
        echo    设置启动类型为禁用...
        sc config %%s start= disabled >nul 2>&1
        echo    %esc%[%_Green%    - 已禁用%esc%[0m
    ) || (
        echo    %esc%[%_Gray%    - 服务不存在，跳过%esc%[0m
    )
)

echo.
echo  %esc%[%_Cyan%  修复注册表恢复机制...%esc%[0m
echo.

reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo  %esc%[%_Green%  [OK] 服务启动类型已设为禁用%esc%[0m

echo  修复 FailureActions...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v FailureActions /t REG_BINARY /d 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v FailureActions /t REG_BINARY /d 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 /f >nul 2>&1
echo  %esc%[%_Green%  [OK] FailureActions 已重置（禁用自动恢复）%esc%[0m

echo.
echo  %esc%[%_Cyan%  清理任务计划...%esc%[0m
echo.
call :CleanTaskSchedule

echo.
echo  %esc%[%_Gray%  ----------------------------------------------------------------%esc%[0m
echo.
echo  %esc%[%_Green%  [OK] 修复完成！更新服务不会再自动复活。%esc%[0m
echo  %esc%[%_Yellow%  建议重启电脑以确保所有更改生效。%esc%[0m
echo.
pause
goto MainMenu

:: ==================== 功能函数 ====================

:: ---------- 禁用 Windows Update 服务 ----------
:DisableWUService
echo  停止 Windows Update 服务...
net stop wuauserv >nul 2>&1
sc config wuauserv start= disabled >nul 2>&1
echo  %esc%[%_Green%    [OK] Windows Update 服务已禁用%esc%[0m

echo  停止 UsoSvc 服务...
net stop UsoSvc >nul 2>&1
sc config UsoSvc start= disabled >nul 2>&1
echo  %esc%[%_Green%    [OK] UsoSvc 服务已禁用%esc%[0m

echo  停止 Windows Update Medic Service...
net stop WaaSMedicSvc >nul 2>&1
sc config WaaSMedicSvc start= disabled >nul 2>&1
echo  %esc%[%_Green%    [OK] Windows Update Medic Service 已禁用%esc%[0m

echo  停止 Update Orchestrator Service...
net stop UsoClient >nul 2>&1
sc config UsoClient start= disabled >nul 2>&1
echo  %esc%[%_Green%    [OK] Update Orchestrator Service 已禁用%esc%[0m

echo  设置恢复选项为"无操作"...
sc failure wuauserv reset= 0 actions= // >nul 2>&1
sc failure UsoSvc reset= 0 actions= // >nul 2>&1
sc failure WaaSMedicSvc reset= 0 actions= // >nul 2>&1
echo  %esc%[%_Green%    [OK] 所有服务的恢复操作已设为"无操作"%esc%[0m
goto :eof

:: ---------- 修改注册表 ----------
:ModifyRegistry
echo  修改 wuauserv\Start 为 4（禁用）...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] wuauserv\Start = 4%esc%[0m

echo  修改 UsoSvc\Start 为 4（禁用）...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] UsoSvc\Start = 4%esc%[0m

echo  修改 WaaSMedicSvc\Start 为 4（禁用）...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] WaaSMedicSvc\Start = 4%esc%[0m

echo  修改 UsoClient\Start 为 4（禁用）...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoClient" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] UsoClient\Start = 4%esc%[0m

echo  重置 UsoSvc\FailureActions（禁用自动恢复）...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v FailureActions /t REG_BINARY /d 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] UsoSvc\FailureActions 已重置%esc%[0m

echo  重置 wuauserv\FailureActions（禁用自动恢复）...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v FailureActions /t REG_BINARY /d 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] wuauserv\FailureActions 已重置%esc%[0m

echo  禁用 Windows Update Delivery Optimization...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] 传递优化已禁用%esc%[0m
goto :eof

:: ---------- 配置组策略 ----------
:ConfigureGroupPolicy
echo  创建组策略注册表路径...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /f >nul 2>&1

echo  禁用自动更新（NoAutoUpdate = 1）...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] 自动更新已禁用%esc%[0m

echo  设置自动更新通知为"已禁用"（AUOptions = 1）...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 1 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] 更新通知已禁用%esc%[0m

echo  禁用 Windows Update 功能访问...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /t REG_DWORD /d 1 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] Windows Update 功能访问已禁用%esc%[0m

echo  禁用"重启以更新"提示...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] "重启以更新"提示已禁用%esc%[0m

echo  禁用更新范围检测...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v UseWUServer /t REG_DWORD /d 1 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] 已配置使用内部 WSUS（阻止微软更新服务器）%esc%[0m
goto :eof

:: ---------- 清理任务计划 ----------
:CleanTaskSchedule
set "_wutasks=0"
set "_disabled=0"

for /f "delims=" %%t in ('schtasks /query /tn "Microsoft\Windows\WindowsUpdate" /fo LIST 2^>nul ^| findstr /i "TaskName"') do (
    set "_wutasks=1"
)

if "%_wutasks%"=="0" (
    echo  %esc%[%_Gray%  未找到 WindowsUpdate 任务计划。%esc%[0m
    goto :eof
)

echo  正在禁用 WindowsUpdate 相关任务计划...

set "_taskList=Scheduled Start"
for %%t in (%_taskList%) do (
    schtasks /change /tn "Microsoft\Windows\WindowsUpdate\%%t" /disable >nul 2>&1 && (
        echo  %esc%[%_Green%    [OK] 已禁用: %%t%esc%[0m
        set /a "_disabled+=1"
    ) || (
        echo  %esc%[%_Gray%    - 不存在: %%t%esc%[0m
    )
)

powershell.exe -nop -c "Get-ScheduledTask -TaskPath '\Microsoft\Windows\WindowsUpdate\' -ErrorAction SilentlyContinue | ForEach-Object { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue; Write-Host ('    [OK] 已禁用: ' + $_.TaskName) }" 2>nul

echo  %esc%[%_Green%  [OK] WindowsUpdate 任务计划已全部禁用。%esc%[0m
goto :eof

:: ---------- 恢复服务 ----------
:RestoreWUService
echo  恢复 Windows Update 服务...
sc config wuauserv start= demand >nul 2>&1
sc failure wuauserv reset= 86400 actions= restart/60000/restart/120000/restart/14400000 >nul 2>&1
echo  %esc%[%_Green%    [OK] Windows Update 服务已恢复%esc%[0m

echo  恢复 UsoSvc 服务...
sc config UsoSvc start= demand >nul 2>&1
sc failure UsoSvc reset= 86400 actions= restart/60000/restart/120000/restart/14400000 >nul 2>&1
echo  %esc%[%_Green%    [OK] UsoSvc 服务已恢复%esc%[0m

echo  恢复 Windows Update Medic Service...
sc config WaaSMedicSvc start= demand >nul 2>&1
echo  %esc%[%_Green%    [OK] Windows Update Medic Service 已恢复%esc%[0m

echo  恢复 Update Orchestrator Service...
sc config UsoClient start= demand >nul 2>&1
echo  %esc%[%_Green%    [OK] Update Orchestrator Service 已恢复%esc%[0m
goto :eof

:: ---------- 恢复注册表 ----------
:RestoreRegistry
echo  恢复 wuauserv\Start 为 3（手动）...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] wuauserv\Start = 3%esc%[0m

echo  恢复 UsoSvc\Start 为 3（手动）...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] UsoSvc\Start = 3%esc%[0m

echo  恢复 WaaSMedicSvc\Start 为 3（手动）...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] WaaSMedicSvc\Start = 3%esc%[0m

echo  恢复 UsoClient\Start 为 3（手动）...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UsoClient" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
echo  %esc%[%_Green%    [OK] UsoClient\Start = 3%esc%[0m

echo  删除自定义 FailureActions（恢复默认）...
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v FailureActions /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v FailureActions /f >nul 2>&1
echo  %esc%[%_Green%    [OK] FailureActions 已恢复默认%esc%[0m
goto :eof

:: ---------- 恢复组策略 ----------
:RestoreGroupPolicy
echo  删除 Windows Update 组策略...
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /f >nul 2>&1
echo  %esc%[%_Green%    [OK] 组策略已恢复默认%esc%[0m
goto :eof

:: ---------- 恢复任务计划 ----------
:RestoreTaskSchedule
echo  启用 WindowsUpdate 任务计划...
powershell.exe -nop -c "Get-ScheduledTask -TaskPath '\Microsoft\Windows\WindowsUpdate\' -ErrorAction SilentlyContinue | ForEach-Object { Enable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue; Write-Host ('    [OK] 已启用: ' + $_.TaskName) }" 2>nul
echo  %esc%[%_Green%  [OK] 任务计划已恢复。%esc%[0m
goto :eof

:: ==================== 退出 ====================

:Exit
endlocal
exit /b 0
