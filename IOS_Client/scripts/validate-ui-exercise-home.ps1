[CmdletBinding()]
param([switch]$FinalUI67, [switch]$NutritionEngine, [switch]$SmartEditing, [switch]$NutritionUI)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $clientRoot 'GymManagerClient'
. (Join-Path $PSScriptRoot 'nutrition-checkpoint-source.ps1')
# -NutritionEngine reverses only authorized5C additions for historical hashes.
# Run validate-nutrition-coach.ps1 too: it checks current source and frozen Workout/UI.
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0
function Assert-Refinement([bool]$Condition, [string]$Name) {
    if ($Condition) { $script:passed++; Write-Output "[PASS] $Name" }
    else { $script:failures.Add($Name); Write-Output "[FAIL] $Name" }
}
function Read-Source([string]$Path) { Get-NutritionCheckpointSource (Join-Path $sourceRoot $Path) }
function Text-Hash([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text)))
}
$baseline = Get-Content (Join-Path $clientRoot 'docs/ui-exercise-home-baseline-20261023.json') -Raw | ConvertFrom-Json
$allowed = @('App/ClientRootView.swift','App/GymManagerClientApp.swift','Core/ClientContentLoadState.swift',
    'Core/ClientRepository.swift','Core/ClientSessionStore.swift','Features/Home/ClientHomeView.swift',
    'Features/Workout/ClientAnatomyMap.swift','Features/Workout/ClientExerciseVisualCard.swift',
    'Features/Workout/ClientWorkoutExecutionView.swift','Features/Workout/ClientWorkoutView.swift')
