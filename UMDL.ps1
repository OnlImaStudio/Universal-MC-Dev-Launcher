param(
)

$ErrorActionPreference = 'Stop'
$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimePath = Join-Path $toolRoot 'runtime'
$errorLog = Join-Path $runtimePath 'startup-error.log'
[IO.Directory]::CreateDirectory($runtimePath) | Out-Null

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LauncherConsole {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    [DllImport("shcore.dll")]
    public static extern int SetProcessDpiAwareness(int value);
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    public static string EnableBestDpiMode() {
        try { if (SetProcessDpiAwarenessContext(new IntPtr(-4))) return "PerMonitorV2"; } catch { }
        try {
            int result = SetProcessDpiAwareness(2);
            if (result == 0 || result == unchecked((int)0x80070005)) return "PerMonitor";
        } catch { }
        try { if (SetProcessDPIAware()) return "SystemAware"; } catch { }
        return "ExistingOrUnavailable";
    }
}
'@

$dpiMode = [LauncherConsole]::EnableBestDpiMode()
$consoleHandle = [LauncherConsole]::GetConsoleWindow()
if ($consoleHandle -ne [IntPtr]::Zero) { [void][LauncherConsole]::ShowWindow($consoleHandle, 0) }

try {
    $mainScript = Join-Path $toolRoot 'UniversalMCDevLauncher.ps1'
    if (-not (Test-Path -LiteralPath $mainScript -PathType Leaf)) { throw "UMDL main program was not found: $mainScript" }
    if (Test-Path -LiteralPath $errorLog -PathType Leaf) { Remove-Item -LiteralPath $errorLog -Force }
    & $mainScript
}
catch {
    $rawError = $_ | Out-String
    $detail = $_.Exception.ToString()
    $fullError = "Startup time: $([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))`r`n$rawError`r`n$detail"
    [IO.File]::WriteAllText($errorLog, $fullError, (New-Object Text.UTF8Encoding($true)))
    if ($consoleHandle -ne [IntPtr]::Zero) { [void][LauncherConsole]::ShowWindow($consoleHandle, 5) }
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show(
        "Universal MC Dev Launcher (UMDL) failed to start.`r`n`r`nOriginal error:`r`n$($_.Exception.Message)`r`n`r`nFull details were saved to:`r`n$errorLog",
        'UMDL startup failed', [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    [Environment]::Exit(1)
}

[Environment]::Exit(0)
