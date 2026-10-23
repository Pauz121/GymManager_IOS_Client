[CmdletBinding()]
param([switch]$FinalUI67, [switch]$NutritionUI)

$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $clientRoot
$trainerRoot = Join-Path $projectRoot 'IOS'
$sourceRoot = Join-Path $clientRoot 'GymManagerClient'
. (Join-Path $PSScriptRoot 'nutrition-ui-checkpoint-source.ps1')
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
$detailSource = Get-Content (Join-Path $sourceRoot 'Features/Workout/ClientExerciseDetailView.swift') -Raw
$floatingSource = Get-Content (Join-Path $sourceRoot 'Features/Workout/ClientFloatingRestTimer.swift') -Raw
$mediaPipeline = Get-Content (Join-Path $sourceRoot 'Core/ClientExerciseMediaPipeline.swift') -Raw

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
$backendConfigPath = Join-Path $clientRoot 'Config\Backend.xcconfig'
$backendConfig = if (Test-Path -LiteralPath $backendConfigPath) { Get-Content -LiteralPath $backendConfigPath -Raw } else { '' }
Assert-Check ($baseConfig -match '#include "Backend\.xcconfig"' -and $baseConfig -match '#include\? "Local\.xcconfig"' -and $baseConfig -notmatch '\.\./\.\./IOS/') 'Client configuration is self-contained with an optional ignored local override'
Assert-Check ($backendConfig -match 'SUPABASE_URL\s*=\s*https:/\$\(\)/uslkraelkdjrwqjisczz\.supabase\.co' -and $backendConfig -match 'SUPABASE_PUBLISHABLE_KEY\s*=\s*sb_publishable_[A-Za-z0-9_-]{20,}' -and $backendConfig -notmatch 'service_role') 'Fresh clones include only the client-safe production Supabase configuration'
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
Assert-Check ($repository -notmatch '\.(insert|update|upsert|delete|upload)\s*\(' -and $repository -match 'rpc\("complete_client_onboarding"\)') 'Client repository writes no professional data and only completes own onboarding through RPC'

Assert-Check ($repository -match '\.eq\("auth_user_id", value: authUserID\.uuidString\)') 'Client link derives from authenticated user ID'
Assert-Check ($repository -match '\.eq\("status", value: "active"\)' -and $repository -match 'publishedAt != nil') 'Professional plans require active and published state'
Assert-Check ($repository -match 'isPublishedFor' -and $repository -notmatch 'start > day' -and $swift -match 'func isEffective\(on date: Date = Date\(\)\)') 'Published future plans remain readable while Today respects their effective period'
Assert-Check ($repository -match '\.eq\("client_visible", value: true\)' -and $repository -match '\.eq\("status", value: "scheduled"\)') 'Trainer appointments require visible and scheduled state'
Assert-Check ($repository -match '\.gte\("ends_at", value: clientRequestTimestamp\(today\)\)') 'Check Studio fetch filters expired appointments before ordering and limiting'

$tabs = Get-Content -LiteralPath (Join-Path $sourceRoot 'App\ClientTabView.swift') -Raw
Assert-Check (([regex]::Matches($tabs, '\.tag\(ClientTab\.')).Count -eq 5) 'TabView has exactly five primary destinations'
Assert-Check ($tabs -match 'safeAreaInset' -and $tabs -match 'allowsHitTesting\(false\)') 'Demo badge respects safe area and does not intercept touches'
Assert-Check ($tabs -match '\(\.workout, "Allenamento", "dumbbell\.fill"\)' -and $tabs -notmatch '\(\.workout, "Scheda"') 'Primary workout tab is named Allenamento'
Assert-Check ($tabs -notmatch '\.task\(id: selectedTab\)' -and $tabs -match 'didEnterBackground' -and $tabs -match 'session.canRefreshOnForeground') 'Tab navigation does not reload content; only a real foreground return can refresh successful reads'

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
$widgetSource = Get-Content -LiteralPath $widgetSourcePath -Raw
$locationInitializer = [regex]::Match($locationSource, '(?s)override init\(\)\s*\{(?<body>.*?)\n\s*\}').Groups['body'].Value
$running = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Running\ClientRunningView.swift') -Raw
$nutrition = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Nutrition\ClientNutritionView.swift') -Raw
$account = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Space\ClientAccountView.swift') -Raw
$tabsSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'App\ClientTabView.swift') -Raw
$appSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'App\GymManagerClientApp.swift') -Raw
$rootSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'App\ClientRootView.swift') -Raw
$spaceSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Space\PersonalSpaceView.swift') -Raw
$designSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientDesignSystem.swift') -Raw
$activityModels = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientActivityModels.swift') -Raw
$activityInsights = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientActivityInsights.swift') -Raw
$activityDashboard = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Workout\ClientActivityDashboardView.swift') -Raw
$clientSupabase = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientSupabase.swift') -Raw
$sessionSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientSessionStore.swift') -Raw
$onboardingSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Onboarding\ClientOnboardingView.swift') -Raw
$generatorSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientWorkoutGenerator.swift') -Raw
$guidedWorkoutSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Workout\ClientGuidedWorkoutView.swift') -Raw
$visualModelSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientExerciseVisualModels.swift') -Raw
$visualCardSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Workout\ClientExerciseVisualCard.swift') -Raw
Assert-Check ($homeSource -match 'Ciao, \\\(identity\.firstName\)' -and $homeSource -match 'Allenamento di oggi' -and $homeSource -match 'Nutrizione di oggi') 'Home is today-first and uses the authenticated Client name'
Assert-Check ($sessionSource -match 'guard !isRefreshing' -and $sessionSource -match 'let refreshedIdentity = try await repository\.identity' -and $sessionSource -notmatch '(?s)func refresh\(\) async \{.{0,180}state = \.loading') 'Content refresh preserves the visible session and revalidates the Client link'
Assert-Check ($sessionSource -match 'private var refreshTask: Task<Void, Never>' -and $sessionSource -match 'await refreshTask\.value' -and $sessionSource -match 'Task \{ @MainActor \[weak self\]') 'Refresh uses one session-owned task instead of a cancellable tab-owned request'
Assert-Check ($sessionSource -match 'auth\.session' -and $sessionSource -match 'activeSession\.user\.id == identity\.authUserID' -and $sessionSource -match 'refreshGeneration == generation' -and $sessionSource -match 'currentIdentity\.authUserID == identity\.authUserID') 'Refresh validates the session account and discards stale results'
Assert-Check ($sessionSource -match 'refreshTask\?\.cancel\(\)' -and $sessionSource -match '(?s)func signOut\(\) async \{\s+invalidateSessionReads\(\)' -and $sessionSource -match 'sessionGeneration == ownerGeneration, refreshGeneration == generation') 'Logout and session replacement invalidate both bootstrap and refresh generations'
Assert-Check ($sessionSource -match 'ClientRefreshErrorPolicy\.isCancellation' -and $sessionSource -match 'refreshError = ClientRefreshErrorPolicy.message' -and $sessionSource -notmatch 'refreshFailureNotice') 'Read failures use their own state, not the global Trainer/action alert'
Assert-Check ($swift -match 'NSURLErrorCancelled' -and $swift -match 'error is CancellationError' -and $swift -match 'operation=content_refresh stage=' -and $swift -match 'static func diagnosticCode') 'Refresh diagnostics distinguish cancellations without dumping credentials or payloads'
Assert-Check ($swift -match '\.refreshable \{ await session\.refresh\(\) \}') 'Trainer content screens expose pull-to-refresh'

