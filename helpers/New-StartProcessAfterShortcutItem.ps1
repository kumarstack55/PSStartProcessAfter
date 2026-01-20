function New-StartProcessAfterShortcutItem {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]$ScriptItem,
        [Parameter(Mandatory)][string]$WaitType,
        [Parameter(Mandatory)][string]$WaitFor,
        [Parameter(Mandatory)][string]$CommandLine,
        [Parameter(Mandatory)][string]$ShortcutDirectoryPath,
        [Parameter(Mandatory)][string]$ShortcutBaseName,
        [Parameter()][bool]$NoExit = $false,
        [Parameter()][int]$Seconds = 60
    )
    $scriptPath = $ScriptItem.FullName
    $shortcutName = "{0}.lnk" -f $ShortcutBaseName
    $shortcutPath = Join-Path -Path $ShortcutDirectoryPath -ChildPath $shortcutName
    $extraArguments = if ($NoExit) { "-NoExit " } else { "" }
    $arguments = @'
-NoLogo -NoProfile {0}-Command ". {1}; Start-ProcessAfter -WaitType {2} -WaitFor '{3}' -CommandLine '{4}'; Start-Sleep {5}"
'@ -f $extraArguments, $scriptPath, $WaitType, $WaitFor, $CommandLine, $Seconds
    if ($PSCmdlet.ShouldProcess($shortcutPath, "Create Shortcut with arguments: $arguments")) {
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell"
        $shortcut.Arguments = $arguments
        $shortcut.WorkingDirectory = "$PWD"
        $shortcut.Save()
    }
    $item = Get-Item -LiteralPath $shortcutPath

    $item
}
