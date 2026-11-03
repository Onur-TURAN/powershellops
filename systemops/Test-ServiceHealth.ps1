<#
.SYNOPSIS
Checks the state of Windows services and optionally starts stopped automatic services.

.DESCRIPTION
For each computer and each requested service, the script reports the service
Name, its current Status (Running, Stopped, ...) and its StartType (Automatic,
Manual, Disabled). When -Restart is specified and a service whose StartType is
Automatic is Stopped, the script starts it. Starting a service is performed
through ShouldProcess, so -WhatIf and -Confirm are supported.

Services that do not exist, or computers that cannot be queried, produce a
warning and the script continues with the remaining items.

.PARAMETER ServiceName
One or more exact service names (for example Spooler, W32Time). Mandatory.

.PARAMETER ComputerName
One or more computer names to query. Defaults to the local computer.

.PARAMETER Restart
When specified, stopped services with StartType Automatic are started.
Services with other start types are only reported.

.EXAMPLE
.\Test-ServiceHealth.ps1 -ServiceName Spooler,W32Time

Reports the status and start type of the Spooler and W32Time services on the
local computer. No changes are made.

.EXAMPLE
.\Test-ServiceHealth.ps1 -ServiceName Spooler -ComputerName SRV01,SRV02 -Restart -WhatIf

Shows which stopped automatic services would be started on the two servers,
without starting them.

.EXAMPLE
.\Test-ServiceHealth.ps1 -ServiceName W32Time -Restart -Confirm:$false

Starts the W32Time service on the local computer if it is stopped and set to
Automatic, without prompting.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ServiceName,

    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName = @($env:COMPUTERNAME),

    [switch]$Restart
)

$results = New-Object System.Collections.Generic.List[object]

foreach ($computer in $ComputerName) {
    # Local queries are run without -ComputerName so they do not depend on WinRM.
    $isLocal = ($computer -eq $env:COMPUTERNAME) -or ($computer -eq 'localhost') -or ($computer -eq '.')
    $cimTarget = @{}
    if (-not $isLocal) { $cimTarget.ComputerName = $computer }

    Write-Verbose "Querying services on '$computer'"
    try {
        $services = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop @cimTarget)
    }
    catch {
        Write-Warning "Could not query services on '$computer': $($_.Exception.Message)"
        continue
    }

    foreach ($name in $ServiceName) {
        $svc = $services | Where-Object { $_.Name -eq $name } | Select-Object -First 1

        if (-not $svc) {
            Write-Warning "Service '$name' was not found on '$computer'."
            $results.Add([PSCustomObject]@{
                ComputerName = $computer
                Name         = $name
                Status       = 'NotFound'
                StartType    = 'N/A'
                Restarted    = $false
            })
            continue
        }

        $restarted = $false

        if ($Restart -and $svc.StartMode -eq 'Auto' -and $svc.State -eq 'Stopped') {
            $target = "$computer - service '$name'"
            if ($PSCmdlet.ShouldProcess($target, 'Start service')) {
                $ret = Invoke-CimMethod -InputObject $svc -MethodName StartService
                if ($ret.ReturnValue -eq 0) {
                    $restarted = $true
                    Write-Verbose "Start request accepted for '$name' on '$computer'."

                    # Wait up to 30 seconds for the service to report Running.
                    for ($i = 0; $i -lt 30; $i++) {
                        Start-Sleep -Seconds 1
                        $current = Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue @cimTarget |
                            Where-Object { $_.Name -eq $name } | Select-Object -First 1
                        if ($current -and $current.State -eq 'Running') { break }
                    }
                    if ($current) { $svc = $current }
                }
                else {
                    Write-Warning "Failed to start '$name' on '$computer' (return code $($ret.ReturnValue))."
                }
            }
        }

        if ($svc.StartMode -eq 'Auto') {
            $startType = 'Automatic'
        }
        else {
            $startType = $svc.StartMode
        }

        $results.Add([PSCustomObject]@{
            ComputerName = $computer
            Name         = $svc.Name
            Status       = $svc.State
            StartType    = $startType
            Restarted    = $restarted
        })
    }
}

# Emit objects to the pipeline.
$results.ToArray()
