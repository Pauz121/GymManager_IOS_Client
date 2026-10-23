[CmdletBinding()]
param([switch]$FinalUI67, [switch]$NutritionUI, [switch]$AllStatic)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $clientRoot 'GymManagerClient'
. (Join-Path $PSScriptRoot 'nutrition-ui-checkpoint-source.ps1')
$failures = [Collections.Generic.List[string]]::new()
$passed = 0
function Assert-UI([bool]$Value, [string]$Name) {
    if ($Value) { $script:passed++; Write-Output "[PASS SOURCE] $Name" }
    else { $script:failures.Add($Name); Write-Output "[FAIL SOURCE] $Name" }
}
function Read-Actual([string]$Path) {
    $fullPath = Join-Path $sourceRoot $Path
    $value = Get-Content $fullPath -Raw
    if ($FinalUI67) { . (Join-Path $PSScriptRoot 'phase67-checkpoint-source.ps1'); $value = Restore-FinalUICheckpoint $fullPath $value }
    return $value
}
if (!$NutritionUI) { throw 'Use the explicit -NutritionUI stage; no baseline resets or implicit allowances.' }
$baseline = Get-Content (Join-Path $clientRoot 'docs/nutrition-ui-baseline-20261023.json') -Raw | ConvertFrom-Json
$allowed = @('GymManagerClient/Features/Nutrition/ClientNutritionCreationWizard.swift','GymManagerClient/Features/Nutrition/ClientPersonalNutritionView.swift')
$patches = Get-Content (Join-Path $clientRoot 'docs/nutrition-ui-approved-patches-20261023.json') -Raw | ConvertFrom-Json
Assert-UI ($baseline.sources.Count -eq 85 -and $baseline.tests.Count -eq 22) 'Pre5D checkpoint85 app sources/22 native suites retained'
Assert-UI (!(Compare-Object ($allowed | Sort-Object) ($patches.path | Sort-Object))) 'Exactly two approved existing Nutrition UI diffs;no core engine change'
foreach ($entry in $baseline.sources) {
    $path = Join-Path $clientRoot $entry.path
    Assert-UI ((Get-NutritionUICheckpointHash $path) -eq $entry.sha256) "Exact pre5D source outside approved diff: $($entry.path)"
}
foreach ($entry in $baseline.tests) {
    Assert-UI ((Get-NutritionUICheckpointHash (Join-Path $clientRoot $entry.path)) -eq $entry.sha256) "Original native suite/fixture unchanged outside explicit EOF formatting: $($entry.path)"
}
$flow = Read-Actual 'Core/ClientNutritionCoachFlow.swift'
$adapter = Read-Actual 'Core/ClientNutritionCoachUISession.swift'
$operations = Read-Actual 'Core/ClientNutritionCoachEditing.swift'
$wizard = Read-Actual 'Features/Nutrition/ClientNutritionCoachWizard.swift'
$existing = Read-Actual 'Features/Nutrition/ClientNutritionCreationWizard.swift'
$editor = Read-Actual 'Features/Nutrition/ClientNutritionCoachEditor.swift'
$replacement = Read-Actual 'Features/Nutrition/ClientNutritionReplacementSheet.swift'
$picker = Read-Actual 'Features/Nutrition/ClientPersonalNutritionView.swift'
$tests = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientNutritionCoachUITests.swift') -Raw
$session = Read-Actual 'Core/ClientSessionStore.swift'
foreach ($step in @('profile','activity','training','goal','preferences','safety','meals','review')) {
    Assert-UI ($flow -match "case .$step" -or $flow -match "case $step" -or $flow -match ", $step" -and $wizard -match "case .$step") "Required questionnaire step: $step"
}
Assert-UI ($flow -match 'var phase: ClientNutritionPhase\?' -and $flow -match 'var pattern: ClientNutritionDietPattern\?' -and $flow -match 'var exerciseDays: Int\?' -and $flow -match 'missingStep') 'Required choices are explicit optional evidence,not defaults'
Assert-UI ($wizard -match 'identity.biologicalSex' -and $flow -match 'if biologicalSex == nil' -and $wizard -match 'snapshot.progress' -and $flow -match 'calendar.isDate\(recordedAt, inSameDayAs: now\)' -and $flow -match 'recordedAt <= now' -and $wizard -notmatch 'compactMap\(.creationAnswers|firstName ==') 'Actual profile sex/todays dated progress weight reused;no stale/guessed measures or inherited consent'
Assert-UI ($wizard -match 'dailyActivity' -and $wizard -match 'exerciseDays' -and $flow -match 'ClientNutritionCoachPolicy.evaluate' -and $flow -match 'ClientNutritionCoachEnergy.calculate') 'Occupation plus confirmed exercise evidence uses same5C eligibility/energy'
Assert-UI ($wizard -match 'healthyAdultAcknowledged' -and $wizard -match 'pregnantOrBreastfeeding' -and $wizard -match 'eatingDisorderRisk' -and $wizard -match 'clinicalNutritionRequired' -and $wizard -match 'dietarySafetyReviewed') 'Four explicit safety declarations plus structured diet review'
Assert-UI ($wizard -match 'ClientNutritionAllergen.allCases' -and $wizard -match 'ClientNutritionIntolerance.allCases' -and $wizard -match 'Alimenti esclusi') 'Allergies/intolerances/exclusions collectable with text,not color alone'
Assert-UI ($flow -match 'correction\(' -and $wizard -match 'Correggi:' -and $wizard -match 'insufficientFoodData|Ricarica il catalogo' -and $wizard -match 'show\(_ error') 'Typed corrective error flow preserves answers;explicit catalog retry'
Assert-UI ($wizard -match 'Perché queste calorie' -and $wizard -match 'estimatedRMR' -and $wizard -match 'estimatedMaintenance' -and $wizard -match 'goalAdjustment' -and $wizard -match 'Perché questi macro') 'Readable shared-engine target/rationale without false precision'
Assert-UI ($wizard -match 'generateNutritionCoach' -and $existing -notmatch 'ClientNutritionGenerator.generate\(answers:' -and $existing -match 'ClientNutritionCoachEditorSections') 'New guided entry→actual-session generation→SAME existing Nutrition editor'
Assert-UI ($editor -match 'foodRow' -and $editor -match 'dailySummary' -and $editor -match 'nutrients' -and $editor -match 'Target:' -and $editor -match 'ScrollView\(.horizontal') 'Generated meal/food/quantity/macro/day-target preview'
Assert-UI ($operations -match 'ClientEditedNutritionPlanValidator\(\).prepare' -and $operations -match 'ClientNutritionFoodPolicy.admit' -and $operations -match 'allowedMeals.contains' -and $operations -match 'ClientNutritionGenerator.matches') 'Editing/add-food safety/role/occasion reuse domain policies;no View validator'
foreach ($action in @('remove','move','copyMeal','copyDay')) { Assert-UI ($operations -match "static func $action") "Existing-model edit operation: $action" }
Assert-UI ($editor -match 'quantityGrams' -and $editor -match 'energyShare' -and $editor -match 'proteinShare' -and $editor -match 'Sposta pasto' -and $editor -match 'Sposta in' -and $editor -match 'TextField\("Nome pasto"') 'Whole-plan quantities/names/order/food move/explicit distribution editable'
Assert-UI ($editor -match 'ClientNutritionCoachFeedback.issues' -and $editor -match 'Da correggere' -and $existing -match 'guard let result = coachReview, result.canSave' -and $adapter -match 'guard issues.isEmpty') 'Hard invalid draft visible and both UI/service deny save'
Assert-UI ($editor -match 'plan: replacementPlan' -and $existing -match 'replacementPlan: coachReview' -and $existing -match 'coachOriginal = updated') 'Replacement receives canonically revalidated current draft;accepted edit revision never reset to initial origin'
Assert-UI ($existing -match 'answers.coachProfile = nil' -and $existing -match 'if isCoachPlan \{ prefilled = true; return \}') 'New manual draft never inherits a previous generated coach contract;current coach metadata preserved'
Assert-UI ($replacement -match 'requestID == request' -and $replacement -match '!Task.isCancelled' -and $replacement -match 'disabled\(loading\)') 'Stale/cancelled alternative loads cannot overwrite a newer preview'
Assert-UI ($adapter -match 'ClientNutritionSmartReplacement.alternatives' -and $adapter -match 'ClientNutritionSmartReplacement.proposal' -and $replacement -match 'prepareNutritionAlternatives' -and $replacement -match 'prepareNutritionReplacement') 'Ranked and manually searched replacements use SAME engine and solver via session'
Assert-UI ($adapter -match 'Task.detached' -and ([regex]::Matches($adapter,'nutritionCoachOwner\(expectedOwnerID: expectedOwnerID\)')).Count -ge 7 -and $adapter -match 'Task.checkCancellation') 'Bounded replacement calculations off main actor;owner/cancellation checks on return'
Assert-UI ($replacement -match 'proposal.replacement.quantityDescription' -and $replacement -match 'difference.after' -and $replacement -match 'difference.before' -and $replacement -match 'ClientNutritionCoachFeedback.signed' -and $replacement -notmatch '\.score.value|similarityPercent') 'Real calculated replacement quantity/four-macro deltas;no raw score/fake similarity percent'
Assert-UI ($replacement -match 'additionalChanges' -and $replacement -match 'change.explanation' -and $replacement -match 'Pasto prima:' -and $replacement -match 'Pasto dopo:' -and $replacement -match 'acceptRebalance: consent' -and $replacement -match '!consent') 'Explicit whole-meal before/after and every sibling adjustment disclosed;consent required'
Assert-UI ($picker -match 'var allowedFoodIDs: Set<UUID>\? = nil' -and $picker -match 'var coachPortions: Bool = false' -and $picker -match 'onChooseCandidate' -and $picker -match 'bounds.minimumGrams' -and $picker -match 'bounds.stepGrams') 'Same existing picker:manual defaults retained;optional coach filtering/real lattice/candidate-only action'
Assert-UI ($adapter -match 'savePersonalNutritionPlanConfirmed' -and $session -match 'confirmed.generationMetadata == plan.generationMetadata' -and $session -match 'confirmed.editProvenance == plan.editProvenance' -and $existing -match 'if saveState.isConfirmed' -and $existing -match 'Button\("Fine"\)') 'Existing full payload read-back preserved;explicit confirmed/demo/failure,not early dismissal'
Assert-UI ($flow -match 'actualOwnerID == expectedOwnerID' -and $flow -match 'canManagePersonalNutritionPlans' -and $wizard -match 'expectedOwnerID' -and $existing -match 'identity.authUserID == expectedOwnerID') 'Owner pinned across wizard/editor/generate/save;late Trainer link denied by service'
Assert-UI ($existing -match 'variation = 0' -and $existing -match 'variation \+= 1' -and $existing -match 'variation >= 1000') 'Regenerate same base vs bounded deterministic alternative;no random shuffle'
Assert-UI ($wizard -match 'Form \{' -and $editor -match 'Section\(' -and $wizard -match 'FocusState' -and $wizard -match 'placement: .keyboard' -and $wizard -match 'accessibilityLabel' -and $editor -match 'minHeight: 44') 'Native forms/semantic typography/keyboard/accessibility/44pt source preparation—NOT native acceptance'
$new = $flow + $adapter + $operations + $wizard + $editor + $replacement
Assert-UI ($new -notmatch '\.upsert\(|\.rpc\(|URLSession|service_role|randomElement|shuffled\(|10 \* weightKg|1\.375|1\.725') 'No second energy engine/food API/backend mutations/secrets/randomization'
foreach ($number in 1..20) {
    $case = 'UI{0:D2}' -f $number
    Assert-UI (([regex]::Matches($tests,"func test$case")).Count -eq 1) "$case presentation/domain XCTest definition present—NOT RUN"
}
Assert-UI ($tests -match 'JSONNotARealDatabaseTest' -and $tests -match 'ClientNutritionCoachFixtures' -and $tests -match 'FixedPlanAndCatalog') 'Synthetic/native definitions honest;JSON not represented as database persistence'
Write-Output "Nutrition UI source/hash checks passed: $passed"
if ($failures.Count) { $failures | ForEach-Object { Write-Output "FAILED: $_" }; exit 1 }
if ($AllStatic) {
    $stageArguments = @('-NutritionUI','-AllStatic')
    if ($FinalUI67) { $stageArguments += '-FinalUI67' }
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'validate-smart-plan-editing.ps1') @stageArguments
    if ($LASTEXITCODE -ne 0) { throw 'Prior phase preservation/source regression failed' }
}
Write-Output 'PHASE5D: PASS SOURCE/HASH ONLY;Swift/XCTest/Simulator/VoiceOver/real catalog/save/reopen/RLS NOT RUN;backend gate OPEN.'
