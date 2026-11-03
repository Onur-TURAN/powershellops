<#
.SYNOPSIS
    Deletes files older than a given number of days.

.DESCRIPTION
    Finds files under -Path whose LastWriteTime is older than -Days days and
    deletes them. Every deletion goes through ShouldProcess, so -WhatIf and
    -Confirm work as expected. Optionally appends a log line per file to -LogPath.

    Emits a summary object with the number of deleted files, failures and the
    total size freed in MB.

.PARAMETER Path
    Directory to clean up.

.PARAMETER Days
    Minimum age in days (based on LastWriteTime). Files older than this are removed.

.PARAMETER Filter
    File name filter, e.g. "*.log". Default: "*".

.PARAMETER Recurse
    Include files in subdirectories.

.PARAMETER LogPath
    Optional log file. Each deletion (or failure) is appended as a line.

.EXAMPLE
    .\Remove-OldFiles.ps1 -Path D:\Logs -Days 30 -Filter *.log -WhatIf

    Shows which .log files older than 30 days would be deleted, without deleting.

.EXAMPLE
    .\Remove-OldFiles.ps1 -Path D:\Temp -Days 7 -Recurse -LogPath D:\Logs\cleanup.log -Confirm:$false

    Deletes files older than 7 days recursively without prompting and logs each deletion.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateRange(0, 36500)]
    [int]$Days,

    [ValidateNotNullOrEmpty()]
    [string]$Filter = '*',

    [switch]$Recurse,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath
)

$cutoff = (Get-Date).AddDays(-$Days)

function Write-CleanupLog {
    param([string]$Message)
    if ($LogPath) {
        $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
        # Log writes are not destructive, so they bypass -WhatIf.
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8 -WhatIf:$false
    }
}

$files = Get-ChildItem -LiteralPath $Path -Filter $Filter -File -Recurse:$Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff }

$deletedCount = 0
$failedCount = 0
$candidateCount = 0
[long]$bytesFreed = 0

foreach ($file in $files) {
    $candidateCount++
    if ($PSCmdlet.ShouldProcess($file.FullName, "Delete file (last modified $($file.LastWriteTime))")) {
        try {
            $size = $file.Length
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop -WhatIf:$false -Confirm:$false
            $deletedCount++
            $bytesFreed += $size
            Write-CleanupLog "DELETED $($file.FullName) ($size bytes)"
        } catch {
            $failedCount++
            Write-Warning "Failed to delete $($file.FullName): $($_.Exception.Message)"
            Write-CleanupLog "FAILED  $($file.FullName): $($_.Exception.Message)"
        }
    }
}

[PSCustomObject]@{
    Path         = $Path
    CutoffDate   = $cutoff
    Candidates   = $candidateCount
    DeletedCount = $deletedCount
    FailedCount  = $failedCount
    FreedMB      = [Math]::Round($bytesFreed / 1MB, 2)
    WhatIf       = [bool]$WhatIfPreference
}
