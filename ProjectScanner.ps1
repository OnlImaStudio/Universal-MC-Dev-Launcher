param(
    [Parameter(Mandatory = $true)]
    [string]$RequestFile,

    [Parameter(Mandatory = $true)]
    [string]$ResultFile
)

$ErrorActionPreference = 'Stop'
$script:Utf8 = New-Object Text.UTF8Encoding($false)

function Read-SmallTextFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    try {
        $stream = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
        try {
            $limit = [Math]::Min($stream.Length, 1048576)
            $buffer = New-Object byte[] $limit
            [void]$stream.Read($buffer, 0, $limit)
            return [Text.Encoding]::UTF8.GetString($buffer)
        }
        finally { $stream.Dispose() }
    }
    catch { return '' }
}

function Read-GradleProperties {
    param([string]$Path)
    $properties = @{}
    $text = Read-SmallTextFile -Path $Path
    foreach ($line in ($text -split "`r?`n")) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#') -or $trimmed.StartsWith('!')) { continue }
        if ($trimmed -match '^([^:=\s]+)\s*[:=]\s*(.*)$') {
            $properties[$matches[1].ToLowerInvariant()] = $matches[2].Trim()
        }
    }
    return $properties
}

function Get-PropertyValue {
    param(
        [hashtable]$Properties,
        [string[]]$Keys
    )
    foreach ($key in $Keys) {
        $lower = $key.ToLowerInvariant()
        if ($Properties.ContainsKey($lower)) {
            $value = [string]$Properties[$lower]
            if ($value -and $value -notmatch '^\$[{(]') { return $value.Trim('"', "'") }
        }
    }
    return ''
}

function Resolve-GradleText {
    param(
        [string]$Text,
        [hashtable]$Properties
    )
    $result = $Text
    for ($pass = 0; $pass -lt 3; $pass++) {
        foreach ($key in $Properties.Keys) {
            $value = [string]$Properties[$key]
            if (-not $value) { continue }
            $escapedKey = [Regex]::Escape([string]$key)
            $result = [Regex]::Replace($result, '\$\{' + $escapedKey + '\}', [Text.RegularExpressions.MatchEvaluator]{ param($m) $value }, 'IgnoreCase')
            $result = [Regex]::Replace($result, '\$' + $escapedKey + '\b', [Text.RegularExpressions.MatchEvaluator]{ param($m) $value }, 'IgnoreCase')
        }
    }
    return $result
}

function Get-JavaInfo {
    try {
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = 'java.exe'
        $psi.Arguments = '-version'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $process = New-Object Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(10000)) {
            try { $process.Kill() } catch { }
            return [pscustomobject]@{ Found = $false; Major = 0; Description = 'Java 检测超时' }
        }
        [void][Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 3000)
        $versionText = [string]$stdoutTask.Result + "`n" + [string]$stderrTask.Result
        $major = 0
        if ($versionText -match 'version\s+"1\.(\d+)') { $major = [int]$matches[1] }
        elseif ($versionText -match 'version\s+"(\d+)') { $major = [int]$matches[1] }
        elseif ($versionText -match 'openjdk\s+(\d+)') { $major = [int]$matches[1] }
        if ($major -gt 0) {
            return [pscustomobject]@{ Found = $true; Major = $major; Description = "Java $major" }
        }
        return [pscustomobject]@{ Found = $true; Major = 0; Description = 'Java 已找到（版本未知）' }
    }
    catch {
        return [pscustomobject]@{ Found = $false; Major = 0; Description = '未检测到 Java' }
    }
}

