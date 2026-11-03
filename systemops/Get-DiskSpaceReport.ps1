<#
.SYNOPSIS
Reports logical disk space usage for one or more computers.

.DESCRIPTION
Queries fixed local disks (DriveType=3) through Win32_LogicalDisk using CIM.
Each disk is reported with its size, free space and free percentage. A disk is
flagged as "Warning" when its free percentage is below -WarningPercent,
otherwise it is flagged as "OK". Computers that cannot be queried produce a
warning and the script continues with the remaining computers.

.PARAMETER ComputerName
One or more computer names to query. Defaults to the local computer.

.PARAMETER WarningPercent
Free-space threshold in percent. Disks with less free space than this value
are flagged as "Warning". Valid range: 1-100. Default: 15.

.PARAMETER OutputPath
Optional CSV file path. When specified, the results are also exported to this
file (UTF8, no type information).

.EXAMPLE
.\Get-DiskSpaceReport.ps1

Reports all fixed disks on the local computer using the default 15% threshold.

.EXAMPLE
.\Get-DiskSpaceReport.ps1 -ComputerName SRV01,SRV02 -WarningPercent 20 -OutputPath C:\Reports\disk.csv

Checks two servers with a 20% threshold and exports the results to a CSV file.

.EXAMPLE
.\Get-DiskSpaceReport.ps1 | Where-Object Status -eq 'Warning'

Lists only the disks that are below the free-space threshold.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName = @($env:COMPUTERNAME),

    [ValidateRange(1, 100)]
    [int]$WarningPercent = 15,

    [string]$OutputPath
)

$results = New-Object System.Collections.Generic.List[object]

foreach ($computer in $ComputerName) {
    # Local queries are run without -ComputerName so they do not depend on WinRM.
    $isLocal = ($computer -eq $env:COMPUTERNAME) -or ($computer -eq 'localhost') -or ($computer -eq '.')
    $cimTarget = @{}
    if (-not $isLocal) { $cimTarget.ComputerName = $computer }

    Write-Verbose "Querying logical disks on '$computer'"
    try {
        $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop @cimTarget
    }
    catch {
        Write-Warning "Could not query '$computer': $($_.Exception.Message)"
        continue
    }

    foreach ($disk in $disks) {
        $sizeBytes = [double]$disk.Size
        $freeBytes = [double]$disk.FreeSpace

        if ($sizeBytes -gt 0) {
            $freePercent = [math]::Round(($freeBytes / $sizeBytes) * 100, 2)
        }
        else {
            $freePercent = 0
        }

        if ($freePercent -lt $WarningPercent) {
            $status = 'Warning'
        }
        else {
            $status = 'OK'
        }

        $results.Add([PSCustomObject]@{
            ComputerName = $computer
            Drive        = $disk.DeviceID
            SizeGB       = [math]::Round($sizeBytes / 1GB, 2)
            FreeGB       = [math]::Round($freeBytes / 1GB, 2)
            FreePercent  = $freePercent
            Status       = $status
        })
    }
}

if ($OutputPath) {
    if ($results.Count -gt 0) {
        $results.ToArray() | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Verbose "Results exported to '$OutputPath'"
    }
    else {
        Write-Warning 'No disk data was collected, so no CSV file was written.'
    }
}

# Emit objects to the pipeline.
$results.ToArray()
