<#
.SYNOPSIS
  Genera el skeleton `analisis_{proyecto}_{version}.md` para el flujo de releases.

.DESCRIPTION
  Precomputa el trabajo mecánico previo al skill `analisis-generator`:
  - Lee `.agents/release-config.json` para resolver el path del repo del proyecto.
  - Para cada commit indicado, extrae mensaje, archivos tocados (A/M/D/R) y binarios.
  - Para cada archivo textual: usa `git show {hash}~1:{file}` (ANTES) y `git show {hash}:{file}` (DESPUÉS).
  - Enmascara secretos con regex conservador dentro de los bloques ANTES/DESPUÉS.
  - Escribe el `.md` en UTF-8 sin BOM.

  El script no redacta prosa ni conclusiones — deja marcadores `<!-- pendiente -->`
  para que `analisis-generator` los complete.

.EXAMPLE
  pwsh -File .\prepare_release.ps1 `
    -Project concentrador -Version 9.4.0 `
    -Commits 005f27788b373244e36dba744b075e36399dfc4c `
    -AwsTaskId "aws 299" -JiraTask "GITSFP-1550" -Fecha "01/06/2026"
#>

param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('concentrador', 'platform', 'backoffice')]
  [string]$Project,

  [Parameter(Mandatory = $true)]
  [string]$Version,

  [Parameter(Mandatory = $true)]
  [string[]]$Commits,

  [string]$AwsTaskId = '[Pendiente]',
  [string]$JiraTask  = '[Pendiente]',
  [string]$Fecha     = '[Pendiente]',
  [string]$OutputDir = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding           = [System.Text.UTF8Encoding]::new($false)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
$configPath = Join-Path $PSScriptRoot '.agents\release-config.json'
if (-not (Test-Path $configPath)) {
  Write-Error "No se encontró el config: $configPath"
  exit 1
}
$cfg = Get-Content -Raw -Path $configPath -Encoding UTF8 | ConvertFrom-Json

$repoEntry = $cfg.repos.$Project
if (-not $repoEntry -or -not $repoEntry.path) {
  Write-Error "El proyecto '$Project' no está mapeado en release-config.json"
  exit 1
}
$repoPath = $repoEntry.path
if (-not (Test-Path $repoPath)) {
  Write-Error "El repo configurado para '$Project' no existe: $repoPath"
  exit 1
}
if (-not (Test-Path (Join-Path $repoPath '.git'))) {
  Write-Error "El path '$repoPath' no es un repositorio git"
  exit 1
}
$defaultLang = $repoEntry.defaultLang
if (-not $defaultLang) { $defaultLang = 'text' }

$langByExt = @{}
foreach ($p in $cfg.langByExtension.PSObject.Properties) {
  $langByExt[$p.Name.ToLowerInvariant()] = $p.Value
}

$excludePatterns = @($cfg.excludePaths)
$maxLinesHint    = [int]$cfg.maxLinesHint
if ($maxLinesHint -le 0) { $maxLinesHint = 1500 }

$projectDisplay = @{ concentrador = 'Concentrador'; platform = 'Platform'; backoffice = 'Backoffice' }[$Project]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Invoke-Git {
  param([string[]]$GitArgs)
  # Ejecuta git con -C $repoPath y devuelve stdout como string.
  # Lanza error si git escribió a stderr y exitcode != 0.
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName               = 'git'
  $psi.WorkingDirectory       = $repoPath
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute        = $false
  $psi.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
  $psi.StandardErrorEncoding  = [System.Text.UTF8Encoding]::new($false)
  foreach ($a in $GitArgs) { [void]$psi.ArgumentList.Add($a) }

  $proc = [System.Diagnostics.Process]::Start($psi)
  $out = $proc.StandardOutput.ReadToEnd()
  $err = $proc.StandardError.ReadToEnd()
  $proc.WaitForExit()
  if ($proc.ExitCode -ne 0) {
    throw "git $($GitArgs -join ' ') -> exit $($proc.ExitCode): $err"
  }
  return $out
}

function Try-GitShow {
  param([string]$Hash, [string]$File)
  # Devuelve $null si el objeto no existe (archivo nuevo en ANTES, o eliminado en DESPUÉS).
  try { return Invoke-Git @('show', "$Hash`:$File") }
  catch { return $null }
}

function Get-CommitMessage {
  param([string]$Hash)
  return (Invoke-Git @('log', '-1', '--format=%s', $Hash)).TrimEnd("`r", "`n")
}