function Find-ProjectRoots {
    param([string[]]$Roots)
    $found = New-Object Collections.Generic.List[string]
    $seen = @{}
    $skipNames = @('.git', '.gradle', '.idea', '.vscode', 'build', 'out', 'run', 'runs', 'node_modules', 'logs', 'runtime')

    foreach ($rootEntry in $Roots) {
        if (-not $rootEntry) { continue }
        try { $root = [IO.Path]::GetFullPath($rootEntry) } catch { continue }
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }

        $queue = New-Object Collections.Generic.Queue[object]
        $queue.Enqueue([pscustomobject]@{ Path = $root; Depth = 0 })
        while ($queue.Count -gt 0) {
            $item = $queue.Dequeue()
            $path = [string]$item.Path
            $depth = [int]$item.Depth
            $key = $path.ToLowerInvariant()
            if ($seen.ContainsKey($key)) { continue }
            $seen[$key] = $true

            $hasWrapper = Test-Path -LiteralPath (Join-Path $path 'gradlew.bat') -PathType Leaf
            $hasBuild = (Test-Path -LiteralPath (Join-Path $path 'build.gradle') -PathType Leaf) -or
                        (Test-Path -LiteralPath (Join-Path $path 'build.gradle.kts') -PathType Leaf)
            $hasSettings = (Test-Path -LiteralPath (Join-Path $path 'settings.gradle') -PathType Leaf) -or
                           (Test-Path -LiteralPath (Join-Path $path 'settings.gradle.kts') -PathType Leaf)
            $hasProperties = Test-Path -LiteralPath (Join-Path $path 'gradle.properties') -PathType Leaf
            $isProject = ($hasWrapper -and ($hasBuild -or $hasSettings -or $hasProperties)) -or ($hasBuild -and $hasSettings)

            if ($isProject) {
                $found.Add($path)
                continue
            }
            if ($depth -ge 6) { continue }

            try {
                foreach ($directory in (Get-ChildItem -LiteralPath $path -Directory -Force -ErrorAction SilentlyContinue)) {
                    if ($skipNames -contains $directory.Name.ToLowerInvariant()) { continue }
                    if (($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                    $queue.Enqueue([pscustomobject]@{ Path = $directory.FullName; Depth = $depth + 1 })
                }
            }
            catch { }
        }
    }
    return @($found | Sort-Object -Unique)
}

function Get-ProjectMetadata {
    param(
        [string]$ProjectPath,
        [pscustomobject]$JavaInfo
    )

    $properties = Read-GradleProperties -Path (Join-Path $ProjectPath 'gradle.properties')
    $settingsText = (Read-SmallTextFile -Path (Join-Path $ProjectPath 'settings.gradle')) + "`n" +
                    (Read-SmallTextFile -Path (Join-Path $ProjectPath 'settings.gradle.kts'))
    $buildText = (Read-SmallTextFile -Path (Join-Path $ProjectPath 'build.gradle')) + "`n" +
                 (Read-SmallTextFile -Path (Join-Path $ProjectPath 'build.gradle.kts'))
    $catalogText = Read-SmallTextFile -Path (Join-Path $ProjectPath 'gradle\libs.versions.toml')
    $allText = Resolve-GradleText -Text ($settingsText + "`n" + $buildText + "`n" + $catalogText) -Properties $properties

    $projectName = Split-Path -Leaf $ProjectPath
    if ($settingsText -match '(?im)rootProject\.name\s*=\s*["'']([^"'']+)["'']') {
        $projectName = $matches[1]
    }
    elseif ($settingsText -match '(?im)rootProject\.name\s*=\s*providers\.gradleProperty\(["'']([^"'']+)["'']\)') {
        $nameProperty = Get-PropertyValue -Properties $properties -Keys @($matches[1])
        if ($nameProperty) { $projectName = $nameProperty }
    }

    $isNeoForge = $allText -match '(?i)net\.neoforged|neoforge|neo_version|neoforge_version'
    $isForge = $allText -match '(?i)net\.minecraftforge|net\.minecraftforge\.gradle|forge_version'
    $isFabric = $allText -match '(?i)fabric-loom|net\.fabricmc|fabric_loader|fabric-api'

    $environment = '未知'
    if ($isNeoForge) { $environment = 'NeoForge' }
    elseif ($isForge) { $environment = 'Forge' }
    elseif ($isFabric) { $environment = 'Fabric' }

    $minecraftVersion = Get-PropertyValue -Properties $properties -Keys @(
        'minecraft_version', 'mc_version', 'minecraftversion', 'minecraft.version', 'minecraft-version'
    )
    if (-not $minecraftVersion -and $allText -match '(?i)com\.mojang:minecraft:([0-9]+\.[0-9]+(?:\.[0-9]+)?(?:[-+._A-Za-z0-9]*)?)') {
        $minecraftVersion = $matches[1]
    }

    $loaderVersion = ''
    $fabricApiVersion = ''
    if ($environment -eq 'NeoForge') {
        $loaderVersion = Get-PropertyValue -Properties $properties -Keys @(
            'neoforge_version', 'neo_version', 'neoform_version', 'neoforge.version'
        )
        if (-not $loaderVersion -and $allText -match '(?i)net\.neoforged:neoforge:([A-Za-z0-9+_.-]+)') {
            $loaderVersion = $matches[1]
        }
    }
    elseif ($environment -eq 'Forge') {
        $loaderVersion = Get-PropertyValue -Properties $properties -Keys @('forge_version', 'forge.version')
        if ($allText -match '(?i)net\.minecraftforge:forge:([0-9][A-Za-z0-9+_.-]*)') {
            $forgeCoordinateVersion = $matches[1]
            if ($forgeCoordinateVersion -match '^([0-9]+\.[0-9]+(?:\.[0-9]+)?)-(.+)$') {
                if (-not $minecraftVersion) { $minecraftVersion = $matches[1] }
                if (-not $loaderVersion) { $loaderVersion = $matches[2] }
            }
            elseif (-not $loaderVersion) { $loaderVersion = $forgeCoordinateVersion }
        }
    }
    elseif ($environment -eq 'Fabric') {
        $loaderVersion = Get-PropertyValue -Properties $properties -Keys @(
            'loader_version', 'fabric_loader_version', 'fabric-loader-version', 'fabric_loader.version'
        )
        $fabricApiVersion = Get-PropertyValue -Properties $properties -Keys @(
            'fabric_version', 'fabric_api_version', 'fabric-api-version', 'fabric_api.version'
        )
        if (-not $loaderVersion -and $allText -match '(?i)net\.fabricmc:fabric-loader:([A-Za-z0-9+_.-]+)') {
            $loaderVersion = $matches[1]
        }
        if (-not $fabricApiVersion -and $allText -match '(?i)net\.fabricmc\.fabric-api:fabric-api:([A-Za-z0-9+_.-]+)') {
            $fabricApiVersion = $matches[1]
        }
    }

    if (-not $minecraftVersion) { $minecraftVersion = '未知' }
    if (-not $loaderVersion) { $loaderVersion = '未知' }
    $loaderDisplay = $loaderVersion
    if ($environment -eq 'Fabric') {
        $loaderDisplay = "Fabric Loader $loaderVersion"
        if ($fabricApiVersion) { $loaderDisplay += "；Fabric API $fabricApiVersion" }
    }

    $requiredJava = 0
    $javaProperty = Get-PropertyValue -Properties $properties -Keys @(
        'java_version', 'java.version', 'jvm_version', 'target_java_version'
    )
    if ($javaProperty -match '^(\d+)$') { $requiredJava = [int]$matches[1] }
    elseif ($allText -match '(?i)JavaLanguageVersion\.of\s*\(\s*(\d+)\s*\)') { $requiredJava = [int]$matches[1] }
    elseif ($allText -match '(?i)JavaVersion\.VERSION_(\d+)') { $requiredJava = [int]$matches[1] }

    if (-not $JavaInfo.Found) {
        $javaStatus = '未检测到 Java'
    }
    elseif ($JavaInfo.Major -le 0) {
        $javaStatus = $JavaInfo.Description
    }
    elseif ($requiredJava -gt 0 -and $JavaInfo.Major -lt $requiredJava) {
        $javaStatus = "Java $($JavaInfo.Major)（项目需 $requiredJava）"
    }
    elseif ($requiredJava -gt 0) {
        $javaStatus = "Java $($JavaInfo.Major)（符合 ≥$requiredJava）"
    }
    else {
        $javaStatus = "Java $($JavaInfo.Major)（项目要求未知）"
    }

    $wrapperPath = Join-Path $ProjectPath 'gradlew.bat'
    return [ordered]@{
        Name = $projectName
        Path = $ProjectPath
        MinecraftVersion = $minecraftVersion
        Environment = $environment
        LoaderVersion = $loaderDisplay
        RawLoaderVersion = $loaderVersion
        FabricApiVersion = $(if ($fabricApiVersion) { $fabricApiVersion } else { '' })
        JavaStatus = $javaStatus
        JavaFound = [bool]$JavaInfo.Found
        InstalledJavaMajor = [int]$JavaInfo.Major
        RequiredJava = $requiredJava
        WrapperPath = $wrapperPath
        HasWrapper = [bool](Test-Path -LiteralPath $wrapperPath -PathType Leaf)
        Tasks = @()
        LaunchTask = ''
        HasBuildTask = $false
        HasCleanTask = $false
        Status = '等待任务检测'
        StatusCode = 'waiting'
        TaskDetectionError = ''
    }
}

function Get-GradleTasks {
    param([System.Collections.IDictionary]$Project)
    if (-not $Project.HasWrapper) {
        $Project.Status = '缺少 gradlew.bat，无法启动'
        $Project.StatusCode = 'missingWrapper'
        $Project.TaskDetectionError = '项目没有 Windows Gradle Wrapper。'
        return
    }

    $process = $null
    try {
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = $env:ComSpec
        $psi.Arguments = '/d /s /c "call gradlew.bat tasks --all --console=plain --no-daemon"'
        $psi.WorkingDirectory = [string]$Project.Path
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $process = New-Object Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(120000)) {
            try {
                & taskkill.exe /PID $process.Id /T /F | Out-Null
            }
            catch {
                try { $process.Kill() } catch { }
            }
            $Project.Status = '任务检测超时'
            $Project.StatusCode = 'taskTimeout'
            $Project.TaskDetectionError = 'gradlew.bat tasks --all 在 120 秒内未完成。'
            return
        }
        [void][Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 5000)
        $stdout = [string]$stdoutTask.Result
        $stderr = [string]$stderrTask.Result
        $combined = $stdout + "`n" + $stderr

        $taskNames = New-Object Collections.Generic.List[string]
        foreach ($match in [Regex]::Matches($combined, '(?m)^\s*((?::?[A-Za-z0-9_.-]+:)*[A-Za-z0-9_.-]+)\s+-\s+')) {
            $name = $match.Groups[1].Value.Trim()
            if ($name -and -not $taskNames.Contains($name)) { $taskNames.Add($name) }
        }
        foreach ($match in [Regex]::Matches($combined, '(?im)^\s*((?::?[A-Za-z0-9_.-]+:)*(?:runClient|runMinecraftClient|runGameTestClient|build|clean|tasks))\s*$')) {
            $name = $match.Groups[1].Value.Trim()
            if ($name -and -not $taskNames.Contains($name)) { $taskNames.Add($name) }
        }
        $Project.Tasks = @($taskNames | ForEach-Object { $_ })

        $launchPriority = @('runClient', 'runMinecraftClient', 'runGameTestClient')
        foreach ($candidate in $launchPriority) {
            $exact = @($taskNames | Where-Object { $_ -eq $candidate }) | Select-Object -First 1
            if ($exact) { $Project.LaunchTask = [string]$exact; break }
            $qualified = @($taskNames | Where-Object { $_ -match (('(:|^)' + [Regex]::Escape($candidate) + '$')) }) | Select-Object -First 1
            if ($qualified) { $Project.LaunchTask = [string]$qualified; break }
        }
        $Project.HasBuildTask = [bool](@($taskNames | Where-Object { $_ -eq 'build' -or $_ -match ':build$' }).Count -gt 0)
        $Project.HasCleanTask = [bool](@($taskNames | Where-Object { $_ -eq 'clean' -or $_ -match ':clean$' }).Count -gt 0)

        if ($process.ExitCode -ne 0) {
            $shortError = ($stderr -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 3) -join ' '
            if (-not $shortError) { $shortError = "Gradle 返回退出代码 $($process.ExitCode)。" }
            $Project.TaskDetectionError = $shortError
        }

        if ($Project.LaunchTask) {
            if ($Project.Environment -eq '未知') { $Project.Status = "可启动（环境未知，任务：$($Project.LaunchTask)）"; $Project.StatusCode='unknownLaunchable' }
            else { $Project.Status = "可启动（$($Project.LaunchTask)）"; $Project.StatusCode='launchable' }
        }
        elseif ($process.ExitCode -ne 0) {
            $Project.Status = '任务检测失败，未找到客户端任务'
            $Project.StatusCode = 'taskFailed'
        }
        else {
            $Project.Status = '未找到可启动的客户端任务'
            $Project.StatusCode = 'noClientTask'
        }
    }
    catch {
        $Project.Status = '任务检测失败，未找到客户端任务'
        $Project.StatusCode = 'taskFailed'
        $Project.TaskDetectionError = $_.Exception.Message
    }
    finally {
        if ($null -ne $process) { $process.Dispose() }
    }
}

try {
    $request = ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $RequestFile))) | ConvertFrom-Json
    $roots = @($request.scanFolders)
    $javaInfo = Get-JavaInfo
    $projectPaths = Find-ProjectRoots -Roots $roots
    $projects = New-Object Collections.Generic.List[object]
    foreach ($path in $projectPaths) {
        $project = Get-ProjectMetadata -ProjectPath $path -JavaInfo $javaInfo
        Get-GradleTasks -Project $project
        $projects.Add([pscustomobject]$project)
    }

    $result = [ordered]@{
        success = $true
        scannedAt = [DateTime]::Now.ToString('o')
        java = $javaInfo
        projects = @($projects | ForEach-Object { $_ })
        error = ''
    }
    [IO.File]::WriteAllText($ResultFile, ($result | ConvertTo-Json -Depth 12), $script:Utf8)
}
catch {
    $result = [ordered]@{
        success = $false
        scannedAt = [DateTime]::Now.ToString('o')
        java = $null
        projects = @()
        error = $_.Exception.Message
    }
    [IO.File]::WriteAllText($ResultFile, ($result | ConvertTo-Json -Depth 8), $script:Utf8)
    exit 1
}
