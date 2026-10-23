[CmdletBinding()]
param([switch]$AllStatic)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$repair = Get-Content (Join-Path $clientRoot 'docs/nutrition-generator-exclusivity-fix-20261023.json') -Raw | ConvertFrom-Json
$path = Join-Path $clientRoot $repair.path
$source = Get-Content $path -Raw
$passed = 0
function Check([bool]$Value, [string]$Name) {
    if (!$Value) { throw "FAIL SOURCE: $Name" }
    $script:passed++; Write-Output "[PASS SOURCE] $Name"
}

Check (([regex]::Matches($source, [regex]::Escape($repair.after))).Count -eq 1) 'Exact scoped two-statement exclusivity fix is present'
Check (!$source.Contains($repair.before)) 'No whole-plan read in metadata mutation expression'
Check ($repair.after -ceq ("            let structuralSignature = ClientNutritionPlanValidator.signature(plan)" + [char]10 + "            plan.generationMetadata?.structuralSignature = structuralSignature" + [char]10)) 'Signature is evaluated before the separate metadata write'
. (Join-Path $PSScriptRoot 'phase67-checkpoint-source.ps1')
$original = Restore-FinalUICheckpoint $path $source
$hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($original)))
Check ($hash -eq $repair.beforeSha256) 'Entire generator outside the exact assignment remains byte-identical'
$metadataIndex = $source.IndexOf('plan.generationMetadata = ClientNutritionGenerationMetadata(')
$signatureIndex = $source.IndexOf('let structuralSignature = ClientNutritionPlanValidator.signature(plan)')
$validationIndex = $source.IndexOf('if ClientNutritionPlanValidator.inspect(plan, context: context, catalog: catalog).isEmpty')
$editingIndex = $source.IndexOf('return ClientPlanEditing.beginNutrition(plan)')
Check ($metadataIndex -ge 0 -and $metadataIndex -lt $signatureIndex) 'All metadata is initialized before signature calculation'
Check ($validationIndex -gt $signatureIndex -and $editingIndex -gt $validationIndex) 'Existing validation and editing provenance still follow signing'
$native = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientNutritionGeneratorMetadataTests.swift') -Raw
foreach ($name in @('testNG01GeneratedSignatureMatchesCompletedPlan', 'testNG02MetadataSignatureSurvivesCodableRoundTrip')) {
    Check (([regex]::Matches($native, [regex]::Escape('func ' + $name + '('))).Count -eq 1) ("Native regression definition present, NOT RUN: " + $name)
}
Check ($native.Contains('XCTAssertEqual(metadata.structuralSignature, ClientNutritionPlanValidator.signature(plan))')) 'Native regression checks the actual generated signature'
Check ($native.Contains('XCTAssertEqual(decoded.generationMetadata, plan.generationMetadata)')) 'Native round-trip regression checks metadata preservation, not database persistence'
Write-Output "Nutrition generator exclusivity source checks passed: $passed. Swift/Xcode and XCTest NOT RUN."
if ($AllStatic) {
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'validate-nutrition-fingerprint.ps1') -AllStatic
    if ($LASTEXITCODE -ne 0) { throw 'Full source regression failed' }
}