function Get-ChangedFiles {
  param([string]$Hash)
  # Devuelve List de PSCustomObject { Status, Path, OldPath }
  $raw = Invoke-Git @('diff', '--name-status', '-M', "$Hash~1", $Hash)
  $result = [System.Collections.Generic.List[object]]::new()
  foreach ($line in $raw -split "`n") {
    $line = $line.TrimEnd("`r")
    if (-not $line) { continue }
    $parts = $line -split "`t"
    $status = $parts[0].Substring(0, 1)
    if ($status -eq 'R') {
      $result.Add([pscustomobject]@{ Status = 'R'; OldPath = $parts[1]; Path = $parts[2] })
    } else {
      $result.Add([pscustomobject]@{ Status = $status; OldPath = $null; Path = $parts[1] })
    }
  }
  return ,$result
}

function Get-BinaryFiles {
  param([string]$Hash)
  # `git diff --numstat` devuelve "-\t-\tpath" para binarios.
  $raw = Invoke-Git @('diff', '--numstat', "$Hash~1", $Hash)
  $result = [System.Collections.Generic.List[string]]::new()
  foreach ($line in $raw -split "`n") {
    $line = $line.TrimEnd("`r")
    if (-not $line) { continue }
    $parts = $line -split "`t"
    if ($parts.Length -ge 3 -and $parts[0] -eq '-' -and $parts[1] -eq '-') {
      $result.Add($parts[2])
    }
  }
  # Wrap con "," para preservar el tipo al retornar (evita unwrapping de colecciones vacías).
  return ,$result
}

function Test-ExcludedPath {
  param([string]$Path)
  foreach ($pattern in $excludePatterns) {
    if ($pattern.EndsWith('/')) {
      # Prefijo de directorio.
      $prefix = $pattern.TrimEnd('/')
      if ($Path -like "$prefix/*" -or $Path -eq $prefix) { return $true }
    } elseif ($Path -like $pattern) {
      return $true
    } else {
      # También chequear match contra el nombre de archivo.
      $name = Split-Path $Path -Leaf
      if ($name -like $pattern) { return $true }
    }
  }
  return $false
}

function Get-Language {
  param([string]$Path)
  $ext = ([System.IO.Path]::GetExtension($Path)).ToLowerInvariant()
  if ($langByExt.ContainsKey($ext)) { return $langByExt[$ext] }
  return $defaultLang
}

function Mask-Secrets {
  param([string]$Content)
  if (-not $Content) { return $Content }

  # 1) Bearer tokens
  $Content = [regex]::Replace($Content, 'Bearer\s+[A-Za-z0-9\.\-_=]{20,}', 'Bearer "xxx"')

  # 2) JWTs
  $Content = [regex]::Replace($Content, 'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+', '"xxx"')

  # 3) Asignaciones tipo api_key = "..." / password: "..."
  $assign = [regex]'(?i)(api[_-]?key|apikey|secret|token|password|passwd|pwd|access[_-]?key)(\s*[:=]\s*)([''"])([^''"\s]{8,})([''"])'
  $Content = $assign.Replace($Content, {
    param($m)
    "$($m.Groups[1].Value)$($m.Groups[2].Value)$($m.Groups[3].Value)xxx$($m.Groups[5].Value)"
  })

  # 4) MongoDB URI: enmascara solo el password
  $mongo = [regex]'(mongodb(?:\+srv)?:\/\/[^:\s]+:)([^@\s]+)(@)'
  $Content = $mongo.Replace($Content, '${1}xxx${3}')

  # 5) AWS access key IDs
  $Content = [regex]::Replace($Content, 'AKIA[0-9A-Z]{16}', '"xxx"')

  return $Content
}

function Get-LineCount {
  param([string]$Text)
  if (-not $Text) { return 0 }
  return ($Text -split "`n").Length
}

# ---------------------------------------------------------------------------
# Precargar mensajes de commits y armar índice
# ---------------------------------------------------------------------------
$commitMessages = [ordered]@{}
foreach ($h in $Commits) {
  $commitMessages[$h] = Get-CommitMessage -Hash $h
}

# ---------------------------------------------------------------------------
# Construcción del .md
# ---------------------------------------------------------------------------
$sb = [System.Text.StringBuilder]::new()

[void]$sb.AppendLine("# Análisis de Release - $projectDisplay $Version")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Versión:** $Version")
[void]$sb.AppendLine("**AWS Task ID:** $AwsTaskId")
[void]$sb.AppendLine("**JIRA Task:** $JiraTask")
[void]$sb.AppendLine("**Fecha de publicación:** $Fecha")
[void]$sb.AppendLine("**Proyecto:** $projectDisplay")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("<!-- pendiente: nota introductoria del release (analisis-generator) -->")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Commits Analizados")

