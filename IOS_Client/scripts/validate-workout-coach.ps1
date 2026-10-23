[CmdletBinding()]
param([switch]$FinalUI67, [switch]$UIIntegration, [switch]$NutritionEngine, [switch]$SmartEditing, [switch]$NutritionUI)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $clientRoot 'GymManagerClient'
. (Join-Path $PSScriptRoot 'nutrition-checkpoint-source.ps1')
# -NutritionEngine reverses only authorized5C additions for historical hashes.
# Run validate-nutrition-coach.ps1 too: it checks current source and frozen Workout/UI.
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0
function Assert-Coach([bool]$Condition, [string]$Name) {
    if ($Condition) { $script:passed++; Write-Output "[PASS] $Name" }
    else { $script:failures.Add($Name); Write-Output "[FAIL] $Name" }
}
function Read-Source([string]$Path) { Get-NutritionCheckpointSource (Join-Path $sourceRoot $Path) }
$baseline = Get-Content (Join-Path $clientRoot 'docs/coach-workout-baseline-20261023.json') -Raw | ConvertFrom-Json
$allowed = @('Core/ClientWorkoutGenerator.swift','Core/ClientPersonalContent.swift','Core/ClientPersonalRepository.swift','Core/ClientSessionStore.swift','Features/Workout/ClientGuidedWorkoutView.swift')
$uiBaseline = if ($UIIntegration) { Get-Content (Join-Path $clientRoot 'docs/coach-workout-ui-baseline-20261023.json') -Raw | ConvertFrom-Json } else { $null }
$uiAllowed = if ($UIIntegration) { @($uiBaseline.allowedModified) } else { @() }
Assert-Coach ($baseline.files.Count -eq 65 -and !(Compare-Object ($allowed | Sort-Object) ($baseline.allowedModified | Sort-Object))) 'Pre-edit65-file source baseline and five explicit authorized modules'
foreach ($entry in $baseline.files) {
    if ($NutritionEngine -and $entry.path -eq 'Core/ClientNutritionGenerator.swift') { continue } # Authorized5C engine, checked separately.
    if ($entry.path -in $allowed -or $entry.path -in $uiAllowed) { continue }
    Assert-Coach ((Get-NutritionCheckpointHash (Join-Path $sourceRoot $entry.path)) -eq $entry.sha256) "Protected exact bytes: $($entry.path)"
}
$fragments = Get-Content (Join-Path $clientRoot 'docs/coach-workout-protected-fragments-20261023.json') -Raw | ConvertFrom-Json
foreach ($entry in $fragments) {
    $source = (Read-Source $entry.path).Replace([string]([char]13), '')
    $start = $source.IndexOf($entry.start, [StringComparison]::Ordinal)
    $end = if ($entry.end -and $start -ge 0) { $source.IndexOf($entry.end, $start + $entry.start.Length, [StringComparison]::Ordinal) } else { $source.Length }
    $valid = $start -ge 0 -and $end -ge $start
    if ($valid) {
        $text = $source.Substring($start, $end - $start).TrimEnd()
        $valid = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))) -eq $entry.sha256
    }
    Assert-Coach $valid "Protected pre-edit workout/timer/read/Nutrition fragment: $($entry.path)"
}
$contract = Read-Source 'Core/ClientWorkoutCoachContract.swift'
$session = Read-Source 'Core/ClientSessionStore.swift'
$repository = Read-Source 'Core/ClientPersonalRepository.swift'
$personal = Read-Source 'Core/ClientPersonalContent.swift'
$generator = Read-Source 'Core/ClientWorkoutGenerator.swift'
Assert-Coach ($contract -match 'enum ClientWorkoutGenerationEligibility' -and $contract -match 'deniedTrainerManaged' -and $contract -match 'missingRequiredAnswers' -and $contract -match 'invalidFrequency' -and $contract -match 'invalidDuration') 'Typed eligibility and input failures, not free-string business state'
Assert-Coach ($contract.IndexOf('guard let mode = context.mode') -lt $contract.IndexOf('return validateAnswers(answers)') -and $contract -match 'canManagePersonalWorkoutPlans') 'Owner gate evaluated before questionnaire validation'
Assert-Coach ($contract -match 'totalMonths >= 36' -and $contract -match 'recentConsistentMonths >= 12' -and $contract -match 'canUseRIR, hasUsedLoadProgression' -and $contract -match 'cappedAt perceived') 'Experience evidence validates continuity/skills and caps perceived level'
Assert-Coach ($contract -match 'guard \(2\.\.\.6\).contains' -and $contract -match 'guard \[30, 45, 60, 75, 90\].contains' -and $contract -match 'professionalAssessmentRequired') 'Invalid frequency/duration and medical-use guardrails reject without clamping'
Assert-Coach ($generator -match 'experienceEvidence: ClientWorkoutExperienceEvidence\? = nil' -and $personal -match 'generationMetadata: ClientWorkoutGenerationMetadata\? = nil') 'Additive optional JSON fields preserve historical decodability'
Assert-Coach ($session -match 'func generatePersonalWorkout' -and $session -match 'ClientWorkoutGenerationPolicy.evaluate' -and $session -match 'guard eligibility == \.allowed else \{ throw eligibility \}') 'Generation service resolves current session identity instead of trusting UI selection'
Assert-Coach ($repository -match 'try await requireStandaloneWorkoutOwner\(userID\)' -and $repository -match 'active.user.id == userID' -and $repository -match 'select\("role,status,is_active"\)' -and $repository -match 'guard links.isEmpty') 'Repository verifies real session, active Client role and no Trainer link before workout write'
Assert-Coach ($session -match 'confirmed.generationMetadata == plan.generationMetadata' -and $repository -match 'let source = "self_created"') 'Confirmed read-back covers new payload metadata without unsupported storage source'
$native = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientWorkoutCoachEligibilityTests.swift') -Raw
Assert-Coach (([regex]::Matches($native,'func test')).Count -eq 7 -and $native -match 'original.merging\(\.empty\)' -and $native -match 'testInvalidValuesAreRejectedNotClamped') 'Seven native eligibility/compatibility/history tests defined; NOT RUN'
$phaseB = Get-Content (Join-Path $clientRoot 'docs/coach-workout-phase5b-protected-20261023.json') -Raw | ConvertFrom-Json
foreach ($entry in $phaseB.files) {
    if ($entry.path -in $uiAllowed) { continue } # Explicit new UI authorization; separately protected by UI checkpoint.
    Assert-Coach ((Get-NutritionCheckpointHash (Join-Path $sourceRoot $entry.path)) -eq $entry.sha256) "Phase5B leaves checkpoint bytes unchanged: $($entry.path)"
}
$normalizer = $generator.Replace([string]([char]13), '')
$normalizerStart = $normalizer.IndexOf($phaseB.normalizer.start, [StringComparison]::Ordinal)
$normalizerEnd = $normalizer.IndexOf($phaseB.normalizer.end, [StringComparison]::Ordinal)
$normalizerHash = if ($normalizerStart -ge 0 -and $normalizerEnd -gt $normalizerStart) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($normalizer.Substring($normalizerStart,$normalizerEnd-$normalizerStart).TrimEnd()))) } else { '' }
Assert-Coach ($normalizerHash -eq $phaseB.normalizer.sha256) 'Original shared display normalizer untouched; generation policy separate'
$catalog = Read-Source 'Core/ClientWorkoutCatalogPolicy.swift'
$rules = Read-Source 'Core/ClientWorkoutCoachRules.swift'
$validator = Read-Source 'Core/ClientWorkoutPlanValidator.swift'
$progression = Read-Source 'Core/ClientWorkoutDoubleProgression.swift'
$engineTests = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientWorkoutCoachEngineTests.swift') -Raw
$fixtures = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientWorkoutCoachFixtures.swift') -Raw
Assert-Coach ($generator -match 'experience = answers.experienceEvidence\?\.classified' -and $generator -match 'let eligibility = ClientWorkoutGenerationPolicy.validateAnswers') 'Effective level and required input contract drive actual generator'
Assert-Coach ($generator -match 'ClientWorkoutCatalogPolicy.admit' -and $catalog -match '\$0.id == item.id.uuidString.lowercased' -and $catalog -match 'normalize\(\$0.name\) == normalize\(item.name\)') 'Admission uses exact reviewed ID/source key AND exact variant name'
Assert-Coach ($catalog -notmatch 'normalized.contains|rule\(for:|ClientExerciseMetadataNormalizer' -and $catalog -match 'links.allSatisfy' -and $catalog -match 'roleIsKnown|hasKnownRole') 'No substring fallback; unknown roles/regions/invalid coefficients fail closed'
Assert-Coach ($catalog -match 'rule.required.isSubset\(of: available\)' -and $catalog -match '!excludedIDs.contains' -and $catalog -match '!exclusions.contains' -and $catalog -match 'exclusions.isSubset\(of: knownNames\)') 'Explicit inventory and exact ID/name exclusions; unresolved names not ignored'
Assert-Coach ($catalog -match 'rows.allSatisfy' -and $catalog -match 'rule.sourceKey == nil' -and $catalog -match 'compoundFamiliarity != true') 'Conflicting catalog IDs excluded; home variants and novice familiarity bounded'
Assert-Coach ($rules -match 'sessionDurationMinutes >= 75' -and $rules -match 'priorityMuscles.count >= 2' -and $rules -match 'profile.goal == .hypertrophy' -and $rules -match 'case .custom') 'Split strategy responds to time, experience, priority, goal and explicit preference'
Assert-Coach ($generator -match 'for pass in 0..<3' -and $generator -match 'for _ in 0..<160' -and $generator -match 'report.summary.isValid' -and $generator -notmatch 'random\(|shuffled\(|localizedCaseInsensitiveCompare') 'Bounded correction; no random/unbounded regeneration; strict acceptance before return'
Assert-Coach ($generator -match 'candidate.primary.sorted' -and $generator -match 'a.item.id.uuidString < b.item.id.uuidString' -and $rules -match 'Stable non-security fingerprint') 'Stable catalog/group ordering and structural fingerprint (not instance UUID reuse)'
Assert-Coach ($validator -match 'Double\(sets\) \* coefficient' -and $validator -match 'else if link.isPrimary' -and $validator -match 'secondaryExposures' -and $validator -notmatch '\* 0\.5') 'Actual stored coefficient or primary-set count; missing secondary weights stay qualitative'
Assert-Coach ($rules -match 'static func minimumVolume' -and $rules -match 'static func target' -and $rules -match 'static func maximum' -and $generator -match 'weeklySets.allSatisfy') 'Conservative weekly floor/target/ceiling and bounded calibration'
Assert-Coach ($rules -match 'max\(0, \$1.sets - 1\) \* \$1.restSeconds' -and $generator -match '<= profile.sessionDurationMinutes' -and $validator -match 'day.durationMinutes !=') 'Actual prescribed rest/work/transitions fit budget; no old18min tolerance'
Assert-Coach ($generator -match 'desired.map' -and $validator -match 'patterns\[.hipHinge\] == nil' -and $validator -match 'issues.insert\(.order\)' -and $validator -match 'issues.insert\(.recovery\)') 'Compound movement balance, exercise order and adjacent-day recovery checks'
Assert-Coach ($generator -match 'loadKg: nil' -and $generator -match 'RIR 3' -and $generator -match '180 : 150' -and $generator -match '"4–6" : "6–10"') 'No invented kilograms; reps/RIR/rest based on exercise/goal, not bulk-cut stereotype'
Assert-Coach ($progression -match 'performed.count == prescription.sets' -and $progression -match 'let rir = set.rir' -and $progression -match 'guard achieved' -and $progression -match 'return .suggestIncrease' -and $progression -notmatch 'loadKg\s*=') 'Pure double-progression decision requires actual complete set/RIR data; never changes load'
Assert-Coach ($validator -match 'case answers, days, catalog, equipment, exclusions, coverage, volume, duration, duplicates, movement, order, recovery, prescription, metadata' -and $validator -match 'contractValid: issues.isEmpty') 'Strict typed validator covers programming and actual catalog contract'
Assert-Coach ($generator -match 'generationMetadata = ClientWorkoutGenerationMetadata' -and $validator -match 'metadata.catalogFingerprint' -and $rules -match 'coach-workout-2.0.0') 'Versioned rationale/level/split/durations/catalog metadata generated AND revalidated'
foreach ($caseNumber in 1..12) {
    $caseID = 'CASE{0:D2}' -f $caseNumber
    Assert-Coach (([regex]::Matches($engineTests,"func test$caseID")).Count -eq 1) "$caseID native test DEFINED (not executed by PowerShell)"
}
Assert-Coach ($engineTests -match 'testDeterminismAcrossCatalogPermutation' -and $engineTests -match 'testAlternativesRemainDeterministic' -and $engineTests -match 'programSignature') 'Determinism assertions cover repeated builds, catalog reversal and variation'
Assert-Coach ($engineTests -match 'testValidatorRejectsEachStructuralAndVolumeViolation' -and $engineTests -match 'testExplicitCustomSplitAndEquipment' -and $engineTests -match 'testUnresolvedExclusion' -and $engineTests -match 'testSecondaryWithoutStoredCoefficient') 'Matrix includes split/equipment/exclusion/volume/unknown-secondary and tamper rejection tests'
Assert-Coach ($fixtures -match 'Synthetic test content' -and $fixtures -match 'NEVER a production seed' -and $fixtures -match 'Stored coefficients are test inputs') 'Test UUIDs and test coefficients explicitly synthetic, not production data'
if ($UIIntegration) {
    Assert-Coach ($uiBaseline.files.Count -eq 70) 'UI starts from existing70-file engine checkpoint, not a stale mirror'
    foreach ($entry in $uiBaseline.files) {
        if ($NutritionEngine -and $entry.path -eq 'Core/ClientNutritionGenerator.swift') { continue } # New5C source checks replace its old freeze ONLY.
        if ($entry.path -in $uiAllowed) { continue }
        Assert-Coach ((Get-NutritionCheckpointHash (Join-Path $sourceRoot $entry.path)) -eq $entry.sha256) "UI protected exact checkpoint: $($entry.path)"
    }
    Assert-Coach ((Get-FileHash (Join-Path $clientRoot 'GymManagerClientTests/ClientWorkoutCoachEngineTests.swift')).Hash -eq $uiBaseline.caseMatrix.engineTests) 'CASE01–CASE12 and supplemental engine tests preserved exact bytes'
    Assert-Coach ((Get-FileHash (Join-Path $clientRoot 'GymManagerClientTests/ClientWorkoutCoachFixtures.swift')).Hash -eq $uiBaseline.caseMatrix.fixtures) 'Engine fixture unchanged; no weakening to fit UI'
    $wizard = Read-Source 'Features/Workout/ClientGuidedWorkoutView.swift'
    $editor = Read-Source 'Features/Workout/ClientPersonalWorkoutView.swift'
    $flow = Read-Source 'Core/ClientWorkoutCoachFlow.swift'
    $editing = Read-Source 'Core/ClientEditedWorkoutPlanValidator.swift'
    $uiTests = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientWorkoutCoachIntegrationTests.swift') -Raw
    Assert-Coach ($wizard -match 'draft = ClientWorkoutCoachDraft' -and $flow -match 'var totalMonths = ""' -and $flow -match 'var compoundFamiliarity: Bool\?' -and $flow -match 'var acknowledgement: Bool\? = nil') 'Questionnaire evidence starts unanswered, not hidden defaults'
    foreach ($field in @('totalMonths','recentMonths','recentFrequency','perceivedLevel','compoundFamiliarity','canUseRIR','hasUsedProgression','frequency','minutes','equipment','goal','phase','weeks','split','acknowledgement')) {
        Assert-Coach ($wizard.Contains('$draft.'+$field) -or $wizard -match ("draft\."+[regex]::Escape($field))) "Required UI input collectable: $field"
    }
    Assert-Coach ($wizard -match 'try draft.completeAnswers' -and $wizard -match 'try session.generatePersonalWorkout' -and $wizard -notmatch 'generator.generate\(') 'Complete answers go through current-session5A gate and existing5B engine'
    Assert-Coach ($flow -match 'classified\(cappedAt: perceivedLevel\)' -and $wizard -match 'Livello stimato') 'Estimated level cannot be raised above evidence cap in View'
    Assert-Coach ($wizard -match 'draft.availableEquipment' -and $flow -match 'ClientWorkoutCatalogPolicy.admit' -and $flow -match 'hasRequiredCoverage') 'Equipment options reflect verified actual catalog coverage'
    Assert-Coach ($wizard -match 'draft.verifiedInventory' -and $wizard -match 'forceReload: true') 'Actual equipment selection and explicit fresh-catalog retry available'
    Assert-Coach ($flow -match 'incompatible|Con 2 giorni|Full Body è supportato' -and $wizard -match 'Usa Decidi tu' -and $flow -match 'customGroups.prefix') 'Split conflict explained; user chooses alternative; custom answers preserved'
    Assert-Coach ($wizard -match 'ClientMuscleRegion.allCases' -and $wizard -match 'molte richieste' -and $wizard -match 'Nessuno in particolare') 'Real priority taxonomy and feasibility warning, no invented hard cap'
    Assert-Coach ($wizard -match 'ClientCoachExclusionsSheet' -and $flow -match 'value.avoidedExerciseIDs = excludedIDs' -and $flow -match 'value.avoidedExerciseNames = \[\]') 'Exclusions selected by real ID, not free-text inference'
    Assert-Coach ($wizard -match 'fitness generale' -and $wizard -match 'draft.acknowledgement = \$0' -and $flow -match 'acknowledgement == true') 'Explicit healthy-adult acknowledgement required'
    Assert-Coach ($flow -match 'case .invalidFrequency, .invalidDuration' -and $flow -match 'case .noCompatibleExercises' -and $flow -match 'case .allowed, .deniedUnauthenticated, .deniedTrainerManaged: step = nil' -and $wizard -match 'Correggi:') 'Typed failures have corrective step or non-overridable owner denial'
    Assert-Coach ($wizard -match 'Sto preparando la tua scheda' -and $wizard -notmatch 'intelligenza artificiale|LLM') 'Honest local rule-based generation feedback'
    Assert-Coach ($wizard -match 'ClientWorkoutCoachExplanation.lines' -and $flow -match 'Abbiamo scelto' -and $wizard -notmatch 'catalogFingerprint|generatorVersion|coach-workout-2') 'Preview explains actual plan, never internal version/fingerprint'
    Assert-Coach ($editor -match 'ClientPersonalWorkoutPlanEditor' -and $editor -match 'ClientPersonalWorkoutSessionEditor' -and $editor -match 'ClientPersonalExerciseEditor' -and $wizard -match 'onEdit\(generated.plan\)') 'Existing editor reused for preview edits, not a parallel editor'
    Assert-Coach ($editing -match 'struct ClientEditedWorkoutPlanValidator' -and $editor -match 'validation\?\.canSave == true' -and $editing -match 'guard validation.canSave' -and $validator -match 'allowEditedPresentation: Bool = false') 'Edited validation gates UI AND save service; strict generation default unchanged'
    Assert-Coach ($editing -match 'Set\(exercise.primaryMuscles' -and $editing -match 'review.pattern == exercise.movementPattern' -and $editing -match 'review.kind == exercise.exerciseKind' -and $editing -match 'firstIndex\(of: \$0.level\)' -and $editing -match '!usedIDs.contains') 'Replacement enforces movement/muscle role,difficulty and no duplicate; admission enforces equipment/exclusions'
    Assert-Coach ($editor -match 'if coachCandidates == nil' -and $editor -match 'ClientWorkoutCoachEditingContext.exercise') 'Coach picker uses canonical metadata and disallows unverified custom exercise escape'
    Assert-Coach ($editing -match 'expectedOwnerID == owner.authUserID' -and $editing -match 'current.authUserID == owner.authUserID' -and $editing -match 'canManagePersonalWorkoutPlans\(in: current.mode\)') 'Save binds wizard/editor owner and rechecks current identity/mode after await'
    Assert-Coach ($editing -match 'await savePersonalWorkoutPlanConfirmed' -and $repository -match 'try await requireStandaloneWorkoutOwner' -and $session -match 'confirmed.generationMetadata == plan.generationMetadata') 'Existing fresh repository preflight and full server metadata read-back retained'
    Assert-Coach ($flow -match 'case localDraft, saving, confirmed\(demo: Bool\), failure' -and $wizard -match 'Salva e attiva' -and $editor -match 'non verrà attivata automaticamente' -and $editing -match 'source != .live') 'Local/saving/confirmed/failure and demo/activation semantics explicit'
    Assert-Coach ($session -match 'if let reason = error as\? ClientWorkoutGenerationEligibility' -and $editing -match 'notice = nil') 'Ownership rejection preserved, old unrelated notice never reused as current-save evidence'
    Assert-Coach ($flow -match 'Conferma|scheda|Scheda' -and $wizard -match 'accessibilityReduceMotion' -and $wizard -match 'safeAreaInset' -and $wizard -match 'ClientControlSize.minimumTarget' -and $wizard -notmatch 'minimumScaleFactor') 'Native progressive controls,safe CTA,ReduceMotion and no text shrinking'
    Assert-Coach (([regex]::Matches($uiTests,'func test')).Count -eq 19 -and $uiTests -match 'testOldPlanWithoutCoachMetadataStillDecodes' -and $uiTests -match 'testMetadataSurvivesEditedValidation') '19 new integration XCTest definitions,including metadata/backwards compatibility; NOT RUN'
    $typedCatch = @'
            // Preserve typed ownership denial instead of presenting it as an offline sync failure.
            if let reason = error as? ClientWorkoutGenerationEligibility {
                notice = reason.errorDescription
            } else {
                notice = "Scheda conservata sul dispositivo, ma il database non ha confermato la sincronizzazione."
            }
'@
    $restoredSession = $session.Replace([string]([char]13),'').Replace($typedCatch.TrimEnd(),'            notice = "Scheda conservata sul dispositivo, ma il database non ha confermato la sincronizzazione."')
    $restoredHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($restoredSession)))
    Assert-Coach ($restoredHash -eq ($uiBaseline.files | Where-Object path -eq 'Core/ClientSessionStore.swift').sha256) 'Entire SessionStore unchanged except narrowly approved typed save-catch preservation'
    Write-Output 'UI INTEGRATION SOURCE ONLY: no Swift/Simulator/VoiceOver/real save/RLS PASS claimed'
}
Write-Output "Workout coach source checks passed: $passed"
if ($failures.Count) { $failures | ForEach-Object { Write-Output "FAILED: $_" }; exit 1 }
if ($UIIntegration) { Write-Output 'IOS CLIENT COACH UI INTEGRATION: PASS SOURCE ONLY - SWIFT BUILD/XCTEST/SIMULATOR/VOICEOVER/REAL SAVE/RLS NOT RUN' }
else { Write-Output 'IOS CLIENT COACH PHASE5A+5B SOURCE CONTRACT: PASS - SWIFT EXECUTION/BUILD/PRODUCTION SAVE/RLS NOT RUN; UI UNCHANGED' }
