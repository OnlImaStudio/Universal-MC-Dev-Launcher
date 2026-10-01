param(
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

if (-not ('ModernFolderPicker' -as [type])) {
Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

[Flags]
public enum FOS : uint {
    FOS_PICKFOLDERS = 0x00000020,
    FOS_FORCEFILESYSTEM = 0x00000040,
    FOS_PATHMUSTEXIST = 0x00000800,
    FOS_FILEMUSTEXIST = 0x00001000,
    FOS_DONTADDTORECENT = 0x02000000
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct COMDLG_FILTERSPEC {
    [MarshalAs(UnmanagedType.LPWStr)] public string pszName;
    [MarshalAs(UnmanagedType.LPWStr)] public string pszSpec;
    public COMDLG_FILTERSPEC(string name, string spec) { pszName = name; pszSpec = spec; }
}

public enum SIGDN : uint { FILESYSPATH = 0x80058000 }

[ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IShellItem {
    void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
    void GetParent(out IShellItem ppsi);
    void GetDisplayName(SIGDN sigdnName, out IntPtr ppszName);
    void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
    void Compare(IShellItem psi, uint hint, out int piOrder);
}

[ComImport, Guid("42F85136-DB7E-439C-85F1-E4075D135FC8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IFileOpenDialog {
    [PreserveSig] int Show(IntPtr parent);
    void SetFileTypes(uint cFileTypes, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 0)] COMDLG_FILTERSPEC[] rgFilterSpec);
    void SetFileTypeIndex(uint iFileType);
    void GetFileTypeIndex(out uint piFileType);
    void Advise(IntPtr pfde, out uint pdwCookie);
    void Unadvise(uint dwCookie);
    void SetOptions(FOS fos);
    void GetOptions(out FOS pfos);
    void SetDefaultFolder(IShellItem psi);
    void SetFolder(IShellItem psi);
    void GetFolder(out IShellItem ppsi);
    void GetCurrentSelection(out IShellItem ppsi);
    void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string pszName);
    void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string pszName);
    void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
    void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
    void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
    void GetResult(out IShellItem ppsi);
    void AddPlace(IShellItem psi, int fdap);
    void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
    void Close(int hr);
    void SetClientGuid(ref Guid guid);
    void ClearClientData();
    void SetFilter(IntPtr pFilter);
    void GetResults(out IntPtr ppenum);
    void GetSelectedItems(out IntPtr ppsai);
}

[ComImport, Guid("DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7")]
public class FileOpenDialogClass { }

public static class ModernFolderPicker {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool EnumWindows(EnumWindowsProc callback, IntPtr extraData);
    delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr extraData);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int maxCount);
    [DllImport("user32.dll")]
    static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    const uint WM_CLOSE = 0x0010;

    public static string PickFolder(IntPtr owner, string title) {
        IFileOpenDialog dialog = (IFileOpenDialog)new FileOpenDialogClass();
        try {
            FOS options;
            dialog.GetOptions(out options);
            dialog.SetOptions(options | FOS.FOS_PICKFOLDERS | FOS.FOS_FORCEFILESYSTEM |
                              FOS.FOS_PATHMUSTEXIST | FOS.FOS_DONTADDTORECENT);
            dialog.SetTitle(title);
            dialog.SetOkButtonLabel("选择此文件夹");
            int result = dialog.Show(owner);
            if (result != 0) return null;
            IShellItem item;
            dialog.GetResult(out item);
            IntPtr value;
            item.GetDisplayName(SIGDN.FILESYSPATH, out value);
            try { return Marshal.PtrToStringUni(value); }
            finally { Marshal.FreeCoTaskMem(value); Marshal.ReleaseComObject(item); }
        }
        finally { Marshal.ReleaseComObject(dialog); }
    }

    public static string PickImage(IntPtr owner, string title) {
        IFileOpenDialog dialog = (IFileOpenDialog)new FileOpenDialogClass();
        try {
            FOS options;
            dialog.GetOptions(out options);
            dialog.SetOptions(options | FOS.FOS_FORCEFILESYSTEM | FOS.FOS_PATHMUSTEXIST |
                              FOS.FOS_FILEMUSTEXIST | FOS.FOS_DONTADDTORECENT);
            COMDLG_FILTERSPEC[] filters = new COMDLG_FILTERSPEC[] {
                new COMDLG_FILTERSPEC("Image files", "*.png;*.jpg;*.jpeg;*.bmp"),
                new COMDLG_FILTERSPEC("PNG", "*.png"),
                new COMDLG_FILTERSPEC("JPEG", "*.jpg;*.jpeg"),
                new COMDLG_FILTERSPEC("Bitmap", "*.bmp")
            };
            dialog.SetFileTypes((uint)filters.Length, filters);
            dialog.SetFileTypeIndex(1);
            dialog.SetTitle(title);
            int result = dialog.Show(owner);
            if (result != 0) return null;
            IShellItem item;
            dialog.GetResult(out item);
            IntPtr value;
            item.GetDisplayName(SIGDN.FILESYSPATH, out value);
            try { return Marshal.PtrToStringUni(value); }
            finally { Marshal.FreeCoTaskMem(value); Marshal.ReleaseComObject(item); }
        }
        finally { Marshal.ReleaseComObject(dialog); }
    }

    public static void ScheduleDialogClose(string title, int milliseconds) {
        new Thread(() => {
            Thread.Sleep(milliseconds);
            EnumWindows((hwnd, state) => {
                StringBuilder text = new StringBuilder(512);
                GetWindowText(hwnd, text, text.Capacity);
                if (text.ToString() == title) {
                    PostMessage(hwnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                    return false;
                }
                return true;
            }, IntPtr.Zero);
        }) { IsBackground = true }.Start();
    }
}

public static class DpiProbe {
    [DllImport("user32.dll")]
    public static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")]
    static extern IntPtr GetThreadDpiAwarenessContext();
    [DllImport("user32.dll")]
    static extern int GetAwarenessFromDpiAwarenessContext(IntPtr value);
    [DllImport("user32.dll")]
    static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    public static bool Enable() {
        try { return SetProcessDpiAwarenessContext(new IntPtr(-4)); }
        catch { return false; }
    }
    public static int CurrentAwareness() {
        try { return GetAwarenessFromDpiAwarenessContext(GetThreadDpiAwarenessContext()); }
        catch { return -1; }
    }
}
'@
}

[void][DpiProbe]::Enable()

$script:ToolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ConfigPath = Join-Path $script:ToolRoot 'config.json'
$script:ScannerPath = Join-Path $script:ToolRoot 'ProjectScanner.ps1'
$script:RunnerPath = Join-Path $script:ToolRoot 'GradleRunner.ps1'
$script:LanguagePath = Join-Path $script:ToolRoot 'languages.json'
$script:LogsPath = Join-Path $script:ToolRoot 'logs'
$script:RuntimePath = Join-Path $script:ToolRoot 'runtime'
[IO.Directory]::CreateDirectory($script:LogsPath) | Out-Null
[IO.Directory]::CreateDirectory($script:RuntimePath) | Out-Null
$script:Utf8 = New-Object Text.UTF8Encoding($false)
$script:ScanFolders = New-Object Collections.ObjectModel.ObservableCollection[string]
$script:Projects = New-Object Collections.ObjectModel.ObservableCollection[object]
$script:ScanProcess = $null
$script:ScanResultFile = ''
$script:RunnerProcess = $null
$script:CurrentSession = $null
$script:AutoClosing = $false
$script:LaunchSuccessHandled = $false
$script:FolderRemovalMode = $false
$script:AppVersion = 'V1.0'
$script:ScanMode = 'full'
$script:ScanRequestFolders = @()
$script:ScanStartCount = 0
$script:UpdatingVisualSettings = $false

function ConvertFrom-Xaml {
    param([string]$Xaml)
    $reader = New-Object Xml.XmlNodeReader([xml]$Xaml)
    return [Windows.Markup.XamlReader]::Load($reader)
}

$mainXaml = [IO.File]::ReadAllText((Join-Path $script:ToolRoot 'MainWindow.xaml'))

$script:MainWindow = ConvertFrom-Xaml $mainXaml
$names = @('TitleText','LogButton','SettingsButton','ContentHost','HomePage','SettingsPage',
           'AddFolderButton','ManageFoldersButton','ScanButton','FolderSummary','FolderRemovalPanel','FolderRemovalHint','FolderList','ProjectGrid','DetailsTitle',
           'DetailMinecraft','DetailEnvironment','DetailLoader','DetailJava','DetailStatus','LaunchButton','BuildButton',
           'CleanBuildButton','TasksButton','StatusText',
           'AutoCloseLabel','AutoCloseHint','AutoCloseToggle','RememberLabel','RememberHint','RememberToggle',
           'AutoCheckLabel','AutoCheckHint','AutoCheckToggle','AutoScanNewLabel','AutoScanNewHint','AutoScanNewToggle','ThemeTitle','DarkThemeButton','LightThemeButton',
           'AccentTitle','AccentPanel','LanguageTitle','LanguagePanel','BackgroundFrame','BackgroundImage','BackgroundOverlay',
           'BackgroundTitle','BackgroundHint','ChooseBackgroundButton','ClearBackgroundButton','BackgroundPathText',
           'VisualDebugTitle','BlurLabel','BlurValueText','BlurSlider','UiOpacityLabel','UiOpacityValueText','UiOpacitySlider','ContactText',
           'LogPage','LogPageTitle','LogPageSubtitle','LogHeader','LogStatus','LogExplanation','LogStdoutLabel','LogStderrLabel',
           'LogStdout','LogStderr','ClearLogButton','CopyLogButton','StopTaskButton')
