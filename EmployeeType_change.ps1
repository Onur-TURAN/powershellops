#Requires -Modules ActiveDirectory
# Sets EmployeeType to "Contractor" for the first enabled AD user whose employeeType is empty.
# For bulk updates with -WhatIf support see adops/Set-EmployeeTypeBulk.ps1
$user = Get-ADUser -LDAPFilter "(&(!(employeeType=*))(!(userAccountControl:1.2.840.113556.1.4.803:=2)))" -Properties employeeType |
    Select-Object -First 1

if ($user) {
    Set-ADUser -Identity $user -Replace @{ employeeType = "Contractor" }
}
