# ==============================================================================
#  Windows Update Disabler (WUD) - PowerShell Launcher
#  Version 1.1
#
#  一键执行:
#    irm https://raw.githubusercontent.com/Dawncopper/WUD/main/WUD.ps1 | iex
#
#  功能: 下载并执行 WUD.cmd 主脚本（自动提权）
# ==============================================================================

# --- 环境预检 ---

# 检查 PowerShell LanguageMode
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Warning "PowerShell is running in $($ExecutionContext.SessionState.LanguageMode) mode. This script requires FullLanguage mode."
    Write-Host "Please run: Set-ExecutionPolicy Bypass -Scope Process -Force"
    Read-Host "Press Enter to exit"
    return
}

# 检查 .NET 是否正常
try {
    [void][System.Reflection.Assembly]::LoadWithPartialName('System.Core')
    $result = [math]::Sqrt(144)
    if ($result -ne 12) { throw }
} catch {
    Write-Warning ".NET runtime check failed. This script requires a working .NET environment."
    Read-Host "Press Enter to exit"
    return
}

# 设置 TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# --- 下载主脚本 ---

# 多源容错
$DownloadURLs = @(
    'https://raw.githubusercontent.com/Dawncopper/WUD/main/WUD.cmd',
    'https://cdn.jsdelivr.net/gh/Dawncopper/WUD@main/WUD.cmd',
    'https://gitee.com/Dawncopper/WUD/raw/main/WUD.cmd'
)

$ScriptContent = $null

# 随机排序 URL，依次尝试
foreach ($URL in ($DownloadURLs | Sort-Object { Get-Random })) {
    try {
        Write-Host "  正在下载: $URL" -ForegroundColor Gray
        $response = Invoke-WebRequest -Uri $URL -UseBasicParsing -TimeoutSec 30
        if ($response.StatusCode -eq 200) {
            $ScriptContent = $response.Content
            Write-Host "  下载成功!" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "  下载失败: $URL" -ForegroundColor DarkGray
        continue
    }
}

if (-not $ScriptContent) {
    Write-Error "所有下载源均失败，请检查网络连接后重试。"
    Write-Host ""
    Write-Host "你也可以手动下载 WUD.cmd 并以管理员身份运行。" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    return
}

# --- 写入临时文件并执行 ---

$rand = [Guid]::NewGuid().Guid
$TempFile = "$env:SystemRoot\Temp\WUD_$rand.cmd"

try {
    # 确保使用 CRLF 行尾（batch 文件要求）
    $ScriptContent = $ScriptContent -replace "`r`n", "`n" -replace "`n", "`r`n"
    Set-Content -Path $TempFile -Value $ScriptContent -Encoding ASCII -NoNewline

    Write-Host ""
    Write-Host "  正在启动 Windows Update Disabler..." -ForegroundColor Cyan
    Write-Host ""

    # 以管理员权限启动 CMD 执行脚本
    # 使用 /k 而不是 /c，确保窗口不会在脚本结束后自动关闭
    $proc = Start-Process -FilePath $env:ComSpec -ArgumentList "/k `"$TempFile`" -el" -Verb RunAs -PassThru -ErrorAction Stop

} catch {
    Write-Error "启动脚本失败: $_"
    Read-Host "Press Enter to exit"
}
