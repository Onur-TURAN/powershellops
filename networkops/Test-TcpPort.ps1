<#
.SYNOPSIS
    Tests whether TCP ports are open on one or more hosts.

.DESCRIPTION
    Attempts a TCP connection to each ComputerName/Port combination using
    System.Net.Sockets.TcpClient.BeginConnect with a configurable timeout, and
    emits one object per combination (ComputerName, Port, Open).

    Intended for checking your own infrastructure (e.g. verifying that a service
    is listening or a firewall rule is in place). Only test hosts you own or are
    authorized to test.

    Compatible with Windows PowerShell 5.1 and PowerShell 7+.

.PARAMETER ComputerName
    One or more host names or IP addresses. Accepts pipeline input.

.PARAMETER Port
    One or more TCP port numbers (1-65535).

.PARAMETER TimeoutMs
    Connection timeout per attempt in milliseconds. Default: 1000.

.EXAMPLE
    .\Test-TcpPort.ps1 -ComputerName localhost -Port 135,445

    Checks whether RPC and SMB ports are listening on the local machine.

.EXAMPLE
    .\Test-TcpPort.ps1 -ComputerName web01,web02 -Port 80,443 -TimeoutMs 500 |
        Where-Object { -not $_.Open }

    Lists web ports that are not reachable on your own web servers.

.EXAMPLE
    'db01','db02' | .\Test-TcpPort.ps1 -Port 1433

    Accepts host names from the pipeline.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateRange(1, 65535)]
    [int[]]$Port,

    [ValidateRange(1, 600000)]
    [int]$TimeoutMs = 1000
)

process {
    foreach ($computer in $ComputerName) {
        foreach ($p in $Port) {
            $open = $false
            $client = New-Object System.Net.Sockets.TcpClient
            try {
                $async = $client.BeginConnect($computer, $p, $null, $null)
                if ($async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
                    try {
                        # EndConnect throws if the connection was refused.
                        $client.EndConnect($async)
                        $open = $client.Connected
                    } catch {
                        $open = $false
                    }
                }
            } catch {
                Write-Verbose "Connection to ${computer}:$p failed: $($_.Exception.Message)"
                $open = $false
            } finally {
                $client.Close()
            }

            [PSCustomObject]@{
                ComputerName = $computer
                Port         = $p
                Open         = $open
            }
        }
    }
}
