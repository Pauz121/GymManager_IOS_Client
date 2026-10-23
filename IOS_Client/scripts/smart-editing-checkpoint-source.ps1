# Reverses ONLY the explicitly recorded Smart Plan Editing patch for old preservation checks.
function Restore-SmartEditingCheckpoint([string]$Path, [string]$Source) {
    $patchSet = Get-Content (Join-Path $clientRoot 'docs/smart-plan-editing-approved-patches-20261023.json') -Raw | ConvertFrom-Json
    $normalizedPath = $Path.Replace('\','/')
    $text = $Source.Replace([string]([char]13), '')
    foreach ($patch in $patchSet.patches) {
        if (!$normalizedPath.EndsWith($patch.path, [StringComparison]::Ordinal)) { continue }
        $occurrences = [regex]::Matches($text, [regex]::Escape($patch.after)).Count
        if ($occurrences -ne 1) { throw "Smart-edit patch not uniquely matched: $($patch.path)" }
        $text = $text.Replace($patch.after, $patch.before)
    }
    return $text
}
