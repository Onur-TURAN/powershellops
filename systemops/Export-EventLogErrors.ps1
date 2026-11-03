<#
.SYNOPSIS
Collects recent event log entries of a given level and optionally exports them to CSV.

.DESCRIPTION
Uses Get-WinEvent with -FilterHashtable to read events from the specified logs
that were created within the last -Hours hours and that match exactly the
requested -Level (Critical, Error or Warning). Each event is emitted as an
object containing TimeCreated, LogName, Id, ProviderName, LevelDisplayName and
the first line of the Message.

When a log contains no matching events, the script continues silently (a
verbose message is written). Logs that cannot be read produce a warning and the
script continues with the remaining logs.

.PARAMETER LogName
One or more event log names. Default: System, Application.

.PARAMETER Hours
Number of hours to look back from the current time. Valid range: 1-8760.
Default: 24.

.PARAMETER Level
Event level to collect: Critical, Error or Warning. Default: Error.

.PARAMETER OutputPath
Optional CSV file path. When specified, the results are also exported to this
file (UTF8, no type information).

.EXAMPLE
.\Export-EventLogErrors.ps1 -Hours 2

Lists Error events from the System and Application logs of the last 2 hours.

.EXAMPLE
.\Export-EventLogErrors.ps1 -LogName System -Hours 72 -Level Critical -OutputPath C:\Reports\critical.csv

Exports Critical events from the System log of the last 3 days to a CSV file.

.EXAMPLE
.\Export-EventLogErrors.ps1 -LogName 'Microsoft-Windows-Windows Defender/Operational' -Level Warning -Hours 48

Lists Warning events from the Windows Defender operational log of the last 48 hours.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string[]]$LogName = @('System', 'Application'),

    [ValidateRange(1, 8760)]
    [int]$Hours = 24,

    [ValidateSet('Critical', 'Error', 'Warning')]
    [string]$Level = 'Error',

    [string]$OutputPath
)

# Numeric levels used by Get-WinEvent filters.
$levelMap = @{
    Critical = 1
    Error    = 2
    Warning  = 3
}

$startTime = (Get-Date).AddHours(-$Hours)
$results = New-Object System.Collections.Generic.List[object]

foreach ($log in $LogName) {
    $filter = @{
        LogName   = $log
        Level     = $levelMap[$Level]
        StartTime = $startTime
    }

    Write-Verbose "Querying '$log' for $Level events since $startTime"
    try {
        $events = @(Get-WinEvent -FilterHashtable $filter -ErrorAction Stop)
    }
    catch {
        if ($_.Exception.Message -match 'No events were found') {
            Write-Verbose "No $Level events found in '$log' during the last $Hours hour(s)."
            continue
        }
        Write-Warning "Could not read '$log': $($_.Exception.Message)"
        continue
    }

    foreach ($evt in $events) {
        # Keep only the first line of the message; some messages are empty.
        $firstLine = ''
        if ($evt.Message) {
            $firstLine = ($evt.Message -split '\r?\n')[0]
        }

        $results.Add([PSCustomObject]@{
            TimeCreated      = $evt.TimeCreated
            LogName          = $evt.LogName
            Id               = $evt.Id
            ProviderName     = $evt.ProviderName
            LevelDisplayName = $evt.LevelDisplayName
            Message          = $firstLine
        })
    }
}

$sorted = @($results.ToArray() | Sort-Object -Property TimeCreated -Descending)

if ($OutputPath) {
    if ($sorted.Count -gt 0) {
        $sorted | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Verbose "Results exported to '$OutputPath'"
    }
    else {
        Write-Warning 'No events were collected, so no CSV file was written.'
    }
}

# Emit objects to the pipeline.
$sorted
