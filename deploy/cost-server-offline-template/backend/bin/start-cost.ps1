$ErrorActionPreference = 'Stop'

$BackendRoot = Split-Path $PSScriptRoot -Parent
$EnvFile = Join-Path $BackendRoot 'config\cost-server.env'
$ConfigFile = Join-Path $BackendRoot 'config\application-intranet.yml'
$JarFile = Join-Path $BackendRoot 'app\cost-server.jar'
$RunDirectory = Join-Path $BackendRoot 'run'
$LogDirectory = Join-Path $BackendRoot 'logs'
$PidFile = Join-Path $RunDirectory 'cost-server.pid'

function Import-EnvFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing $Path. Copy cost-server.env.example to cost-server.env and fill it first."
    }
    foreach ($line in Get-Content -LiteralPath $Path) {
        $value = $line.Trim()
        if (-not $value -or $value.StartsWith('#')) { continue }
        $parts = $value.Split('=', 2)
        if ($parts.Count -ne 2) { throw "Invalid env line: $line" }
        $name = $parts[0].Trim()
        $data = $parts[1].Trim()
        if (($data.StartsWith('"') -and $data.EndsWith('"')) -or
            ($data.StartsWith("'") -and $data.EndsWith("'"))) {
            $data = $data.Substring(1, $data.Length - 2)
        }
        [Environment]::SetEnvironmentVariable($name, $data, 'Process')
    }
}

Import-EnvFile $EnvFile
foreach ($name in @('NACOS_SERVER_ADDR', 'NACOS_USERNAME', 'NACOS_PASSWORD', 'NACOS_NAMESPACE',
                     'COST_DATASOURCE_URL', 'COST_DATASOURCE_USERNAME', 'COST_DATASOURCE_PASSWORD',
                     'COST_REDIS_HOST')) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
        throw "Required setting $name is empty in $EnvFile"
    }
}
if (-not (Test-Path -LiteralPath $JarFile)) { throw "Missing backend jar: $JarFile" }
if (-not (Test-Path -LiteralPath $ConfigFile)) { throw "Missing config: $ConfigFile" }

New-Item -ItemType Directory -Force -Path $RunDirectory, $LogDirectory | Out-Null
if (Test-Path -LiteralPath $PidFile) {
    $oldPid = (Get-Content -LiteralPath $PidFile -Raw).Trim()
    if ($oldPid -match '^\d+$' -and (Get-Process -Id ([int]$oldPid) -ErrorAction SilentlyContinue)) {
        throw "cost-server is already running, pid=$oldPid"
    }
    Remove-Item -LiteralPath $PidFile -Force
}

$java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' } else { (Get-Command java -ErrorAction Stop).Source }
if (-not (Test-Path -LiteralPath $java)) { throw "Java executable not found: $java" }

$javaOptions = if ($env:JAVA_OPTS) { $env:JAVA_OPTS -split '\s+' } else { @('-Xms512m', '-Xmx2048m') }
$configUri = $ConfigFile.Replace('\', '/')
$arguments = @($javaOptions) + @(
    '-jar', "`"$JarFile`"",
    '--spring.profiles.active=jt',
    "--spring.config.additional-location=optional:file:$configUri"
)
$stdout = Join-Path $LogDirectory 'console.log'
$stderr = Join-Path $LogDirectory 'console-error.log'
$process = Start-Process -FilePath $java -ArgumentList $arguments -WorkingDirectory $BackendRoot `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
[IO.File]::WriteAllText($PidFile, [string]$process.Id)
Write-Host "cost-server started, pid=$($process.Id), port=$env:COST_SERVER_PORT"
Write-Host "Logs: $LogDirectory"