foreach ($name in $names) { Set-Variable -Scope Script -Name $name -Value $script:MainWindow.FindName($name) }
$script:ProjectGrid.ItemsSource = $script:Projects
$script:FolderList.ItemsSource = $script:ScanFolders
$script:Languages = [IO.File]::ReadAllText($script:LanguagePath,[Text.Encoding]::UTF8) | ConvertFrom-Json
$script:CurrentPage = 'home'
$script:UpdatingSettings = $false
$script:UpdatingColumns = $false
$script:AccentButtons = @{}
$script:LanguageButtons = @{}

function Get-DefaultConfig {
    [pscustomobject]@{
        schemaVersion = 6; appVersion = $script:AppVersion; autoCloseAfterMinecraftStarts = $false; rememberScanFolders = $true
        autoCheckEnvironmentBeforeLaunch = $true; autoScanNewFolder = $true; theme = 'dark'; accentColor = 'red'; language = 'zh-CN'
        backgroundImage = ''; backgroundZoomBasis = 'fit'; backgroundZoom = 1.0; backgroundOffsetX = 0.0; backgroundOffsetY = 0.0; backgroundBlur = 0; uiOpacity = 0.92; scanFolders = @()
        windowPlacement = $null
        projectColumns = @(
            [pscustomobject]@{id='Name';displayIndex=0;width=160},[pscustomobject]@{id='MinecraftDisplay';displayIndex=1;width=100},
            [pscustomobject]@{id='EnvironmentDisplay';displayIndex=2;width=110},[pscustomobject]@{id='LoaderDisplay';displayIndex=3;width=190},
            [pscustomobject]@{id='JavaDisplay';displayIndex=4;width=150},[pscustomobject]@{id='StatusDisplay';displayIndex=5;width=190}
        )
    }
}

