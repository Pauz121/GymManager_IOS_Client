[CmdletBinding()]
param([switch]$FinalUI67, [switch]$RefinementPhase34, [switch]$NutritionEngine, [switch]$SmartEditing, [switch]$NutritionUI)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $clientRoot 'GymManagerClient'
. (Join-Path $PSScriptRoot 'nutrition-checkpoint-source.ps1')
# -NutritionEngine reverses only authorized5C additions for historical hashes.
# Run validate-nutrition-coach.ps1 too: it checks current source and frozen Workout/UI.
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0
function Assert-Training([bool]$Condition, [string]$Name) {
    if ($Condition) { $script:passed++; Write-Output "[PASS] $Name" }
    else { $script:failures.Add($Name); Write-Output "[FAIL] $Name" }
}
function Read-Source([string]$Path) { Get-NutritionCheckpointSource (Join-Path $sourceRoot $Path) }
function Get-TextHash([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text)))
}
$workout = Read-Source 'Features/Workout/ClientWorkoutView.swift'
$activity = Read-Source 'Features/Workout/ClientActivityDashboardView.swift'
$running = Read-Source 'Features/Running/ClientRunningView.swift'
$tabs = Read-Source 'App/ClientTabView.swift'
$selector = Read-Source 'Core/ClientCompactSelector.swift'
$scrub = Read-Source 'Core/ClientTabScrubState.swift'
$baseline = Get-Content (Join-Path $clientRoot 'docs/ui-training-baseline-20261023.json') -Raw | ConvertFrom-Json
$allowed = @('App/ClientTabView.swift','Features/Workout/ClientWorkoutView.swift','Features/Workout/ClientActivityDashboardView.swift','Features/Running/ClientRunningView.swift')
Assert-Training ($baseline.files.Count -eq 54 -and !(Compare-Object ($allowed | Sort-Object) ($baseline.allowedModified | Sort-Object))) '54-file baseline has exactly4 authorized UI edits'
$approved34 = if ($RefinementPhase34) {
    (Get-Content (Join-Path $clientRoot 'docs/ui-exercise-home-baseline-20261023.json') -Raw | ConvertFrom-Json).allowedModified
} else { @() }
foreach ($entry in $baseline.files) {
    if ($NutritionEngine -and $entry.path -eq 'Core/ClientNutritionGenerator.swift') { continue } # Authorized5C engine, checked separately.
    if ($entry.path -in $allowed -or $entry.path -in $approved34) { continue }
    Assert-Training ((Get-NutritionCheckpointHash (Join-Path $sourceRoot $entry.path)) -eq (Get-NutritionHistoricalExpectedHash $entry)) "Exact protected source bytes: $($entry.path)"
}
$fragments = Get-Content (Join-Path $clientRoot 'docs/ui-training-protected-fragments-20261023.json') -Raw | ConvertFrom-Json
Assert-Training ($fragments.Count -eq 13) '13 frozen pre-edit fragments cover details, read lifecycle, running data/actions/replay/format'
foreach ($entry in $fragments) {
    if ($RefinementPhase34 -and $entry.start -eq 'private struct ClientWorkoutPlanDetailView') {
        # Phase3 explicitly authorizes exercise detail only. Phase34 validator
        # checks the exact Phase2 prefix up to that detail, not a blanket waiver.
        continue
    }
    $source = (Read-Source $entry.path).Replace("`r`n","`n")
    $start = $source.IndexOf($entry.start, [StringComparison]::Ordinal)
    $end = if ($entry.end -and $start -ge 0) { $source.IndexOf($entry.end, $start + $entry.start.Length, [StringComparison]::Ordinal) } else { $source.Length }
    $valid = $start -ge 0 -and $end -ge $start
    if ($valid) { $valid = (Get-TextHash ($source.Substring($start, $end - $start))) -eq (Get-NutritionHistoricalExpectedHash $entry) }
    Assert-Training $valid "Frozen fragment: $($entry.path) / $($entry.start.Trim())"
}
Assert-Training ($workout -match 'ClientCompactSelector\(values: availableCategories' -and $workout -notmatch 'categoryCard\(') 'Category cards replaced with one shared navigation control'
Assert-Training ($selector -match 'ScrollView\(\.horizontal\)' -and $selector -match 'fixedSize\(horizontal: true, vertical: true\)' -and $selector -notmatch 'lineLimit|minimumScaleFactor') 'Selector scrolls intrinsic labels instead of truncating or shrinking'
Assert-Training ($selector -match 'Button \{' -and $selector -match 'minimumTarget' -and $selector -match 'isSelected' -and $selector -match 'accessibilityElement\(children: \.contain\)') 'Native selector buttons retain44pt/selected semantics/individual accessibility'
Assert-Training ($selector -match 'accessibilityReduceMotion' -and $selector -match 'scrollTo\(value' -and $selector -notmatch 'premiumCard|shadow\(') 'Quiet navigation follows selected item and ReduceMotion without decorative cards'
Assert-Training ($workout -match 'gymStatus\("Oggi riposo' -and $workout -match 'gymStatus\("Piano in arrivo' -and $workout -match 'minHeight: ClientControlSize.minimumTarget') 'Gym rests/upcoming are inline and session targets stay44pt'
$gymHeader = $workout.Substring($workout.IndexOf('struct ClientGymPlanHeader'), $workout.IndexOf('private struct ClientWorkoutPlanDetailView') - $workout.IndexOf('struct ClientGymPlanHeader'))
Assert-Training ($gymHeader -match 'plan.title' -and $gymHeader -match 'plan.currentWeek' -and $gymHeader -match 'plan.sessions.count' -and $gymHeader -notmatch 'premiumCard|GeometryReader|offset\(|height:') 'Compact Gym header has real plan/week/session data and no structural height/offset hacks'
Assert-Training ($activity -match 'if dynamicTypeSize.isAccessibilitySize' -and $activity -match 'calendarGrid.frame\(minWidth: 7 \* ClientControlSize.minimumTarget\)' -and $activity -match 'DatePicker\("Giorno da consultare"' -and $activity -notmatch '\.dynamicTypeSize\(\.\.\.') 'Calendar has native fallback for accessibility/insufficient width, not a DynamicType ceiling'
Assert-Training ($activity -match 'underline\(isToday' -and $activity -match 'isSelected \? ClientClay.color\(\.textEmphasis\)' -and $activity -match 'square.stack.fill' -and $activity -notmatch 'system\(size: 8') 'Today underline/selected border/activity symbols replace tiny color-only markers'
Assert-Training ($activity -match 'ClientCompactSelector\(values: ClientActivityPeriod.allCases' -and $activity -match 'recapStatus\(' -and $activity -notmatch 'ClientEmptyState|premiumCard') 'Recap periods reuse selector and empty data stays inline'
Assert-Training ($activity -match 'max\(5, ceil\(summary.runningDistanceKm / 5\) \* 5\)' -and $activity -match 'min\(1, max\(0, summary.runningDistanceKm / maximum\)\)' -and $activity -match 'Chart\(buckets\)') 'Distance scale and real activity bucket source are retained'
Assert-Training ($running -match 'ForEach\(recordedTargets\)' -and $running -match 'leaderboard\(results: results, target: \$0\).isEmpty') 'Only achieved PB distances create cards'
Assert-Training ($running -match 'if location.route.count > 1' -and $running -match 'if let distance = result.distanceKm' -and $running -match 'if let pace = result.averagePaceMinutesPerKm' -and $running -notmatch '\?\? "Non disponibile"') 'Running renders actual metrics, not a grid of unavailable placeholders'
Assert-Training ($running -match 'if result.route.count > 1' -and $running -match 'Percorso GPS non disponibile. Sono mostrati solo i dati registrati.' -and $running -match 'summaryMetric\("Durata"') 'No-GPS completion omits empty map but preserves duration/context'
Assert-Training ($tabs -match 'LongPressGesture\(minimumDuration: 0.45, maximumDistance: 12\)' -and $tabs -match 'sequenced\(before: DragGesture' -and $tabs -match 'case \.second\(true, \.some\(let drag\)\)') 'Scrub requires native longpress then actual drag'
Assert-Training ($tabs -match 'tabButtons.highPriorityGesture\(scrubGesture\)' -and $tabs -notmatch '\.onTapGesture' -and $tabs -match 'Button \{\s*select\(tab\)' -and $tabs -match 'safeAreaInset\(edge: \.bottom') 'Five real tab buttons remain primary; gesture scoped inside inset bar'
Assert-Training ($tabs -match 'voiceOverEnabled \|\| switchControlEnabled' -and $tabs -match 'switchControlStatusDidChangeNotification' -and $tabs -match 'accessibilityAddTraits' -and $tabs -match 'accessibilityIdentifier') 'Assistive-tech alternatives retain separate labelled selected buttons'
Assert-Training ($tabs -match 'onChange\(of: isScrubbing\)' -and $tabs -match 'onEnded \{ _ in scrub.end\(\)' -and $tabs -match 'withAnimation\(reduceMotion \? nil' -and $tabs -match 'guard selection != tab else') 'GestureState cancellation cleans interaction; reduced motion and unchanged-selection guard'
Assert-Training ($scrub -match 'threshold: Double = 40' -and $scrub -match 'abs\(delta\) >= Self.threshold' -and $scrub -match 'anchorX = horizontal' -and $scrub -match 'min\(count - 1, max\(0,' -and $scrub -notmatch '\bwhile\b|Timer|Task|Supabase') 'UI-only scrub uses fresh40pt movement,one step/event,clamped indices,no timers/backend'
$testSource = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientTabScrubTests.swift') -Raw
Assert-Training ($testSource -match 'testHoldAndSmallJitter' -and $testSource -match 'testFirstAndLastBoundaries' -and $testSource -match 'testCancelResetsInteraction' -and $testSource -match 'testOneLargeSample') 'Native deterministic interaction tests defined; execution requires Swift/Xcode'
$layoutTests = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientTrainingLayoutTests.swift') -Raw
Assert-Training ($layoutTests -match '\[288, 343, 398\]' -and $layoutTests -match 'accessibility3' -and $layoutTests -match 'UIHostingController') 'Small/standard/ProMax native layout measurements defined,not HTML approximations'
$preview = Read-Source 'Preview/ClientTrainingPreview.swift'
Assert-Training ($preview -match '#if DEBUG' -and $preview -match 'width: 320' -and $preview -match 'width: 375' -and $preview -match 'width: 430' -and $preview -match 'accessibility3') 'Three native preview specimens cover phone sizes and large type'
# Exact approved literal delta; the protected file hashes prove no other area migrated.
$literalPattern = '(?<![A-Za-z0-9_])(?:Color\.(?:white|black|red|green|blue|orange|yellow|gray|pink|purple|cyan|mint)|\.(?:white|black|red|green|blue|orange|yellow|gray|pink|purple|cyan|mint))\b|(?<![A-Za-z0-9_])Color\s*\(\s*(?:red|white|hue):'
$outside = 0
foreach ($file in Get-ChildItem $sourceRoot -Recurse -File -Filter '*.swift') {
    $relative = $file.FullName.Substring($sourceRoot.Length+1).Replace('\','/')
    if ($relative -notin @('Core/ClientDesignSystem.swift','Core/ClientTheme.swift') -and !$relative.StartsWith('Preview/')) {
        $outside += [regex]::Matches((Get-Content $file.FullName -Raw),$literalPattern).Count
    }
}
if (!$RefinementPhase34) {
    Assert-Training ($outside -eq 68) 'Phase2 migrates18 literal occurrences in authorized UI (86→68),not the whole app'
} else {
    Write-Output "Phase3/4 authorized literal migration counted separately; current inventory $outside"
}
Write-Output "Training source checks passed: $passed"
if ($failures.Count) { $failures | ForEach-Object { Write-Output "FAILED: $_" }; exit 1 }
Write-Output 'IOS CLIENT PHASE2 SOURCE VALIDATION: PASS — NATIVE BUILD/TOUCH/VOICEOVER/SYSTEM GESTURES NOT RUN'