$contentLifecycle = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientContentLoadState.swift') -Raw
$contentStatus = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientContentStatusView.swift') -Raw
$progressSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Progress\ClientProgressView.swift') -Raw
$lifecycleTests = Get-Content -LiteralPath (Join-Path $clientRoot 'GymManagerClientTests\ClientContentLifecycleTests.swift') -Raw
$layoutTests = Get-Content -LiteralPath (Join-Path $clientRoot 'GymManagerClientTests\ClientCardLayoutTests.swift') -Raw
$readRefresh = [regex]::Match($sessionSource, '(?s)private func performContentRefresh.*?(?=    private func invalidateContentRefresh)').Value
$surface = [regex]::Match($designSource, '(?s)struct ClientPremiumCardSurface.*?(?=extension View)').Value
Assert-Check ($contentLifecycle -match 'case idle, authBootstrap, loading, loaded, empty, error' -and $contentLifecycle -match 'case failed\(String\)') 'Six read phases and per-section pending/empty/failure states are explicit'
Assert-Check ($repository -match 'async throws -> ClientSnapshot' -and $repository -match 'if cancelled \{ throw CancellationError\(\) \}' -and $repository -match 'try Task.checkCancellation\(\)') 'Snapshot cancellation propagates instead of creating section warnings'
Assert-Check ($repository -match 'activeSession.user.id == identity.authUserID' -and $repository -match 'throw ClientAppError.invalidClientLink') 'Content reads require the authenticated account and connected Client/Trainer IDs'
Assert-Check ($repository -match 'retainFailedSections\(from: previous\)' -and $sessionSource -match 'previous: sameOwnership \? previousSnapshot : nil') 'Cached failed sections are retained only for unchanged Client/Trainer ownership'
Assert-Check ($sessionSource -match 'private var bootstrapTask' -and $sessionSource -match 'await bootstrapTask.value' -and $sessionSource -match 'bootstrapTask\?\.cancel\(\)') 'Initial restoration is session-owned, single-flight and invalidated at session replacement'
Assert-Check ($sessionSource -match 'ownerGeneration: UUID, requestID: UUID = UUID\(\)' -and $sessionSource -notmatch 'ownerGeneration: UUID\?') 'Every bootstrap caller must supply its original generation, not adopt a later session'
Assert-Check ($readRefresh -notmatch 'notice\s*=' -and $readRefresh -notmatch 'activate\(code:|completeInitialOnboarding|\.rpc\(|\.upsert\(|\.update\(') 'Read-only refresh has no Trainer mutation or action-notice assignment'
Assert-Check ($rootSource -match 'get: \{ session.notice != nil \}' -and $progressSource -match 'contentState\(for: \.progress\).failure') 'Global alert is action-only; Progress renders its own section failure'
Assert-Check ($homeSource -match 'ClientContentGate\(section: \.workout' -and $homeSource -match 'ClientContentGate\(section: \.nutrition' -and $contentStatus -match 'case \.idle, \.loading:' -and $contentStatus -match 'case \.loaded, \.empty:') 'Home gates empty content behind successful loading and keeps actual section errors actionable'
Assert-Check ($sessionSource -match 'refreshError == nil && \(readPhase == \.loaded \|\| readPhase == \.empty\)') 'Actual read errors are not silently retried on foreground events'
Assert-Check ($contentLifecycle -match '#if DEBUG' -and $contentLifecycle -match '\[IOS_CLIENT\]' -and $contentLifecycle -match 'requestID.uuidString' -and $contentLifecycle -match 'sessionReady=' -and $contentLifecycle -notmatch 'error.localizedDescription|accessToken|refreshToken|userID.uuidString') 'Read diagnostics use random request IDs and prerequisite flags without user IDs or payloads'
Assert-Check ($surface -match '\.overlay\(alignment: \.topTrailing\)' -and $surface -match '\.clipShape' -and $surface -notmatch 'ZStack|GeometryReader|minHeight|maxHeight') 'Premium decorative background cannot impose the circle size on the surface'
Assert-Check ($activityDashboard -match 'ClientActivityRecapHeader' -and $activityDashboard -match 'ViewThatFits\(in: \.horizontal\)' -and $activityDashboard -match 'VStack\(alignment: \.leading, spacing: ClientSpacing.related\) \{ metrics \}') 'Recap inline metrics retain natural height and a wrapping vertical fallback'
Assert-Check ($swift -match '(?s)private var gymContent: some View \{\s*VStack\(alignment: \.leading, spacing: ClientSpacing.control\)' -and $swift -match 'struct ClientGymPlanHeader' -and $swift -match 'Text\(plan.title\).*\n\s*\.fixedSize\(horizontal: false, vertical: true\)') 'Gym header/inline rest/session rows participate in one natural vertical stack with wrapping title'
Assert-Check ($lifecycleTests -match 'testCancelledSnapshotStopsBeforeAuthAndSectionQueries' -and $lifecycleTests -match 'testSuccessfulEmptyReadDoesNotResurrectPreviouslyAssignedPlans' -and $lifecycleTests -match 'testMissingConnectedIdentityIsNotReportedAsEmpty') 'Native tests define cancellation, empty/error separation and invalid connected identity regression cases (not executed here)'
Assert-Check ($layoutTests -match 'testDecorativeSurfaceHonorsShortCardProposal' -and $layoutTests -match 'testGymHeaderAndRestCardReserveSeparateVerticalSpace' -and $layoutTests -match 'accessibility3' -and $layoutTests -match '\[288, 398\]') 'Native layout tests define short surface, two-card spacing and small/large phone Dynamic Type cases (not executed here)'
Assert-Check ($homeSource -match 'ClientProfileAvatar' -and $homeSource -match 'ClientAccountView\(identity: identity, source: source\)' -and $homeSource -notmatch '👋') 'Home uses a real or fallback avatar linked to Account and no waving emoji'
Assert-Check ($workoutExecution -match 'Completa serie' -and $workoutExecution -match 'clientFloatingRestTimer' -and $workoutExecution -match 'Termina allenamento') 'Workout execution preserves set completion/final check with one floating timer presentation'
Assert-Check ($workoutExecution -match 'Fatica percepita' -and $workoutExecution -match 'Qualità allenamento' -and $workoutExecution -match 'Dolori o fastidi') 'Post-workout flow is limited to rapid feedback fields'
Assert-Check ($swift -match 'toggleMealCompletion' -and $swift -match 'pasti completati') 'Daily meal completion and progress are implemented'
Assert-Check ($health -match 'requestAccessAndRefresh' -and $health -match 'HKStatisticsQuery' -and $homeSource -match 'Collega Apple Salute' -and $tabsSource -match 'ClientHealthConnectionPrompt') 'HealthKit steps use an explicit user-triggered permission flow'
Assert-Check ($health -notmatch 'requestAccessAndRefresh\(\).*init') 'HealthKit permission is not requested during initialization'
Assert-Check ($health -match 'ClientHealthPermissionDecision' -and $health -match 'case notAsked' -and $health -match 'case accepted' -and $health -match 'case declined' -and $tabsSource -match 'healthKit\.declineConnection') 'HealthKit first-run decision is persisted as notAsked, accepted or declined'
Assert-Check ($tabsSource -match 'GymManager può leggere i passi' -and $tabsSource -match 'Non ora' -and $tabsSource -match 'source == \.live' -and $tabsSource -match '!session\.shouldOfferTrainerCode') 'HealthKit primer is branded, live-only and deferred until onboarding completes'
Assert-Check ($health -match 'requestAuthorization\(toShare: \[\], read: \[stepType\]\)' -and $health -notmatch 'HKObjectType\.quantityType\(forIdentifier: \.(?!stepCount)') 'HealthKit requests read access only to step count'
Assert-Check ($swift -match 'endsAt: Date\?' -and $swift -match 'timeIntervalSince\(date\)') 'Rest timer authority is a persisted timestamp rather than a decrement counter'
Assert-Check ($info -match 'NSLocationWhenInUseUsageDescription' -and $locationSource -match 'requestWhenInUseAuthorization') 'Running uses disclosed When-In-Use location access'
Assert-Check ($locationSource -match 'ObservableObject, @preconcurrency CLLocationManagerDelegate') 'Core Location delegate conformance is compatible with Swift 6 actor isolation'
Assert-Check (([regex]::Matches($liveActivityManager, 'nonisolated\(unsafe\) let activityFor(Update|End)')).Count -eq 2) 'ActivityKit update and end isolate the Xcode 26.4 concurrency workaround'
Assert-Check ($locationInitializer -notmatch 'requestWhenInUseAuthorization') 'Location permission is deferred until the Client starts a run'
Assert-Check ($running -match 'MapPolyline' -and $running -match 'location\.distanceKm' -and $running -match 'RunningMetricMode') 'Running shows a live map, measured distance and selectable speed or pace'
Assert-Check ($running -match 'onLongPressGesture' -and $running -match 'ClientRunningCompletionView' -and $running -match 'accessibilityReduceMotion') 'Running has protected finish, route replay and Reduce Motion support'
Assert-Check ($swift -match 'route: \[ClientRoutePoint\]' -and $swift -match 'maximumSpeedKmh' -and $swift -match 'averageSpeedKmh') 'Completed runs persist route and final speed metrics'
Assert-Check ($swift -match 'private var availableCategories: \[Category\] \{ Category\.allCases \}' -and $swift -match 'snapshot\.runningPlan \?\? ClientRunningPlan') 'Running UI is always available with an honest free-run fallback'
Assert-Check ($swift -match 'ClientPersonalWorkoutPlan' -and $swift -match 'savePersonalWorkoutPlan' -and $swift -match 'ClientPersonalWorkoutPlanEditor') 'Standalone workout plans support real personal CRUD and reuse the execution engine'
Assert-Check ($swift -match 'searchPersonalExercises' -and $swift -match 'ClientExercisePickerSheet' -and $swift -match 'catalogExerciseID') 'Standalone workout uses the global exercise catalog and private exercise snapshots'
Assert-Check ($swift -match 'ClientPersonalNutritionPlan' -and $swift -match 'ClientPersonalNutritionPlanEditor' -and $swift -match 'ClientPersonalMealEditor') 'Standalone nutrition supports personal plans, days, meals and quantities'
Assert-Check ($swift -match 'searchPersonalFoods' -and $swift -match 'ClientFoodPickerSheet' -and $swift -match 'caloriesPer100g') 'Standalone nutrition searches the real food catalog and computes quantity calories'
Assert-Check ($swift -match 'ClientPersonalContentStore' -and $swift -match 'owner_user_id' -and $swift -match 'self_created') 'Personal content is namespaced locally and synchronized under Auth user ownership'
Assert-Check ($swift -match 'ClientWorkoutCreationChoiceView' -and $guidedWorkoutSource -match 'Crea da solo' -and $guidedWorkoutSource -match 'Crea per me') 'Standalone workout exposes manual and guided creation without a second plan system'
Assert-Check ($generatorSource -match 'ClientTrainingProfile' -and $generatorSource -match 'ClientWorkoutProgressionRule' -and $generatorSource -match 'ClientWorkoutPlanValidation' -and $generatorSource -match 'double_progression') 'Guided workout uses separated profile, prescription, progression and validation models'
Assert-Check ($generatorSource -notmatch 'random\(' -and $generatorSource -notmatch 'Int\.random|randomElement' -and $guidedWorkoutSource -match 'variation \+= 1') 'Guided regeneration is deterministic and preserves questionnaire constraints'
Assert-Check ($generatorSource -match 'loadKg: nil' -and $generatorSource -match 'nutritionPhase == \.cut' -and $generatorSource -match 'goal == \.strengthAndMass') 'Generator never invents loads and treats goal and nutrition phase as separate modifiers'
Assert-Check ($sessionSource -match 'personalExerciseCatalog' -and $sessionSource -match 'exerciseCatalogCache' -and $sessionSource -match 'savePersonalWorkoutPlanConfirmed' -and $sessionSource -match 'workoutPlan\(id:') 'Guided catalog is cached and save waits for a server read-back confirmation'
Assert-Check ($mediaPipeline -match 'bench_press_v1' -and $mediaPipeline -match 'lateral_raise_v1' -and $mediaPipeline -match 'approvedAssetKeys: Set<String> = \[\]' -and $visualCardSource -notmatch 'TimelineView|ClientExerciseMotionView' -and $visualCardSource -match 'ClientAnatomyMap') 'Exercise visual uses static anatomy and approval-gated ten-candidate media pipeline,not a robot loop'
Assert-Check ($visualCardSource -match 'accessibilityReduceMotion' -and $visualCardSource -match 'accessibilityElement\(children: \.contain\)' -and $visualModelSource -match 'static_body_v1' -and $visualCardSource -notmatch '(?i)animation unavailable|asset mancante') 'Exercise visuals preserve accessible controls, Reduce Motion and user-safe offline fallback'
Assert-Check ($workoutExecution -match 'ClientExerciseDetailSheet' -and $workoutExecution -match 'clientFloatingRestTimer' -and $detailSource -match 'ClientExerciseVisualCard') 'Execution opens the shared exercise visual in detail while preserving floating recovery'
Assert-Check ($swift -match 'RunningHistoryPeriod' -and $swift -match 'threeMonths' -and $swift -match 'sixMonths') 'Running history provides Month, 3M, 6M and Year filters'
Assert-Check ($homeSource -match 'ClientCircularProgress' -and $homeSource.IndexOf('ClientContentGate(section: .workout') -lt $homeSource.IndexOf('stepsCard')) 'Home keeps real circular steps after actionable daily priorities'
Assert-Check ($health -match 'ClientHealthDayWindow' -and $health -match '\.autoupdatingCurrent' -and $health -match '\.cumulativeSum') 'HealthKit total uses the current local day and HealthKit cumulative source reconciliation'
Assert-Check ($health -notmatch 'HKSampleQuery' -and $health -notmatch 'reduce\s*\{') 'HealthKit steps are not manually summed across potentially overlapping sources'
Assert-Check ($homeSource -match 'refreshIfPreviouslyRequested' -and $homeSource -match 'scenePhase' -and $homeSource -match 'Task\.sleep\(for: \.seconds\(60\)\)') 'HealthKit steps refresh periodically and when the app becomes active'
Assert-Check ($homeSource -match 'Le tue priorità' -and $homeSource -match 'dayStatusHeadline' -and $homeSource -notmatch 'Il tuo percorso') 'Home prioritizes daily actions rather than a generic journey hero'
Assert-Check ($homeSource -match 'Piano completato' -and $homeSource -match 'ClientProgressSegmentBar\(completed: completed' -and $homeSource -match 'withAnimation\(reduceMotion \? nil') 'Home retains one-tap meal completion/progress with reduced-motion support'
$workoutBrowse = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Workout\ClientWorkoutView.swift') -Raw
$personalWorkoutSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Workout\ClientPersonalWorkoutView.swift') -Raw
$personalNutritionSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Nutrition\ClientPersonalNutritionView.swift') -Raw
$progressSource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Progress\ClientProgressView.swift') -Raw
Assert-Check ($workoutBrowse -match 'selectedExercise' -and $workoutBrowse -match 'ClientExerciseDetailSheet' -and $detailSource -match 'Storico personale' -and $visualCardSource -match 'videoURL') 'Every browsed/executed exercise shares prescription,real media and local history detail'
Assert-Check ($progressSource -match $(if ($FinalUI67) { 'Picker\("Periodo' } else { 'kpiGrid' }) -and $progressSource -match 'weeklyWorkoutChart' -and $progressSource -match 'weightSection' -and $progressSource -match 'measurementsSection' -and $progressSource -match 'runningSection') 'Progress combines real period data and charts;legacy KPI grid only before67'
Assert-Check ($progressSource -match '\.position\(by: \.value\("Tipo"' -and $progressSource -match 'ActivityKind\.gym' -and $progressSource -match 'ActivityKind\.running') 'Progress compares real Gym and Running sessions with grouped weekly bars'
Assert-Check ($progressSource -match 'ActivityHeatmapPoint' -and $progressSource -match 'RectangleMark' -and $progressSource -match 'Ultime 16 settimane') 'Progress renders a real completion heatmap across sixteen weeks'
Assert-Check ($repository -match 'calories_kcal' -and $homeSource -match 'completedCalories' -and $homeSource -match '-- kcal') 'Nutrition calories use backend values and an honest unavailable fallback'
Assert-Check ($nutrition -match 'ForEach\(plan\.days\)' -and $nutrition -match 'isCurrentDay' -and $nutrition -match 'Consultazione · sola lettura') 'Nutrition exposes every plan day and gates completion to today'
Assert-Check ($nutrition.IndexOf('planHeader(plan)') -lt $nutrition.IndexOf('weekSelector(plan)') -and $nutrition.IndexOf('weekSelector(plan)') -lt $nutrition.IndexOf('currentDayHero(plan: plan, day: day)')) 'Nutrition shows plan and weekly selector before daily meals'
Assert-Check ($account -match 'PhotosPicker' -and $tabsSource -match 'avatarStore\.image' -and $swift -match 'GymManagerClient/Avatars') 'Profile photo is local per account and appears in the Spazio tab'
Assert-Check ($homeSource -match 'homeAgendaTasks' -and $homeSource -match 'toggleAgendaTask') 'Home shows and completes personal Agenda activities'
Assert-Check ($locationSource -match 'allowsBackgroundLocationUpdates = true' -and $running -match 'ClientRunLiveActivityManager') 'Running continues location updates and publishes lock-screen metrics'
Assert-Check ($rootSource -match $(if ($FinalUI67) { 'clientAppearance\(appearance.preference\)' } else { 'preferredColorScheme\(\.dark\)' }) -and $designSource -match 'surfaceElevated' -and $designSource -match 'brandGradient') 'Client uses centralized premium tokens;final67 adopts persisted appearance'
Assert-Check ($tabsSource -match 'ClientPremiumTabBar' -and $tabsSource -match 'safeAreaInset\(edge: \.bottom' -and $tabsSource -match 'accessibilityAddTraits') 'Bottom navigation uses a custom accessible premium dark tab bar'
Assert-Check ($homeSource -match 'dailyHero' -and $homeSource -match 'ClientProgressSegmentBar' -and $homeSource -match 'ViewThatFits') 'Home combines top daily hero, meal progress and adaptive layouts'
Assert-Check ($homeSource -match '(?s)VStack\(alignment: \.leading, spacing: 18\) \{\s*header\s*Text\(dayStatusHeadline\)' -and $homeSource -match 'size: 44' -and $homeSource -notmatch 'size: 118') 'Home has compact identity/status and secondary88pt steps instead of a decorated hero'
Assert-Check ($workoutExecution -match 'ESERCIZIO ATTIVO' -and $workoutExecution -match 'clientInputField' -and $workoutExecution -match 'focusedField') 'Workout execution has a high-contrast active state and keyboard-safe inputs'
Assert-Check ($nutrition -match 'currentDayHero' -and $nutrition -match 'ScrollView\(\.horizontal' -and $nutrition -match 'dayPill') 'Nutrition highlights today and exposes only real plan days in its selector'
Assert-Check ($nutrition -match $(if ($FinalUI67) { 'frame\(minWidth: 72, minHeight: 72\)' } else { 'frame\(width: 72, height: 72\)' }) -and $personalNutritionSource -match $(if ($FinalUI67) { 'frame\(minWidth: 66, minHeight: 58\)' } else { 'frame\(width: 66, height: 58\)' }) -and $nutrition -notmatch 'frame\(width: 72, minHeight:' -and $personalNutritionSource -notmatch 'frame\(width: 66, minHeight:' -and $nutrition -match 'isToday \? ClientClay\.sage' -and $nutrition -notmatch 'isSelected \? ClientClay\.brandGradient') 'Nutrition weekdays are spacious, compile-safe, use a green today border and no red selected fill'
Assert-Check ($progressSource -match 'recentWeightDelta' -and $progressSource -match 'ClientDirectionalBadge' -and $progressSource -match 'chartPlotStyle') 'Progress uses neutral recent deltas and integrated dark charts'
Assert-Check ($progressSource -match 'ClientProgressWeek\.mondayToSunday' -and $progressSource -match 'firstWeekday = 2' -and $progressSource -match 'Lunedì – Domenica') 'Progress week is always Monday through Sunday'
Assert-Check ($progressSource -notmatch '(?i)body fat|massa magra|storico passi') 'Progress does not invent unavailable body composition or step history'
Assert-Check ($workoutBrowse -match 'case activity = "Attività"' -and $workoutBrowse -match 'case gym = "Palestra"' -and $workoutBrowse -match 'case running = "Corsa"' -and $workoutBrowse -match 'case recap = "Riepilogo"' -and $workoutBrowse -match 'category: Category = \.activity') 'Training opens Activity first and preserves Gym, Running and Recap'
Assert-Check ($workoutBrowse -match 'ClientCompactSelector\(values: availableCategories' -and $workoutBrowse -notmatch 'categoryCard\(' -and $workoutBrowse -match 'ClientWorkoutPlanDetailView' -and $workoutBrowse -match 'Storico schede') 'Training starts with compact native navigation and preserves active and historical plan destinations'
Assert-Check ($workoutBrowse -match 'canManagePersonalWorkoutPlans\(in: identity\.mode\)' -and $nutrition -match 'ClientPersonalNutritionLibraryView\(allowsEditing: false\)') 'Trainer-connected workout and nutrition render personal content in read-only mode'
Assert-Check ($personalWorkoutSource -match 'if !allowsEditing' -and $personalWorkoutSource -match 'Schede personali precedenti' -and $personalWorkoutSource -match 'PERSONALE · STORICO' -and $personalNutritionSource -match 'Piani personali precedenti' -and $personalNutritionSource -match 'Storico · sola lettura') 'Previous personal plans remain visible as a clearly separated history'
Assert-Check (([regex]::Matches($sessionSource, 'guard ClientAccessPolicy\.canManagePersonal(Workout|Nutrition)Plans')).Count -ge 5 -and $sessionSource -match 'savePersonalWorkoutPlanConfirmed' -and $sessionSource -match 'trainerManagedPlansMessage') 'Session service rejects direct and confirmed workout or nutrition mutations after Trainer linking'
Assert-Check ($activityDashboard -match '0\.\.<42' -and $activityDashboard -match 'Palestra' -and $activityDashboard -match 'Corsa' -and $activityDashboard -match 'Entrambi') 'Activity calendar uses a fixed compact month and non-color-only legend'
Assert-Check ($activityDashboard -match 'dayCellBackground' -and $activityDashboard -match 'dumbbell\.fill' -and $activityDashboard -match 'figure\.run' -and $activityDashboard -match 'square.stack.fill' -and $activityDashboard -match 'underline\(isToday') 'Activity uses tonal cells and distinct today/selection/gym/run/both cues, not color alone'
Assert-Check ($activityDashboard -notmatch 'summaryTile\("Tempo attivo"') 'Monthly Activity summary omits active time'
Assert-Check ($activityInsights -match 'state\.workouts' -and $activityInsights -match 'state\.runningResults' -and $activityInsights -notmatch '(?i)calendar_table|activity_calendar') 'Activity calendar derives from real workout and running sessions without a duplicate calendar store'
Assert-Check ($activityInsights -match 'gymSessions' -and $activityInsights -match 'runningDistanceKm' -and $activityInsights -match 'activeSeconds' -and $activityInsights -match 'activeDays' -and $activityInsights -match 'personalBests') 'Monthly and period summaries aggregate only supported activity metrics'
Assert-Check ($activityModels -match 'elapsedSeconds: TimeInterval\?' -and $locationSource -match 'stabilizedUpdateInterval: TimeInterval = 25' -and $locationSource -match 'smoothingWindow: TimeInterval = 30') 'Running persists active sample time and stabilizes live speed on a 25-second cadence'
Assert-Check ($running -match 'Ritmo attuale · 25s' -and $running -match 'Velocità attuale · 25s' -and $running -match 'Ritmo medio' -and $running -match 'Velocità media') 'Running live selector exposes current and average pace or speed without duplicating the metric grid'
Assert-Check ($activityModels -match 'func speedSamples' -and $running -match 'liveTrendChart' -and $running -match 'Chart\(samples\)' -and $running -match 'VELOCITÀ LIVE') 'Running live chart is derived from accepted GPS route samples'
Assert-Check ($activityInsights -match 'func splits\(for route:' -and $activityInsights -match 'Double\(index\) \* 1_000' -and $running -match 'ClientRunSplitToast') 'Running generates and presents automatic one-kilometer splits'
Assert-Check ($activityInsights -match 'case oneKilometer = 1_000' -and $activityInsights -match 'case threeKilometers = 3_000' -and $activityInsights -match 'case fiveKilometers = 5_000' -and $activityInsights -match 'case tenKilometers = 10_000') 'Personal Best supports 1K, 3K, 5K and 10K without extrapolation'
Assert-Check ($activityInsights -match 'startOffsetMeters' -and $activityInsights -match 'interpolatedSample' -and $activityInsights -match 'start\.distance \+ Double\(target\.rawValue\)') 'Best-effort engine searches interpolated internal route windows'
Assert-Check ($activityInsights -match 'func leaderboard' -and $activityInsights -match 'entries\.count < max\(0, limit\)' -and $activityInsights -match 'sessionID == candidate\.sessionID') 'Top 3 is sorted and deduplicated per running session'
Assert-Check ($running -match 'ClientPersonalBestDetailView' -and $running -match 'Split automatici' -and $running -match 'NUOVI PERSONAL BEST') 'Running home and final summary expose Top 3, splits and multiple PB results'
Assert-Check ($running -notmatch 'CORSA ASSEGNATA' -and $running.IndexOf('Inizia corsa') -lt $running.IndexOf('Personal Best')) 'Running removes the assigned-run header and prioritizes its start CTA'
Assert-Check ($running -notmatch 'Text\(plan\.detail\)' -and $running -notmatch 'plan\.targetDistanceKm' -and $running -notmatch 'plan\.targetMinutes') 'Running entry removes assigned-session details before the start CTA'
Assert-Check ($activityDashboard -match 'ClientActivityPeriod\.allCases' -and $activityDashboard -match 'AreaMark' -and $activityDashboard -match 'LineMark' -and $activityDashboard -notmatch 'BarMark' -and $activityDashboard -notmatch 'Durata palestra') 'Recap supports all periods with one premium running-distance area chart in kilometers'
Assert-Check ($activityDashboard -match 'distanceScaleIndicator' -and $activityDashboard -match 'GeometryReader' -and $activityDashboard -match 'Circle\(\)\.fill\(ClientClay.color\(\.runningAccent\)\)' -and $activityDashboard -match 'proxy.size.width \* CGFloat\(ratio\)') 'Recap distance retains its exact scaled marker using the shared running color'
Assert-Check ($workoutBrowse -match 'minHeight: ClientControlSize.minimumTarget' -and $workoutBrowse -match 'clayCard\(padding: ClientSpacing.control, appearance: \.adaptive\)' -and $activityDashboard -match 'compactMetric') 'Gym rows retain44pt targets with compact adaptive surfaces and Recap metrics'
Assert-Check ($activityDashboard -match 'private var compactHeader' -and $activityDashboard -match 'ClientCompactSelector' -and $activityDashboard -match 'private func recapStatus' -and $activityDashboard -notmatch 'premiumCard\(') 'Recap replaces decorative hero/empty cards with inline metrics/status and shared period controls'
Assert-Check ($widgetSource -match 'activityBackgroundTint\(background\)' -and $widgetSource -match 'foregroundStyle\(\.white\)' -and $widgetSource -match 'accent\.opacity\(0\.26\)') 'Running Live Activity uses dark high-contrast surfaces and red accents'
Assert-Check ($clientSupabase -match 'functions\.invoke' -and $clientSupabase -match 'redeem-client-link-code' -and $clientSupabase -match 'Authorization.*Bearer' -and $clientSupabase -match 'FunctionsError\.httpError') 'Trainer code redemption explicitly sends the authenticated Client JWT to the Supabase Edge Function'
Assert-Check ($sessionSource -match 'func connectTrainer\(code:' -and $onboardingSource -match 'TrainerCodeEntryForm' -and $account -match 'TrainerCodeEntryForm') 'First login and Account reuse the same Trainer-code flow'
Assert-Check ($onboardingSource -match 'Text\("GYMMANAGER"\)' -and $onboardingSource -match 'Text\("Accedi"\)' -and $onboardingSource -match 'Text\("Registrati"\)' -and $onboardingSource -notmatch 'Ho un codice dal mio Trainer') 'Welcome contains only GymManager access and registration actions'
Assert-Check ($onboardingSource.Contains('PASSO \(step) DI 2') -and $onboardingSource -match 'Nome' -and $onboardingSource -match 'Cognome' -and $onboardingSource -match 'ClientBiologicalSex' -and $onboardingSource -match 'Email') 'Registration step one collects personal data and biological sex'
Assert-Check ($onboardingSource -match 'Username' -and $onboardingSource -match 'Ripeti password' -and $onboardingSource -match 'Creazione account' -and $sessionSource -match 'auth\.signUp') 'Registration step two creates the Auth account without duplicate submit'
Assert-Check ($sessionSource -match 'account_type.*client_self_registration' -and $sessionSource -notmatch 'UserDefaults.*password|password.*UserDefaults') 'Client signup uses constrained metadata and never persists passwords'
Assert-Check ($sessionSource -match 'resumePendingRegistrationAfterEmailConfirmation' -and $sessionSource -match 'AuthError\.api' -and $sessionSource -match 'email_not_confirmed' -and $onboardingSource -match 'Ho confermato l.email') 'Email-confirmed registration resumes a real Client session with structured Auth errors'
Assert-Check ($sessionSource -match 'ClientEmailVerificationStatus' -and $sessionSource -match 'emailConfirmedAt' -and $sessionSource -match 'auth\.user\(\)' -and $spaceSource -match 'Email non verificata') 'Space reflects the current server-side email verification state'
Assert-Check ($sessionSource -match 'auth\.resend\(email: email, type: \.signup\)' -and $spaceSource -match 'Invia email di conferma' -and $onboardingSource -match 'Reinvia email di conferma') 'Email confirmation can be resent from both authenticated and no-session flows'
Assert-Check ($sessionSource -match 'auth\.session\(from: url\)' -and $appSource -match '\.onOpenURL' -and $appSource -match 'handleAuthCallback') 'Incoming Auth callbacks refresh the real Supabase session'
Assert-Check ($spaceSource -match 'ClientProfileAvatar' -and $spaceSource -match 'size: 44' -and $spaceSource -match 'minHeight: 68' -and $spaceSource -match 'ClientAccountView\(identity: identity, source: source\)' -and $spaceSource -notmatch 'destination\("Account"') 'Space profile is a compact accessible account link without duplicate navigation'
Assert-Check ($sessionSource -match 'Logger\(' -and $sessionSource -match 'status=.*code=' -and $sessionSource -notmatch 'user=|message=|password=|token=') 'Debug registration diagnostics expose stage/status/code without user IDs, server prose or credentials'
Assert-Check ($rootSource -match 'ClientTrainerInvitationView' -and $onboardingSource -match 'Hai un codice di accesso\?' -and $onboardingSource -match 'Non ora' -and $sessionSource -match 'completeInitialOnboarding') 'Optional Trainer prompt is shown after first login and can be skipped persistently'
Assert-Check ($detailSource -match 'import Charts' -and $detailSource -match 'Carico massimo per sessione' -and $activityInsights -match 'exerciseLoadHistory' -and $activityInsights -match 'actualLoadKg.*\.max\(\)') 'Exercise history charts the actual maximum recorded per session with accurate labels'
Assert-Check ($demo -match 'workoutHistory: pastPlans' -and $demo -match 'static func activity' -and $demo -match '\(5, 10, 56\)' -and $demo -match '\(3, 10, 54\)' -and $demo -match '\(1, 10, 52\)') 'Trainer-connected demo includes past plans, activity and running PB data'
Assert-Check ($workoutExecution -match '(?s)private var header: some View \{\s*let completed = .*?\s*return VStack' -and $workoutExecution -match 'ClientProgressSegmentBar\(completed: completed') 'Compact workout header keeps real completed count in scope'

