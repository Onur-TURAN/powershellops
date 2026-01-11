$csvPath = "traintrue.csv"
$data = Import-Csv -Path $csvPath

$patterns = @(Read-Host "Enter patterns to search for, separated by commas").Split(',')

$results = @()

foreach ($row in $data) {
    $query = $row.Query
    $matched = $false

    foreach ($pattern in $patterns) {
        try {
            if ($query -match $pattern) {
                $matched = $true
                break
            }
        } catch {
        }
    }

    $result = [PSCustomObject]@{
        Query = $query
        Label = $row.Label
        Match = if ($matched) { 1 } else { 0 }
    }
    $results += $result
}

$results | Export-Csv -Path "results.csv" -NoTypeInformation