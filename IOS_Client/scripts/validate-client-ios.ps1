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
$pbx = Get-Content -LiteralPath $projectFile -Raw
$swift = Read-AllSwift

foreach ($xmlPath in @($workspacePath, $schemePath, $infoPath, $privacyPath)) {
    try { [xml](Get-Content -LiteralPath $xmlPath -Raw) | Out-Null; Assert-Check $true "Valid XML: $(Split-Path -Leaf $xmlPath)" }
    catch { Assert-Check $false "Valid XML: $(Split-Path -Leaf $xmlPath)" }
}

$workspace = Get-Content -LiteralPath $workspacePath -Raw
Assert-Check ($workspace -match 'group:GymManagerClient\.xcodeproj' -and $workspace -notmatch 'GymManager\.xcodeproj') 'Client workspace contains only the Client project'
Assert-Check ((Split-Path -Leaf $clientRoot) -eq 'IOS_Client') 'Client project root is IOS_Client'
Assert-Check (([regex]::Matches($pbx, 'isa = PBXNativeTarget')).Count -eq 2) 'Client project has app and test targets'
Assert-Check ($pbx -match 'version = 2\.55\.1' -and $pbx -match 'supabase-swift') 'Supabase Swift exact version matches Trainer'
Assert-Check ((([regex]::Matches($pbx, '\{')).Count) -eq (([regex]::Matches($pbx, '\}')).Count)) 'Xcode project braces are balanced'

$defined = [regex]::Matches($pbx, '(?m)^\s*([A-F0-9]{24})\s+(?:/\*.*?\*/\s+)?=') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$referenced = [regex]::Matches($pbx, '\b([A-F0-9]{24})\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
Assert-Check (@($referenced | Where-Object { $_ -notin $defined }).Count -eq 0) 'Every Xcode object reference has a definition'

$baseConfig = Get-Content -LiteralPath (Join-Path $clientRoot 'Config\Base.xcconfig') -Raw
Assert-Check ($baseConfig -match '#include\? "Local\.xcconfig"' -and $baseConfig -notmatch '\.\./\.\./IOS/') 'Client configuration is self-contained with an optional ignored local override'
Assert-Check ($baseConfig -match 'PRODUCT_BUNDLE_IDENTIFIER = com\.gymmanager\.client\.ios') 'Client has an independent bundle identifier'
$info = Get-Content -LiteralPath $infoPath -Raw
Assert-Check ($info -match '\$\(SUPABASE_URL\)' -and $info -match '\$\(SUPABASE_PUBLISHABLE_KEY\)') 'Info.plist references client-safe Supabase build settings'

$demo = Get-Content -LiteralPath (Join-Path $sourceRoot 'Demo\ClientDemoData.swift') -Raw
$repository = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\ClientRepository.swift') -Raw
Assert-Check ($demo -match '(?s)#if DEBUG.*enum ClientDemoData.*#endif') 'Demo data is compiled only in Debug'
Assert-Check ($swift -notmatch '(?i)service.?role') 'No service-role marker exists in Client source'
Assert-Check ($repository -notmatch '\.(insert|update|upsert|delete|rpc|upload)\s*\(') 'No professional-data writer exists in Client repository'

Assert-Check ($repository -match '\.eq\("auth_user_id", value: authUserID\.uuidString\)') 'Client link derives from authenticated user ID'
Assert-Check ($repository -match '\.eq\("status", value: "active"\)' -and $repository -match 'publishedAt != nil') 'Professional plans require active and published state'
Assert-Check ($repository -match '\.eq\("client_visible", value: true\)' -and $repository -match '\.eq\("status", value: "scheduled"\)') 'Trainer appointments require visible and scheduled state'

$tabs = Get-Content -LiteralPath (Join-Path $sourceRoot 'App\ClientTabView.swift') -Raw
Assert-Check (([regex]::Matches($tabs, '\.tag\(ClientTab\.')).Count -eq 5) 'TabView has exactly five primary destinations'
Assert-Check ($tabs -match 'safeAreaInset' -and $tabs -match 'allowsHitTesting\(false\)') 'Demo badge respects safe area and does not intercept touches'

$requiredPages = @(
    'Features\Home\ClientHomeView.swift', 'Features\Workout\ClientWorkoutView.swift',
    'Features\Nutrition\ClientNutritionView.swift', 'Features\Progress\ClientProgressView.swift',
    'Features\Space\PersonalAgendaView.swift', 'Features\Space\ClientUpdatesView.swift',
    'Features\Space\ClientAccountView.swift'
)
Assert-Check (@($requiredPages | Where-Object { -not (Test-Path -LiteralPath (Join-Path $sourceRoot $_)) }).Count -eq 0) 'All seven required functional pages exist'
Assert-Check ($swift -match 'Piano del Trainer · sola lettura' -and $swift -match 'Fissato dal Trainer') 'Read-only plans and Trainer appointments are visibly labelled'
Assert-Check ($swift -match 'gymmanager\.client\.agenda\.\\\(source\.rawValue\)' -and $swift -match 'authUserID') 'Personal Agenda storage is namespaced per source and user'

$tests = Get-Content -LiteralPath (Join-Path $clientRoot 'GymManagerClientTests\ClientPhase1Tests.swift') -Raw
Assert-Check (([regex]::Matches($tests, '(?m)^\s*func test')).Count -ge 18) 'At least 18 native unit tests are defined'

$trainerProject = Get-Content -LiteralPath (Join-Path $trainerRoot 'GymManager.xcodeproj\project.pbxproj') -Raw
Assert-Check ($trainerProject -notmatch 'GymManagerClient|ClientApp') 'Trainer project has no Client membership or reference'
Assert-Check (-not (Test-Path -LiteralPath (Join-Path $trainerRoot 'ClientApp')) -and -not (Test-Path -LiteralPath (Join-Path $trainerRoot 'GymManager.xcworkspace'))) 'No Client application artifact remains inside IOS'

Write-Output "Static checks passed: $passed"
if ($failures.Count) {
    Write-Output "Static checks failed: $($failures.Count)"
    $failures | ForEach-Object { Write-Output " - $_" }
    exit 1
}
Write-Output 'CLIENT IOS STATIC VALIDATION: PASS'
