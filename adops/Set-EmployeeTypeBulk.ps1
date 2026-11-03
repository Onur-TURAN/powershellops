#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Sets EmployeeType in bulk for enabled users that have no value yet.

.DESCRIPTION
    Finds enabled users whose employeeType attribute is empty and sets it to the
    given value. Existing values are never overwritten. Supports -WhatIf and -Confirm.

.PARAMETER EmployeeType
    Value to set: Employee, Contractor, Intern or Vendor.

.PARAMETER SearchBase
    Optional DN of the OU to search.

.PARAMETER Limit
    Maximum number of users to modify (0 = no limit). Default 0.

.EXAMPLE
    .\Set-EmployeeTypeBulk.ps1 -EmployeeType Employee -SearchBase "OU=Staff,DC=contoso,DC=com" -WhatIf

.EXAMPLE
    .\Set-EmployeeTypeBulk.ps1 -EmployeeType Intern -Limit 10
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Employee', 'Contractor', 'Intern', 'Vendor')]
    [string]$EmployeeType,

    [ValidateNotNullOrEmpty()]
    [string]$SearchBase,

    [ValidateRange(0, 100000)]
    [int]$Limit = 0
)

$adParams = @{
    LDAPFilter = '(&(!(employeeType=*))(!(userAccountControl:1.2.840.113556.1.4.803:=2)))'
}
if ($SearchBase) { $adParams['SearchBase'] = $SearchBase }

$users = Get-ADUser @adParams
if ($Limit -gt 0) { $users = $users | Select-Object -First $Limit }

foreach ($user in $users) {
    $status = 'Skipped'
    if ($PSCmdlet.ShouldProcess($user.DistinguishedName, "Set employeeType to '$EmployeeType'")) {
        try {
            Set-ADUser -Identity $user -Replace @{ employeeType = $EmployeeType } -ErrorAction Stop
            $status = 'Updated'
        }
        catch {
            $status = "Failed: $($_.Exception.Message)"
        }
    }
    [PSCustomObject]@{
        SamAccountName = $user.SamAccountName
        EmployeeType   = $EmployeeType
        Status         = $status
    }
}
