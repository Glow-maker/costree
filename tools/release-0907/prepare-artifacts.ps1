param([Parameter(Mandatory=$true)][string]$PackageRoot)
$ErrorActionPreference='Stop'
$releaseRoot=(Resolve-Path -LiteralPath $PackageRoot).Path
if ((Split-Path $releaseRoot -Leaf) -ne 'cost-server-offline-package-20260907-staging') { throw 'Only the staging package may be prepared' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$externalized=[Collections.Generic.List[string]]::new()
foreach($service in @('cost','system')) {
$jarPath=Join-Path $releaseRoot "backend/app/$service-server.jar"
$archive=[IO.Compression.ZipFile]::Open($jarPath,[IO.Compression.ZipArchiveMode]::Update)
try {
  foreach($entry in @($archive.Entries | Where-Object FullName -Match '^BOOT-INF/classes/application-.+\.ya?ml$')) {$entry.Delete()}
  foreach($configName in @('application.yml','application.yaml')) {
  $entry=$archive.GetEntry("BOOT-INF/classes/$configName")
  if(-not $entry){continue}
  $reader=[IO.StreamReader]::new($entry.Open())
  try {$config=$reader.ReadToEnd()} finally {$reader.Dispose()}
  $scope=[Collections.Generic.List[object]]::new()
  $lines=foreach($line in ($config -split "`r?`n")) {
    if($line -notmatch '^(\s*)([\w.-]+):\s*(.*)$'){$line;continue}
    $indent=$Matches[1];$key=$Matches[2];$value=$Matches[3]
    while($scope.Count -gt 0 -and $scope[$scope.Count-1].Indent -ge $indent.Length){$scope.RemoveAt($scope.Count-1)}
    $keys=@($scope | ForEach-Object Key)+@($key)
    $property=$keys -join '.'
    if([string]::IsNullOrWhiteSpace($value) -or $value.StartsWith('#')) {
      $scope.Add([pscustomobject]@{Indent=$indent.Length;Key=$key});$line;continue
    }
    if($property -eq 'spring.profiles.active') { $indent+$key+': ${SPRING_PROFILES_ACTIVE:intranet}';continue }
    if(($key -match '(?i)^(password|accessToken|secret|api-key|client-secret|secret-key)$' -or $keys[0] -eq 'fw' -or $key -in @('app_server','ocsp_ip')) -and -not $value.StartsWith('${')) {
      $variable=($service+'_'+($property -replace '[^a-zA-Z0-9]','_')).ToUpperInvariant()
      $externalized.Add("$service-server $configName $property -> $variable (retain original intranet value)")
      $indent+$key+': ${'+$variable+':}'
    } else {$line}
  }
  $entry.Delete()
  $entry=$archive.CreateEntry("BOOT-INF/classes/$configName")
  $writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false))
  try {$writer.Write($lines -join "`n")} finally {$writer.Dispose()}
  }
} finally {$archive.Dispose()}
}
[IO.File]::WriteAllLines((Join-Path $releaseRoot 'backend/config/EXTERNALIZED-CONFIG.txt'),$externalized,[Text.UTF8Encoding]::new($false))
$dist=Join-Path $releaseRoot 'frontend/dist'
if(Test-Path -LiteralPath $dist){throw 'Expanded frontend already exists'}
[IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $releaseRoot 'frontend/costree-frontend-dist-prod.zip'),$dist)
$info=Join-Path $releaseRoot 'RELEASE-INFO.txt'
$text=Get-Content -LiteralPath $info -Raw
foreach($pair in @(@('backendJarSha256','cost'),@('systemJarSha256','system'))) {
  $hash=(Get-FileHash -LiteralPath (Join-Path $releaseRoot "backend/app/$($pair[1])-server.jar") -Algorithm SHA256).Hash
  $text=$text -replace "(?m)^$($pair[0])=.*$",($pair[0]+'='+$hash)
}
[IO.File]::WriteAllText($info,$text,[Text.UTF8Encoding]::new($false))
Write-Host 'Both JARs sanitized; environment profiles excluded; supplied frontend ZIP expanded.'