function Load-Config {
    $config = Get-DefaultConfig
    try {
        if (Test-Path -LiteralPath $script:ConfigPath) {
            $loaded = [IO.File]::ReadAllText($script:ConfigPath) | ConvertFrom-Json
            foreach ($key in @('autoCloseAfterMinecraftStarts','rememberScanFolders','autoCheckEnvironmentBeforeLaunch','autoScanNewFolder','theme','accentColor','language','backgroundImage','backgroundZoom','backgroundOffsetX','backgroundOffsetY','backgroundBlur','uiOpacity')) {
                if ($loaded.PSObject.Properties[$key] -and $null -ne $loaded.$key) { $config.$key = $loaded.$key }
            }
            if (-not $loaded.PSObject.Properties['backgroundZoomBasis'] -or $loaded.backgroundZoomBasis -ne 'fit') { $config.backgroundZoom=1.0;$config.backgroundOffsetX=0.0;$config.backgroundOffsetY=0.0 }
            if ($loaded.rememberScanFolders) { $config.scanFolders = @($loaded.scanFolders) }
            if ($loaded.PSObject.Properties['projectColumns'] -and @($loaded.projectColumns).Count -eq 6) { $config.projectColumns = @($loaded.projectColumns) }
            if ($loaded.PSObject.Properties['windowPlacement'] -and $null -ne $loaded.windowPlacement) { $config.windowPlacement = $loaded.windowPlacement }
        }
    } catch { }
    if ($config.theme -notin @('dark','light')) {
        try { $config.theme = if ([int](Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize').AppsUseLightTheme -eq 0) {'dark'} else {'light'} } catch { $config.theme='dark' }
    }
    $legacyAccents=@{'#E53935'='red';'#F9A825'='yellow';'#2BCB70'='green';'#00A6C8'='aqua';'#38BDF8'='aqua';'#2979FF'='blue';'#7C4DFF'='purple';'#EC4899'='pink';''='gray'}
    if ([string]$config.accentColor -match '^#') { $config.accentColor = if($legacyAccents.ContainsKey(([string]$config.accentColor).ToUpperInvariant())){$legacyAccents[([string]$config.accentColor).ToUpperInvariant()]}else{'gray'} }
    if ($config.accentColor -eq 'none') {$config.accentColor='gray'}
    if ($config.accentColor -notin @('gray','red','yellow','green','aqua','blue','purple','pink')) { $config.accentColor='gray' }
    if ($config.language -notin @('en-US','es-ES','ja-JP','ko-KR','zh-TW','zh-CN')) { $config.language='zh-CN' }
    $config.backgroundBlur=[Math]::Max(0,[Math]::Min(30,[double]$config.backgroundBlur))
    $config.backgroundZoom=[Math]::Max(1.0,[Math]::Min(5.0,[double]$config.backgroundZoom))
    foreach($key in @('backgroundOffsetX','backgroundOffsetY')) { if([double]::IsNaN([double]$config.$key) -or [double]::IsInfinity([double]$config.$key)) { $config.$key=0.0 } }
    $config.uiOpacity=[Math]::Max(0.0,[Math]::Min(1.0,[double]$config.uiOpacity))
    return $config
}

$script:Config = Load-Config
foreach ($folder in @($script:Config.scanFolders)) {
    if ($folder -and -not $script:ScanFolders.Contains([string]$folder)) { $script:ScanFolders.Add([string]$folder) }
}

function Save-Config {
    if($script:ProjectGrid -and -not $script:UpdatingColumns){Update-ConfigColumnLayout}
    $folders = New-Object Collections.ArrayList
    if ([bool]$script:Config.rememberScanFolders) {
        foreach ($folder in $script:ScanFolders) { [void]$folders.Add([string]$folder) }
    }
    $data = [ordered]@{
        schemaVersion = 6
        appVersion = $script:AppVersion
        autoCloseAfterMinecraftStarts = [bool]$script:Config.autoCloseAfterMinecraftStarts
        rememberScanFolders = [bool]$script:Config.rememberScanFolders
        autoCheckEnvironmentBeforeLaunch = [bool]$script:Config.autoCheckEnvironmentBeforeLaunch
        autoScanNewFolder = [bool]$script:Config.autoScanNewFolder
        theme = [string]$script:Config.theme
        accentColor = [string]$script:Config.accentColor
        language = [string]$script:Config.language
        backgroundImage = [string]$script:Config.backgroundImage
        backgroundZoomBasis = 'fit'
        backgroundZoom = [double]$script:Config.backgroundZoom
        backgroundOffsetX = [double]$script:Config.backgroundOffsetX
        backgroundOffsetY = [double]$script:Config.backgroundOffsetY
        backgroundBlur = [double]$script:Config.backgroundBlur
        uiOpacity = [double]$script:Config.uiOpacity
        windowPlacement = $script:Config.windowPlacement
        projectColumns = @($script:Config.projectColumns)
        scanFolders = $folders
    }
    [IO.File]::WriteAllText($script:ConfigPath, ($data | ConvertTo-Json -Depth 5), $script:Utf8)
}

function Test-UsableWindowPlacement($placement) {
    if ($null -eq $placement) { return $false }
    try {
        $left=[double]$placement.left;$top=[double]$placement.top;$width=[double]$placement.width;$height=[double]$placement.height
        foreach($value in @($left,$top,$width,$height)){if([double]::IsNaN($value) -or [double]::IsInfinity($value)){return $false}}
        if($width -lt $script:MainWindow.MinWidth -or $height -lt $script:MainWindow.MinHeight){return $false}
        $right=$left+$width;$bottom=$top+$height
        $visibleWidth=[Math]::Max(0,[Math]::Min($right,[Windows.SystemParameters]::VirtualScreenLeft+[Windows.SystemParameters]::VirtualScreenWidth)-[Math]::Max($left,[Windows.SystemParameters]::VirtualScreenLeft))
        $visibleHeight=[Math]::Max(0,[Math]::Min($bottom,[Windows.SystemParameters]::VirtualScreenTop+[Windows.SystemParameters]::VirtualScreenHeight)-[Math]::Max($top,[Windows.SystemParameters]::VirtualScreenTop))
        return ($visibleWidth -ge 96 -and $visibleHeight -ge 72)
    } catch { return $false }
}

function Apply-SavedWindowPlacement {
    $placement=$script:Config.windowPlacement
    if(-not (Test-UsableWindowPlacement $placement)){return}
    $virtualLeft=[double][Windows.SystemParameters]::VirtualScreenLeft;$virtualTop=[double][Windows.SystemParameters]::VirtualScreenTop
    $virtualWidth=[double][Windows.SystemParameters]::VirtualScreenWidth;$virtualHeight=[double][Windows.SystemParameters]::VirtualScreenHeight
    $width=[Math]::Min([double]$placement.width,$virtualWidth);$height=[Math]::Min([double]$placement.height,$virtualHeight)
    $left=[Math]::Max($virtualLeft,[Math]::Min([double]$placement.left,$virtualLeft+$virtualWidth-$width))
    $top=[Math]::Max($virtualTop,[Math]::Min([double]$placement.top,$virtualTop+$virtualHeight-$height))
    $script:MainWindow.WindowStartupLocation=[Windows.WindowStartupLocation]::Manual
    $script:MainWindow.Width=$width;$script:MainWindow.Height=$height
    $script:MainWindow.Left=$left;$script:MainWindow.Top=$top
    if([bool]$placement.maximized){$script:MainWindow.WindowState=[Windows.WindowState]::Maximized}
}

function Save-WindowPlacement {
    $bounds=if($script:MainWindow.WindowState -eq [Windows.WindowState]::Normal){
        [Windows.Rect]::new($script:MainWindow.Left,$script:MainWindow.Top,$script:MainWindow.Width,$script:MainWindow.Height)
    }else{$script:MainWindow.RestoreBounds}
    if($bounds.Width -ge $script:MainWindow.MinWidth -and $bounds.Height -ge $script:MainWindow.MinHeight){
        $script:Config.windowPlacement=[pscustomobject]@{
            left=[Math]::Round($bounds.Left,1);top=[Math]::Round($bounds.Top,1)
            width=[Math]::Round($bounds.Width,1);height=[Math]::Round($bounds.Height,1)
            maximized=($script:MainWindow.WindowState -eq [Windows.WindowState]::Maximized)
        }
    }
}

function Update-ConfigColumnLayout {
    if(-not $script:ProjectGrid){return}
    $layout=New-Object Collections.Generic.List[object]
    foreach($column in $script:ProjectGrid.Columns){
        $width=if($column.ActualWidth -gt 0){[Math]::Round([double]$column.ActualWidth,1)}else{[Math]::Round([double]$column.Width.Value,1)}
        $layout.Add([pscustomobject]@{id=[string]$column.SortMemberPath;displayIndex=[int]$column.DisplayIndex;width=$width})
    }
    $script:Config.projectColumns=@($layout | ForEach-Object { $_ })
}

function Apply-ColumnLayout {
    $script:UpdatingColumns=$true
    try{
        $saved=@($script:Config.projectColumns)
        foreach($entry in $saved){
            $column=@($script:ProjectGrid.Columns|Where-Object{$_.SortMemberPath -eq [string]$entry.id})|Select-Object -First 1
            if($column){
                $width=[Math]::Max([double]$column.MinWidth,[Math]::Min(900,[double]$entry.width))
                $column.Width=[Windows.Controls.DataGridLength]::new($width,[Windows.Controls.DataGridLengthUnitType]::Pixel)
            }
        }
        foreach($entry in ($saved|Sort-Object {[int]$_.displayIndex})){
            $column=@($script:ProjectGrid.Columns|Where-Object{$_.SortMemberPath -eq [string]$entry.id})|Select-Object -First 1
            if($column){$column.DisplayIndex=[Math]::Max(0,[Math]::Min($script:ProjectGrid.Columns.Count-1,[int]$entry.displayIndex))}
        }
    }finally{$script:UpdatingColumns=$false}
}

function Initialize-ColumnPersistence {
    Apply-ColumnLayout
    $script:ColumnWidthChangedHandler=[EventHandler]{if(-not $script:UpdatingColumns){Update-ConfigColumnLayout;Save-Config}}
    $descriptor=[ComponentModel.DependencyPropertyDescriptor]::FromProperty([Windows.Controls.DataGridColumn]::WidthProperty,[Windows.Controls.DataGridColumn])
    foreach($column in $script:ProjectGrid.Columns){$descriptor.AddValueChanged($column,$script:ColumnWidthChangedHandler)}
}

function Get-IsDarkTheme {
    return ($script:Config.theme -eq 'dark')
}

function New-Brush([string]$Color,[double]$Opacity=1.0) {
    $source = [Windows.Media.ColorConverter]::ConvertFromString($Color)
    $clamped = [Math]::Max([double]0.0,[Math]::Min([double]1.0,[double]$Opacity))
    $alpha = [byte][Math]::Round($clamped*255)
    $brush = New-Object Windows.Media.SolidColorBrush
    ($brush.Color = [Windows.Media.Color]::FromArgb($alpha,$source.R,$source.G,$source.B)) | Out-Null
    return ,$brush
}

function Set-ResourceBrush($Resources,[string]$Key,[string]$Color,[double]$Opacity=1.0) {
    $source = [Windows.Media.ColorConverter]::ConvertFromString($Color)
    $clamped = [Math]::Max([double]0.0,[Math]::Min([double]1.0,[double]$Opacity))
    $alpha = [byte][Math]::Round($clamped*255)
    $brush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb($alpha,$source.R,$source.G,$source.B))
    $Resources.Remove($Key)
    $Resources.Add($Key,$brush)
}

function Apply-Theme {
    $dark = Get-IsDarkTheme
    if ($dark) {
        $palette = @('#0F1214','#1D2226','#171B1E','#252B30','#F4F6F8','#AAB2BA','#4A525B')
    } else {
        $palette = @('#F1F5F7','#FFFFFF','#FFFFFF','#EDF3F6','#172126','#64727B','#C8D4DA')
    }
    $accentMap=@{gray='#7D858E';red='#EF3B3A';yellow='#F6B914';green='#24C66B';aqua='#32BFD8';blue='#168FCE';purple='#8657E9';pink='#E94A93'}
    $accent=[string]$accentMap[[string]$script:Config.accentColor]
    if(-not $accent){$accent=[string]$accentMap.gray}
    $softMap=@{gray=if($dark){'#4B535A'}else{'#B9C2C7'};red='#EF3B3A';yellow='#F6B914';green='#24C66B';aqua='#32BFD8';blue='#168FCE';purple='#8657E9';pink='#E94A93'}
    $accentSoft=[string]$softMap[[string]$script:Config.accentColor]
    $resources = $script:MainWindow.Resources
    $backgroundPath=[string]$script:Config.backgroundImage
    $hasBackground=[bool]($backgroundPath -and (Test-Path -LiteralPath $backgroundPath -PathType Leaf))
    $opacity=if($hasBackground){[double]$script:Config.uiOpacity}else{1.0}
    $themeColors=[ordered]@{
        WindowBrush=@($palette[0],1.0);WindowOverlayBrush=@($palette[0],$(if($dark){0.40}else{0.26}));HeaderBrush=@($palette[1],$opacity);
        SurfaceBrush=@($palette[2],$opacity);SurfaceAltBrush=@($palette[3],$opacity);SurfaceHoverBrush=@($palette[3],$opacity);
        TextBrush=@($palette[4],1.0);MutedBrush=@($palette[5],1.0);BorderBrush=@($palette[6],0.72);AccentBrush=@($accent,1.0);AccentSoftBrush=@($accentSoft,$(if($dark){0.34}else{0.22}))
    }
    foreach($key in $themeColors.Keys){
        $entry=$themeColors[$key]
        Set-ResourceBrush -Resources $resources -Key $key -Color ([string]$entry[0]) -Opacity ([double]$entry[1])
    }
    Update-SettingsSelectionVisuals
}

function New-BitmapSource([string]$Path) {
    $bitmap=New-Object Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit();$bitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$bitmap.UriSource=New-Object Uri([IO.Path]::GetFullPath($Path));$bitmap.EndInit();$bitmap.Freeze()
    return $bitmap
}

function Update-BackgroundView {
    $source=$script:BackgroundImage.Source
    if(-not $source){return}
    $width=[double]$script:BackgroundFrame.ActualWidth;$height=[double]$script:BackgroundFrame.ActualHeight
    if($width -le 0 -or $height -le 0 -or $source.PixelWidth -le 0 -or $source.PixelHeight -le 0){return}
    $fit=[Math]::Min($width/[double]$source.PixelWidth,$height/[double]$source.PixelHeight)
    $zoom=[Math]::Max(1.0,[Math]::Min(5.0,[double]$script:Config.backgroundZoom))
    $imageWidth=[double]$source.PixelWidth*$fit*$zoom;$imageHeight=[double]$source.PixelHeight*$fit*$zoom
    $maxX=[Math]::Max(0,($imageWidth-$width)/2);$maxY=[Math]::Max(0,($imageHeight-$height)/2)
    $script:Config.backgroundOffsetX=[Math]::Max(-$maxX,[Math]::Min($maxX,[double]$script:Config.backgroundOffsetX))
    $script:Config.backgroundOffsetY=[Math]::Max(-$maxY,[Math]::Min($maxY,[double]$script:Config.backgroundOffsetY))
    $script:BackgroundImage.Width=$imageWidth;$script:BackgroundImage.Height=$imageHeight
    [Windows.Controls.Canvas]::SetLeft($script:BackgroundImage,($width-$imageWidth)/2+[double]$script:Config.backgroundOffsetX)
    [Windows.Controls.Canvas]::SetTop($script:BackgroundImage,($height-$imageHeight)/2+[double]$script:Config.backgroundOffsetY)
}

function Reset-BackgroundView {
    $script:Config.backgroundZoom=1.0;$script:Config.backgroundOffsetX=0.0;$script:Config.backgroundOffsetY=0.0
}

function Apply-Logo {
    $exePath=Join-Path $script:ToolRoot 'UMDL.exe'
    if(-not(Test-Path -LiteralPath $exePath -PathType Leaf)){return}
    $icon=$null
    try{
        Add-Type -AssemblyName System.Drawing
        $icon=[Drawing.Icon]::ExtractAssociatedIcon($exePath)
        if($icon){$source=[Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($icon.Handle,[Windows.Int32Rect]::Empty,[Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions());$source.Freeze();$script:MainWindow.Icon=$source}
    }catch{}finally{if($icon){$icon.Dispose()}}
}

function Apply-Background {
    $path=[string]$script:Config.backgroundImage
    $valid=$false
    if($path -and (Test-Path -LiteralPath $path -PathType Leaf)){
        try{$script:BackgroundImage.Source=New-BitmapSource $path;$valid=$true}catch{$valid=$false}
    }
    if(-not $valid){
        $script:BackgroundImage.Source=$null
        if($path){$script:Config.backgroundImage='';Reset-BackgroundView;Save-Config}
    }
    Update-BackgroundView
    $effect=New-Object Windows.Media.Effects.BlurEffect;$effect.Radius=[double]$script:Config.backgroundBlur;$effect.KernelType=[Windows.Media.Effects.KernelType]::Gaussian
    $script:BackgroundImage.Effect=$effect
    if($script:BackgroundPathText){$script:BackgroundPathText.Text=if($valid){$path}else{Get-Loc 'backgroundDefault'}}
    if($script:BlurValueText){$script:BlurValueText.Text=('{0:0} px' -f [double]$script:Config.backgroundBlur)}
    if($script:UiOpacityValueText){$script:UiOpacityValueText.Text=('{0:0}%' -f ([double]$script:Config.uiOpacity*100))}
    Apply-Theme
}

function Choose-BackgroundImage {
    $path=''
    $helper=New-Object Windows.Interop.WindowInteropHelper($script:MainWindow);$path=[ModernFolderPicker]::PickImage($helper.Handle,(Get-Loc 'backgroundPickerTitle'))
    if(-not $path){return}
    Set-BackgroundImage $path
}

function Set-BackgroundImage([string]$Path) {
    if(-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
    try{[void](New-BitmapSource $Path);$script:Config.backgroundImage=[IO.Path]::GetFullPath($Path);Reset-BackgroundView;Save-Config;Apply-Background;return $true}
    catch{$script:StatusText.Text=Format-Loc 'backgroundInvalid' @($_.Exception.Message)}
    return $false
}

function Clear-BackgroundImage {
    $script:Config.backgroundImage='';Reset-BackgroundView;Save-Config;Apply-Background
}

function Get-Loc([string]$Key) {
    $set=$script:Languages.PSObject.Properties[[string]$script:Config.language].Value
    $prop=$set.PSObject.Properties[$Key]
    if($prop){return [string]$prop.Value}
    $fallback=$script:Languages.PSObject.Properties['zh-CN'].Value.PSObject.Properties[$Key]
    if($fallback){return [string]$fallback.Value}
    return $Key
}

function Format-Loc([string]$Key,[object[]]$Values) { return [string]::Format((Get-Loc $Key),$Values) }

function Format-JavaStatus($Project) {
    $found=if($Project.PSObject.Properties['JavaFound']){[bool]$Project.JavaFound}else{([string]$Project.JavaStatus -notmatch '未检测到')}
    $major=if($Project.PSObject.Properties['InstalledJavaMajor']){[int]$Project.InstalledJavaMajor}else{if([string]$Project.JavaStatus -match 'Java\s+(\d+)'){[int]$Matches[1]}else{0}}
    $required=[int]$Project.RequiredJava
    if(-not $found){return Get-Loc 'javaMissing'}
    if($major -le 0){return Get-Loc 'javaUnknown'}
    if($required -gt 0 -and $major -lt $required){return Format-Loc 'javaTooLow' @($major,$required)}
    if($required -gt 0){return Format-Loc 'javaSuitable' @($major,$required)}
    return Format-Loc 'javaRequirementUnknown' @($major)
}

function Format-ProjectStatus($Project) {
    $code=if($Project.PSObject.Properties['StatusCode']){[string]$Project.StatusCode}else{''}
    if(-not $code){
        $raw=[string]$Project.Status
        $code=if(-not $Project.HasWrapper){'missingWrapper'}elseif($Project.LaunchTask -and $Project.Environment -eq '未知'){'unknownLaunchable'}elseif($Project.LaunchTask){'launchable'}elseif($raw -match '超时'){'taskTimeout'}elseif($raw -match '失败'){'taskFailed'}else{'noClientTask'}
    }
    switch($code){
        'missingWrapper'{Get-Loc 'projectMissingWrapper'}
        'taskTimeout'{Get-Loc 'projectTaskTimeout'}
        'launchable'{Format-Loc 'projectLaunchable' @([string]$Project.LaunchTask)}
        'unknownLaunchable'{Format-Loc 'projectUnknownLaunchable' @([string]$Project.LaunchTask)}
        'taskFailed'{Get-Loc 'projectTaskFailed'}
        'noClientTask'{Get-Loc 'projectNoClientTask'}
        default{Get-Loc 'projectWaiting'}
    }
}

function Update-ProjectLocalizedFields($Project) {
    $java=Format-JavaStatus $Project;$status=Format-ProjectStatus $Project
    $minecraft=if([string]$Project.MinecraftVersion -eq '未知'){Get-Loc 'unknown'}else{[string]$Project.MinecraftVersion}
    $environment=if([string]$Project.Environment -eq '未知'){Get-Loc 'unknown'}else{[string]$Project.Environment}
    $loader=([string]$Project.LoaderVersion).Replace('未知',(Get-Loc 'unknown'))
    $Project|Add-Member -NotePropertyName MinecraftDisplay -NotePropertyValue $minecraft -Force
    $Project|Add-Member -NotePropertyName EnvironmentDisplay -NotePropertyValue $environment -Force
    $Project|Add-Member -NotePropertyName LoaderDisplay -NotePropertyValue $loader -Force
    $Project|Add-Member -NotePropertyName JavaDisplay -NotePropertyValue $java -Force
    $Project|Add-Member -NotePropertyName StatusDisplay -NotePropertyValue $status -Force
}

function Update-AllProjectLocalizedFields {
    foreach($project in @($script:Projects)){Update-ProjectLocalizedFields $project}
    $script:ProjectGrid.Items.Refresh()
}

function Update-SettingsSelectionVisuals {
    if(-not $script:DarkThemeButton){return}
    foreach($pair in @(@($script:DarkThemeButton,'dark'),@($script:LightThemeButton,'light'))){
        $selected=([string]$script:Config.theme -eq $pair[1]);$pair[0].BorderThickness=if($selected){'3'}else{'1'};$pair[0].BorderBrush=if($selected){$script:MainWindow.Resources['AccentBrush']}else{$script:MainWindow.Resources['BorderBrush']};$pair[0].Background=if($selected){$script:MainWindow.Resources['AccentSoftBrush']}else{$script:MainWindow.Resources['SurfaceAltBrush']}
    }
    foreach($key in $script:AccentButtons.Keys){$b=$script:AccentButtons[$key];$selected=([string]$script:Config.accentColor -eq $key);$b.BorderThickness=if($selected){'4'}else{'1'};$b.BorderBrush=if($selected){$script:MainWindow.Resources['TextBrush']}else{$script:MainWindow.Resources['BorderBrush']}}
    foreach($key in $script:LanguageButtons.Keys){$b=$script:LanguageButtons[$key];$selected=([string]$script:Config.language -eq $key);$b.BorderThickness=if($selected){'3'}else{'1'};$b.BorderBrush=if($selected){$script:MainWindow.Resources['AccentBrush']}else{$script:MainWindow.Resources['BorderBrush']};$b.Background=if($selected){$script:MainWindow.Resources['AccentSoftBrush']}else{$script:MainWindow.Resources['SurfaceAltBrush']}}
}

function Update-NavigationLabels {
    $script:LogButton.Content=if($script:CurrentPage -eq 'log'){Get-Loc 'backHome'}else{Get-Loc 'logButton'}
    $script:SettingsButton.Content=if($script:CurrentPage -eq 'settings'){Get-Loc 'backHome'}else{Get-Loc 'settingsButton'}
}

function Update-Language {
    $script:MainWindow.Title='Universal MC Dev Launcher';$script:TitleText.Text=Get-Loc 'appTitle'
    Update-NavigationLabels
    $script:AddFolderButton.Content=Get-Loc 'addFolder';$script:AddFolderButton.ToolTip=Get-Loc 'addFolderTip';$script:ManageFoldersButton.Content=if($script:FolderRemovalMode){Get-Loc 'finishRemoving'}else{Get-Loc 'manageFolders'};$script:ScanButton.Content=Get-Loc 'rescan';$script:FolderRemovalHint.Text=Get-Loc 'folderRemovalHint'
    $headers=@('projectName','minecraft','environment','loaderVersion','java','status');for($i=0;$i -lt $headers.Count;$i++){$script:ProjectGrid.Columns[$i].Header=Get-Loc $headers[$i]}
    $script:DetailsTitle.Text=Get-Loc 'projectDetails';$script:LaunchButton.Content=Get-Loc 'actionLaunch';$script:BuildButton.Content=Get-Loc 'actionBuild';$script:CleanBuildButton.Content=Get-Loc 'actionCleanBuild';$script:TasksButton.Content=Get-Loc 'actionTasks'
    $selected=Get-SelectedProject;$launchTask=if($selected -and $selected.LaunchTask){[string]$selected.LaunchTask}else{'runClient'}
    $script:LaunchButton.ToolTip=Format-Loc 'tipLaunch' @($launchTask);$script:BuildButton.ToolTip=Get-Loc 'tipBuild';$script:CleanBuildButton.ToolTip=Get-Loc 'tipCleanBuild';$script:TasksButton.ToolTip=Get-Loc 'tipTasks'
    $script:AutoCloseLabel.Text=Get-Loc 'autoClose';$script:AutoCloseHint.Text=Get-Loc 'autoCloseHint';$script:RememberLabel.Text=Get-Loc 'rememberFolders';$script:RememberHint.Text=Get-Loc 'rememberFoldersHint';$script:AutoCheckLabel.Text=Get-Loc 'autoCheck';$script:AutoCheckHint.Text=Get-Loc 'autoCheckHint';$script:AutoScanNewLabel.Text=Get-Loc 'autoScanNew';$script:AutoScanNewHint.Text=Get-Loc 'autoScanNewHint'
    $script:ThemeTitle.Text=Get-Loc 'theme';$script:DarkThemeButton.Content=Get-Loc 'themeDark';$script:LightThemeButton.Content=Get-Loc 'themeLight';$script:AccentTitle.Text=Get-Loc 'accent';$script:LanguageTitle.Text=Get-Loc 'language'
    $script:BackgroundTitle.Text=Get-Loc 'backgroundTitle';$script:BackgroundHint.Text=Get-Loc 'backgroundHint';$script:ChooseBackgroundButton.Content=Get-Loc 'chooseBackground';$script:ClearBackgroundButton.Content=Get-Loc 'clearBackground';$script:VisualDebugTitle.Text=Get-Loc 'visualDebug';$script:BlurLabel.Text=Get-Loc 'backgroundBlur';$script:UiOpacityLabel.Text=Get-Loc 'uiOpacity';$script:ContactText.Text=(Get-Loc 'contactUs') + 'OnlIma.Studio@gmail.com'
    $script:LogPageTitle.Text=Get-Loc 'logTitle';$script:LogPageSubtitle.Text=Get-Loc 'logPageSubtitle';$script:LogStdoutLabel.Text=Get-Loc 'stdout';$script:LogStderrLabel.Text=Get-Loc 'stderr';$script:ClearLogButton.Content=Get-Loc 'clearLog';$script:CopyLogButton.Content=Get-Loc 'copyLog';$script:StopTaskButton.Content=Get-Loc 'stopTask'
    $accentKeys=@{gray='accentGray';red='accentRed';yellow='accentYellow';green='accentGreen';aqua='accentAqua';blue='accentBlue';purple='accentPurple';pink='accentPink'};foreach($key in $accentKeys.Keys){$script:AccentButtons[$key].ToolTip=Get-Loc $accentKeys[$key]}
    $langKeys=@{'en-US'='langEn';'es-ES'='langEs';'ja-JP'='langJa';'ko-KR'='langKo';'zh-TW'='langZhTw';'zh-CN'='langZhCn'};foreach($code in $langKeys.Keys){if($script:LanguageButtons[$code]){$script:LanguageButtons[$code].Content=Get-Loc $langKeys[$code]}}
    Update-FolderSummary;Update-AllProjectLocalizedFields;Update-ProjectDetails;Update-SettingsSelectionVisuals;Apply-Background
    if($script:CurrentSession){
        $display=Get-ActionDisplay ([string]$script:CurrentSession.Action)
        if($script:RunnerProcess -and -not $script:RunnerProcess.HasExited){$script:StatusText.Text=Format-Loc 'statusRunning' @([string]$script:CurrentSession.Project.Name,$display)}
        elseif($script:CurrentSession.PSObject.Properties['LastOutcome'] -and $script:CurrentSession.LastOutcome -eq 'completed'){$script:StatusText.Text=Format-Loc 'statusCompleted' @([string]$script:CurrentSession.Project.Name,$display)}
        elseif($script:CurrentSession.PSObject.Properties['LastOutcome'] -and $script:CurrentSession.LastOutcome -eq 'failed'){$script:StatusText.Text=Format-Loc 'statusFailed' @([string]$script:CurrentSession.Project.Name)}
    }
    Update-LogPage
}

function Quote-ProcessArgument([string]$Value) { return '"' + $Value.Replace('"','\"') + '"' }

function Start-HiddenPowerShell([string]$ScriptPath, [string[]]$NamedArguments) {
    $parts = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Quote-ProcessArgument $ScriptPath)) + $NamedArguments
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'; $psi.Arguments = ($parts -join ' '); $psi.WorkingDirectory = $script:ToolRoot
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.WindowStyle = 'Hidden'
    return [Diagnostics.Process]::Start($psi)
}

function Read-SharedText([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return '' }
    try {
        $stream = [IO.File]::Open($Path,'Open','Read','ReadWrite')
        try { $reader = New-Object IO.StreamReader($stream,[Text.Encoding]::UTF8,$true); try { $text=$reader.ReadToEnd() } finally {$reader.Dispose()} }
        finally { $stream.Dispose() }
        if ($text.Length -gt 500000) { return '[仅显示最后 500000 个字符]' + "`r`n" + $text.Substring($text.Length-500000) }
        return $text
    } catch { return '' }
}

function Get-ErrorExplanations([string]$Text) {
    $rules = @(
        [pscustomobject]@{Pattern='JAVA_HOME is set to an invalid directory|JAVA_HOME.*not valid';Key='errJavaHome'},
        [pscustomobject]@{Pattern='java.*not recognized|java.*not found';Key='errJavaMissing'},
        [pscustomobject]@{Pattern='Unsupported class file major version|compiled by a more recent version';Key='errJavaVersion'},
        [pscustomobject]@{Pattern='PKIX path building failed';Key='errCertificate'},
        [pscustomobject]@{Pattern='Could not resolve|Could not GET|Could not download|timed out|UnknownHostException';Key='errNetwork'},
        [pscustomobject]@{Pattern='Compilation failed|cannot find symbol';Key='errCompile'},
        [pscustomobject]@{Pattern='OutOfMemoryError|Java heap space';Key='errMemory'},
        [pscustomobject]@{Pattern='daemon.*disappeared';Key='errDaemon'},
        [pscustomobject]@{Pattern='Could not acquire lock|Timeout waiting to lock';Key='errLock'},
        [pscustomobject]@{Pattern='BUILD FAILED';Key='errBuild'}
    )
    $found = New-Object Collections.Generic.List[string]
    foreach ($rule in $rules) { if ($Text -match $rule.Pattern) { $found.Add('• ' + (Get-Loc $rule.Key)) } }
    if ($found.Count -eq 0) { return Get-Loc 'noKnownError' }
    return ($found -join "`r`n")
}

function Update-FolderSummary {
    $count = $script:ScanFolders.Count
    $script:ManageFoldersButton.Visibility = if ($count) {'Visible'} else {'Collapsed'}
    $script:FolderSummary.Text = if ($count) { Format-Loc 'foldersCount' @($count) } else { Get-Loc 'noFolders' }
    if(-not $count -and $script:FolderRemovalMode){Set-FolderRemovalMode $false}
}

function Add-FolderPath([string]$Path) {
    if (-not $Path) { return }
    $full = [IO.Path]::GetFullPath($Path)
    if (@($script:ScanFolders | Where-Object { $_.Equals($full,[StringComparison]::OrdinalIgnoreCase) }).Count) { return }
    $script:ScanFolders.Add($full);Update-FolderSummary;Save-Config
    if([bool]$script:Config.autoScanNewFolder){Start-ProjectScan -Folders @($full) -Incremental $true}
    else{$script:StatusText.Text=Get-Loc 'statusFolderAddedNoScan'}
}

function Add-ScanFolder {
    $helper = New-Object Windows.Interop.WindowInteropHelper($script:MainWindow)
    $path = [ModernFolderPicker]::PickFolder($helper.Handle,(Get-Loc 'folderPickerTitle'))
    if ($path) { Add-FolderPath $path }
}

function Test-PathInsideFolder([string]$Path,[string]$Folder) {
    if(-not $Path -or -not $Folder){return $false}
    $child=[IO.Path]::GetFullPath($Path).TrimEnd('\','/');$root=[IO.Path]::GetFullPath($Folder).TrimEnd('\','/')
    return $child.Equals($root,[StringComparison]::OrdinalIgnoreCase) -or $child.StartsWith(($root+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)
}

function Resolve-ProjectScanSource([string]$ProjectPath,[string[]]$Folders) {
    return [string](@($Folders|Where-Object{Test-PathInsideFolder $ProjectPath $_}|Sort-Object Length -Descending)|Select-Object -First 1)
}

function Set-FolderRemovalMode([bool]$Enabled) {
    $script:FolderRemovalMode=$Enabled
    $script:FolderRemovalPanel.Visibility=if($Enabled){'Visible'}else{'Collapsed'}
    $script:ManageFoldersButton.Content=if($Enabled){Get-Loc 'finishRemoving'}else{Get-Loc 'manageFolders'}
    if(-not $Enabled){$script:FolderList.SelectedItem=$null}
}

function Toggle-FolderRemovalMode {
    if(-not $script:ScanFolders.Count){return}
    Set-FolderRemovalMode (-not $script:FolderRemovalMode)
}

function Remove-ScanFolderPath([string]$Path) {
    if(-not $Path){return $false}
    $index=-1;for($i=0;$i -lt $script:ScanFolders.Count;$i++){if($script:ScanFolders[$i].Equals($Path,[StringComparison]::OrdinalIgnoreCase)){$index=$i;break}}
    if($index -lt 0){return $false}
    $removed=[string]$script:ScanFolders[$index];$script:ScanFolders.RemoveAt($index)
    for($i=$script:Projects.Count-1;$i -ge 0;$i--){
        $project=$script:Projects[$i];$source=if($project.PSObject.Properties['SourceScanFolder']){[string]$project.SourceScanFolder}else{''}
        if(($source -and $source.Equals($removed,[StringComparison]::OrdinalIgnoreCase)) -or (Test-PathInsideFolder ([string]$project.Path) $removed)){$script:Projects.RemoveAt($i)}
    }
    Update-FolderSummary;Save-Config;Update-ProjectDetails
    $script:StatusText.Text=Format-Loc 'statusFolderRemoved' @($removed)
    return $true
}

function Remove-SelectedScanFolder {
    $selected=[string]$script:FolderList.SelectedItem
    if($selected){[void](Remove-ScanFolderPath $selected)}
}

function Start-ProjectScan([string[]]$Folders,[bool]$Incremental=$false) {
    if ($script:ScanProcess -and -not $script:ScanProcess.HasExited) { return }
    if(-not $PSBoundParameters.ContainsKey('Folders')){$Folders=@($script:ScanFolders)}
    $Folders=@($Folders|Where-Object{$_})
    if (-not $Folders.Count) { $script:StatusText.Text=Get-Loc 'statusAddFirst'; return }
    $script:ScanMode=if($Incremental){'incremental'}else{'full'};$script:ScanRequestFolders=@($Folders);$script:ScanStartCount++
    $id=[Guid]::NewGuid().ToString('N'); $requestFile=Join-Path $script:RuntimePath "scan-$id-request.json"
    $script:ScanResultFile=Join-Path $script:RuntimePath "scan-$id-result.json"
    [IO.File]::WriteAllText($requestFile,(@{scanFolders=@($Folders)}|ConvertTo-Json -Depth 5),$script:Utf8)
    $script:AddFolderButton.IsEnabled=$false;$script:ManageFoldersButton.IsEnabled=$false;$script:ScanButton.IsEnabled=$false
    if(-not $Incremental){$script:Projects.Clear()};$script:StatusText.Text=Get-Loc 'statusScanning'
    $script:ScanProcess=Start-HiddenPowerShell $script:ScannerPath @('-RequestFile',(Quote-ProcessArgument $requestFile),'-ResultFile',(Quote-ProcessArgument $script:ScanResultFile))
}

function Finish-ProjectScan {
    $script:AddFolderButton.IsEnabled=$true;$script:ManageFoldersButton.IsEnabled=$true;$script:ScanButton.IsEnabled=$true
    try {
        $result=[IO.File]::ReadAllText($script:ScanResultFile)|ConvertFrom-Json
        if(-not $result.success){throw $result.error}
        foreach($project in @($result.projects)){
            $source=Resolve-ProjectScanSource ([string]$project.Path) $script:ScanRequestFolders
            $project|Add-Member -NotePropertyName SourceScanFolder -NotePropertyValue $source -Force
            for($i=$script:Projects.Count-1;$i -ge 0;$i--){if(([string]$script:Projects[$i].Path).Equals([string]$project.Path,[StringComparison]::OrdinalIgnoreCase)){$script:Projects.RemoveAt($i)}}
            Update-ProjectLocalizedFields $project;$script:Projects.Add($project)
        }
        if($script:Projects.Count){$script:ProjectGrid.SelectedIndex=0; $launchable=@($script:Projects|Where-Object{$_.LaunchTask}).Count; $script:StatusText.Text=Format-Loc 'statusScanDone' @($script:Projects.Count,$launchable)}
        else{$script:StatusText.Text=Get-Loc 'statusNoneFound'}
        Update-ProjectDetails
    } catch { $script:StatusText.Text=Format-Loc 'statusScanReadFailed' @($_.Exception.Message) }
}

function Stop-ProjectScanOnExit {
    if(-not $script:ScanProcess){return}
    try {
        if(-not $script:ScanProcess.HasExited){
            $psi=New-Object Diagnostics.ProcessStartInfo
            $psi.FileName='taskkill.exe';$psi.Arguments="/PID $($script:ScanProcess.Id) /T /F"
            $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.WindowStyle='Hidden'
            $killer=[Diagnostics.Process]::Start($psi);$killer.WaitForExit(5000)|Out-Null;$killer.Dispose()
            if(-not $script:ScanProcess.WaitForExit(3000)){$script:ScanProcess.Kill();$script:ScanProcess.WaitForExit(2000)|Out-Null}
        }
    } catch { }
    try{$script:ScanProcess.Dispose()}catch{}
    $script:ScanProcess=$null
}

function Get-SelectedProject { return $script:ProjectGrid.SelectedItem }
function Find-TaskByLeafName($Project,[string]$Leaf) {
    $exact=@($Project.Tasks|Where-Object{[string]$_ -eq $Leaf})|Select-Object -First 1; if($exact){return [string]$exact}
    return [string](@($Project.Tasks|Where-Object{[string]$_ -match (('(:|^)'+[Regex]::Escape($Leaf)+'$'))})|Select-Object -First 1)
}

function Update-ProjectDetails {
    $p=Get-SelectedProject
    if(-not $p){$script:DetailMinecraft.Text=Format-Loc 'minecraftLabel' @('—');$script:DetailEnvironment.Text=Format-Loc 'environmentLabel' @('—');$script:DetailLoader.Text=Format-Loc 'loaderLabel' @('—');$script:DetailJava.Text=Format-Loc 'javaLabel' @('—');$script:DetailStatus.Text=Format-Loc 'statusLabel' @((Get-Loc 'selectProject'));@($script:LaunchButton,$script:BuildButton,$script:CleanBuildButton,$script:TasksButton)|ForEach-Object{$_.IsEnabled=$false};return}
    Update-ProjectLocalizedFields $p
    $script:DetailMinecraft.Text=Format-Loc 'minecraftLabel' @([string]$p.MinecraftDisplay);$script:DetailEnvironment.Text=Format-Loc 'environmentLabel' @([string]$p.EnvironmentDisplay)
    $script:DetailLoader.Text=Format-Loc 'loaderLabel' @([string]$p.LoaderDisplay);$script:DetailJava.Text=Format-Loc 'javaLabel' @([string]$p.JavaDisplay);$script:DetailStatus.Text=Format-Loc 'statusLabel' @([string]$p.StatusDisplay)
    $script:LaunchButton.ToolTip=Format-Loc 'tipLaunch' @([string]$p.LaunchTask)
    $script:LaunchButton.IsEnabled=[bool]$p.LaunchTask;$script:BuildButton.IsEnabled=[bool](Find-TaskByLeafName $p 'build')
    $script:CleanBuildButton.IsEnabled=[bool]((Find-TaskByLeafName $p 'build') -and (Find-TaskByLeafName $p 'clean'));$script:TasksButton.IsEnabled=[bool]$p.HasWrapper
}

function Test-EnvironmentBeforeRun($Project) {
    if(-not [bool]$script:Config.autoCheckEnvironmentBeforeLaunch){return $true}
    if(-not(Test-Path -LiteralPath $Project.WrapperPath)){[Windows.MessageBox]::Show((Get-Loc 'envMissingWrapper'),(Get-Loc 'envTitle'),'OK','Error')|Out-Null;return $false}
    $javaFound=if($Project.PSObject.Properties['JavaFound']){[bool]$Project.JavaFound}else{([string]$Project.JavaStatus -notmatch '未检测到')}
    $javaMajor=if($Project.PSObject.Properties['InstalledJavaMajor']){[int]$Project.InstalledJavaMajor}else{if([string]$Project.JavaStatus -match 'Java\s+(\d+)'){[int]$Matches[1]}else{0}}
    if((-not $javaFound) -or ([int]$Project.RequiredJava -gt 0 -and $javaMajor -gt 0 -and $javaMajor -lt [int]$Project.RequiredJava)){
        return ([Windows.MessageBox]::Show((Format-Loc 'envJavaWarning' @((Format-JavaStatus $Project))),(Get-Loc 'envTitle'),'YesNo','Warning') -eq 'Yes')
    }
    return $true
}

function Get-ActionDisplay([string]$Action) {
    switch($Action){'launch'{Get-Loc 'runLaunch'}'build'{Get-Loc 'runBuild'}'cleanbuild'{Get-Loc 'runCleanBuild'}default{Get-Loc 'runTasks'}}
}

function Start-GradleAction([string]$Action) {
    $p=Get-SelectedProject;if(-not $p -or -not(Test-EnvironmentBeforeRun $p)){return $false}
    switch($Action){
        'launch'{$tasks=@([string]$p.LaunchTask)}
        'build'{$tasks=@(Find-TaskByLeafName $p 'build')}
        'cleanbuild'{$tasks=@((Find-TaskByLeafName $p 'clean'),(Find-TaskByLeafName $p 'build'))}
        default{$tasks=@('tasks')}
    }
    $display=Get-ActionDisplay $Action
    if(-not $tasks[0]){return $false}
    $id=[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6);$safe=([string]$p.Name -replace '[\\/:*?"<>|]','_')
    $folder=Join-Path $script:LogsPath "$id-$safe";[IO.Directory]::CreateDirectory($folder)|Out-Null
    $stdout=Join-Path $folder 'stdout.log';$stderr=Join-Path $folder 'stderr.log';$state=Join-Path $folder 'state.json';$request=Join-Path $script:RuntimePath "run-$id-request.json"
    $data=[ordered]@{projectPath=[string]$p.Path;wrapperPath=[string]$p.WrapperPath;tasks=$tasks;stdoutFile=$stdout;stderrFile=$stderr;stateFile=$state}
    [IO.File]::WriteAllText($request,($data|ConvertTo-Json -Depth 6),$script:Utf8)
    $script:CurrentSession=[pscustomobject]@{Project=$p;Action=$Action;Display=$display;LastOutcome='running';StdoutFile=$stdout;StderrFile=$stderr;StateFile=$state;Folder=$folder;Tasks=$tasks;StdoutOffset=0;StderrOffset=0}
    $script:LaunchSuccessHandled=$false;$script:RunnerProcess=Start-HiddenPowerShell $script:RunnerPath @('-RequestFile',(Quote-ProcessArgument $request))
    $script:StatusText.Text=Format-Loc 'statusRunning' @([string]$p.Name,$display);return $true
}

function Show-HomePage {
    $script:CurrentPage='home';$script:SettingsPage.Visibility='Collapsed';$script:LogPage.Visibility='Collapsed';$script:HomePage.Visibility='Visible';Update-NavigationLabels
}

function Show-SettingsPage {
    $script:CurrentPage='settings';$script:HomePage.Visibility='Collapsed';$script:LogPage.Visibility='Collapsed';$script:SettingsPage.Visibility='Visible';Update-NavigationLabels;Update-SettingsSelectionVisuals
}

function Show-LogPage {
    $script:CurrentPage='log';$script:HomePage.Visibility='Collapsed';$script:SettingsPage.Visibility='Collapsed';$script:LogPage.Visibility='Visible';Update-NavigationLabels;Update-LogPage
}

function Invoke-LogNavigation {if($script:CurrentPage -eq 'log'){Show-HomePage}else{Show-LogPage}}
function Invoke-SettingsNavigation {if($script:CurrentPage -eq 'settings'){Show-HomePage}else{Show-SettingsPage}}

function Set-BooleanSetting([string]$Name,[bool]$Value) {
    if($script:UpdatingSettings){return}
    $script:Config.$Name=$Value;Save-Config
}

function Initialize-SettingsControls {
    $script:UpdatingSettings=$true
    $script:AutoCloseToggle.IsChecked=[bool]$script:Config.autoCloseAfterMinecraftStarts;$script:RememberToggle.IsChecked=[bool]$script:Config.rememberScanFolders;$script:AutoCheckToggle.IsChecked=[bool]$script:Config.autoCheckEnvironmentBeforeLaunch;$script:AutoScanNewToggle.IsChecked=[bool]$script:Config.autoScanNewFolder
    $script:UpdatingSettings=$false
    $accentColors=[ordered]@{gray='#7D858E';red='#EF3B3A';yellow='#F6B914';green='#24C66B';aqua='#32BFD8';blue='#168FCE';purple='#8657E9';pink='#E94A93'}
    foreach($key in $accentColors.Keys){
        $button=New-Object Windows.Controls.Button;$button.Style=$script:MainWindow.FindResource('AccentCircleButton');$button.Tag=$key;$button.Background=New-Brush $accentColors[$key]
        $button.Add_Click({param($s,$e)$script:Config.accentColor=[string]$s.Tag;Save-Config;Apply-Theme})
        $script:AccentButtons[$key]=$button;[void]$script:AccentPanel.Children.Add($button)
    }
    foreach($code in @('en-US','es-ES','ja-JP','ko-KR','zh-TW','zh-CN')){
        $button=New-Object Windows.Controls.Button;$button.Height=56;$button.MinHeight=56;$button.Margin='6';$button.Padding='14,10';$button.VerticalContentAlignment='Center';$button.Tag=$code
        $button.Add_Click({param($s,$e)$script:Config.language=[string]$s.Tag;Save-Config;Update-Language})
        $script:LanguageButtons[$code]=$button;[void]$script:LanguagePanel.Children.Add($button)
    }
    $script:UpdatingVisualSettings=$true
    $script:BlurSlider.Value=[double]$script:Config.backgroundBlur;$script:UiOpacitySlider.Value=[double]$script:Config.uiOpacity*100
    $script:UpdatingVisualSettings=$false
    Update-SettingsSelectionVisuals
}

function Get-LogSlice([string]$Text,[int]$Offset) {
    if(-not $Text -or $Offset -ge $Text.Length){return ''}
    if($Offset -lt 0){$Offset=0};return $Text.Substring($Offset)
}

function Update-LogPage {
    if(-not $script:CurrentSession){
        $script:LogHeader.Text=Get-Loc 'logNoSessionTitle';$script:LogStatus.Text=Get-Loc 'logNoSession';$script:LogExplanation.Text='';$script:LogStdout.Text='';$script:LogStderr.Text='';$script:StopTaskButton.IsEnabled=$false;return
    }
    $fullOut=Read-SharedText $script:CurrentSession.StdoutFile;$fullErr=Read-SharedText $script:CurrentSession.StderrFile
    $out=Get-LogSlice $fullOut ([int]$script:CurrentSession.StdoutOffset);$err=Get-LogSlice $fullErr ([int]$script:CurrentSession.StderrOffset)
    $script:LogStdout.Text=$out;$script:LogStderr.Text=$err;$script:LogExplanation.Text=Get-ErrorExplanations($fullOut+"`n"+$fullErr)
    $commands=@($script:CurrentSession.Tasks|ForEach-Object{".\gradlew.bat $_ --console=plain --no-daemon"}) -join '；'
    $script:LogHeader.Text=Format-Loc 'logHeader' @([string]$script:CurrentSession.Project.Name,$commands)
    $statusKey=switch([string]$script:CurrentSession.LastOutcome){'completed'{'logStatusCompleted'}'failed'{'logStatusFailed'}'stopped'{'logStatusStopped'}default{'logStatusRunning'}}
    $script:LogStatus.Text=Get-Loc $statusKey
    $script:StopTaskButton.IsEnabled=[bool]($script:RunnerProcess -and -not $script:RunnerProcess.HasExited)
    if($script:CurrentPage -eq 'log'){$script:LogStdout.ScrollToEnd();$script:LogStderr.ScrollToEnd()}
}

function Clear-LogView {
    if(-not $script:CurrentSession){return}
    $script:CurrentSession.StdoutOffset=(Read-SharedText $script:CurrentSession.StdoutFile).Length;$script:CurrentSession.StderrOffset=(Read-SharedText $script:CurrentSession.StderrFile).Length;Update-LogPage
}

function Copy-LogView {
    $text=(Get-Loc 'stdout')+"`r`n"+$script:LogStdout.Text+"`r`n`r`n"+(Get-Loc 'stderr')+"`r`n"+$script:LogStderr.Text
    for($attempt=0;$attempt -lt 5;$attempt++){
        try{[Windows.Clipboard]::SetDataObject($text,$true);return}catch{Start-Sleep -Milliseconds 40}
    }
}

function Stop-CurrentTask {
    if(-not $script:RunnerProcess -or $script:RunnerProcess.HasExited){return}
    $pidToStop=$script:RunnerProcess.Id
    $psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName='taskkill.exe';$psi.Arguments="/PID $pidToStop /T /F";$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.WindowStyle='Hidden'
    $killer=[Diagnostics.Process]::Start($psi);$killer.WaitForExit(5000)|Out-Null;$killer.Dispose()
    try{
        if(-not $script:RunnerProcess.WaitForExit(5000)){
            $script:RunnerProcess.Kill()
            $script:RunnerProcess.WaitForExit(3000)|Out-Null
        }
    }catch{}
    try{$script:RunnerProcess.Dispose()}catch{};$script:RunnerProcess=$null;$script:CurrentSession.LastOutcome='stopped';$script:StatusText.Text=Get-Loc 'logStatusStopped';Update-LogPage
}

function Enable-LogMouseWheel($TextBox) {
    $handler=[Windows.Input.MouseWheelEventHandler]{
        param($sender,$eventArgs)
        $lines = -([double]$eventArgs.Delta / 120.0) * 3.0
        $sender.ScrollToVerticalOffset([Math]::Max(0,[double]$sender.VerticalOffset + $lines))
        $eventArgs.Handled = $true
    }
    $TextBox.AddHandler([Windows.UIElement]::MouseWheelEvent,$handler,$true)
    if(-not $script:LogWheelHandlers){$script:LogWheelHandlers=New-Object Collections.Generic.List[object]}
    $script:LogWheelHandlers.Add($handler)
}

$script:AddFolderButton.Add_Click({Add-ScanFolder})
$script:ManageFoldersButton.Add_Click({Toggle-FolderRemovalMode})
$script:ScanButton.Add_Click({Start-ProjectScan})
$script:SettingsButton.Add_Click({Invoke-SettingsNavigation})
$script:LogButton.Add_Click({Invoke-LogNavigation})
$script:ClearLogButton.Add_Click({Clear-LogView});$script:CopyLogButton.Add_Click({Copy-LogView});$script:StopTaskButton.Add_Click({Stop-CurrentTask})
Enable-LogMouseWheel $script:LogStdout;Enable-LogMouseWheel $script:LogStderr
$script:ProjectGrid.Add_SelectionChanged({Update-ProjectDetails})
$script:ProjectGrid.Add_ColumnReordered({if(-not $script:UpdatingColumns){Update-ConfigColumnLayout;Save-Config}})
$script:AutoCloseToggle.Add_Checked({Set-BooleanSetting 'autoCloseAfterMinecraftStarts' $true});$script:AutoCloseToggle.Add_Unchecked({Set-BooleanSetting 'autoCloseAfterMinecraftStarts' $false})
$script:RememberToggle.Add_Checked({Set-BooleanSetting 'rememberScanFolders' $true});$script:RememberToggle.Add_Unchecked({Set-BooleanSetting 'rememberScanFolders' $false})
$script:AutoCheckToggle.Add_Checked({Set-BooleanSetting 'autoCheckEnvironmentBeforeLaunch' $true});$script:AutoCheckToggle.Add_Unchecked({Set-BooleanSetting 'autoCheckEnvironmentBeforeLaunch' $false})
$script:AutoScanNewToggle.Add_Checked({Set-BooleanSetting 'autoScanNewFolder' $true});$script:AutoScanNewToggle.Add_Unchecked({Set-BooleanSetting 'autoScanNewFolder' $false})
$script:DarkThemeButton.Add_Click({$script:Config.theme='dark';Save-Config;Apply-Theme});$script:LightThemeButton.Add_Click({$script:Config.theme='light';Save-Config;Apply-Theme})
$script:ChooseBackgroundButton.Add_Click({Choose-BackgroundImage})
$script:ClearBackgroundButton.Add_Click({Clear-BackgroundImage})
$script:BackgroundFrame.Add_SizeChanged({Update-BackgroundView})
$script:BackgroundOverlay.Add_MouseLeftButtonDown({
    param($sender,$eventArgs)
    if(-not $script:BackgroundImage.Source -or -not (([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -ne 0)){return}
    $script:BackgroundDragPoint=$eventArgs.GetPosition($script:BackgroundFrame)
    [void]$script:BackgroundOverlay.CaptureMouse();$eventArgs.Handled=$true
})
$script:BackgroundOverlay.Add_MouseMove({
    param($sender,$eventArgs)
    if(-not $script:BackgroundDragPoint -or -not $script:BackgroundOverlay.IsMouseCaptured){return}
    if(-not (([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -ne 0)){return}
    $point=$eventArgs.GetPosition($script:BackgroundFrame)
    $script:Config.backgroundOffsetX += $point.X-$script:BackgroundDragPoint.X
    $script:Config.backgroundOffsetY += $point.Y-$script:BackgroundDragPoint.Y
    $script:BackgroundDragPoint=$point;Update-BackgroundView;$eventArgs.Handled=$true
})
$script:BackgroundOverlay.Add_MouseLeftButtonUp({
    param($sender,$eventArgs)
    if($script:BackgroundOverlay.IsMouseCaptured){$script:BackgroundOverlay.ReleaseMouseCapture();$script:BackgroundDragPoint=$null;Save-Config;$eventArgs.Handled=$true}
})
$script:BackgroundOverlay.Add_LostMouseCapture({$script:BackgroundDragPoint=$null})
$script:MainWindow.Add_PreviewMouseWheel({
    param($sender,$eventArgs)
    if(-not $script:BackgroundImage.Source -or -not (([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -ne 0)){return}
    $oldZoom=[double]$script:Config.backgroundZoom
    $newZoom=[Math]::Max(1.0,[Math]::Min(5.0,$oldZoom*[Math]::Pow(1.1,[double]$eventArgs.Delta/120.0)))
    if([Math]::Abs($newZoom-$oldZoom) -lt 0.000001){$eventArgs.Handled=$true;return}
    $point=$eventArgs.GetPosition($script:BackgroundFrame);$ratio=$newZoom/$oldZoom
    $script:Config.backgroundOffsetX=$point.X-$script:BackgroundFrame.ActualWidth/2-($point.X-$script:BackgroundFrame.ActualWidth/2-[double]$script:Config.backgroundOffsetX)*$ratio
    $script:Config.backgroundOffsetY=$point.Y-$script:BackgroundFrame.ActualHeight/2-($point.Y-$script:BackgroundFrame.ActualHeight/2-[double]$script:Config.backgroundOffsetY)*$ratio
    $script:Config.backgroundZoom=$newZoom;Update-BackgroundView;Save-Config;$eventArgs.Handled=$true
})
$script:MainWindow.Add_DragOver({
    param($sender,$eventArgs)
    if($eventArgs.Data.GetDataPresent([Windows.DataFormats]::FileDrop)){$eventArgs.Effects=[Windows.DragDropEffects]::Copy}else{$eventArgs.Effects=[Windows.DragDropEffects]::None}
    $eventArgs.Handled=$true
})
$script:MainWindow.Add_Drop({
    param($sender,$eventArgs)
    try{
        if(-not $eventArgs.Data.GetDataPresent([Windows.DataFormats]::FileDrop)){return}
        $files=@([string[]]$eventArgs.Data.GetData([Windows.DataFormats]::FileDrop))
        if($files.Count -ne 1){return}
        $extension=[IO.Path]::GetExtension($files[0]).ToLowerInvariant()
        if($extension -notin @('.png','.jpg','.jpeg','.bmp')){return}
        [void](Set-BackgroundImage $files[0])
    }finally{$eventArgs.Handled=$true}
})
$script:BlurSlider.Add_ValueChanged({
    if($script:UpdatingVisualSettings){return};$script:Config.backgroundBlur=[Math]::Round([double]$script:BlurSlider.Value);Save-Config;Apply-Background
})
$script:UiOpacitySlider.Add_ValueChanged({
    if($script:UpdatingVisualSettings){return};$script:Config.uiOpacity=[Math]::Round(([double]$script:UiOpacitySlider.Value/100),2);Save-Config;Apply-Theme;Apply-Background
})
$script:LaunchButton.Add_Click({[void](Start-GradleAction 'launch')})
$script:BuildButton.Add_Click({[void](Start-GradleAction 'build')})
$script:CleanBuildButton.Add_Click({[void](Start-GradleAction 'cleanbuild')})
$script:TasksButton.Add_Click({[void](Start-GradleAction 'tasks')})
$script:FolderList.Add_KeyDown({param($s,$e)if($e.Key -eq [Windows.Input.Key]::Delete){Remove-SelectedScanFolder;$e.Handled=$true}})
$script:FolderList.Add_MouseDoubleClick({param($s,$e)Remove-SelectedScanFolder;$e.Handled=$true})
$script:MainWindow.Add_KeyDown({param($s,$e)if($e.Key -eq [Windows.Input.Key]::Escape -and $script:FolderRemovalMode){Set-FolderRemovalMode $false;$e.Handled=$true}})
Apply-SavedWindowPlacement

$script:UiTimer=New-Object Windows.Threading.DispatcherTimer
$script:UiTimer.Interval=[TimeSpan]::FromMilliseconds(700)
$script:UiTimer.Add_Tick({
    if($script:ScanProcess -and $script:ScanProcess.HasExited){$script:ScanProcess.Dispose();$script:ScanProcess=$null;Finish-ProjectScan}
    if($script:CurrentSession){
        Update-LogPage
        $out=Read-SharedText $script:CurrentSession.StdoutFile
        if($script:CurrentSession.Action -eq 'launch' -and [bool]$script:Config.autoCloseAfterMinecraftStarts -and -not $script:LaunchSuccessHandled -and $out -match '(?i)Setting user:|Backend library: LWJGL|OpenAL initialized|Sound engine started'){
            $script:LaunchSuccessHandled=$true
            $script:AutoClosing=$true;$script:MainWindow.Close();return
        }
        if($script:RunnerProcess -and $script:RunnerProcess.HasExited){
            $script:RunnerProcess.Dispose();$script:RunnerProcess=$null
            try{$state=(Read-SharedText $script:CurrentSession.StateFile)|ConvertFrom-Json;if($state.status -eq 'completed'){$script:CurrentSession.LastOutcome='completed';$script:StatusText.Text=Format-Loc 'statusCompleted' @([string]$script:CurrentSession.Project.Name,(Get-ActionDisplay ([string]$script:CurrentSession.Action)))}else{$script:CurrentSession.LastOutcome='failed';$script:StatusText.Text=Format-Loc 'statusFailed' @([string]$script:CurrentSession.Project.Name)}}catch{}
        }
    }
})

$script:MainWindow.Add_ContentRendered({
    Initialize-SettingsControls;Initialize-ColumnPersistence;Apply-Logo;Apply-Theme;Update-Language;Update-FolderSummary;Update-ProjectDetails;$script:UiTimer.Start()
    if($script:ScanFolders.Count){Start-ProjectScan}
})
$script:MainWindow.Add_Closing({Save-WindowPlacement;Update-ConfigColumnLayout;Save-Config;$script:UiTimer.Stop();Stop-ProjectScanOnExit})

[void]$script:MainWindow.ShowDialog()
[Environment]::Exit(0)
