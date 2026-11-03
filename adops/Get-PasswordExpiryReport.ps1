#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Reports enabled users whose password expires within a given number of days.

.DESCRIPTION
    Uses the computed attribute msDS-UserPasswordExpiryTimeComputed. Accounts with
    PasswordNeverExpires and disabled accounts are skipped. Already-expired
    passwords are included (DaysLeft is negative).

.PARAMETER WithinDays
    Report passwords expiring within this many days. Default 14.

.PARAMETER OutputPath
    Optional CSV path to export results.

.EXAMPLE
    .\Get-PasswordExpiryReport.ps1

.EXAMPLE
    .\Get-PasswordExpiryReport.ps1 -WithinDays 30 -OutputPath .\expiry.csv
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 365)]
    [int]$WithinDays = 14,

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

$now = Get-Date
$limit = $now.AddDays($WithinDays)

$results = Get-ADUser -Filter 'Enabled -eq $true -and PasswordNeverExpires -eq $false' `
        -Properties 'msDS-UserPasswordExpiryTimeComputed', 'PasswordNeverExpires', 'EmailAddress' |
    ForEach-Object {
        $raw = $_.'msDS-UserPasswordExpiryTimeComputed'
        # 0 or Int64.MaxValue means no expiry information
        if ($raw -and $raw -ne [Int64]::MaxValue) {
            $expiry = [DateTime]::FromFileTime($raw)
            if ($expiry -le $limit) {
                [PSCustomObject]@{
                    SamAccountName = $_.SamAccountName
                    Name           = $_.Name
                    EmailAddress   = $_.EmailAddress
                    ExpiryDate     = $expiry
                    DaysLeft       = [int][Math]::Floor(($expiry - $now).TotalDays)
                }
            }
        }
    } |
    Sort-Object ExpiryDate

if ($OutputPath -and $results) {
    $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Verbose "Exported to $OutputPath"
}

$results
