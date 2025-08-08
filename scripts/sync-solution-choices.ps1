param(
    [string]$JsonPath = "solutions.json",
    [string[]]$WorkflowPaths = @(
        ".github/workflows/export-and-branch-solution.yml",
        ".github/workflows/release-action-call.yml"
    )
)

if (-not (Test-Path $JsonPath)) {
    Write-Error "JSON file not found: $JsonPath"
    exit 1
}

$solutions = Get-Content -Raw -Path $JsonPath | ConvertFrom-Json
if (-not $solutions -or $solutions.Count -eq 0) {
    Write-Error "solutions.json is empty. Provide at least one solution name."
    exit 1
}

# Normalize, dedupe, sort
$names = $solutions | Where-Object { $_ -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() } | Select-Object -Unique | Sort-Object
if ($names.Count -eq 0) {
    Write-Error "No valid solution names after normalization."
    exit 1
}

$changed = $false
function Find-Index {
    param(
        [object[]]$Array,
        [scriptblock]$Predicate
    )
    for ($i = 0; $i -lt $Array.Count; $i++) {
        if (& $Predicate $Array[$i]) { return $i }
    }
    return -1
}

foreach ($wf in $WorkflowPaths) {
    if (-not (Test-Path $wf)) { Write-Warning "Workflow not found: $wf"; continue }
    $content = Get-Content -Raw -Path $wf

    # Find the start marker line to derive indentation
    $lines = $content -replace "\r\n?", "`n" -split "`n"
    $startIndex = Find-Index -Array $lines -Predicate { param($l) $l -match "# GENERATED-OPTIONS-START" }
    $endIndex   = Find-Index -Array $lines -Predicate { param($l) $l -match "# GENERATED-OPTIONS-END" }

    if ($startIndex -lt 0 -or $endIndex -lt 0 -or $endIndex -le $startIndex) {
        Write-Warning "Markers not found or malformed in $wf; skipping"
        continue
    }

    # Compute indentation from the start marker line
    $markerLine = $lines[$startIndex]
    $indent = ([regex]::Match($markerLine, '^(\s*)').Groups[1].Value)

    # Build new block between markers
    $items = $names | ForEach-Object { "$indent- $_" }

    # Replace lines between markers (exclusive) with our items
    $newLines = @()
    if ($startIndex -gt 0) { $newLines += $lines[0..$startIndex] } else { $newLines += $lines[0] }
    $newLines += $items
    $newLines += $lines[$endIndex..($lines.Count-1)]

    $newContent = ($newLines -join "`n")
    if ($newContent -ne $content) {
        Set-Content -NoNewline -Path $wf -Value $newContent
        Write-Host "Updated options in $wf"
        $changed = $true
    }
}

if ($changed) {
    Write-Host "Options updated."
} else {
    Write-Host "No changes needed."
}
exit 0
