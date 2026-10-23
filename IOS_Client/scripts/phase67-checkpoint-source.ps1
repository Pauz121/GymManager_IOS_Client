# Explicit FINAL UI67 presentation-only stage. Historical baselines are immutable.
function Restore-FinalUICheckpoint([string]$Path, [string]$Source) {
    $patches = Get-Content (Join-Path $clientRoot 'docs/phase67-approved-patches-20261023.json') -Raw | ConvertFrom-Json
    $normalized = $Path.Replace('\','/')
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
