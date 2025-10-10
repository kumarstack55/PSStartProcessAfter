function Write-CustomHost {
<#
.SYNOPSIS
    Writes a message to the host with a timestamp.

.PARAMETER Message
    The message to write.
#>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter()]
        [DateTime]$Date
    )

    if ($null -eq $Date) {
        $now = Get-Date
    } else {
        $now = $Date
    }

    $dateTime = Get-Date -Date $now -UFormat "%Y-%m-%d %H:%M:%S"
    $line = "{0} {1}" -f $dateTime, $Message
    $line | Write-Host
}

function Test-WebCondition {
<#
.SYNOPSIS
    Tests if a web request to the specified URL succeeds.

.EXAMPLE
    Test-WebCondition -Url "https://www.example.com"
    Tests if access to the specified URL is successful.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $message = "Checking URL: {0}" -f $Url
    Write-CustomHost -Message $message

    $oldProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 10 -ErrorAction Stop
        $statusCode = $response.StatusCode
        $webCondition = $statusCode -eq 200
    } catch {
        $webCondition = $false
    } finally {
        $ProgressPreference = $oldProgressPreference
    }

    return $webCondition
}

function Test-FolderCondition {
<#
.SYNOPSIS
    Tests if the specified folder exists.

.EXAMPLE
    Test-FolderCondition -FolderPath "C:\temp"
    Checks if the specified folder exists.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    $message = "Checking Folder: {0}" -f $FolderPath
    Write-CustomHost -Message $message

    try {
        return Test-Path -Path $FolderPath -PathType Container
    } catch {
        return $false
    }
}

function Test-ProcessCondition {
<#
.SYNOPSIS
    Tests if the specified process is running.

.EXAMPLE
    Test-ProcessCondition -ProcessName "notepad"
    Checks if the notepad process is running.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProcessName
    )

    $message = "Checking Process: {0}" -f $ProcessName
    Write-CustomHost -Message $message

    try {
        $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        return $processes.Count -gt 0
    } catch {
        return $false
    }
}

function Test-ConditionMet {
<#
.SYNOPSIS
    Tests if the condition is met based on the specified type and target.

.EXAMPLE
    Test-ConditionMet -WaitType "UrlIsAccessible" -WaitFor "https://example.com"
    Tests URL accessibility.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("UrlIsAccessible", "FolderExists", "ProcessExists")]
        [string]$WaitType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WaitFor
    )

    switch ($WaitType) {
        'UrlIsAccessible' {
            return Test-WebCondition -Url $WaitFor
        }
        'FolderExists' {
            return Test-FolderCondition -FolderPath $WaitFor
        }
        'ProcessExists' {
            return Test-ProcessCondition -ProcessName $WaitFor
        }
        default {
            throw "Unknown WaitType: $WaitType"
        }
    }
}

function Start-ProcessUsingCommandLine {
<#
.SYNOPSIS
    Start a process using command line parsing.

.DESCRIPTION
    This function takes a command line string, tokenizes it while ignoring comments,
    and starts the specified process with the parsed arguments.

    Unlike `&` operators, it executes asynchronously. Therefore, it runs in a separate window.

    Unlike Start-Process, the command line is parsed.

.PARAMETER CommandLine
    The command line string to be parsed and executed.

.EXAMPLE
    Start-ProcessUsingCommandLine -CommandLine 'cmd.exe'

.EXAMPLE
    Start-ProcessUsingCommandLine -CommandLine 'powershell.exe -NoProfile'

.EXAMPLE
    Start-ProcessUsingCommandLine -CommandLine '"C:\Program Files\teraterm5\ttermpro.exe" ssh://user@host:22 ; comment'

.EXAMPLE
    Start-ProcessUsingCommandLine -CommandLine 'powershell.exe -NoProfile -Command "& { while ($true) { Get-Date; Start-Sleep 1; } }"'

.NOTES
    DO NOT PROVIDE COMMAND LINES THAT TAKE INPUT FROM UNTRUSTED SOURCES.

#>
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandLine
    )

    # Tokenize the command line, ignoring comments.
    #
    # PSParser is primarily a class for syntax colorizations,
    # but here it is used to tokenize strings containing whitespace.
    $tokensMayContainComments = [System.Management.Automation.PSParser]::Tokenize($CommandLine, [ref]$null)
    if ($tokensMayContainComments.Count -eq 0) {
        throw "Failed to tokenize command line"
    }
    $tokens = $tokensMayContainComments | Where-Object { $_.Type -ne 'Comment' }
    if ($tokens.Count -eq 0) {
        throw "No tokens found"
    }

    # The first token is the file path, and the rest are arguments.
    $filePath = $tokens[0].Content

    $argumentList = [string[]]::new($tokens.Count - 1)
    for ($index = 0; $index -lt $tokens.Count - 1; $index++) {
        $argumentList[$index] = $tokens[$index + 1].Content
    }

    # Start the process.
    if ($argumentList.Count -eq 0) {
        Start-Process -FilePath $filePath
    } else {
        Start-Process -FilePath $filePath -ArgumentList $argumentList
    }
}

