# Explicit FINAL UI67 stage plus the separately audited post-release compiler fix.
# Historical baselines stay immutable; compiler fix changes serialization structure, NOT bytes.
function Restore-FinalUICheckpoint([string]$Path, [string]$Source) {
    $patches = Get-Content (Join-Path $clientRoot 'docs/phase67-approved-patches-20261023.json') -Raw | ConvertFrom-Json
    $normalized = $Path.Replace('\','/')
    $compileFix = Get-Content (Join-Path $clientRoot 'docs/nutrition-fingerprint-compiler-fix-20261023.json') -Raw | ConvertFrom-Json
    if ($normalized.EndsWith('/' + $compileFix.path)) {
        $matches = [regex]::Matches($Source, [regex]::Escape($compileFix.after))
        if ($matches.Count -ne 1) { throw 'Nutrition fingerprint compiler-fix drift; review exact change, NEVER reset baselines.' }
        $original = $Source.Replace($compileFix.after, $compileFix.before)
        $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($original)))
        if ($hash -ne $compileFix.beforeSha256) { throw 'Out-of-scope Nutrition policy change outside compiler expression fix.' }
        return $original
    }
    foreach ($patch in $patches) {
        if ($normalized.EndsWith('/' + $patch.path)) {
            $matches = [regex]::Matches($Source, [regex]::Escape($patch.after))
            if ($matches.Count -ne 1) { throw "Phase67 approved patch drift: $($patch.path). NEVER reset historical baselines." }
            $restored = $Source.Replace($patch.after, $patch.before)
            $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($restored)))
            if ($hash -ne $patch.beforeSha256) { throw "Phase67 out-of-scope source drift: $($patch.path)" }
            return $restored
        }
    }
    return $Source
}
