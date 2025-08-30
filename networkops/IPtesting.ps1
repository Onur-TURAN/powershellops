
#example subnet writing type, changable
$subnets = @(
    "192.168.1",
    "10.0.0",
    "172.16.0"
)


$firstOctet = 1
$LastOctet = 255
$csvPath = "C:\path\to\your\output.csv"
$results = @()

foreach ($subnet in $subnets) {
    Write-Host "Testing subnet: $subnet"

    for ($i = $firstOctet; $i -le $LastOctet; $i++) {
        $ip = "$subnet.$i"
        Write-Host "Pinging $ip"
        $pingResult = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue

        if ($pingResult) {
            try {
                $dnsResult = Resolve-DnsName -Name $ip -ErrorAction Stop
                $dnsStatus = "Dns is reachable: $($dnsResult.Name)"
            } catch {
                $dnsStatus = "Dns is not reachable"
            }
            $pingStatus = "Ping is reachable"
        } else {
            $pingStatus = "Ping is not reachable"
            $dnsStatus = "Dns is not reachable"
        }
    }
}

# Export results to CSV
$results | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "Results exported to $csvPath"