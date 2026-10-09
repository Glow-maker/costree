$ErrorActionPreference = 'Stop'
$base = [IO.Path]::GetFullPath($PSScriptRoot)
$count = 0
foreach ($line in Get-Content -LiteralPath (Join-Path $base 'SHA256SUMS.txt') -Encoding UTF8) {
    if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { throw 'Invalid manifest line' }
    $expected = $Matches[1]
    $relative = $Matches[2]
    $target = [IO.Path]::GetFullPath((Join-Path $base $relative))
    if (-not $target.StartsWith($base + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe manifest path' }
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing: $relative" }
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $expected) { throw "Hash mismatch: $relative" }
    $count++
}
Write-Host "PASS: $count package files match SHA256. This does not execute SQL or deploy services."
