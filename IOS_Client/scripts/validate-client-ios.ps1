[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $clientRoot
$trainerRoot = Join-Path $projectRoot 'IOS'
$sourceRoot = Join-Path $clientRoot 'GymManagerClient'
$projectFile = Join-Path $clientRoot 'GymManagerClient.xcodeproj\project.pbxproj'
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0

function Assert-Check([bool]$Condition, [string]$Name) {
    if ($Condition) { $script:passed++; Write-Output "[PASS] $Name" }
    else { $script:failures.Add($Name); Write-Output "[FAIL] $Name" }
}

function Read-AllSwift {
    (Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.swift' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
}

$workspacePath = Join-Path $clientRoot 'GymManagerClient.xcworkspace\contents.xcworkspacedata'
$schemePath = Join-Path $clientRoot 'GymManagerClient.xcodeproj\xcshareddata\xcschemes\GymManagerClient.xcscheme'
$infoPath = Join-Path $sourceRoot 'Resources\Info.plist'
$privacyPath = Join-Path $sourceRoot 'Resources\PrivacyInfo.xcprivacy'
$entitlementsPath = Join-Path $sourceRoot 'GymManagerClient.entitlements'
$assetCatalogPath = Join-Path $sourceRoot 'Resources\Assets.xcassets'
$appIconContentsPath = Join-Path $assetCatalogPath 'AppIcon.appiconset\Contents.json'
$appIconPath = Join-Path $assetCatalogPath 'AppIcon.appiconset\AppIcon-1024.png'
$widgetRoot = Join-Path $clientRoot 'GymManagerRunWidget'
$widgetInfoPath = Join-Path $widgetRoot 'Info.plist'
$widgetSourcePath = Join-Path $widgetRoot 'GymManagerRunLiveActivity.swift'
$sharedActivityPath = Join-Path $clientRoot 'Shared\ClientRunActivityAttributes.swift'
$pbx = Get-Content -LiteralPath $projectFile -Raw
$swift = Read-AllSwift

foreach ($xmlPath in @($workspacePath, $schemePath, $infoPath, $widgetInfoPath, $privacyPath, $entitlementsPath)) {
    try { [xml](Get-Content -LiteralPath $xmlPath -Raw) | Out-Null; Assert-Check $true "Valid XML: $(Split-Path -Leaf $xmlPath)" }
    catch { Assert-Check $false "Valid XML: $(Split-Path -Leaf $xmlPath)" }
}

$workspace = Get-Content -LiteralPath $workspacePath -Raw
Assert-Check ($workspace -match 'group:GymManagerClient\.xcodeproj' -and $workspace -notmatch 'GymManager\.xcodeproj') 'Client workspace contains only the Client project'
Assert-Check ((Split-Path -Leaf $clientRoot) -eq 'IOS_Client') 'Client project root is IOS_Client'
Assert-Check (([regex]::Matches($pbx, 'isa = PBXNativeTarget')).Count -eq 3) 'Client project has app, Live Activity widget and test targets'
Assert-Check ($pbx -match 'version = 2\.55\.1' -and $pbx -match 'supabase-swift') 'Supabase Swift exact version matches Trainer'
Assert-Check ((([regex]::Matches($pbx, '\{')).Count) -eq (([regex]::Matches($pbx, '\}')).Count)) 'Xcode project braces are balanced'

$defined = [regex]::Matches($pbx, '(?m)^\s*([A-F0-9]{24})\s+(?:/\*.*?\*/\s+)?=') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$referenced = [regex]::Matches($pbx, '\b([A-F0-9]{24})\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
Assert-Check (@($referenced | Where-Object { $_ -notin $defined }).Count -eq 0) 'Every Xcode object reference has a definition'

$baseConfig = Get-Content -LiteralPath (Join-Path $clientRoot 'Config\Base.xcconfig') -Raw
Assert-Check ($baseConfig -match '#include\? "Local\.xcconfig"' -and $baseConfig -notmatch '\.\./\.\./IOS/') 'Client configuration is self-contained with an optional ignored local override'
Assert-Check ($baseConfig -match 'PRODUCT_BUNDLE_IDENTIFIER = com\.gymmanager\.client\.ios') 'Client has an independent bundle identifier'
Assert-Check ($baseConfig -match 'CODE_SIGN_ENTITLEMENTS = GymManagerClient/GymManagerClient\.entitlements') 'Client target references its HealthKit entitlement file'
Assert-Check ($baseConfig -match 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon') 'Client target references the AppIcon asset'
$info = Get-Content -LiteralPath $infoPath -Raw
Assert-Check ($info -match '\$\(SUPABASE_URL\)' -and $info -match '\$\(SUPABASE_PUBLISHABLE_KEY\)') 'Info.plist references client-safe Supabase build settings'
Assert-Check ($info -match 'NSHealthShareUsageDescription' -and (Get-Content -LiteralPath $entitlementsPath -Raw) -match 'com\.apple\.developer\.healthkit') 'HealthKit disclosure and entitlement are both present'
Assert-Check ($info -match 'NSSupportsLiveActivities' -and $info -match '(?s)UIBackgroundModes.*location') 'Running declares Live Activities and background location mode'
Assert-Check ((Test-Path -LiteralPath $widgetSourcePath) -and (Test-Path -LiteralPath $sharedActivityPath) -and $pbx -match 'GymManagerRunWidget\.appex in Embed App Extensions') 'Running Live Activity extension and shared attributes are embedded'
try {
    Get-Content -LiteralPath $appIconContentsPath -Raw | ConvertFrom-Json | Out-Null
    Add-Type -AssemblyName System.Drawing
    $appIconBitmap = [System.Drawing.Bitmap]::FromFile($appIconPath)
    try { Assert-Check ($appIconBitmap.Width -eq 1024 -and $appIconBitmap.Height -eq 1024) 'App icon uses the supplied logo at 1024x1024' }
    finally { $appIconBitmap.Dispose() }
} catch { Assert-Check $false 'App icon uses the supplied logo at 1024x1024' }

$demo = Get-Content -LiteralPath (Join-Path $sourceRoot 'Demo\ClientDemoData.swift') -Raw
$repository = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientRepository.swift') -Raw
Assert-Check ($demo -match '(?s)#if DEBUG.*enum ClientDemoData.*#endif') 'Demo data is compiled only in Debug'
Assert-Check ($demo -match 'case trainerConnected' -and $demo -match 'case standalone') 'Two isolated Debug demo personas are defined'
Assert-Check ($demo -notmatch '(?i)password|secret|token') 'Debug demo data contains no credential fields'
Assert-Check ($swift -notmatch '(?i)service.?role') 'No service-role marker exists in Client source'
Assert-Check ($repository -notmatch '\.(insert|update|upsert|delete|rpc|upload)\s*\(') 'No professional-data writer exists in Client repository'

Assert-Check ($repository -match '\.eq\("auth_user_id", value: authUserID\.uuidString\)') 'Client link derives from authenticated user ID'
Assert-Check ($repository -match '\.eq\("status", value: "active"\)' -and $repository -match 'publishedAt != nil') 'Professional plans require active and published state'
Assert-Check ($repository -match '\.eq\("client_visible", value: true\)' -and $repository -match '\.eq\("status", value: "scheduled"\)') 'Trainer appointments require visible and scheduled state'

$tabs = Get-Content -LiteralPath (Join-Path $sourceRoot 'App\ClientTabView.swift') -Raw
Assert-Check (([regex]::Matches($tabs, '\.tag\(ClientTab\.')).Count -eq 5) 'TabView has exactly five primary destinations'
Assert-Check ($tabs -match 'safeAreaInset' -and $tabs -match 'allowsHitTesting\(false\)') 'Demo badge respects safe area and does not intercept touches'
Assert-Check ($tabs -match '\(\.workout, "Allenamento", "dumbbell\.fill"\)' -and $tabs -notmatch '\(\.workout, "Scheda"') 'Primary workout tab is named Allenamento'

$requiredPages = @(
    'Features\Home\ClientHomeView.swift', 'Features\Workout\ClientWorkoutView.swift',
    'Features\Workout\ClientWorkoutExecutionView.swift', 'Features\Running\ClientRunningView.swift',
    'Features\Nutrition\ClientNutritionView.swift', 'Features\Progress\ClientProgressView.swift',
    'Features\Space\PersonalAgendaView.swift', 'Features\Space\ClientUpdatesView.swift',
    'Features\Space\ClientAccountView.swift'
)
Assert-Check (@($requiredPages | Where-Object { -not (Test-Path -LiteralPath (Join-Path $sourceRoot $_)) }).Count -eq 0) 'All required functional and execution pages exist'
Assert-Check ($swift -match 'Piano del Trainer · sola lettura' -and $swift -match 'Fissato dal Trainer') 'Read-only plans and Trainer appointments are visibly labelled'
Assert-Check ($swift -match 'gymmanager\.client\.agenda\.\\\(source\.rawValue\)' -and $swift -match 'authUserID') 'Personal Agenda storage is namespaced per source and user'
Assert-Check ($swift -match 'gymmanager\.client\.activity\.\\\(source\.rawValue\)' -and $swift -match 'ClientActivityState') 'Workout, meal and running activity is persisted per source and user'

$homeSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Home\ClientHomeView.swift') -Raw
$workoutExecution = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Workout\ClientWorkoutExecutionView.swift') -Raw
$health = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\HealthKitStepService.swift') -Raw
$locationSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\RunningLocationService.swift') -Raw
$liveActivityManager = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientRunLiveActivityManager.swift') -Raw
$locationInitializer = [regex]::Match($locationSource, '(?s)override init\(\)\s*\{(?<body>.*?)\n\s*\}').Groups['body'].Value
$running = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Running\ClientRunningView.swift') -Raw
$nutrition = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Nutrition\ClientNutritionView.swift') -Raw
$account = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Space\ClientAccountView.swift') -Raw
$tabsSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'App\ClientTabView.swift') -Raw
$rootSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'App\ClientRootView.swift') -Raw
$designSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientDesignSystem.swift') -Raw
$activityModels = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientActivityModels.swift') -Raw
$activityInsights = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientActivityInsights.swift') -Raw
$activityDashboard = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Workout\ClientActivityDashboardView.swift') -Raw
Assert-Check ($homeSource -match 'Ciao, \\\(identity\.firstName\)' -and $homeSource -match 'Allenamento di oggi' -and $homeSource -match 'Nutrizione di oggi') 'Home is today-first and uses the authenticated Client name'
Assert-Check ($homeSource -match 'ClientProfileAvatar' -and $homeSource -match 'ClientAccountView\(identity: identity, source: source\)' -and $homeSource -notmatch '👋') 'Home uses a real or fallback avatar linked to Account and no waving emoji'
Assert-Check ($workoutExecution -match 'Completa serie' -and $workoutExecution -match 'ClientRestTimerBar' -and $workoutExecution -match 'Termina allenamento') 'Workout execution includes set completion, rest timer and final check'
Assert-Check ($workoutExecution -match 'Fatica percepita' -and $workoutExecution -match 'Qualità allenamento' -and $workoutExecution -match 'Dolori o fastidi') 'Post-workout flow is limited to rapid feedback fields'
Assert-Check ($swift -match 'toggleMealCompletion' -and $swift -match 'pasti completati') 'Daily meal completion and progress are implemented'
Assert-Check ($health -match 'requestAccessAndRefresh' -and $health -match 'HKStatisticsQuery' -and $homeSource -match 'Collega Apple Salute') 'HealthKit steps use an explicit user-triggered permission flow'
Assert-Check ($health -notmatch 'requestAccessAndRefresh\(\).*init') 'HealthKit permission is not requested during initialization'
Assert-Check ($swift -match 'endsAt: Date\?' -and $swift -match 'timeIntervalSince\(date\)') 'Rest timer authority is a persisted timestamp rather than a decrement counter'
Assert-Check ($info -match 'NSLocationWhenInUseUsageDescription' -and $locationSource -match 'requestWhenInUseAuthorization') 'Running uses disclosed When-In-Use location access'
Assert-Check ($locationSource -match 'ObservableObject, @preconcurrency CLLocationManagerDelegate') 'Core Location delegate conformance is compatible with Swift 6 actor isolation'
Assert-Check (([regex]::Matches($liveActivityManager, 'nonisolated\(unsafe\) let activityFor(Update|End)')).Count -eq 2) 'ActivityKit update and end isolate the Xcode 26.4 concurrency workaround'
Assert-Check ($locationInitializer -notmatch 'requestWhenInUseAuthorization') 'Location permission is deferred until the Client starts a run'
Assert-Check ($running -match 'MapPolyline' -and $running -match 'location\.distanceKm' -and $running -match 'RunningMetricMode') 'Running shows a live map, measured distance and selectable speed or pace'
Assert-Check ($running -match 'onLongPressGesture' -and $running -match 'ClientRunningCompletionView' -and $running -match 'accessibilityReduceMotion') 'Running has protected finish, route replay and Reduce Motion support'
Assert-Check ($swift -match 'route: \[ClientRoutePoint\]' -and $swift -match 'maximumSpeedKmh' -and $swift -match 'averageSpeedKmh') 'Completed runs persist route and final speed metrics'
Assert-Check ($swift -match 'capabilities\.runningEnabled' -and $swift -match 'runningPlan != nil') 'Running UI is gated by Client capability and assigned plan'
Assert-Check ($homeSource -match 'ClientCircularProgress' -and $homeSource.IndexOf('stepsCard') -lt $homeSource.IndexOf('ClientSectionHeader(title: "Priorità"')) 'Home places circular daily steps inside the top daily hero'
Assert-Check ($health -match 'ClientHealthDayWindow' -and $health -match '\.autoupdatingCurrent' -and $health -match '\.cumulativeSum') 'HealthKit total uses the current local day and HealthKit cumulative source reconciliation'
Assert-Check ($health -notmatch 'HKSampleQuery' -and $health -notmatch 'reduce\s*\{') 'HealthKit steps are not manually summed across potentially overlapping sources'
Assert-Check ($homeSource -match 'refreshIfPreviouslyRequested' -and $homeSource -match 'scenePhase' -and $homeSource -match 'Task\.sleep\(for: \.seconds\(60\)\)') 'HealthKit steps refresh periodically and when the app becomes active'
Assert-Check ($homeSource -match 'IL TUO OGGI' -and $homeSource -match 'dayStatusHeadline' -and $homeSource -notmatch 'Il tuo percorso') 'Home replaces the old journey block with actionable daily status'
Assert-Check ($homeSource -match 'Piano completato' -and $homeSource -match 'ClientProgressSegmentBar\(completed: completed' -and $homeSource -match 'withAnimation\(\.snappy') 'Home nutrition has premium one-tap animated completion and daily progress'
$workoutBrowse = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Workout\ClientWorkoutView.swift') -Raw
$progressSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Progress\ClientProgressView.swift') -Raw
Assert-Check ($workoutBrowse -match 'selectedExercise' -and $workoutBrowse -match 'ClientExerciseDetailSheet' -and $workoutBrowse -match 'Storico personale' -and $workoutBrowse -match 'videoURL') 'Every browsed exercise opens supported prescription, media and local history details'
Assert-Check ($progressSource -match 'kpiGrid' -and $progressSource -match 'weeklyWorkoutChart' -and $progressSource -match 'weightSection' -and $progressSource -match 'measurementsSection' -and $progressSource -match 'runningSection') 'Progress combines real KPIs and charts for weight, measures, workouts, steps and running'
Assert-Check ($repository -match 'calories_kcal' -and $homeSource -match 'completedCalories' -and $homeSource -match '-- kcal') 'Nutrition calories use backend values and an honest unavailable fallback'
Assert-Check ($nutrition -match 'ForEach\(plan\.days\)' -and $nutrition -match 'isCurrentDay' -and $nutrition -match 'Consultazione · sola lettura') 'Nutrition exposes every plan day and gates completion to today'
Assert-Check ($nutrition.IndexOf('planHeader(plan)') -lt $nutrition.IndexOf('weekSelector(plan)') -and $nutrition.IndexOf('weekSelector(plan)') -lt $nutrition.IndexOf('currentDayHero(plan: plan, day: day)')) 'Nutrition shows plan and weekly selector before daily meals'
Assert-Check ($account -match 'PhotosPicker' -and $tabsSource -match 'avatarStore\.image' -and $swift -match 'GymManagerClient/Avatars') 'Profile photo is local per account and appears in the Spazio tab'
Assert-Check ($homeSource -match 'homeAgendaTasks' -and $homeSource -match 'toggleAgendaTask') 'Home shows and completes personal Agenda activities'
Assert-Check ($locationSource -match 'allowsBackgroundLocationUpdates = true' -and $running -match 'ClientRunLiveActivityManager') 'Running continues location updates and publishes lock-screen metrics'
Assert-Check ($rootSource -match 'preferredColorScheme\(\.dark\)' -and $designSource -match 'surfaceElevated' -and $designSource -match 'brandGradient') 'Client uses centralized layered dark premium tokens'
Assert-Check ($tabsSource -match 'ClientPremiumTabBar' -and $tabsSource -match 'safeAreaInset\(edge: \.bottom' -and $tabsSource -match 'accessibilityAddTraits') 'Bottom navigation uses a custom accessible premium dark tab bar'
Assert-Check ($homeSource -match 'dailyHero' -and $homeSource -match 'ClientProgressSegmentBar' -and $homeSource -match 'ViewThatFits') 'Home combines top daily hero, meal progress and adaptive layouts'
Assert-Check ($workoutExecution -match 'ESERCIZIO ATTIVO' -and $workoutExecution -match 'clientInputField' -and $workoutExecution -match 'focusedField') 'Workout execution has a high-contrast active state and keyboard-safe inputs'
Assert-Check ($nutrition -match 'currentDayHero' -and $nutrition -match 'ScrollView\(\.horizontal' -and $nutrition -match 'dayPill') 'Nutrition highlights today and exposes only real plan days in its selector'
Assert-Check ($progressSource -match 'recentWeightDelta' -and $progressSource -match 'ClientDirectionalBadge' -and $progressSource -match 'chartPlotStyle') 'Progress uses neutral recent deltas and integrated dark charts'
Assert-Check ($progressSource -notmatch '(?i)body fat|massa magra|storico passi') 'Progress does not invent unavailable body composition or step history'
Assert-Check ($workoutBrowse -match 'case activity = "Attività"' -and $workoutBrowse -match 'case gym = "Palestra"' -and $workoutBrowse -match 'case running = "Corsa"' -and $workoutBrowse -match 'case recap = "Riepilogo"' -and $workoutBrowse -match 'category: Category = \.activity') 'Training opens Activity first and preserves Gym, Running and Recap'
Assert-Check ($workoutBrowse -match 'LazyVGrid' -and $workoutBrowse -notmatch 'Il tuo percorso' -and $workoutBrowse -match 'ClientWorkoutPlanDetailView' -and $workoutBrowse -match 'Storico schede') 'Training starts with category cards and exposes active and historical plans'
Assert-Check ($activityDashboard -match '0\.\.<42' -and $activityDashboard -match 'Palestra' -and $activityDashboard -match 'Corsa' -and $activityDashboard -match 'Entrambi') 'Activity calendar uses a fixed compact month and non-color-only legend'
Assert-Check ($activityDashboard -match 'dayCellBackground' -and $activityDashboard -match 'dumbbell\.fill' -and $activityDashboard -match 'figure\.run') 'Activity completion colors the full day cell and retains icon-based states'
Assert-Check ($activityDashboard -notmatch 'summaryTile\("Tempo attivo"') 'Monthly Activity summary omits active time'
Assert-Check ($activityInsights -match 'state\.workouts' -and $activityInsights -match 'state\.runningResults' -and $activityInsights -notmatch '(?i)calendar_table|activity_calendar') 'Activity calendar derives from real workout and running sessions without a duplicate calendar store'
Assert-Check ($activityInsights -match 'gymSessions' -and $activityInsights -match 'runningDistanceKm' -and $activityInsights -match 'activeSeconds' -and $activityInsights -match 'activeDays' -and $activityInsights -match 'personalBests') 'Monthly and period summaries aggregate only supported activity metrics'
Assert-Check ($activityModels -match 'elapsedSeconds: TimeInterval\?' -and $locationSource -match 'stabilizedUpdateInterval: TimeInterval = 25' -and $locationSource -match 'smoothingWindow: TimeInterval = 30') 'Running persists active sample time and stabilizes live speed on a 25-second cadence'
Assert-Check ($running -match 'Ritmo attuale · 25s' -and $running -match 'Velocità attuale · 25s' -and $running -match 'Ritmo medio' -and $running -match 'Velocità media') 'Running live shows pace and speed simultaneously with session averages'
Assert-Check ($activityInsights -match 'func splits\(for route:' -and $activityInsights -match 'Double\(index\) \* 1_000' -and $running -match 'ClientRunSplitToast') 'Running generates and presents automatic one-kilometer splits'
Assert-Check ($activityInsights -match 'case oneKilometer = 1_000' -and $activityInsights -match 'case threeKilometers = 3_000' -and $activityInsights -match 'case fiveKilometers = 5_000' -and $activityInsights -match 'case tenKilometers = 10_000') 'Personal Best supports 1K, 3K, 5K and 10K without extrapolation'
Assert-Check ($activityInsights -match 'startOffsetMeters' -and $activityInsights -match 'interpolatedSample' -and $activityInsights -match 'start\.distance \+ Double\(target\.rawValue\)') 'Best-effort engine searches interpolated internal route windows'
Assert-Check ($activityInsights -match 'func leaderboard' -and $activityInsights -match 'entries\.count < max\(0, limit\)' -and $activityInsights -match 'sessionID == candidate\.sessionID') 'Top 3 is sorted and deduplicated per running session'
Assert-Check ($running -match 'ClientPersonalBestDetailView' -and $running -match 'Split automatici' -and $running -match 'NUOVI PERSONAL BEST') 'Running home and final summary expose Top 3, splits and multiple PB results'
Assert-Check ($running -notmatch 'CORSA ASSEGNATA' -and $running.IndexOf('Inizia corsa') -lt $running.IndexOf('Personal Best')) 'Running removes the assigned-run header and prioritizes its start CTA'
Assert-Check ($activityDashboard -match 'ClientActivityPeriod\.allCases' -and $activityDashboard -match 'LineMark' -and $activityDashboard -notmatch 'BarMark' -and $activityDashboard -notmatch 'Durata palestra') 'Recap supports all periods with one running-distance chart in kilometers'
Assert-Check ($workoutBrowse -match 'import Charts' -and $workoutBrowse -match 'Carico migliore per sessione' -and $activityInsights -match 'exerciseLoadHistory' -and $activityInsights -match 'actualLoadKg.*\.max\(\)') 'Exercise history charts the best real load recorded per session'
Assert-Check ($demo -match 'workoutHistory: pastPlans' -and $demo -match 'static func activity' -and $demo -match '\(5, 10, 56\)' -and $demo -match '\(3, 10, 54\)' -and $demo -match '\(1, 10, 52\)') 'Trainer-connected demo includes past plans, activity and running PB data'
Assert-Check ($workoutExecution -match '(?s)private var header: some View \{\s*let completed = .*?\s*return VStack' -and $workoutExecution -match '\.premiumCard\(tint: completed ==') 'Workout header keeps completed count in modifier scope'

$tests = Get-Content -LiteralPath (Join-Path $clientRoot 'GymManagerClientTests\ClientPhase1Tests.swift') -Raw
Assert-Check (([regex]::Matches($tests, '(?m)^\s*func test')).Count -ge 30) 'At least 30 native unit tests are defined'
Assert-Check ($tests -match 'testAutomaticKilometerSplitsRequireCompletedDistance' -and $tests -match 'testBestEffortFindsInternalThreeKilometerWindow' -and $tests -match 'testRunningTopThreeSortsAndKeepsOneEntryPerSession' -and $tests -match 'testActivityAggregationCombinesGymAndRunningWithoutDuplicates') 'Native tests cover splits, internal best effort, Top 3 and activity aggregation'

$trainerProjectPath = Join-Path $trainerRoot 'GymManager.xcodeproj\project.pbxproj'
if (Test-Path -LiteralPath $trainerProjectPath) {
    $trainerProject = Get-Content -LiteralPath $trainerProjectPath -Raw
    Assert-Check ($trainerProject -notmatch 'GymManagerClient|ClientApp') 'Trainer project has no Client membership or reference'
    Assert-Check (-not (Test-Path -LiteralPath (Join-Path $trainerRoot 'ClientApp')) -and -not (Test-Path -LiteralPath (Join-Path $trainerRoot 'GymManager.xcworkspace'))) 'No Client application artifact remains inside IOS'
} else {
    Assert-Check ($pbx -notmatch 'GymManager\.xcodeproj|\.\.[\\/]IOS[\\/]') 'Standalone Client project has no Trainer project reference'
    Assert-Check (-not (Test-Path -LiteralPath $trainerRoot)) 'Dedicated Client repository contains no IOS Trainer directory'
}

Write-Output "Static checks passed: $passed"
if ($failures.Count) {
    Write-Output "Static checks failed: $($failures.Count)"
    $failures | ForEach-Object { Write-Output " - $_" }
    exit 1
}
Write-Output 'CLIENT IOS STATIC VALIDATION: PASS'
