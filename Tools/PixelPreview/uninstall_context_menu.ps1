$ErrorActionPreference = 'Stop'
$shell = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\SystemFileAssociations\.png\shell', $true)
if ($shell) {
    foreach ($k in 'SideviewPixelPreview', 'SideviewPixelPreview1Prop', 'SideviewPixelPreview2Room') { $shell.DeleteSubKeyTree($k, $false) }
    $shell.Close()
}
# Explorer caches file associations; without this notification an already running
# Explorer keeps showing the old menu until it restarts.
Add-Type -Namespace SideviewPixelPreview -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);'
[SideviewPixelPreview.Shell]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)  # SHCNE_ASSOCCHANGED
'Removed pixel preview context menu entries'
