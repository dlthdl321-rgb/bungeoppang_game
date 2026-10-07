param([string]$JobFile,[string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
$saveImageBlock = [ScriptBlock]::Create((Get-Content -LiteralPath (Join-Path $ProjectRoot 'output/imagegen/save_eyelash_edit.ps1') -Raw))
$editJobs = Get-Content -LiteralPath $JobFile -Raw -Encoding utf8 | ConvertFrom-Json
foreach ($editJob in $editJobs) {
    $destinationImage = Join-Path $ProjectRoot $editJob.path
    $referenceImage = Join-Path $ProjectRoot $editJob.reference
    & $saveImageBlock -SourcePath $editJob.source -OriginalPath $referenceImage -DestinationPath $destinationImage
    $editedHash = (Get-FileHash -LiteralPath $destinationImage -Algorithm SHA256).Hash
    $previousHash = (Get-FileHash -LiteralPath $referenceImage -Algorithm SHA256).Hash
    if ($editedHash -eq $previousHash) { throw "Edited image unchanged: $destinationImage" }
    $editJob.path | Add-Content -LiteralPath (Join-Path $ProjectRoot 'output/imagegen/eyelash_completed_verified.txt') -Encoding utf8
    Write-Output $editJob.path
}
