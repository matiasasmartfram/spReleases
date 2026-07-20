param(
    [string]$Project = "concentrador",
    [string]$Version = "9.4.2"
)

$mdFile = "analisis_${Project}_${Version}.md"
$htmlFile = "releases_${Project}_${Version}.html"

Write-Host "Leyendo $mdFile ..."
$lines = Get-Content $mdFile -Encoding UTF8

function HtmlEscape([string]$text) {
    $text = $text -replace '&', '&amp;'
    $text = $text -replace '<', '&lt;'
    $text = $text -replace '>', '&gt;'
    return $text
}

function LinesToHtml([string[]]$lines) {
    return ($lines | ForEach-Object { HtmlEscape $_ }) -join "`n"
}

# --- Parse md into structured data ---
$meta = @{
    version    = $Version
    fecha      = "[Pendiente]"
    aws        = "[Pendiente]"
    jira       = "[Pendiente]"
    commits    = @()
    intro      = ""
    conclusion = ""
}

$files = [System.Collections.Generic.List[hashtable]]::new()
$currentFile = $null

$STATE_NONE         = 0
$STATE_INTRO        = 1
$STATE_MODIF        = 2
$STATE_ANTES        = 3
$STATE_DESPUES      = 4
$STATE_CONCL_FILE   = 5
$STATE_CONCL_GEN    = 6
$STATE_COMMITS      = 7

$state = $STATE_NONE
$buffer = [System.Collections.Generic.List[string]]::new()
$inCodeBlock = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    # Extract metadata
    if ($line -match '^\*\*Fecha de publicación:\*\* (.+)') { $meta.fecha = $Matches[1].Trim() }
    if ($line -match '^\*\*AWS Task ID:\*\* (.+)')          { $meta.aws   = $Matches[1].Trim() }
    if ($line -match '^\*\*JIRA Task:\*\* (.+)')            { $meta.jira  = $Matches[1].Trim() }
    if ($line -match '^## Commits Analizados') { $state = $STATE_COMMITS; continue }

    if ($state -eq $STATE_COMMITS) {
        if ($line -match '^\d+\. \`(.+?)\` - (.+)') {
            $meta.commits += "$($Matches[1]) — $($Matches[2])"
        }
        if ($line -match '^---') { $state = $STATE_NONE }
        continue
    }

    # Intro note
    if ($line -match '<!-- pendiente: nota introductoria' ) { $state = $STATE_INTRO; continue }
    if ($state -eq $STATE_INTRO) {
        if ($line -match '^---') { $meta.intro = $buffer -join ' '; $buffer.Clear(); $state = $STATE_NONE }
        elseif ($line.Trim() -ne '') { $buffer.Add($line.Trim()) }
        continue
    }
    # If intro already filled (no pendiente comment left)
    if ($state -eq $STATE_NONE -and $line -match '^Este release ' -and $meta.intro -eq '') {
        $meta.intro = $line.Trim()
        continue
    }

    # New file section
    if ($line -match '^### Archivo: `(.+?)`') {
        if ($currentFile -ne $null) { $files.Add($currentFile) }
        $currentFile = @{
            path       = $Matches[1]
            modif      = ""
            antes      = [System.Collections.Generic.List[string]]::new()
            despues    = [System.Collections.Generic.List[string]]::new()
            conclusion = ""
        }
        $state = $STATE_NONE
        $buffer.Clear()
        $inCodeBlock = $false
        continue
    }

    # Subsections within a file
    if ($line -match '^#### Modificaciones Identificadas') {
        $state = $STATE_MODIF; $buffer.Clear(); $inCodeBlock = $false; continue
    }
    if ($line -match '^#### Código ANTES') {
        if ($state -eq $STATE_MODIF -and $currentFile) { $currentFile.modif = ($buffer | Where-Object { $_ -notmatch '^<!--' }) -join "`n"; $buffer.Clear() }
        $state = $STATE_ANTES; $inCodeBlock = $false; continue
    }
    if ($line -match '^#### Código DESPUÉS') {
        $state = $STATE_DESPUES; $inCodeBlock = $false; continue
    }
    if ($line -match '^#### Conclusión del Archivo') {
        $state = $STATE_CONCL_FILE; $buffer.Clear(); $inCodeBlock = $false; continue
    }
    if ($line -match '^## Conclusión General del Análisis') {
        if ($currentFile -ne $null) {
            if ($buffer.Count -gt 0) { $currentFile.conclusion = ($buffer | Where-Object { $_ -notmatch '^<!--' }) -join "`n" }
            $files.Add($currentFile)
            $currentFile = $null
        }
        $state = $STATE_CONCL_GEN; $buffer.Clear(); continue
    }

    # Accumulate content per state
    switch ($state) {
        $STATE_MODIF {
            if ($line -notmatch '^<!--' -and $line -notmatch '^---') { $buffer.Add($line) }
        }
        $STATE_ANTES {
            if ($line -eq '```javascript' -or $line -eq '```') { $inCodeBlock = !$inCodeBlock; continue }
            if ($inCodeBlock -and $currentFile) { $currentFile.antes.Add($line) }
        }
        $STATE_DESPUES {
            if ($line -eq '```javascript' -or $line -eq '```') { $inCodeBlock = !$inCodeBlock; continue }
            if ($inCodeBlock -and $currentFile) { $currentFile.despues.Add($line) }
        }
        $STATE_CONCL_FILE {
            if ($line -notmatch '^<!--' -and $line -notmatch '^---' -and $line.Trim() -ne '') { $buffer.Add($line.Trim()) }
            if ($line -match '^---') {
                if ($currentFile) { $currentFile.conclusion = $buffer -join "`n" }
                $buffer.Clear()
                $state = $STATE_NONE
            }
        }
        $STATE_CONCL_GEN {
            if ($line -notmatch '^<!--' -and $line.Trim() -ne '') { $buffer.Add($line.Trim()) }
        }
    }
}

