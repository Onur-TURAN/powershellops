<#
.SYNOPSIS
    Fast, parameterized ping sweep of one or more /24 subnets.

.DESCRIPTION
    Pings a range of host addresses (x.x.x.Start - x.x.x.End) in each given subnet
    concurrently using System.Net.NetworkInformation.Ping.SendPingAsync. Pings are
    sent in batches of -ThrottleLimit tasks and awaited with Task.WaitAll, so the
    script works on Windows PowerShell 5.1 as well as PowerShell 7+.

    Optionally resolves the host name of reachable addresses via reverse DNS.
    Emits one object per address (IP, Reachable, RoundtripMs, HostName) and
    optionally exports the results to CSV.

    This is the parameterized, concurrent replacement for the legacy IPtesting.ps1.
    Only scan networks you own or are authorized to test.

.PARAMETER Subnet
    One or more subnet prefixes made of the first three octets, e.g. "192.168.1".

.PARAMETER Start
    First host octet to ping (1-254). Default: 1.

.PARAMETER End
    Last host octet to ping (1-254). Default: 254. Must be >= Start.

.PARAMETER TimeoutMs
    Ping timeout per address in milliseconds. Default: 500.

.PARAMETER ThrottleLimit
    Maximum number of concurrent pings per batch. Default: 64.

.PARAMETER ResolveDns
    Resolve host names of reachable addresses via reverse DNS lookup.

.PARAMETER OutputPath
    Optional CSV file path. When given, results are exported with
    Export-Csv -NoTypeInformation -Encoding UTF8.

.EXAMPLE
    .\Invoke-SubnetSweep.ps1 -Subnet 192.168.1

    Pings 192.168.1.1 - 192.168.1.254 and outputs the results.

.EXAMPLE
    .\Invoke-SubnetSweep.ps1 -Subnet 10.0.0,10.0.1 -ResolveDns -OutputPath C:\temp\sweep.csv

    Sweeps two subnets, resolves host names and writes a CSV report.

.EXAMPLE
    .\Invoke-SubnetSweep.ps1 -Subnet 172.16.0 -Start 1 -End 50 -TimeoutMs 250 |
        Where-Object Reachable

    Pings the first 50 hosts with a shorter timeout and shows only reachable hosts.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^\d{1,3}\.\d{1,3}\.\d{1,3}$')]
    [string[]]$Subnet,

    [ValidateRange(1, 254)]
    [int]$Start = 1,

    [ValidateRange(1, 254)]
    [int]$End = 254,

    [ValidateRange(1, 60000)]
    [int]$TimeoutMs = 500,

    [ValidateRange(1, 1024)]
    [int]$ThrottleLimit = 64,

    [switch]$ResolveDns,

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

if ($Start -gt $End) {
    throw "Start ($Start) must be less than or equal to End ($End)."
}

# Validate that each octet of every subnet is in 0-255.
foreach ($s in $Subnet) {
    foreach ($octet in $s.Split('.')) {
        if ([int]$octet -gt 255) {
            throw "Invalid subnet '$s': octet '$octet' is greater than 255."
        }
    }
}

# Build the full list of target addresses.
$targets = New-Object System.Collections.Generic.List[string]
foreach ($s in $Subnet) {
    for ($i = $Start; $i -le $End; $i++) {
        $targets.Add("$s.$i")
    }
}

$results = New-Object System.Collections.Generic.List[object]
$total = $targets.Count

for ($offset = 0; $offset -lt $total; $offset += $ThrottleLimit) {
    $count = [Math]::Min($ThrottleLimit, $total - $offset)
    Write-Progress -Activity 'Subnet sweep' -Status "Pinging $($offset + 1)-$($offset + $count) of $total" `
        -PercentComplete ([int](($offset / $total) * 100))

    # Start one async ping per address in this batch; each Ping instance handles one request.
    $pingers = New-Object 'System.Net.NetworkInformation.Ping[]' $count
    $tasks   = New-Object 'System.Threading.Tasks.Task[System.Net.NetworkInformation.PingReply][]' $count
    for ($j = 0; $j -lt $count; $j++) {
        $pingers[$j] = New-Object System.Net.NetworkInformation.Ping
        $tasks[$j] = $pingers[$j].SendPingAsync($targets[$offset + $j], $TimeoutMs)
    }

    try {
        [System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]$tasks)
    } catch {
        # Individual task failures (e.g. invalid address) are handled per task below.
        Write-Verbose "One or more pings in the batch faulted: $($_.Exception.Message)"
    }

    for ($j = 0; $j -lt $count; $j++) {
        $ip = $targets[$offset + $j]
        $reachable = $false
        $rtt = $null
        $hostName = $null

        $task = $tasks[$j]
        if ($task.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion -and
            $task.Result.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            $reachable = $true
            $rtt = [int]$task.Result.RoundtripTime
        }

        if ($reachable -and $ResolveDns) {
            try {
                $hostName = [System.Net.Dns]::GetHostEntry($ip).HostName
            } catch {
                $hostName = $null
            }
        }

        $results.Add([PSCustomObject]@{
            IP          = $ip
            Reachable   = $reachable
            RoundtripMs = $rtt
            HostName    = $hostName
        })

        $pingers[$j].Dispose()
    }
}

Write-Progress -Activity 'Subnet sweep' -Completed

if ($OutputPath) {
    $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Verbose "Results exported to $OutputPath"
}

$results
