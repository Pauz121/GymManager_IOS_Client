[CmdletBinding()]
param([switch]$AllStatic)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $clientRoot 'GymManagerClient'
. (Join-Path $PSScriptRoot 'phase67-checkpoint-source.ps1')
$failures = [Collections.Generic.List[string]]::new()
$passed = 0
function Check([bool]$Value,[string]$Name) {
    if ($Value) { $script:passed++; Write-Output "[PASS SOURCE67] $Name" }
    else { $script:failures.Add($Name); Write-Output "[FAIL SOURCE67] $Name" }
}
function Read-Actual([string]$Path) { Get-Content (Join-Path $sourceRoot $Path) -Raw }
$baseline = Get-Content (Join-Path $clientRoot 'docs/phase67-baseline-20261023.json') -Raw | ConvertFrom-Json
$patches = Get-Content (Join-Path $clientRoot 'docs/phase67-approved-patches-20261023.json') -Raw | ConvertFrom-Json
Check ($baseline.files.Count -eq 115) 'Immutable pre67 checkpoint92app/23native files'
foreach ($entry in $baseline.files) {
    $path = Join-Path $clientRoot $entry.path
    $actual = Get-Content $path -Raw
    $restored = Restore-FinalUICheckpoint $path $actual
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($restored)))
    Check ($hash -eq $entry.sha256) "Exact pre67 bytes outside18 approved UI/palette diffs: $($entry.path)"
}
Check ($patches.Count -eq 21 -and @($patches | Where-Object kind -eq 'EOF_WHITESPACE_ONLY').Count -eq 3) '18presentation diffs+3explicit pre-existing EOF formatting repairs'
Check (@($patches | Where-Object { $_.kind -ne 'EOF_WHITESPACE_ONLY' -and $_.path -match 'Repository|SessionStore|Generator|Validator|SmartReplacement|FoodPolicy|Models|Theme.swift' }).Count -eq 0) 'No backend/engine/schema/palette formula rewrites'
foreach ($patch in $patches | Where-Object kind -eq 'EOF_WHITESPACE_ONLY') {
    Check ($patch.before.TrimEnd() -ceq $patch.after.TrimEnd()) "Only EOF whitespace changed:$($patch.path)"
}
$progress = Read-Actual 'Features/Progress/ClientProgressView.swift'
$presentation = Read-Actual 'Core/ClientProgressPresentation.swift'
$charts = Read-Actual 'Core/ClientChartStyle.swift'
$nutrition = Read-Actual 'Features/Nutrition/ClientNutritionView.swift'
$personal = Read-Actual 'Features/Nutrition/ClientPersonalNutritionView.swift'
$account = Read-Actual 'Features/Space/ClientAccountView.swift'
$information = Read-Actual 'Features/Space/ClientAccountInformationView.swift'
$appearance = Read-Actual 'Features/Space/ClientAppearanceView.swift'
$root = Read-Actual 'App/ClientRootView.swift'
$design = Read-Actual 'Core/ClientDesignSystem.swift'
$tabs = Read-Actual 'App/ClientTabView.swift'
$session = Read-Actual 'Core/ClientSessionStore.swift'
$repository = Read-Actual 'Core/ClientRepository.swift'
$policy = Read-Actual 'Core/ClientRefreshErrorPolicy.swift'
Check ($progress -match 'Picker\("Periodo' -and $progress -notmatch 'progressHero|kpiGrid|compactHeroMetric') 'Progress content hierarchy,no duplicated hero/KPIs'
Check ($presentation -match 'date <= now' -and $presentation -match 'weight.isFinite && weight > 0' -and $presentation -match 'days = 30' -and $presentation -match 'days = 90') 'Real finite records/calendar period/future rejection'
Check ($progress -match 'Precedente:' -and $progress -match 'weights.count > 1' -and $progress -match 'seconda rilevazione' -and $progress -match 'interpolationMethod\(\.linear\)') 'Current/previous/change/date;no fabricated sparse/smoothed trend'
Check ($progress -match 'chartXSelection' -and $progress -match 'nearest\(to:' -and $charts -match 'AxisGridLine' -and $charts -match 'ClientClay.secondaryInk' -and ([regex]::Matches($progress,'clientMeasurementChart')).Count -eq 2) 'Native chart selection uses actual record;shared semantic axes/grid'
Check ($progress -match 'periodRuns' -and $progress -match 'period.contains' -and $progress -match 'mondayToSunday' -and $progress -match 'su questo iPhone') 'Activity is real/period scoped,currentweek MondaySunday,local data explicitly identified'
Check ($progress -match 'isPending' -and $progress -match '\.failure' -and $progress -match 'Nessun peso registrato' -and $progress -match 'non sono disponibili') 'Pending/failure/empty separate;missing photos/composition explicit'
$read = [regex]::Match($session,'(?s)private func performContentRefresh.*?(?=    private func invalidateContentRefresh)').Value
$identity = [regex]::Match($repository,'(?s)func identity\(.*?(?=    func completeInitialOnboarding)').Value
Check ($read.Length -gt 0 -and $read -notmatch 'notice\s*=|\.update\(|\.rpc\(|\.upsert\(|activate\(' -and $identity -notmatch '\.update\(|\.insert\(|\.rpc\(' -and $policy -match 'refresh only reads data') 'Progress refresh/identity read-only;prior root-cause fix retained,no alert suppression'
Check ($nutrition -notmatch 'ClientCaloriePie|premiumCard|progressCopy' -and $nutrition -match 'toggleMealCompletion' -and $nutrition -match 'plan.isEffective' -and $nutrition -match 'P · C · G: non forniti') 'Trainer Nutrition compact day→meals→foods;missing macros not fabricated'
Check ($personal -match 'day.meals.reduce' -and $personal -match '\$1.protein' -and $personal -match '\$1.carbs' -and $personal -match '\$1.fat' -and $personal -match 'accessibilityAddTraits') 'Personal real macro totals;selected days have non-color state'
Check ($account -match 'Form \{' -and $account -match 'Section\("Profilo"' -and $account -match 'Section\("Trainer"' -and $account -match 'DisclosureGroup\("Cambia password"' -and $account -notmatch 'premiumCard|clayCard') 'Account native grouped hierarchy/compact profile/password disclosure,no nested cards'
Check ($account -match 'connectTrainer\(code:' -and $account -match 'Allenamento e nutrizione sono gestiti dal Trainer' -and $account -notmatch '\.task.*connectTrainer') 'Trainer status is explicit;link mutation remains deliberate action only'
Check ($appearance -match 'ClientAppearanceStore' -and $appearance -match 'appearance.select' -and $appearance -match 'ClientAppearance.allCases' -and $appearance -match 'pickerStyle\(\.inline\)') 'Native System/Light/Dark picker reuses persisted store'
Check ($root -match 'clientAppearance\(appearance.preference\)' -and $root -notmatch 'preferredColorScheme\(\.dark\)') 'Root dark pin removed only in final global-adoption stage'
Check (([regex]::Matches($design,'static let \w+ = ClientColorRole\.\w+\.adaptiveColor')).Count -eq 19 -and $design -match 'tertiaryInk = ClientColorRole.textTertiary' -and $design -match 'ClientSurfaceAppearance = \.adaptive') 'All19 legacy color aliases adaptive;cards defaultadaptive/readabletertiary'
Check ($design -match 'foregroundStyle\(ClientClay.color\(\.textOnAccent\)\)' -and $design -notmatch 'accent.opacity\(0.76\)' -and $design -match 'accessibilityReduceMotion' -and $design -match 'ClientElevation.lightSurface') 'Accent foreground/solid pressed contrast;Light lift/ReduceMotion'
Check ($design -match 'buttonStyle\(\.borderedProminent\).tint\(ClientClay.accent\)\r?\n\s*\.foregroundStyle\(ClientClay.color\(\.textOnAccent\)\)') 'Native prominent retry also uses contrast-safe accent foreground'
Check ($tabs -match 'highPriorityGesture\(scrubGesture\)' -and $tabs -match 'voiceOverEnabled \|\| switchControlEnabled' -and $tabs -match 'accessibilityAddTraits' -and $tabs -match 'minHeight: 52') 'PremiumTabBar preserves source gesture/native accessible buttons/52pt targets'
Check ($information -match 'Bozza — sito' -and $information -match 'mailto:Paolinob2@libero.it' -and $information -notmatch 'https?://' -and $information -match 'non ancora disponibile' -and $information -match 'Nessun dato è stato eliminato') 'Privacy/support no fabricated URL;deletion explicitlyblocked/not fake local deletion'
$literal = '(?<![A-Za-z0-9_])(?:Color\.(?:white|black|red|green|blue|orange|yellow|gray|pink|purple|cyan|mint)|\.(?:white|black|red|green|blue|orange|yellow|gray|pink|purple|cyan|mint))\b|(?<![A-Za-z0-9_])Color\s*\(\s*(?:red|white|hue):'
$total = 0
foreach ($file in Get-ChildItem $sourceRoot -Recurse -Filter '*.swift') {
    if ($file.FullName -match '[\\/]Preview[\\/]') { continue }
    $value = Get-Content $file.FullName -Raw
    $total += [regex]::Matches($value,$literal).Count
}
Check ($total -eq 3) '3 remaining literal matches:map marker white,font weight .black,central RGB initializer;NO semantic literal foregrounds'
$theme = Read-Actual 'Core/ClientTheme.swift'
$pairs = @{}
foreach ($match in [regex]::Matches($theme,'case \.(?<name>\w+): return ClientColorPair\(light: 0x(?<light>[0-9A-F]{6}), dark: 0x(?<dark>[0-9A-F]{6})\)')) {
    $pairs[$match.Groups['name'].Value] = @{ light = $match.Groups['light'].Value; dark = $match.Groups['dark'].Value }
}
function Luminance([string]$Hex) {
    $rgb = for ($i = 0; $i -lt 6; $i += 2) {
        $value = [Convert]::ToInt32($Hex.Substring($i,2),16)/255.0
        if ($value -le 0.04045) { $value/12.92 } else { [Math]::Pow(($value+0.055)/1.055,2.4) }
    }
    0.2126*$rgb[0]+0.7152*$rgb[1]+0.0722*$rgb[2]
}
foreach ($scheme in @('light','dark')) {
    foreach ($background in @('brandAccent','brandAccentPressed')) {
        $front = Luminance $pairs.textOnAccent[$scheme]; $back = Luminance $pairs[$background][$scheme]
        $ratio = ([Math]::Max($front,$back)+0.05)/([Math]::Min($front,$back)+0.05)
        Check ($ratio -ge 4.5) "Actual opaque button contrast $scheme/$background $([Math]::Round($ratio,2)):1"
    }
}
$tests = Get-Content (Join-Path $clientRoot 'GymManagerClientTests/ClientFinalUIIntegrationTests.swift') -Raw
foreach ($number in 1..12) { Check (($tests -split ('func testF{0:D2}' -f $number)).Count -eq 2) ("F{0:D2} native definition present—NOT RUN" -f $number) }
Check ($tests -match 'NOT rendered acceptance or DB tests' -and $tests -match 'brandAccentPressed' -and $tests -match 'LegacyAliasesResolveInBothTraits') 'Native definitions honest;contrast/appearance/presentation edge cases included'
foreach ($file in Get-ChildItem $PSScriptRoot -Filter '*.ps1') {
    $tokens = $null; $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors) | Out-Null
    Check ($errors.Count -eq 0) "PowerShell syntax:$($file.Name)"
}
Write-Output "Phase67 source checks passed:$passed;literal inventory:$total;counts overlap,NOT native tests."
if ($failures.Count) { $failures | ForEach-Object { Write-Output "FAILED:$_" }; exit 1 }
if ($AllStatic) {
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'validate-nutrition-ui.ps1') -NutritionUI -FinalUI67 -AllStatic
    if ($LASTEXITCODE -ne 0) { throw 'Historical phase regression failed;DO NOT PUSH' }
}
Write-Output 'PHASE6+7 SOURCE ONLY. Native Swift/XCTest/Simulator/VoiceOver/haptics/LiveActivity/RLS/save-reopen NOT RUN.'
