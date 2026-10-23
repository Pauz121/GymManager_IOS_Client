# Explicit5D adapter: reverse ONLY the two reviewed UI diffs; historical baselines stay immutable.
function Restore-NutritionUICheckpoint([string]$Path, [string]$Source) {
    $patches = Get-Content (Join-Path $clientRoot 'docs/nutrition-ui-approved-patches-20261023.json') -Raw | ConvertFrom-Json
    $normalized = $Path.Replace('\','/')
    foreach ($patch in $patches) {
        if ($normalized.EndsWith('/' + $patch.path)) {
            $matches = [regex]::Matches($Source, [regex]::Escape($patch.after))
            if ($matches.Count -ne 1) { throw "5D approved patch drift: $($patch.path). Review/update the explicit patch; NEVER reset a baseline." }
            return $Source.Replace($patch.after, $patch.before)
        }
    }
    return $Source
}
function Get-NutritionUICheckpointHash([string]$Path) {
    $source = Get-Content -LiteralPath $Path -Raw
    if ($FinalUI67) {
        . (Join-Path $PSScriptRoot 'phase67-checkpoint-source.ps1')
        $source = Restore-FinalUICheckpoint $Path $source
    }
    if ($NutritionUI) { $source = Restore-NutritionUICheckpoint $Path $source }
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($source)))
}
