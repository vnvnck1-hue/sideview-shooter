# Adds two "픽셀 미리보기" entries to the Explorer right-click menu of .png files for the
# current user only (HKCU, no admin). On Windows 11 they appear under "더 많은 옵션 표시"
# (Shift+F10). Flat verbs are used on purpose: a SubCommands cascade under
# SystemFileAssociations is ignored by Explorer. Remove with uninstall_context_menu.ps1.
# Re-run after moving the repository.
$ErrorActionPreference = 'Stop'
$script = (Resolve-Path (Join-Path $PSScriptRoot 'pixel_preview.ps1')).Path
$shellPath = 'Software\Classes\SystemFileAssociations\.png\shell'
$launch = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Gui"

# The .NET registry API takes literal key names (the PowerShell provider expands wildcards).
$hkcu = [Microsoft.Win32.Registry]::CurrentUser
$shell = $hkcu.CreateSubKey($shellPath)
foreach ($old in 'SideviewPixelPreview', 'SideviewPixelPreview1Prop', 'SideviewPixelPreview2Room') {
    $shell.DeleteSubKeyTree($old, $false)
}
$entries = @(
    @{ key = 'SideviewPixelPreview1Prop'; label = '픽셀 미리보기 - 프랍 (Tolerance 12)'; args = '' },
    @{ key = 'SideviewPixelPreview2Room'; label = '픽셀 미리보기 - 배경·방 (Tolerance 4)'; args = ' -Tolerance 4' }
)
foreach ($e in $entries) {
    $verb = $shell.CreateSubKey($e.key)
    $verb.SetValue('MUIVerb', $e.label)
    $verb.SetValue('Icon', 'imageres.dll,-5356')
    $command = $verb.CreateSubKey('command')
    $command.SetValue('', "$launch$($e.args) `"%1`"")
    $command.Close(); $verb.Close()
}
$shell.Close()
# Explorer caches file associations; without this notification an already running
# Explorer keeps showing the old menu until it restarts.
Add-Type -Namespace SideviewPixelPreview -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);'
[SideviewPixelPreview.Shell]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)  # SHCNE_ASSOCCHANGED
"Installed: right-click a .png -> 더 많은 옵션 표시 -> 픽셀 미리보기 - 프랍 / 배경·방"