$tests = Get-Content -LiteralPath (Join-Path $clientRoot 'GymManagerClientTests\ClientPhase1Tests.swift') -Raw
$difficultyPolicy = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientExerciseDifficultyPolicy.swift') -Raw
Assert-Check ((Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientCatalogMuscleMapping.swift') -Raw) -match 'difficulty_level') 'Catalog decoding includes the optional persistent difficulty attribute'
Assert-Check ($difficultyPolicy -match 'guard let level' -and $difficultyPolicy -match 'level != \.advanced' -and $difficultyPolicy -match 'case \(\.advanced, _\)') 'Difficulty policy excludes unknown and automatic advanced techniques for nonadvanced users'
$catalogMapping = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientCatalogMuscleMapping.swift') -Raw
$anatomySource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Workout\ClientAnatomyMap.swift') -Raw
Assert-Check ($catalogMapping -match 'primary_muscle_group_id' -and $catalogMapping -match 'posterior_chain' -and $mediaPipeline -match 'exercise.catalogMuscles' -and $visualCardSource -match 'Accessori non classificati') 'Anatomy retains canonical catalog roles/axes and honestly reports unclassified accessories'
Assert-Check ($catalogMapping -match 'roleIsKnown: primaryMuscleGroupID != nil' -and $catalogMapping -match 'hasKnownRole &&' -and $visualCardSource -match 'Ruolo non definito') 'Missing catalog primary role remains unclassified rather than labelled secondary'
Assert-Check ($catalogMapping -match '\$0 <= 1' -and $generatorSource -match 'primaryMuscles: hasCatalogMuscles \? item.primaryMuscles') 'Stored coefficients share Desktop validity bounds and authoritative associations suppress inferred roles'
Assert-Check ($workoutExecution -match 'ClientExerciseDetailSheet' -and $workoutExecution -match 'detailExercise = exercise' -and $workoutExecution -notmatch 'ClientExerciseVisualCard\(') 'Execution prioritizes set input and keeps full anatomy behind the technique detail action'
Assert-Check ($anatomySource -match 'Posteriore' -and $anatomySource -match 'Anteriore' -and $anatomySource -match 'path.closeSubpath' -and $visualCardSource -match 'nessuna percentuale di attivazione') 'Anatomy retains front/rear contours and discloses missing classification without invented percentages'
Assert-Check ($workoutExecution -match '\$detailExercise' -and $workoutExecution -match 'timer.exerciseID' -and $visualCardSource -notmatch 'ClientMuscleMiniMap') 'Execution opens per-exercise details and keeps the resting exercise visible without a duplicate map'
Assert-Check ($floatingSource -match 'Circle\(\).trim' -and $floatingSource -match 'runningAccent' -and $floatingSource -match 'timer.phase == .paused' -and $floatingSource -notmatch 'fullScreenCover') 'Floating circular recovery uses existing phase and cyan role without blocking the workout'
Assert-Check ($floatingSource -match 'adjustRestTimer\(by: -15\)' -and $floatingSource -match 'adjustRestTimer\(by: 15\)' -and $floatingSource -match 'Pronto per la prossima serie' -and $floatingSource -match 'skipRestTimer') 'Floating recovery preserves adjustment,skip,pause and nonblocking completion feedback'
Assert-Check ((Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientActivityModels.swift') -Raw) -match 'durationSeconds: TimeInterval\?') 'Recovery persists a backwards-compatible duration denominator'
$manualWizard = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Workout\ClientManualWorkoutWizard.swift') -Raw
$manualDraft = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientManualWorkoutDraft.swift') -Raw
$manualTests = Get-Content -LiteralPath (Join-Path $clientRoot 'GymManagerClientTests\ClientManualWorkoutTests.swift') -Raw
Assert-Check ($personalWorkoutSource -match '\? \.manual : \.guided' -and $manualWizard -match 'PASSO' -and $manualWizard -match 'groupsStep' -and $manualWizard -match 'prescriptionStep') 'Manual entry opens a staged day/group/exercise/prescription/preview wizard'
Assert-Check ($manualWizard -match 'showReduction' -and $manualWizard -match 'interactiveDismissDisabled' -and $manualWizard -match 'Continua a creare') 'Manual wizard protects draft dismissal and reduction of days'
Assert-Check ($manualWizard -match 'personalExerciseCatalog' -and $manualDraft -match 'ClientExerciseMetadataNormalizer.enrich' -and $manualDraft -match 'loadKg: nil' -and $manualWizard -notmatch 'Carico kg|\$exercise.loadKg') 'Manual wizard reuses cached system catalog and shared metadata with no invented load input'
Assert-Check ($manualWizard -match 'savePersonalWorkoutPlanConfirmed' -and $manualWizard -match 'if saved \{ onSaved\(\) \}' -and $sessionSource -match 'confirmed.sessions == plan.sessions') 'Manual save closes only after confirmed payload readback and retains retry draft on failure'
Assert-Check ($manualTests -match 'testOldSessionPayloadWithoutGroupsStillDecodes' -and $manualTests -match 'testPayloadRoundTripPreservesGroupsExerciseOrderAndIDs' -and $manualTests -match 'testValidationRequiresExercisesButNotWeight') 'Native manual tests define backwards compatibility, stable ordered payload and no-weight validation'
Assert-Check ($workoutExecution -match 'Ultima volta:' -and $activityInsights -match 'previousExerciseLoad' -and $activityInsights -match '\$0.startedAt < startedAt') 'Execution displays only a previous real completed-set load without prefill'
$nutritionWizard = Get-Content -LiteralPath (Join-Path $sourceRoot 'Features\Nutrition\ClientNutritionCreationWizard.swift') -Raw
if ($FinalUI67) { . (Join-Path $PSScriptRoot 'phase67-checkpoint-source.ps1'); $nutritionWizard = Restore-FinalUICheckpoint (Join-Path $sourceRoot 'Features/Nutrition/ClientNutritionCreationWizard.swift') $nutritionWizard }
if ($NutritionUI) { $nutritionWizard = Restore-NutritionUICheckpoint (Join-Path $sourceRoot 'Features/Nutrition/ClientNutritionCreationWizard.swift') $nutritionWizard }
$nutritionCreation = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientNutritionCreation.swift') -Raw
$nutritionGenerator = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientNutritionGenerator.swift') -Raw
$personalRepositorySource = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientPersonalRepository.swift') -Raw
$nutritionCreationTests = Get-Content -LiteralPath (Join-Path $clientRoot 'GymManagerClientTests\ClientNutritionCreationTests.swift') -Raw
Assert-Check ($manualWizard -match '\.draggable' -and $manualWizard -match '\.dropDestination' -and $manualWizard -match 'swapAt') 'Manual workout supports drag reorder and accessible up/down alternatives'
Assert-Check ($personalWorkoutSource -match 'await session.saveWorkoutCoachPlan' -and $personalWorkoutSource -match 'if confirmed' -and $personalWorkoutSource -match 'Button\("Fine"\) \{ onSaved\(\); dismiss\(\) \}') 'Generated workout edits show confirmed status before explicit dismissal'
Assert-Check ($personalWorkoutSource -match 'onDismiss: presentPendingModal' -and $personalNutritionSource -match 'onDismiss: presentPendingModal' -and $personalWorkoutSource -notmatch 'milliseconds\(220\)' -and $personalNutritionSource -notmatch 'milliseconds\(220\)') 'Creation modal transitions wait for sheet dismissal instead of a fixed delay'
Assert-Check ($personalWorkoutSource -match 'Scartare le modifiche non confermate' -and $personalWorkoutSource -match '\.interactiveDismissDisabled\(\)') 'Workout editor protects unsaved edits with explicit discard confirmation'
Assert-Check ($personalWorkoutSource -match '(?s)let matches = await session.searchPersonalExercises\(query\)\s*guard !Task.isCancelled else \{ return \}\s*results = matches') 'Exercise search checks cancellation again after the awaited response'
Assert-Check ($personalNutritionSource -match 'ClientNutritionCreationChoiceView' -and $nutritionWizard -match 'Crea per me' -and $nutritionWizard -match 'Crea da solo' -and $nutritionWizard -match 'setupStep' -and $nutritionWizard -match 'quantitiesStep') 'Nutrition library routes both modes to staged native creation flows'
Assert-Check ($nutritionWizard -match 'copyDayMenu' -and $nutritionWizard -match 'showCopyWarning' -and $nutritionCreation -match 'copy.foods = meal.foods.map.*item.id = UUID') 'Meal/day copy uses independent nested IDs and confirms day replacement'
Assert-Check ($nutritionWizard -match 'snapshot.progress' -and $nutritionWizard -match 'identity.biologicalSex' -and $nutritionWizard -match 'healthyAdultConfirmed = false') 'Guided nutrition prefills known profile data without inheriting safety consent'
$nutritionEnergy = Get-Content (Join-Path $sourceRoot 'Core/ClientNutritionCoachEnergy.swift') -Raw
$nutritionPolicy = Get-Content (Join-Path $sourceRoot 'Core/ClientNutritionCoachContract.swift') -Raw
Assert-Check ($nutritionEnergy -match '10 \* weightKg \+ 6.25 \* heightCm' -and $nutritionCreation -match '1.375' -and $nutritionEnergy -match '-0.10' -and $nutritionEnergy -match '0.05') 'Nutrition5C reuses Desktop-compatible Mifflin/factors and versioned modest goal modifiers'
Assert-Check ($nutritionPolicy -match 'age >= 18' -and $nutritionPolicy -match 'clinicalNutritionRequired' -and $nutritionGenerator -match 'ClientNutritionPlanValidator.inspect' -and $nutritionGenerator -notmatch 'randomElement|Int.random') 'Nutrition5C typed adult/clinical/owner gates and deterministic strict acceptance;no old35%fit shortcut'
Assert-Check ($nutritionCreation -match 'case "pz"' -and $nutritionCreation -match 'gramsPerPiece.isFinite' -and $personalRepositorySource -match 'serving_unit' -and $personalRepositorySource -match 'trainer_id.*, value: nil') 'Food catalog handles explicit serving units and trusted piece weights with global-only queries'
Assert-Check ($nutritionWizard -match 'TOTALE ATTUALE' -and $nutritionWizard -match 'Macro parziali' -and $nutritionWizard -match 'draft.target == nil') 'Manual nutrition shows actual totals and discloses incomplete macro data without an invented target'
Assert-Check ($nutritionWizard -match 'savePersonalNutritionPlanConfirmed' -and $sessionSource -match 'confirmed.days == plan.days' -and $sessionSource -match 'confirmed.creationAnswers == plan.creationAnswers') 'Nutrition save defines full content readback and closes only on confirmation'
Assert-Check ($personalRepositorySource -match 'saveWorkoutPlans' -and $personalRepositorySource -match 'saveNutritionPlans' -and ([regex]::Matches($personalRepositorySource, 'upsert\(rows, onConflict: "id"\)')).Count -eq 2) 'Both confirmed save paths define batched activation/archive transport'
Assert-Check ($nutritionWizard -match 'canManagePersonalNutritionPlans' -and $manualWizard -match 'canManagePersonalWorkoutPlans' -and $nutritionWizard -match 'guard canEdit') 'New wizard service entry points retain local Trainer-connected restrictions (not a production RLS test)'
Assert-Check ($nutritionCreationTests -match 'testLegacyNutritionPayloadStillDecodesWithoutCreationFields' -and $nutritionCreationTests -match 'testGuidedPlanUsesCatalogIDsRoundedGramsAndEditablePayload' -and $manualTests -match 'testPreviousLoadNeverUsesAnUnexecutedPrescribedWeight') 'Native tests define compatibility, genuine nutrient/portion inputs and actual-load-only history'
Assert-Check (([regex]::Matches($tests, '(?m)^\s*func test')).Count -ge 30) 'At least 30 native unit tests are defined'
Assert-Check ($tests -match 'testAutomaticKilometerSplitsRequireCompletedDistance' -and $tests -match 'testBestEffortFindsInternalThreeKilometerWindow' -and $tests -match 'testRunningTopThreeSortsAndKeepsOneEntryPerSession' -and $tests -match 'testActivityAggregationCombinesGymAndRunningWithoutDuplicates') 'Native tests cover splits, internal best effort, Top 3 and activity aggregation'
Assert-Check ($tests -match 'testLiveRunningSpeedSamplesUseRecordedRouteAndRespectLimit') 'Native tests cover bounded real GPS speed samples for the live chart'
Assert-Check ($tests -match 'testHealthPermissionDecisionDefaultsToNotAsked' -and $tests -match 'testHealthPermissionDecisionPersistsDeclineWithoutRepeatingPrompt' -and $tests -match 'testHealthPermissionDecisionMigratesPreviousAuthorizationRequest') 'Native tests cover HealthKit first-run choice and legacy migration'

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
