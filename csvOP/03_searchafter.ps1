$originalCsvPath = "results.csv"
$newCsvPath = "alldata.csv"

$data = Import-Csv -Path $originalCsvPath

$updatedData = @()

# Kullanıcıdan yeni sütun adını ve değerini al
$newColumnName = Read-Host "Yeni sütun adı"
$newColumnValue = Read-Host "Yeni sütun değeri"

foreach ($row in $data) {
    $updatedRow = [PSCustomObject]@{
        Query = $row.Query
        Label = $row.Label
        SELECT = $row.SELECT
        UNION = $row.UNION
        OR = $row.OR
        AND = $row.AND
        NewColkkumn = $row.SELECT
    }
    # Yeni sütunu ekle
    $updatedRow | Add-Member -MemberType NoteProperty -Name $newColumnName -Value $newColumnValue
    $updatedData += $updatedRow
}

$updatedData | Export-Csv -Path $newCsvPath -NoTypeInformation