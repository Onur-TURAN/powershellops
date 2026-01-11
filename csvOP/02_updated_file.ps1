
$csvPath = "trainfalse.csv"
$lines = Get-Content -Path $csvPath
$updatedLines = @()
foreach ($line in $lines) {
    $updatedLine = "$line,0"
    $updatedLines += $updatedLine
}

$updatedLines | Set-Content -Path $csvPath