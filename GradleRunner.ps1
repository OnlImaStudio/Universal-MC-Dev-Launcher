param(
    [Parameter(Mandatory = $true)]
    [string]$RequestFile
)

$ErrorActionPreference = 'Stop'

function Write-State {
    param(
        [string]$Status,
        [Nullable[int]]$ExitCode = $null,
        [string]$Message = ''
    )

    $state = [ordered]@{
        status = $Status
        exitCode = $ExitCode
        message = $Message
        updatedAt = [DateTime]::Now.ToString('o')
        runnerPid = $PID
    }
    $json = $state | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($script:request.stateFile, $json, (New-Object Text.UTF8Encoding($false)))
}

try {
    $requestText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $RequestFile))
    $script:request = $requestText | ConvertFrom-Json

    $projectPath = [IO.Path]::GetFullPath([string]$request.projectPath)
    $wrapperPath = [IO.Path]::GetFullPath([string]$request.wrapperPath)
    $stdoutFile = [IO.Path]::GetFullPath([string]$request.stdoutFile)
    $stderrFile = [IO.Path]::GetFullPath([string]$request.stderrFile)
    $tasks = @($request.tasks)

    if (-not (Test-Path -LiteralPath $projectPath -PathType Container)) {
        throw "项目目录不存在：$projectPath"
    }
    if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) {
        throw "找不到 Gradle Wrapper：$wrapperPath"
    }
    if ($tasks.Count -eq 0) {
        throw '没有要执行的 Gradle 任务。'
    }
    foreach ($task in $tasks) {
        if ([string]$task -notmatch '^[A-Za-z0-9_.:-]+$') {
            throw "任务名称不安全或无效：$task"
        }
    }

    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($stdoutFile, '', $utf8)
    [IO.File]::WriteAllText($stderrFile, '', $utf8)

    Write-State -Status 'running' -Message 'Gradle 命令正在运行。'
    $taskText = (@($tasks | ForEach-Object { [string]$_ }) -join ' ')
    $escapedStdout = $stdoutFile.Replace('"', '""')
    $escapedStderr = $stderrFile.Replace('"', '""')
    $commandLine = "chcp 65001>nul & call gradlew.bat $taskText --console=plain --no-daemon 1>`"$escapedStdout`" 2>`"$escapedStderr`""
    $cmdArguments = '/d /s /c "' + $commandLine + '"'

    # Start-Process enumerates the inherited environment before CreateProcess.
    # Some hosts legally provide both Path and PATH; that makes Start-Process
    # throw a duplicate-key exception. ProcessStartInfo can inherit that block
    # directly and keeps the Gradle child fully hidden.
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $env:ComSpec
    $startInfo.Arguments = $cmdArguments
    $startInfo.WorkingDirectory = $projectPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $gradleProcess = New-Object Diagnostics.Process
    $gradleProcess.StartInfo = $startInfo
    if (-not $gradleProcess.Start()) { throw '无法启动 Gradle 后台进程。' }
    $gradleProcess.WaitForExit()
    $overallExitCode = [int]$gradleProcess.ExitCode
    $gradleProcess.Dispose()

    if ($overallExitCode -eq 0) {
        Write-State -Status 'completed' -ExitCode 0 -Message '命令已正常结束。'
    }
    else {
        Write-State -Status 'failed' -ExitCode $overallExitCode -Message "Gradle 返回退出代码 $overallExitCode。"
    }
}
catch {
    try {
        if ($null -ne $script:request -and $script:request.stderrFile) {
            [IO.File]::AppendAllText(
                [string]$script:request.stderrFile,
                "`r`n[启动器错误] $($_.Exception.Message)`r`n",
                (New-Object Text.UTF8Encoding($false))
            )
        }
        if ($null -ne $script:request -and $script:request.stateFile) {
            Write-State -Status 'failed' -ExitCode 1 -Message $_.Exception.Message
        }
    }
    catch { }
    exit 1
}