if ($buffer.Count -gt 0 -and $state -eq $STATE_CONCL_GEN) {
    $meta.conclusion = $buffer -join "`n"
}

Write-Host "Archivos encontrados: $($files.Count)"
foreach ($f in $files) {
    Write-Host "  - $($f.path) | ANTES=$($f.antes.Count) líneas | DESPUÉS=$($f.despues.Count) líneas"
}

# --- Build HTML ---
$commitStr = $meta.commits -join "<br>"
$descBreve = if ($meta.intro) { [System.Web.HttpUtility]::HtmlEncode($meta.intro) } else { "Release de mantenimiento" }
# don't double-escape — meta.intro is plain text, render it directly
$descBreve = HtmlEscape $meta.intro

$sb = [System.Text.StringBuilder]::new(1MB * 20)

[void]$sb.Append(@"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Notas de Release: Concentrador $Version</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css" />
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700&family=Fira+Code:wght@400&display=swap');
        :root {
            --bg-color: #f4f7f9;
            --card-bg-color: #ffffff;
            --text-color: #212529;
            --text-muted-color: #6c757d;
            --border-color: #dee2e6;
            --primary-color: #0056b3;
            --analysis-bg: #e6f7ff;
            --analysis-border: #91d5ff;
            --deployment-bg: #f0fdf4;
            --deployment-border: #86efac;
        }
        body { font-family: 'Inter', sans-serif; background-color: var(--bg-color); color: var(--text-color); margin: 0; padding: 2em; line-height: 1.7; }
        .container { max-width: 960px; margin: 0 auto; }
        .main-header { background-color: var(--card-bg-color); padding: 2em; border-radius: 8px; border: 1px solid var(--border-color); margin-bottom: 2.5em; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
        .main-header h1 { margin: 0 0 0.25em 0; font-size: 2.2em; color: var(--primary-color); }
        .main-header p { margin: 0; font-size: 1.1em; color: var(--text-muted-color); }
        .deployment-info-box { background-color: var(--deployment-bg); border-left: 4px solid var(--deployment-border); padding: 1em 1.5em; margin-bottom: 2.5em; border-radius: 4px; }
        .deployment-info-box h4 { margin-top: 0; font-size: 1.2em; color: #166534; }
        .deployment-info-box p { margin: 0.5em 0 0 0; font-family: 'Fira Code', monospace; font-size: 0.95em; }
        .service-section { margin-bottom: 3em; }
        .service-section > h2 { font-size: 1.8em; color: var(--primary-color); border-bottom: 2px solid var(--border-color); padding-bottom: 0.5em; margin-bottom: 1.5em; }
        .component-card { background-color: var(--card-bg-color); border: 1px solid var(--border-color); border-radius: 8px; margin-bottom: 2em; box-shadow: 0 4px 12px rgba(0,0,0,0.05); overflow: hidden; }
        .component-header { padding: 1em 1.5em; background-color: #fafafa; border-bottom: 1px solid var(--border-color); cursor: pointer; list-style: none; }
        .component-header::-webkit-details-marker { display: none; }
        .component-header h3 { margin: 0; font-family: 'Fira Code', monospace; font-size: 1.2em; }
        .component-body { padding: 1.5em; }
        .component-body h4 { margin-top: 1.5em; font-size: 1.2em; color: #343a40; }
        .analysis-box { background-color: var(--analysis-bg); border-left: 4px solid var(--analysis-border); padding: 1em 1.5em; margin-top: 1.5em; border-radius: 4px; }
        .analysis-box h4 { margin-top: 0; font-size: 1.1em; color: var(--primary-color); }
        pre[class*="language-"] { padding: 1.2em !important; margin: 1em 0 !important; border-radius: 6px; font-family: 'Fira Code', monospace !important; font-size: 0.9em !important; line-height: 1.5 !important; border: 1px solid var(--border-color); white-space: pre-wrap !important; word-break: break-all !important; overflow-wrap: break-word !important; background-color: #2d2d2d; color: #ccc; }
    </style>
</head>
<body>
<div class="container">
    <header class="main-header">
        <h1>Notas de Release: Concentrador $Version</h1>
        <p>$descBreve</p>
    </header>
    <div class="deployment-info-box">
        <h4>Información de Despliegue</h4>
        <p><b>Versión:</b> $Version</p>
        <p><b>Fecha de Despliegue:</b> $($meta.fecha)</p>
        <p><b>AWS Task:</b> $($meta.aws)</p>
        <p><b>JIRA Task:</b> $($meta.jira)</p>
        <p><b>Commits:</b> $commitStr</p>
    </div>
    <section id="summary" class="service-section">
        <h2>Resumen General de la Versión</h2>
        <p>Esta versión limita el proceso de verificación de cambios de UTC —y sus notificaciones por mail— exclusivamente al entorno de producción. Antes, dicho proceso podía ejecutarse también en entornos de desarrollo o testing, generando alertas innecesarias. Además, el horario del chequeo diario automático se desplaza a las 4:00 AM UTC, un momento de menor actividad operativa.</p>
    </section>
    <section id="technical-analysis" class="service-section">
        <h2>Análisis Técnico Detallado</h2>
"@)

foreach ($f in $files) {
    $pathEscaped = HtmlEscape $f.path
    $modifHtml   = ($f.modif.Split("`n") | ForEach-Object {
        $l = $_.Trim()
        if ($l -eq '') { '' }
        elseif ($l -match '^\d+\.') { "<p><b>$( HtmlEscape $l )</b></p>" }
        else { "<p>$( HtmlEscape $l )</p>" }
    }) -join "`n"
    $antesHtml   = LinesToHtml $f.antes
    $despuesHtml = LinesToHtml $f.despues
    $conclHtml   = HtmlEscape $f.conclusion

    [void]$sb.Append(@"

        <details class="component-card" open>
            <summary class="component-header">
                <h3>$pathEscaped</h3>
            </summary>
            <div class="component-body">
                <div class="analysis-box">
                    <h4>Modificaciones Identificadas</h4>
                    $modifHtml
                </div>
                <h4>Código ANTES</h4>
                <pre class="language-javascript"><code>$antesHtml</code></pre>
                <h4>Código DESPUÉS</h4>
                <pre class="language-javascript"><code>$despuesHtml</code></pre>
                <div class="analysis-box">
                    <h4>Conclusión del Archivo</h4>
                    <p>$conclHtml</p>
                </div>
            </div>
        </details>
"@)
}

[void]$sb.Append(@"

    </section>
    <section id="conclusion" class="service-section">
        <h2>Conclusión General</h2>
        <p>$( HtmlEscape $meta.conclusion )</p>
    </section>
</div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/plugins/autoloader/prism-autoloader.min.js"></script>
</body>
</html>
"@)

Write-Host "Escribiendo $htmlFile ..."
[System.IO.File]::WriteAllText("$PSScriptRoot\$htmlFile", $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "OK: $htmlFile ($([Math]::Round($sb.Length / 1KB)) KB)"
