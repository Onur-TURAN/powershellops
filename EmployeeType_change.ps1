$user = @(Get-ADUser -Filter "EmployeeType -eq '' -and Enabled -eq $true" -Properties EmployeeType | Select-Object -First 1)

if ($user) {
    Update-Mguser -UserId $user.Id -EmployeeType "Contractor"
}