Assert-Refinement ($baseline.files.Count -eq 57 -and !(Compare-Object ($allowed | Sort-Object) ($baseline.allowedModified | Sort-Object))) 'Pre-edit57-file baseline: exactly10 authorized original source files'
foreach ($entry in $baseline.files) {
    if ($NutritionEngine -and $entry.path -eq 'Core/ClientNutritionGenerator.swift') { continue } # Authorized5C engine, checked separately.
    if ($entry.path -in $allowed) { continue }
    Assert-Refinement ((Get-NutritionCheckpointHash (Join-Path $sourceRoot $entry.path)) -eq (Get-NutritionHistoricalExpectedHash $entry)) "Unchanged exact bytes: $($entry.path)"
}
$fragments = Get-Content (Join-Path $clientRoot 'docs/ui-exercise-home-protected-fragments-20261023.json') -Raw | ConvertFrom-Json
Assert-Refinement ($fragments.Count -eq 6) 'Six frozen fragments compared with original preimages before hash capture'
foreach ($entry in $fragments) {
    $source = (Get-NutritionCheckpointSource (Join-Path $clientRoot $entry.path)).Replace([string]([char]13), '')
    $start = if ($entry.start) { $source.IndexOf($entry.start, [StringComparison]::Ordinal) } else { 0 }
    $end = if ($entry.end -and $start -ge 0) { $source.IndexOf($entry.end, $start + $entry.start.Length, [StringComparison]::Ordinal) } else { $source.Length }
    $valid = $start -ge 0 -and $end -ge $start
    if ($NutritionEngine -and $entry.path -eq 'GymManagerClient/Core/ClientSessionStore.swift') {
        $checkpoint = Get-Content (Join-Path $clientRoot 'docs/coach-nutrition-baseline-20261023.json') -Raw | ConvertFrom-Json
        $valid = (Get-NutritionCheckpointHash (Join-Path $clientRoot $entry.path)) -eq ($checkpoint.files | Where-Object path -eq 'Core/ClientSessionStore.swift').sha256
    } elseif ($valid) { $valid = (Text-Hash ($source.Substring($start, $end - $start).TrimEnd())) -eq $entry.sha256 }
    Assert-Refinement $valid "Protected logic/Phase2 UI: $($entry.path) / $($entry.start.Trim())"
}
$visual = Read-Source 'Features/Workout/ClientExerciseVisualCard.swift'
$media = Read-Source 'Core/ClientExerciseMediaPipeline.swift'
$detail = Read-Source 'Features/Workout/ClientExerciseDetailView.swift'
$prescription = Read-Source 'Features/Workout/ClientExercisePrescriptionView.swift'
$anatomy = Read-Source 'Features/Workout/ClientAnatomyMap.swift'
$execution = Read-Source 'Features/Workout/ClientWorkoutExecutionView.swift'
$floating = Read-Source 'Features/Workout/ClientFloatingRestTimer.swift'
$placement = Read-Source 'Core/ClientFloatingTimerPlacement.swift'
$bridge = Read-Source 'Features/Workout/ClientRestTimerBridge.swift'
$live = Read-Source 'Core/ClientRestLiveActivityManager.swift'
$homeSource = Read-Source 'Features/Home/ClientHomeView.swift'
$readiness = Read-Source 'Core/ClientContentLoadState.swift'
$session = Read-Source 'Core/ClientSessionStore.swift'
$repository = Read-Source 'Core/ClientRepository.swift'
$app = Read-Source 'App/GymManagerClientApp.swift'
$widget = Get-Content (Join-Path $clientRoot 'GymManagerRunWidget/ClientRestLiveActivity.swift') -Raw
Assert-Refinement ($visual -match 'ClientCompactSelector' -and $visual -match 'Movimento' -and $visual -match 'Muscoli') 'Single native visual module has two modes'
Assert-Refinement ($visual -notmatch 'TimelineView|ClientExerciseMotionView|sin\(|cos\(') 'Rejected procedural motion removed from exercise presentation'
Assert-Refinement ($visual -match 'Guida anatomica statica, non una dimostrazione' -and $visual -match 'exercise.technique' -and $visual -match 'videoURL.scheme\?\.lowercased\(\) == "https"') 'Fallback honest, technique actual, external video HTTPS and user-opened only'
Assert-Refinement ($media -match 'approvedAssetKeys: Set<String> = \[\]' -and $media -match 'prototypeKeys.contains\(key\), approvedAssetKeys.contains\(key\)' -and $media -match 'bundle.url') 'No unapproved or nonexistent clip can resolve'
Assert-Refinement (([regex]::Matches($media, '"[a-z_]+_v1"')).Count -eq 10) 'Ten media candidate keys, not ten fabricated playable clips'
Assert-Refinement ($media -match 'hasKnownRole' -and $media -match 'unclassified' -and $media -notmatch 'relevance\s*[><=]|random\(|exercise.name') 'Known primary/secondary/unknown roles use real metadata without new weights or name guessing'
Assert-Refinement ($anatomy -match 'AnyLayout\(VStackLayout' -and $anatomy -match 'dash: part.group' -and $anatomy -match 'accessibilityLabel' -and $anatomy -notmatch 'TimelineView') 'Static front/back map supports AX layout and non-color role distinction'
Assert-Refinement ($prescription -match 'exercise.sets' -and $prescription -match 'exercise.repetitions' -and $prescription -match 'exercise.restSeconds' -and $prescription -match 'exercise.loadKg' -and $prescription -notmatch 'premiumCard|\.rpc|TextField') 'Compact operative prescription uses actual Trainer sets/reps/rest/load fields, not a new data model'
Assert-Refinement ($detail -match 'isResting: session.activity.restTimer\?\.exerciseID == exercise.id' -and $visual -match 'player\?\.pause\(\)' -and $visual -match 'accessibilityReduceMotion') 'Shared detail passes real rest state; approved player has pause/disappearance/ReduceMotion hooks'
Assert-Refinement ($detail -match 'history.isEmpty && loadHistory.isEmpty' -and $detail -match 'Carico massimo per sessione' -and $detail -match 'history.prefix\(3\)' -and $detail -match 'loadHistory.count > 1') 'One empty history, accurate session-maximum label, bounded recent rows and actual chart points'
Assert-Refinement ($execution -match 'if let current = log\?\.sets.first' -and $execution.IndexOf('if let current = log?.sets.first') -lt $execution.IndexOf('ForEach(log?.sets.filter')) 'Current set before compact completed history, not accumulating above active input'
Assert-Refinement ($execution -match 'detailExercise = exercise' -and $execution -notmatch 'ClientExerciseVisualCard\(' -and $execution -match 'Tutti gli esercizi' -and $execution -match 'Prossimo:') 'Execution focuses one exercise; technique secondary, all exercises and next accessible'
Assert-Refinement ($execution -match 'completionSummary' -and $execution -match 'durationMinutes' -and $execution -match 'serie registrate' -and $execution -notmatch 'ClientRestTimerBar') 'Actual completion summary replaces abrupt dismissal; old fixed rest card absent'
Assert-Refinement (([regex]::Matches($execution,'anchorPreference\(key: ClientWorkoutAvoidanceKey')).Count -ge 5 -and $detail -match 'anchorPreference\(key: ClientWorkoutAvoidanceKey') 'Current card, notes/detail/undo, next, exercise list, finish and detail content publish critical avoidance'
Assert-Refinement ($floating -match 'highPriorityGesture\(DragGesture\(minimumDistance: 10\)' -and $floating -match 'normalizedPosition' -and $floating -match 'proxy.safeAreaInsets') 'Draggable bounded presentation position separate from timer truth'
Assert-Refinement ($placement -match 'bounds.width >= diameter \+ 16' -and $placement -match '!area.isNull' -and $placement -match 'area.minX.isFinite' -and $placement -match 'avoiding.map' -and $placement -match 'return nil') 'Geometry rejects invalid/narrow bounds and returns accessory when every position blocked'
Assert-Refinement ($floating -match 'safeAreaInset\(edge: \.top\)' -and $floating -match 'useAccessory, presentation.hosts.last == hostID' -and $floating -match 'if owner != hostID \{ expanded = false') 'One top host owns bubble/accessory; popovers close when ownership changes'
Assert-Refinement ($floating -match 'accessibilityValue\("\\\(timer.remainingSeconds\(at: context.date\)' -and $floating -match 'in pausa' -and $floating -match 'A sinistra' -and $floating -match 'A destra') 'Accessible countdown shares timeline clock and non-drag relocation controls'
Assert-Refinement ($floating -match 'adjustRestTimer\(by: -15\)' -and $floating -match 'adjustRestTimer\(by: 15\)' -and $floating -match 'resumeRestTimer' -and $floating -match 'pauseRestTimer' -and $floating -match 'skipRestTimer') 'Controls call existing single timer API only'
Assert-Refinement ($floating -match 'seconds\(4\)' -and $floating -match 'dismissRestReady' -and $floating -match 'allowsHitTesting\(false\)' -and $floating -notmatch 'timerFinished\(') 'Ready popup expires nonblockingly without duplicate haptic engine'
Assert-Refinement ($bridge -match 'task\(id: displayState\)' -and $bridge -match 'state\?\.endsAt' -and $bridge -match 'end.timeIntervalSinceNow' -and $bridge -match 'finishRestTimerIfElapsed' -and $bridge -notmatch 'Timer.publish|\.restTimer\s*=') 'App bridge reads same timestamp, waits once and reconciles foreground; no second countdown store'
Assert-Refinement ($app -match 'StateObject private var restPresentation' -and $app -match 'StateObject private var restLiveActivity' -and $app -match 'background \{ ClientRestTimerBridge\(\) \}' -and $app -match 'environmentObject\(restPresentation\)') 'One app-scoped rest presentation and bridge, not one timer per exercise'
Assert-Refinement ($live -match 'await previous\?\.value' -and $live -match 'Activity<ClientRestActivityAttributes>.activities' -and $live -match 'areActivitiesEnabled' -and $live -notmatch 'ClientRunActivityAttributes|requestAuthorization|\.rpc|service_role') 'Serialized optional rest-only Live Activity; no Run manipulation, permission request or backend'
Assert-Refinement ($live -match 'settings.authorizationStatus == \.authorized' -and $live -match 'settings.soundSetting == \.enabled' -and $live -match 'removePendingNotificationRequests' -and $live -match 'notificationID') 'Only pre-authorized notifications, one identifier, permission-aware sound'
Assert-Refinement ($widget -match 'ActivityConfiguration\(for: ClientRestActivityAttributes' -and $widget -match 'context.isStale' -and $widget -match 'Text\(timerInterval:' -and $widget -match 'Pronto' -and $widget -notmatch 'Button|AppIntent') 'Existing Widget extension adds date-based rest activity and stale/paused presentation; no unsupported actions'
$homeBody = $homeSource.Substring($homeSource.IndexOf('var body:'), $homeSource.IndexOf('private var header:') - $homeSource.IndexOf('var body:'))
Assert-Refinement ($homeBody.IndexOf('header') -lt $homeBody.IndexOf('Le tue priorità') -and $homeBody.IndexOf('contextCards') -lt $homeBody.IndexOf('stepsCard') -and $homeBody -match 'session.contentState\(for: \.workout\)') 'Compact Home greeting then actionable priorities, secondary steps and common readiness gate'
Assert-Refinement ($homeSource -match 'size: 44' -and $homeSource -match 'size: 88' -and $homeSource -notmatch 'size: 118' -and $homeBody -notmatch 'session.prepare\(') 'Hero reduced; no view-owned auth bootstrap or extra content request'
Assert-Refinement ($readiness -match 'guard hasActiveIdentity, phase != \.idle, phase != \.authBootstrap' -and $readiness -match 'return section' -and $session -match 'ClientContentReadiness.resolve') 'Readiness separates bootstrap from known ready-state errors without hiding genuine failures'
Assert-Refinement ($readiness -match '#if DEBUG' -and $readiness -match 'request_id=' -and $readiness -match 'prerequisites_ready=' -and $repository -match 'stage: "profile"' -and $repository -match 'stage: "client_identity"') 'Correlated safe DEBUG stage diagnostics present; no claim of observed device root cause'
Assert-Refinement ($repository -match 'let activeSession = try await client.auth.session' -and $repository -match 'activeSession.user.id == identity.authUserID' -and $repository -match 'prerequisitesReady: true') 'Content prerequisite event follows actual SDK session and ownership gate'
$tests = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientExerciseExperienceTests.swift'), (Join-Path $clientRoot 'GymManagerClientTests/ClientFloatingTimerTests.swift'), (Join-Path $clientRoot 'GymManagerClientTests/ClientHomeReadinessTests.swift') -Raw
Assert-Refinement (([regex]::Matches(($tests -join ''), 'func test')).Count -eq 10) 'Ten deterministic native test definitions present; NOT executed here'
$preview = Read-Source 'Preview/ClientExerciseExperiencePreview.swift'
Assert-Refinement ($preview -match 'width: 320' -and $preview -match 'width: 375' -and $preview -match 'width: 430' -and $preview -match 'accessibility3' -and $preview -match 'Synthetic specimen') 'Three native synthetic preview specimens; no fabricated screenshots'
$literalPattern = '(?<![A-Za-z0-9_])(?:Color\.(?:white|black|red|green|blue|orange|yellow|gray|pink|purple|cyan|mint)|\.(?:white|black|red|green|blue|orange|yellow|gray|pink|purple|cyan|mint))\b|(?<![A-Za-z0-9_])Color\s*\(\s*(?:red|white|hue):'
$outside = 0
foreach ($file in Get-ChildItem $sourceRoot -Recurse -File -Filter '*.swift') {
    $relative = $file.FullName.Substring($sourceRoot.Length+1).Replace('\','/')
    if ($relative -notin @('Core/ClientDesignSystem.swift','Core/ClientTheme.swift') -and !$relative.StartsWith('Preview/')) {
        $outside += [regex]::Matches((Get-Content $file.FullName -Raw),$literalPattern).Count
    }
}
if ($NutritionEngine) {
    Write-Output "Historical Phase34 inventory55; approved Workout UI integration changed that inventory to $outside.5C checks exact UI bytes,not an obsolete global count."
} else {
    Assert-Refinement ($outside -eq 55) 'Authorized semantic migration13 occurrences (68 to55), not full-app Light/Dark adoption'
}
Write-Output "Phase3/4 source checks passed: $passed"
if ($failures.Count) { $failures | ForEach-Object { Write-Output "FAILED: $_" }; exit 1 }
Write-Output 'IOS CLIENT PHASE3/4 SOURCE VALIDATION: PASS - NATIVE BUILD/WORKOUT/TIMER/LIVE ACTIVITY NOT RUN'
