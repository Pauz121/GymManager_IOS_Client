[CmdletBinding()]
param([switch]$AllStatic)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$repair = Get-Content (Join-Path $clientRoot 'docs/nutrition-fingerprint-compiler-fix-20261023.json') -Raw | ConvertFrom-Json
$path = Join-Path $clientRoot $repair.path
$source = Get-Content $path -Raw
$passed = 0
function Check([bool]$Value, [string]$Name) {
    if (!$Value) { throw "FAIL SOURCE: $Name" }
    $script:passed++; Write-Output "[PASS SOURCE] $Name"
}
function Split-FieldExpressions([string]$Value) {
    $parts = [Collections.Generic.List[string]]::new()
    $depth = 0; $quoted = $false; $escaped = $false; $start = 0
    for ($i = 0; $i -lt $Value.Length; $i++) {
        $character = $Value[$i]
        if ($quoted) {
            if ($escaped) { $escaped = $false }
            elseif ($character -eq '\') { $escaped = $true }
            elseif ($character -eq '"') { $quoted = $false }
            continue
        }
        if ($character -eq '"') { $quoted = $true; continue }
        if ($character -in '(', '[', '{') { $depth++ }
        elseif ($character -in ')', ']', '}') { $depth-- }
        elseif ($character -eq ',' -and $depth -eq 0) {
            $parts.Add($Value.Substring($start, $i - $start).Trim()); $start = $i + 1
        }
    }
    $parts.Add($Value.Substring($start).Trim())
    return $parts.ToArray()
}
Check (([regex]::Matches($source,[regex]::Escape($repair.after))).Count -eq 1) 'Exact scoped typed-expression fix is present'
. (Join-Path $PSScriptRoot 'phase67-checkpoint-source.ps1')
$original = Restore-FinalUICheckpoint $path $source
$hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($original)))
Check ($hash -eq $repair.beforeSha256) 'All policy/admission/digest code outside the fingerprint function is byte-identical'
$oldBody = [regex]::Match($repair.before,'(?s)return \[\s*(.*?)\s*\]\.map').Groups[1].Value
$base = [regex]::Match($repair.after,'(?s)var fields: \[String\] = \[\s*(.*?)\s*\]').Groups[1].Value
$provenance = [regex]::Match($repair.after,'(?s)let provenance: \[String\] = \[\s*(.*?)\s*\]').Groups[1].Value
$oldFields = @(Split-FieldExpressions $oldBody)
$newFields = @(Split-FieldExpressions $base) + @(Split-FieldExpressions $provenance)
$newFields += @([regex]::Matches($repair.after,'(?m)^\s*fields\.append\((?!contentsOf)(.*)\)\s*$') | ForEach-Object { $_.Groups[1].Value })
Check ($oldFields.Count -eq 30 -and $newFields.Count -eq 30) 'Same30 legacy serialized fields'
for ($i = 0; $i -lt $oldFields.Count; $i++) {
    $oldExpression = [regex]::Replace($oldFields[$i],'\s+','')
    $newExpression = [regex]::Replace($newFields[$i],'\s+','')
    Check ($oldExpression -ceq $newExpression) "Field expression/order unchanged:$($i + 1)"
}
foreach ($typedStep in @('let sortedCatalog: [ClientFoodCatalogItem]','let records: [String]','var fields: [String]','let provenance: [String]','let framedFields: [String]','let serializedCatalog: String')) {
    Check ($repair.after.Contains($typedStep)) "Bounded explicit type:$typedStep"
}
Check ($repair.after.Contains('return item.id.uuidString + ":unreviewed"')) 'Same unreviewed marker'
Check ($repair.after.Contains('$0.id.uuidString < $1.id.uuidString')) 'Same canonical UUID sort'
Check ($repair.after.Contains('String(field.utf8.count)') -and $repair.after.Contains('return byteCount + ":" + field')) 'Same UTF8 length framing'
Check ($repair.after.Contains('records.joined(separator: "\n")') -and $repair.after.Contains('return digest(serializedCatalog)')) 'Same newline record separator and SHA256 input'
$native = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientNutritionFingerprintTests.swift') -Raw
foreach ($i in 1..6) {
    Check (([regex]::Matches($native,('func testPF{0:D2}' -f $i))).Count -eq 1) ("PF{0:D2} native regression definition present—NOT RUN" -f $i)
}
Check ($native -match '6f4f3da8a24f583fc6bf64856afaf5bb68e8ec2cca53fe0184cc0e8a70d0fd81' -and $native -match '54e40012162bdcb6b63d4b939e98fddba6ec3e738ed0e99ef899dbecb2fa1c3e') 'Golden legacy-format vectors cover reviewed and UTF8/missing-nutrient payloads'
Write-Output "Nutrition fingerprint compiler-fix source checks passed:$passed. NOT a Swift/Xcode compilation."
if ($AllStatic) {
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'validate-ui-final.ps1') -AllStatic
    if ($LASTEXITCODE -ne 0) { throw 'Full source regression failed' }
}
