[CmdletBinding()]
param([switch]$FinalUI67, [switch]$AllStatic, [switch]$NutritionUI)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $clientRoot 'GymManagerClient'
. (Join-Path $PSScriptRoot 'smart-editing-checkpoint-source.ps1')
. (Join-Path $PSScriptRoot 'nutrition-ui-checkpoint-source.ps1')
if ($FinalUI67) { . (Join-Path $PSScriptRoot 'phase67-checkpoint-source.ps1') }
$failures = [Collections.Generic.List[string]]::new()
$passed = 0
function Assert-Smart([bool]$Value, [string]$Name) {
    if ($Value) { $script:passed++; Write-Output "[PASS SOURCE] $Name" }
    else { $script:failures.Add($Name); Write-Output "[FAIL SOURCE] $Name" }
}
function Read-Current([string]$Path) { Get-Content (Join-Path $sourceRoot $Path) -Raw }
$baseline = Get-Content (Join-Path $clientRoot 'docs/smart-plan-editing-baseline-20261023.json') -Raw | ConvertFrom-Json
$allowed = @('Core/ClientEditedWorkoutPlanValidator.swift','Core/ClientNutritionPlanValidator.swift',
    'Core/ClientNutritionPortionSolver.swift','Core/ClientPersonalContent.swift','Core/ClientWorkoutGenerator.swift',
    'Core/ClientNutritionGenerator.swift','Core/ClientSessionStore.swift')