function Start-ProcessAfter {
<#
.SYNOPSIS
    Executes a process after the specified condition is met.

.DESCRIPTION
    Waits for conditions such as successful web requests, folder accessibility,
    or process startup, and executes the specified process after the condition is met.

.PARAMETER WaitType
    Specifies the type of condition to wait for.
    - UrlIsAccessible: Wait for URL access
    - FolderExists: Wait for folder existence
    - ProcessExists: Wait for process execution

.PARAMETER WaitFor
    Specifies the target to wait for.
    - UrlIsAccessible: URL to monitor (must start with http:// or https://)
    - FolderExists: Folder path to monitor
    - ProcessExists: Process name to monitor

.PARAMETER CommandLine
    Specifies the command line to execute after the condition is met.

.PARAMETER CheckIntervalSeconds
    Specifies the check interval (seconds) for the condition. Default is 5 seconds.

.EXAMPLE
    Start-ProcessAfter -WaitType "UrlIsAccessible" -WaitFor "https://www.example.com" -CommandLine "notepad.exe C:\\temp\\test.txt"
    Opens test.txt with notepad after the web request to the specified URL succeeds.

.EXAMPLE
    Start-ProcessAfter -WaitType "FolderExists" -WaitFor "$HOME\OneDrive\Personal Vault" -CommandLine "powershell.exe -Command Get-Process"
    Executes PowerShell command after the specified folder becomes accessible.

.EXAMPLE
    Start-ProcessAfter -WaitType "ProcessExists" -WaitFor "notepad" -CommandLine "calc.exe"
    Starts calculator after notepad process is launched.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("UrlIsAccessible", "FolderExists", "ProcessExists")]
        [string]$WaitType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WaitFor,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CommandLine,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$CheckIntervalSeconds = 5
    )

    Write-Host "Wait Type: $WaitType"
    Write-Host "Wait Target: $WaitFor"
    Write-Host "Check Interval: $CheckIntervalSeconds seconds"

    while ($true) {
        if (Test-ConditionMet -WaitType $WaitType -WaitFor $WaitFor) {
            break
        }

        $message = "Waiting for {0} seconds..." -f $CheckIntervalSeconds
        Write-CustomHost -Message $message
        Start-Sleep -Seconds $CheckIntervalSeconds
    }

    Write-Host "Condition met! Executing process..." -ForegroundColor Green
    try {
        Write-Host "CommandLine: ${CommandLine}" -ForegroundColor Green
        Start-ProcessUsingCommandLine -CommandLine $CommandLine
        Write-Host "Command line executed: $CommandLine" -ForegroundColor Green
    }
    catch {
        Write-Error "Error occurred while executing command line: $($_.Exception.Message)"
        throw
    }
}

# Sample execution when run as a script
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Start-ProcessAfter function has been loaded."
    Write-Host "Usage examples:"
    Write-Host "  Start-ProcessAfter -WaitType 'UrlIsAccessible' -WaitFor 'https://www.example.com' -CommandLine 'notepad.exe'"
    Write-Host "  Start-ProcessAfter -WaitType 'FolderExists' -WaitFor '`$HOME\Documents\Personal Vault' -CommandLine 'notepad.exe'"
    Write-Host "  Start-ProcessAfter -WaitType 'ProcessExists' -WaitFor 'notepad' -CommandLine 'notepad.exe'"
}
