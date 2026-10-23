[CmdletBinding()]
param([switch]$FinalUI67, [switch]$AllStatic, [switch]$SmartEditing, [switch]$NutritionUI)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $clientRoot 'GymManagerClient'
$NutritionEngine = $true
. (Join-Path $PSScriptRoot 'nutrition-checkpoint-source.ps1')
$failures = [Collections.Generic.List[string]]::new()
$passed = 0
function Assert-Nutrition([bool]$Value, [string]$Name) {
    if ($Value) { $script:passed++; Write-Output "[PASS SOURCE] $Name" }
    else { $script:failures.Add($Name); Write-Output "[FAIL SOURCE] $Name" }
}
function Read-Current([string]$Path) { Get-Content (Join-Path $sourceRoot $Path) -Raw }
$baseline = Get-Content (Join-Path $clientRoot 'docs/coach-nutrition-baseline-20261023.json') -Raw | ConvertFrom-Json
$allowed = @('Core/ClientNutritionGenerator.swift','Core/ClientNutritionCreation.swift','Core/ClientPersonalContent.swift',
    'Core/ClientPersonalRepository.swift','Core/ClientSessionStore.swift')
Assert-Nutrition ($baseline.files.Count -eq 73 -and !(Compare-Object ($baseline.allowedModified | Sort-Object) ($allowed | Sort-Object))) 'Immutable pre-edit73-source checkpoint;exactly5 Nutrition/shared modules authorized'
foreach ($entry in $baseline.files) {
    if ($entry.path -in $allowed) {
        if ($entry.path -eq 'Core/ClientNutritionGenerator.swift') { continue } # Existing engine intentionally upgraded; new strict source checks below.
        Assert-Nutrition ((Get-NutritionCheckpointHash (Join-Path $sourceRoot $entry.path)) -eq $entry.sha256) "Exact shared-source preservation after reversing listed Nutrition additions ONLY: $($entry.path)"
    } else {
        Assert-Nutrition ((Get-NutritionCheckpointHash (Join-Path $sourceRoot $entry.path)) -eq $entry.sha256) "Unchanged exact source bytes: $($entry.path)"
    }
}
foreach ($entry in $baseline.tests) {
    if ($entry.path -eq 'ClientNutritionCreationTests.swift') { continue }
    Assert-Nutrition ((Get-NutritionCheckpointHash (Join-Path $clientRoot "GymManagerClientTests/$($entry.path)")) -eq $entry.sha256) "Existing native definitions unchanged outside explicit EOF formatting: $($entry.path)"
}
$legacy = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientNutritionCreationTests.swift') -Raw
$masked = [regex]::Replace($legacy.Replace([string]([char]13),''), '(?s)    func testGuidedPlanUsesCatalogIDsRoundedGramsAndEditablePayload\(\) throws \{.*?\n    \}\n', '<5C_GENERATION_CONTEXT_TEST>' + [char]10)
$maskedHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($masked)))
Assert-Nutrition ($maskedHash -eq '3B64EEF00BC302BFD9859F28F2DF9AEE096915521680BB82717AABDE26C5423F') 'Only one old guided-generation test adapted;other legacy arithmetic/copy/decoder/manual tests untouched'
$contract = Read-Current 'Core/ClientNutritionCoachContract.swift'
$energy = Read-Current 'Core/ClientNutritionCoachEnergy.swift'
$food = Read-Current 'Core/ClientNutritionFoodPolicy.swift'
$solver = Read-Current 'Core/ClientNutritionPortionSolver.swift'
$generator = Read-Current 'Core/ClientNutritionGenerator.swift'
$validator = Read-Current 'Core/ClientNutritionPlanValidator.swift'
$repository = Read-Current 'Core/ClientPersonalRepository.swift'
$session = Read-Current 'Core/ClientSessionStore.swift'
$service = Read-Current 'Core/ClientNutritionCoachService.swift'
$tests = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientNutritionCoachEngineTests.swift') -Raw
$fixtures = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientNutritionCoachFixtures.swift') -Raw
foreach ($state in @('deniedTrainerManaged','underAge','pregnancyOrBreastfeeding','eatingDisorderRisk','medicalConditionRequiresProfessional','missingRequiredProfile','invalidAnthropometrics','energyTargetUnsafe','insufficientFoodData','allergyConflict')) {
    Assert-Nutrition ($contract -match $state) "Typed eligibility/error: $state"
}
Assert-Nutrition ($contract.IndexOf('guard let mode') -lt $contract.IndexOf('guard let profile') -and $contract -match 'age >= 18') 'Owner gate before profile;adults only'
Assert-Nutrition ($contract -match 'pregnantOrBreastfeeding == false' -and $contract -match 'eatingDisorderRisk == false' -and $contract -match 'clinicalNutritionRequired == false' -and $contract -match 'healthyAdultAcknowledged == true') 'Explicit health declarations required,unknown never treated as No'
Assert-Nutrition ($contract -match 'case seated, mixed, physical' -and $contract -match 'switch dailyActivity' -and $contract -notmatch 'BMI|bodyMassIndex') 'Daily occupation and exercise evidence;no disease inference'
Assert-Nutrition ($energy -match '10 \* weightKg \+ 6.25 \* heightCm - 5 \* Double\(age\)' -and $energy -match '5 : -161' -and $energy -match 'mifflin-st-jeor-simplified-1990-v1') 'Exact simplified Mifflin coefficients and equation version'
Assert-Nutrition ($energy -match 'estimatedMaintenance: maintenance' -and $energy -match 'activityVersion' -and $energy -match 'goalAdjustment: calories - maintenance') 'Unrounded RMR/TDEE inputs/evidence/modifier retained'
Assert-Nutrition ($energy -match '-0.10' -and $energy -match '0.05' -and $energy -match 'minimumEnergy = 1400' -and $energy -match 'maximumEnergy = 4500') 'Inherited modest goal modifiers;explicit unsupported-energy envelope'
Assert-Nutrition ($energy -match '1.8 : 1.6' -and $energy -match '2.0' -and $energy -match ': 1.0' -and $energy -match 'calories \* 0.30 / 9' -and $energy -match 'calories - protein \* 4 - fat \* 9') 'Context g/kg protein,30%fat,remaining carbohydrate—not universal percentage macros'
Assert-Nutrition ($energy -match 'targetAtwaterTolerance' -and $energy -match '0.20\.\.\.0.35' -and $energy -match 'protein \* 4 / calories <= 0.35') 'Macro positivity/4-4-9/fat/protein fraction checked'
foreach ($field in @('reviewVersion','reviewReference','canonicalID','sourceID','sourceURL','datasetRevision','cacheProvenance','cacheRevision','sourceServingAmount','sourceServingUnit','foodState','assessedAllergens','assessedIntolerances','portion')) {
    Assert-Nutrition ($food -match $field) "Source-grounded food evidence required: $field"
}
Assert-Nutrition ($food -match 'assessedAllergens == Set' -and $food -match 'containsAllergens.union\(evidence.traceAllergens\)' -and $food -match 'incompatibleIntolerances' -and $food -match 'compatiblePatterns.contains') 'Allergy including traces,intolerance,pattern and exclusions HARD;complete review coverage'
Assert-Nutrition ($food -notmatch 'name.contains|lowercased\(\).contains|localizedStandardContains' -and $food -match 'rows.allSatisfy' -and $food -match 'sourceGroups') 'No substring food-role inference;duplicate/conflicting IDs quarantined'
Assert-Nutrition ($food -match 'allowedMeals' -and $generator -match 'dailyUse' -and $generator -match 'occasion\(index: mealIndex' -and $validator -match 'e.allowedMeals.contains') 'Reviewed meal-occasion compatibility and least-used deterministic variety;no invented recipe metadata'
Assert-Nutrition ($food -match 'let p = item.proteinPer100g' -and $food -match 'caloriesPer100g \* 0.25' -and $food -match '\[5.0, 10.0\]') 'Missing/invalid nutrients excluded;stored energy quality tolerance;realistic5/10g or whole-piece lattice'
Assert-Nutrition ($repository -match 'e.sourceID == externalFoodID' -and $repository -match 'e.cacheRevision == updatedAt' -and $repository -match 'nutrition_coach_review' -and $repository -match 'nutritionCoachReview = try\?') 'Optional reviewed metadata tied to actual source/cache;missing/malformed review never invented'
Assert-Nutrition ($repository -match 'trainer_id.*, value: nil' -and $repository -match 'limit\(500\)') 'Existing global-only bounded catalog/manual search preserved'
Assert-Nutrition ($solver -match 'grams / 100' -and $solver -match 'for _ in 0..<40' -and $solver -match 'for _ in 0..<160' -and $solver -match 'rounded\(\) \* bounds.stepGrams' -and $solver -match 'static func refineDay') 'Bounded continuous optimization→quantization→discrete repair;whole-day fitting'
Assert-Nutrition ($generator -match 'for attempt in 0..<6' -and $generator -match 'variation \* 13' -and $generator -match 'priorities\[min\(attempt / 2' -and $generator -notmatch 'random\(|shuffled|LLM\(') 'Deterministic bounded selection/rotation and source-priority fallback;no random/LLM core'
Assert-Nutrition ($generator -match 'ClientNutritionDraft.newPlan' -and $generator -match 'ClientPersonalFood\(' -and $generator -match 'plan.source = .guided' -and $generator -match 'referenceWeekday') 'Existing plan/meals/foods/source reused;single-day structure independent of wall-clock'
Assert-Nutrition ($generator -match 'ClientNutritionPlanValidator.inspect.*isEmpty' -and $generator -match 'throw ClientNutritionGenerationEligibility.fitFailed') 'No return of failed fit or loose old15%/35%acceptance'
foreach ($issue in @('eligibility','metadata','target','catalog','food','preference','portions','days','meals','mealTotals','dayTotals','duplicate')) {
    Assert-Nutrition ($validator -match $issue) "Strict validator covers $issue"
}
Assert-Nutrition ($validator -match 'food.nutritionEvidence != e' -and $validator -match 'food.caloriesPer100g != item.caloriesPer100g' -and $validator -match 'e.portion.contains' -and $validator -match 'proteinRange.contains') 'Independent exact nutrient/evidence/portion and actual protein-range validation'
Assert-Nutrition ($validator -match 'metadata.energy != energy' -and $validator -match 'metadata.structuralSignature != signature' -and $validator -match 'metadata.catalogFingerprint !=' -and $validator -match 'answers.coachProfile != profile') 'Metadata/signature/input/catalog consistency independently recalculated'
Assert-Nutrition ($service -match 'case .active\(let identity' -and $service -match 'mode: identity.mode' -and $service -notmatch 'upsert|\.insert\(|\.rpc\(') 'Current-session generation gate;no generation writes'
Assert-Nutrition ($generator -match 'maintenance: resting \* answers.activity.coefficient' -and $generator -notmatch 'evidence = .init\(dailyActivity' -and $generator -match 'Conservative general-product protein estimate') 'Legacy estimate reuses declared factor/shared arithmetic,never fabricated workout/occupation/health evidence'
Assert-Nutrition (([regex]::Matches($session,'guard validateNutritionCoachBeforeSave')).Count -eq 2 -and $session -match 'confirmed.generationMetadata == plan.generationMetadata') 'Both save entry points validate before local stage;server read-back includes metadata'
Assert-Nutrition ($repository -match 'try await requireStandaloneNutritionOwner' -and $repository -match 'ClientNutritionPlanValidator.inspect' -and $repository -match 'session.user.id == userID' -and $repository -match 'ClientNutritionGenerationEligibility.deniedTrainerManaged') 'Repository fresh owner/profile/link check and strict generated validation before transport—not RLS proof'
foreach ($number in 1..16) {
    $id = 'N{0:D2}' -f $number
    Assert-Nutrition (([regex]::Matches($tests, "func test$id")).Count -eq 1) "$id native definition present—NOT EXECUTED"
}
Assert-Nutrition ($tests -match 'testMifflinKnown' -and $tests -match 'testMacroArithmetic' -and $tests -match 'testExactPortionArithmetic' -and $tests -match 'testValidatorRejectsTampered' -and $tests -match 'testMetadataJSONRoundTrip') 'Known arithmetic,hard-safety,tamper and backwards payload XCTest definitions'
Assert-Nutrition ($fixtures -match 'SYNTHETIC TEST RECORDS ONLY' -and $fixtures -match 'Never a production seed' -and $fixtures -match 'example.test') 'Fixtures explicitly synthetic—not real provider/API/persistence evidence'
Write-Output "Nutrition source/hash checks passed: $passed"
if ($failures.Count) { $failures | ForEach-Object { Write-Output "FAILED: $_" }; exit 1 }
if ($AllStatic) {
    $runs = @(
        @('validate-ui-foundation.ps1','-RefinementPhase34','-NutritionEngine'),
        @('validate-ui-training.ps1','-RefinementPhase34','-NutritionEngine'),
        @('validate-ui-exercise-home.ps1','-NutritionEngine'),
        @('validate-workout-coach.ps1','-UIIntegration','-NutritionEngine'),
        @('validate-client-ios.ps1')
    )
    foreach ($run in $runs) {
        $scriptPath = Join-Path $PSScriptRoot $run[0]
        $arguments = @($run | Select-Object -Skip 1)
        if ($SmartEditing -and $run[0] -ne 'validate-client-ios.ps1') { $arguments += '-SmartEditing' }
        if ($NutritionUI) { $arguments += '-NutritionUI' }
        if ($FinalUI67) { $arguments += '-FinalUI67' }
        & pwsh -NoProfile -File $scriptPath @arguments
        if ($LASTEXITCODE -ne 0) { throw "Regression source validator failed: $($run[0])" }
    }
}
Write-Output 'PHASE5C SOURCE/HASH ONLY: PASS;Swift compile/XCTest/Simulator/real APIs/real save/RLS NOT RUN. STOP BEFORE5D.'
