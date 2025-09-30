# PSStartProcessAfter

Executes a process after specified conditions are met.
For example, wait for a web request to succeed before executing a process.
Or execute a process after a specified process starts.

## Requirements

- Windows PowerShell 5.1+

## Installation

```powershell
# powershell
git clone ...
Set-Location .\PSStartProcessAfter\
```

## Usage

### Execute a process after a web request succeeds

```powershell
# powershell
. .\Start-ProcessAfter.ps1
Start-ProcessAfter -WaitType "UrlIsAccessible" -WaitFor "https://www.example.com" -CommandLine "notepad.exe"
```

### Execute a process when a folder becomes accessible

```powershell
# powershell
. .\Start-ProcessAfter.ps1
Start-ProcessAfter -WaitType "FolderExists" -WaitFor "$HOME\OneDrive\Personal Vault" -CommandLine "notepad.exe"
```

### Execute a process after another process starts

```powershell
# powershell
. .\Start-ProcessAfter.ps1
Start-ProcessAfter -WaitType "ProcessExists" -WaitFor "notepad" -CommandLine "calc.exe"
```

## Parameters

- WaitType: Specifies the type of condition to wait for
  - `"UrlIsAccessible"`: Wait for URL accessibility
  - `"FolderExists"`: Wait for folder existence
  - `"ProcessExists"`: Wait for process execution

- WaitFor: Specifies the target to wait for (URL, folder path, or process name)

- CommandLine: Command line to execute after the condition is met

- CheckIntervalSeconds: Check interval in seconds (default: 5)

## Creating Shortcuts

```powershell
# powershell

Set-Location .\PSStartProcessAfter\

$scriptItem = Get-Item .\Start-ProcessAfter.ps1
$scriptPath = $scriptItem.FullName

$arguments = "-NoLogo -NoProfile -Command `". {0}`"; Start-ProcessAfter -WaitType UrlIsAccessible -WaitFor 'https://www.example.com' -CommandLine 'notepad.exe'; Start-Sleep 60" -f $scriptPath

$shortcutName = "StartProcessAfterUrlIsAccessible.lnk"
$location = Get-Location
$shortcutDirectory = $location.Path
$shortcutPath = Join-Path -Path $shortcutDirectory -ChildPath $shortcutName

$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell"
$shortcut.Arguments = $arguments
$shortcut.WorkingDirectory = "$PWD"
$shortcut.Save()

Start-Process .
```

## Development requirements

- Visual Studio Code

 Visual Stuido Extensions

- [PowerShell](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell)
- [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)
- [Markdownlint](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint)
- [EditorConfig for VS Code](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig)

## LICENSE

MIT