Assert-Smart ($baseline.files.Count -eq 79 -and !(Compare-Object ($allowed | Sort-Object) ($baseline.allowedModified | Sort-Object))) 'Pre-edit79-source checkpoint:exactly7 authorized core modules;NO UI scope'
foreach ($entry in $baseline.files) {
    $path = Join-Path $sourceRoot $entry.path
    if ($entry.path -in $allowed) {
        $original = Get-Content $path -Raw
        if ($FinalUI67) { $original = Restore-FinalUICheckpoint $path $original }
        $restored = Restore-SmartEditingCheckpoint $path $original
        $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($restored)))
        Assert-Smart ($hash -eq $entry.sha256) "Exact original source outside approved smart-editing patch: $($entry.path)"
    } else {
        Assert-Smart ((Get-NutritionUICheckpointHash $path) -eq $entry.sha256) "Exact source outside approved stage: $($entry.path)"
    }
}
foreach ($entry in $baseline.tests) {
    Assert-Smart ((Get-NutritionUICheckpointHash (Join-Path $clientRoot "GymManagerClientTests/$($entry.path)")) -eq $entry.sha256) "Existing native test suite unchanged outside explicit EOF formatting: $($entry.path)"
}
$ranking = Read-Current 'Core/ClientWorkoutSmartReplacement.swift'
$workoutEditor = Read-Current 'Core/ClientEditedWorkoutPlanValidator.swift'
$nutrition = Read-Current 'Core/ClientNutritionSmartReplacement.swift'
$layout = Read-Current 'Core/ClientNutritionEditingLayout.swift'
$edited = Read-Current 'Core/ClientEditedNutritionPlanValidator.swift'
$validator = Read-Current 'Core/ClientNutritionPlanValidator.swift'
$solver = Read-Current 'Core/ClientNutritionPortionSolver.swift'
$provenance = Read-Current 'Core/ClientPlanEditProvenance.swift'
$personal = Read-Current 'Core/ClientPersonalContent.swift'
$session = Read-Current 'Core/ClientSessionStore.swift'
$sessionEntry = Read-Current 'Core/ClientSmartPlanEditingSession.swift'
$wtests = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientWorkoutSmartReplacementTests.swift') -Raw
$ntests = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientNutritionSmartReplacementTests.swift') -Raw
Assert-Smart ($workoutEditor -match 'ClientWorkoutReplacementRanking.ranked' -and $workoutEditor -match 'ClientWorkoutCatalogPolicy.admit') 'Existing Workout replacement policy/catalog admission reused,not a second catalog'
Assert-Smart ($ranking -match 'primary == Set\(original.primaryMuscles' -and $ranking -match 'pattern == original.movementPattern' -and $ranking -match 'kind == original.exerciseKind') 'Hard same primary/pattern/kind from reviewed real catalog'
Assert-Smart ($ranking -match 'original.difficultyLevel == originalCandidate.level' -and $ranking -match '<= ceiling' -and $ranking -match '!usedIDs.contains') 'No technical escalation/unknown difficulty or same-session duplicate'
foreach ($criterion in @('difficultyDistance','equipmentSetupChanges','priorityShortfall','volumeDistance')) {
    Assert-Smart ($ranking -match $criterion) "Deterministic Workout ranking criterion: $criterion"
}
Assert-Smart ($ranking -match 'symmetricDifference' -and $ranking -match 'ClientWorkoutVolumeMetrics' -and $ranking -match 'keys.sorted' -and $ranking -match 'id.uuidString <') 'Setup/actual weighted volume/stable UUID ties;no invented muscle weights'
Assert-Smart ($ranking -match 'ClientEditedWorkoutPlanValidator\(\).inspect' -and $ranking -match 'guard result.canSave' -and $ranking -match 'beforeVolume:' -and $ranking -match 'afterVolume:') 'Every Workout proposal revalidates complete plan and exposes recalculated volume'
Assert-Smart ($ranking -match 'context.mode' -and $ranking -match 'parentSignature' -and $ranking -match 'catalogFingerprint' -and $ranking -match 'Rebuild from current trusted catalog') 'Workout owner-mode/stale target/catalog recheck before local apply'
Assert-Smart ($workoutEditor -match 'sets: original\?\.sets' -and $workoutEditor -match 'repetitions: original\?\.repetitions' -and $workoutEditor -match 'restSeconds: original\?\.restSeconds' -and $workoutEditor -match 'effortTarget: original\?\.effortTarget' -and $workoutEditor -match 'notes: original\?\.notes') 'No silent prescription rewrite on exercise replacement'
Assert-Smart ($solver -match 'generation = Self\(weights: \[4, 1, 1, 1\], minimumScales: \[1, 1, 1, 1\]\)' -and $solver -match 'objective: ClientNutritionFitObjective = .generation') 'Existing generation objective/math preserved by default'
Assert-Smart ($solver -match 'replacement = Self\(weights: \[4, 3, 2, 2\], minimumScales: \[25, 5, 5, 3\]\)' -and $solver -match 'objective.weights\[axis\]' -and $solver -match 'objective: objective') 'Configurable four-nutrient objective reaches SAME continuous/discrete solver'
Assert-Smart ($nutrition -match 'ClientNutritionFoodPolicy.admit' -and $nutrition -match 'allowedMeals.contains' -and $nutrition -match 'matches\(candidate, role: role\)' -and $nutrition -match '!used.contains') 'Nutrition same-role/occasion/global-review/pattern/allergy/exclusion/duplicate hard admission'
Assert-Smart ($nutrition -match 'ClientNutritionPortionSolver.fit' -and $nutrition -match 'bounds: evidence.portion' -and $nutrition -match 'objective: policy.objective' -and $nutrition -notmatch 'grams: beforeFood.quantityGrams') 'Candidate quantity solved+quantized,not copied from original grams'
Assert-Smart ($nutrition -match 'nutrientDistance \+ sourcePenalty' -and $nutrition -match 'sourcePenalty = 0.01' -and $nutrition -match 'maximumItemEnergyDistance = 0.25' -and $nutrition -match 'maximumRoleNutrientDistance = 0.30') 'Documented engineering score/fit guard;no fake similarity percentage'
Assert-Smart ($nutrition -match 'allowMealRebalance = false' -and $nutrition -match 'maximumOtherFoodSteps = 1' -and $nutrition -match 'minimumGrams: item.quantityGrams, maximumGrams: item.quantityGrams') 'Default swap-only;optional sibling repair max1realstep and offered replacement quantity locked'
Assert-Smart ($nutrition -match 'additionalChanges' -and $nutrition -match 'beforeGrams' -and $nutrition -match 'afterGrams' -and $nutrition -match 'acceptRebalance: Bool = false' -and $nutrition -match 'rebalanceConsentRequired') 'Every sibling quantity change disclosed and explicit consent required on apply'
Assert-Smart ($nutrition -match 'fresh.original == proposal.original' -and $nutrition -match 'fresh.replacement == proposal.replacement' -and $nutrition -match 'fresh.additionalChanges == proposal.additionalChanges') 'Fresh recomputation prevents forged/stale preview or undisclosed change'
Assert-Smart ($nutrition -match 'guard result.canSave' -and $nutrition -match 'ClientEditedNutritionPlanValidator\(\).prepare' -and $nutrition -match 'calories: replacement.calories' -and $nutrition -match 'protein: replacement.protein') 'Real preview deltas and strict full meal/day validation before accepting a swap'
Assert-Smart ($layout -match 'mealID' -and $layout -match 'foodID' -and $layout -match 'energyShare' -and $layout -match 'proteinShare' -and $layout -match 'reduce\(0\)' -and $layout -match '1\) < 0.000001') 'ID-based editable layout/roles and normalized finite meal distributions'
Assert-Smart ($validator -match 'static func inspectCore' -and $validator -match 'editingLayout == nil' -and $validator -match 'ClientEditedNutritionPlanValidator.hasValidContract' -and $edited -match 'generationMetadataSignature == ClientSmartPlanFingerprint.nutritionOrigin') 'Generation remains strict;edited presentation requires valid source-preserving contract'
Assert-Smart ($edited -match 'original.generationMetadata == edited.generationMetadata' -and $edited -match 'original.target == edited.target' -and $edited -match 'original.creationAnswers == edited.creationAnswers') 'Editing never changes original engine metadata/profile/targets or creates separate plan'
Assert-Smart ($provenance -match 'smart-plan-edit-1.0.0' -and $provenance -match 'hasUserEdits: Bool \{ revision > 0 \}' -and $provenance -match 'originalPlanSignature' -and $provenance -match 'currentPlanSignature') 'Optional version/revision/original/current provenance;old payloads default nil'
Assert-Smart (([regex]::Matches($personal,'var editProvenance: ClientPlanEditProvenance\? = nil')).Count -eq 2 -and ([regex]::Matches($session,'confirmed.editProvenance == plan.editProvenance')).Count -eq 2) 'Same normal Workout/Nutrition payloads plus metadata read-back on both save paths'
Assert-Smart ($sessionEntry -match 'identity.authUserID == expectedOwnerID' -and $sessionEntry -match 'canManagePersonalNutritionPlans' -and ([regex]::Matches($sessionEntry,'let owner = try smartEditingOwner')).Count -eq 5 -and $sessionEntry -notmatch '\.upsert\(|persist|savePersonal') 'Five proposal/apply entry points recheck actual current owner/mode;local draft only,not a server write'
foreach ($number in 1..6) {
    $id = 'WREP{0:D2}' -f $number
    Assert-Smart (([regex]::Matches($wtests,"func test$id")).Count -eq 1) "$id native definition present—NOT RUN"
}
foreach ($number in 1..10) {
    $id = 'NREP{0:D2}' -f $number
    Assert-Smart (([regex]::Matches($ntests,"func test$id")).Count -eq 1) "$id native definition present—NOT RUN"
}
Assert-Smart ($ntests -match 'testRenameReorderAndDistributionEditable' -and $ntests -match 'testDeterministicAlternativesAndStale' -and $ntests -match 'testEditedMetadataAndLayoutSurviveJSON') 'Additional editability/determinism/stale/JSON tests defined,not persistence evidence'
Assert-Smart ($wtests -match 'F = ClientWorkoutCoachFixtures' -and $ntests -match 'F = ClientNutritionCoachFixtures' -and $ntests -match 'Test-only metadata') 'Existing explicitly synthetic fixtures reused;no production food/exercise IDs fabricated'
$newSource = $ranking + $nutrition + $layout + $edited + $provenance
Assert-Smart ($newSource -notmatch '\.upsert\(|\.insert\(|\.rpc\(|URLSession|service_role|randomElement|shuffled\(') 'Pure deterministic local policies;no backend mutation/network/LLM/secrets'
Write-Output "Smart editing source/hash checks passed: $passed"
if ($failures.Count) { $failures | ForEach-Object { Write-Output "FAILED: $_" }; exit 1 }
if ($AllStatic) {
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'validate-nutrition-coach.ps1') -SmartEditing -AllStatic -NutritionUI:$NutritionUI -FinalUI67:$FinalUI67
    if ($LASTEXITCODE -ne 0) { throw 'Prior phase source regressions failed' }
}
Write-Output 'SMART PLAN EDITING: PASS SOURCE/HASH ONLY;Swift/XCTest/real catalog/save/RLS NOT RUN;STOP BEFORE5D.'
