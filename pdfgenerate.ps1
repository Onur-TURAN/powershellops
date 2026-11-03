$document_path = 'C:\path\to\your\'
$file_path = Join-Path -Path $document_path -ChildPath 'GeneratedDocument.docx'

if (-NOT (Test-Path -Path $document_path)) {
    New-Item -ItemType Directory -Path $document_path | Out-Null
    exit
}

$word = New-Object -ComObject Word.Application
$word.Visible = $false

try {
    $document = $word.Documents.Open($file_path)
    $pdf_filename = Join-Path -Path $document_path -ChildPath 'GeneratedDocument.pdf'
    $document.SaveAs([ref] $pdf_filename, [ref] 17) # 17 is the enum for wdFormatPDF
    $document.Close()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($document) | Out-Null
    Write-Host "PDF generated at: $pdf_filename"
} catch {
    Write-Host "Error: $_"
} finally {
    $word.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}