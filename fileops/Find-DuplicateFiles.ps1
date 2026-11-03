<#
.SYNOPSIS
    Finds duplicate files by content hash.

.DESCRIPTION
    Scans -Path for files, groups them by size first and only hashes files that
    share a size with at least one other file. Files with identical size and hash
    are reported as a duplicate set.

    Emits one object per duplicate file (SetId, Hash, Length, Path), ordered by
    duplicate set, and optionally exports the results to CSV.

.PARAMETER Path
    Directory to scan. Default: current directory.

.PARAMETER Recurse
    Include files in subdirectories.

.PARAMETER Algorithm
    Hash algorithm: SHA1, SHA256, SHA384, SHA512 or MD5. Default: SHA256.

.PARAMETER OutputPath
    Optional CSV file path. When given, results are exported with
    Export-Csv -NoTypeInformation -Encoding UTF8.

.EXAMPLE
    .\Find-DuplicateFiles.ps1 -Path D:\Photos -Recurse

    Lists duplicate files under D:\Photos.

.EXAMPLE
    .\Find-DuplicateFiles.ps1 -Path \\fs01\share -Recurse -Algorithm MD5 -OutputPath C:\temp\dupes.csv

    Uses the faster MD5 algorithm and writes a CSV report.

.EXAMPLE
    .\Find-DuplicateFiles.ps1 -Path D:\Data -Recurse | Group-Object SetId |
        ForEach-Object { $_.Group | Select-Object -Skip 1 }

    Returns every duplicate except the first file of each set (e.g. to review before deleting).
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path = '.',

    [switch]$Recurse,

    [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5')]
    [string]$Algorithm = 'SHA256',

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

$files = Get-ChildItem -LiteralPath $Path -File -Recurse:$Recurse -ErrorAction SilentlyContinue

# Step 1: only files sharing a size with another file can be duplicates.
$sizeGroups = $files | Where-Object { $_.Length -gt 0 } | Group-Object -Property Length |
    Where-Object { $_.Count -gt 1 }

$results = New-Object System.Collections.Generic.List[object]
$setId = 0

foreach ($sizeGroup in $sizeGroups) {
    # Step 2: hash the same-size candidates.
    $hashed = New-Object System.Collections.Generic.List[object]
    foreach ($file in $sizeGroup.Group) {
        try {
            $h = Get-FileHash -LiteralPath $file.FullName -Algorithm $Algorithm -ErrorAction Stop
            $hashed.Add([PSCustomObject]@{
                Hash   = $h.Hash
                Length = $file.Length
                Path   = $file.FullName
            })
        } catch {
            Write-Warning "Cannot hash $($file.FullName): $($_.Exception.Message)"
        }
    }

    # Step 3: same size + same hash = duplicate set.
    foreach ($hashGroup in ($hashed | Group-Object -Property Hash | Where-Object { $_.Count -gt 1 })) {
        $setId++
        foreach ($item in ($hashGroup.Group | Sort-Object Path)) {
            $results.Add([PSCustomObject]@{
                SetId  = $setId
                Hash   = $item.Hash
                Length = $item.Length
                Path   = $item.Path
            })
        }
    }
}

if ($OutputPath) {
    $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Verbose "Results exported to $OutputPath"
}

$results
