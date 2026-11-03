#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Lists Active Directory users who have not logged on for a given number of days.

.DESCRIPTION
    Queries AD using LastLogonTimestamp and returns users whose last logon is older
    than the threshold (or who have never logged on). Optionally exports to CSV.
    Note: LastLogonTimestamp is replicated lazily (up to ~14 days of skew).

.PARAMETER DaysInactive
    Number of days without logon to be considered inactive. Default 90.

.PARAMETER SearchBase
    Optional DN of the OU to search.

.PARAMETER OutputPath
    Optional CSV path to export results.

.PARAMETER IncludeDisabled
    Include disabled accounts. By default only enabled accounts are returned.

.EXAMPLE
    .\Get-InactiveADUsers.ps1 -DaysInactive 120

.EXAMPLE
    .\Get-InactiveADUsers.ps1 -SearchBase "OU=Sales,DC=contoso,DC=com" -OutputPath .\inactive.csv -IncludeDisabled
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 3650)]
    [int]$DaysInactive = 90,

    [ValidateNotNullOrEmpty()]
    [string]$SearchBase,

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [switch]$IncludeDisabled
)

$cutoff = (Get-Date).AddDays(-$DaysInactive)

$adParams = @{
    Filter     = '*'
    Properties = 'LastLogonTimestamp', 'Enabled'
}
if ($SearchBase) { $adParams['SearchBase'] = $SearchBase }

$now = Get-Date
$results = Get-ADUser @adParams |
    Where-Object { $IncludeDisabled -or $_.Enabled } |
    ForEach-Object {
        $lastLogon = $null
        $days = $null
        if ($_.LastLogonTimestamp) {
            $lastLogon = [DateTime]::FromFileTime($_.LastLogonTimestamp)
            $days = [int]($now - $lastLogon).TotalDays
        }
        # Never logged on (null) counts as inactive
        if ($null -eq $lastLogon -or $lastLogon -lt $cutoff) {
            [PSCustomObject]@{
                SamAccountName    = $_.SamAccountName
                Name              = $_.Name
                Enabled           = $_.Enabled
                LastLogonDate     = $lastLogon
                DaysSinceLogon    = $days
                DistinguishedName = $_.DistinguishedName
            }
        }
    }

if ($OutputPath -and $results) {
    $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Verbose "Exported to $OutputPath"
}

$results