$idx = 1
foreach ($h in $Commits) {
  [void]$sb.AppendLine("$idx. ``$h`` - $($commitMessages[$h])")
  $idx++
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

foreach ($h in $Commits) {
  $msg = $commitMessages[$h]
  [void]$sb.AppendLine("## Commit: ``$h`` — $msg")
  [void]$sb.AppendLine("")

  $files    = Get-ChangedFiles -Hash $h
  $binaries = Get-BinaryFiles  -Hash $h

  foreach ($f in $files) {
    if (Test-ExcludedPath -Path $f.Path) { continue }
    if ($f.OldPath -and (Test-ExcludedPath -Path $f.OldPath)) { continue }

    [void]$sb.AppendLine("### Archivo: ``$($f.Path)``")
    [void]$sb.AppendLine("")

    if ($f.Status -eq 'R' -and $f.OldPath) {
      [void]$sb.AppendLine("> Renombrado desde ``$($f.OldPath)``")
      [void]$sb.AppendLine("")
    }

    # ¿Binario?
    if ($binaries.Contains($f.Path) -or ($f.OldPath -and $binaries.Contains($f.OldPath))) {
      [void]$sb.AppendLine("> Archivo binario — sin diff textual")
      [void]$sb.AppendLine("")
      [void]$sb.AppendLine("#### Modificaciones Identificadas")
      [void]$sb.AppendLine("")
      [void]$sb.AppendLine("<!-- pendiente: analisis-generator lo llena -->")
      [void]$sb.AppendLine("")
      [void]$sb.AppendLine("#### Conclusión del Archivo")
      [void]$sb.AppendLine("")
      [void]$sb.AppendLine("<!-- pendiente: analisis-generator lo llena -->")
      [void]$sb.AppendLine("")
      [void]$sb.AppendLine("---")
      [void]$sb.AppendLine("")
      continue
    }

    $lang = Get-Language -Path $f.Path

    switch ($f.Status) {
      'A' {
        $before = $null
        $after  = Try-GitShow -Hash $h -File $f.Path
      }
      'D' {
        $before = Try-GitShow -Hash "$h~1" -File $f.Path
        $after  = $null
      }
      'R' {
        $before = Try-GitShow -Hash "$h~1" -File $f.OldPath
        $after  = Try-GitShow -Hash $h     -File $f.Path
      }
      default {
        # 'M' u otros
        $before = Try-GitShow -Hash "$h~1" -File $f.Path
        $after  = Try-GitShow -Hash $h     -File $f.Path
      }
    }

    $before = Mask-Secrets $before
    $after  = Mask-Secrets $after

    $beforeLines = Get-LineCount $before
    $afterLines  = Get-LineCount $after
    $maxLines    = [Math]::Max($beforeLines, $afterLines)

    [void]$sb.AppendLine("#### Modificaciones Identificadas")
    [void]$sb.AppendLine("")
    if ($maxLines -ge $maxLinesHint) {
      [void]$sb.AppendLine("<!-- HINT: archivo grande ($maxLines líneas) — priorizar cambios estructurales -->")
    }
    [void]$sb.AppendLine("<!-- pendiente: analisis-generator lo llena -->")
    [void]$sb.AppendLine("")

    # Código ANTES
    [void]$sb.AppendLine("#### Código ANTES")
    [void]$sb.AppendLine("``````$lang")
    if ($null -eq $before) {
      [void]$sb.AppendLine("// (archivo nuevo)")
    } else {
      [void]$sb.Append($before)
      if (-not $before.EndsWith("`n")) { [void]$sb.AppendLine("") }
    }
    [void]$sb.AppendLine("``````")
    [void]$sb.AppendLine("")

    # Código DESPUÉS
    [void]$sb.AppendLine("#### Código DESPUÉS")
    [void]$sb.AppendLine("``````$lang")
    if ($null -eq $after) {
      [void]$sb.AppendLine("// (archivo eliminado)")
    } else {
      [void]$sb.Append($after)
      if (-not $after.EndsWith("`n")) { [void]$sb.AppendLine("") }
    }
    [void]$sb.AppendLine("``````")
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("#### Conclusión del Archivo")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("<!-- pendiente: analisis-generator lo llena -->")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
  }
}

[void]$sb.AppendLine("## Conclusión General del Análisis")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("<!-- pendiente: analisis-generator lo llena -->")
[void]$sb.AppendLine("")

# ---------------------------------------------------------------------------
# Escribir output
# ---------------------------------------------------------------------------
if (-not (Test-Path $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$outFile = Join-Path $OutputDir "analisis_${Project}_${Version}.md"
[System.IO.File]::WriteAllText($outFile, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))

Write-Host "OK: $outFile"
