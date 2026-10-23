[CmdletBinding()]
param([switch]$FinalUI67, [switch]$TrainingPhase2, [switch]$RefinementPhase34, [switch]$NutritionEngine, [switch]$SmartEditing, [switch]$NutritionUI)
$ErrorActionPreference = 'Stop'
$clientRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $clientRoot 'GymManagerClient'
. (Join-Path $PSScriptRoot 'nutrition-checkpoint-source.ps1')
# -NutritionEngine reverses only authorized5C additions for historical hashes.
# Run validate-nutrition-coach.ps1 too: it checks current source and frozen Workout/UI.
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0
function Assert-Foundation([bool]$Condition, [string]$Name) {
    if ($Condition) { $script:passed++; Write-Output "[PASS] $Name" }
    else { $script:failures.Add($Name); Write-Output "[FAIL] $Name" }
}
function Read-Source([string]$Path) { Get-NutritionCheckpointSource (Join-Path $sourceRoot $Path) }
$theme = Read-Source 'Core/ClientTheme.swift'
$appearance = Read-Source 'Core/ClientAppearance.swift'
$tokens = Read-Source 'Core/ClientUITokens.swift'
$design = Read-Source 'Core/ClientDesignSystem.swift'
$app = Read-Source 'App/GymManagerClientApp.swift'
$root = Read-Source 'App/ClientRootView.swift'
$preview = Read-Source 'Preview/ClientFoundationPreview.swift'
$nativeTests = Get-Content -LiteralPath (Join-Path $clientRoot 'GymManagerClientTests/ClientThemeFoundationTests.swift') -Raw
$baselinePath = if ($RefinementPhase34) { 'docs/ui-exercise-home-baseline-20261023.json' } elseif ($TrainingPhase2) { 'docs/ui-training-baseline-20261023.json' } else { 'docs/ui-foundation-baseline-20261022.json' }
$baseline = Get-Content -LiteralPath (Join-Path $clientRoot $baselinePath) -Raw | ConvertFrom-Json

foreach ($entry in $baseline.files) {
    if ($NutritionEngine -and $entry.path -eq 'Core/ClientNutritionGenerator.swift') { continue } # Authorized5C engine, checked separately.
    if ($entry.path -in $baseline.allowedModified) { continue }
    $actualHash = (Get-NutritionCheckpointHash (Join-Path $sourceRoot $entry.path))
    Assert-Foundation ($actualHash -eq (Get-NutritionHistoricalExpectedHash $entry)) "Protected exact source bytes: $($entry.path)"
}
if ($RefinementPhase34) {
    Assert-Foundation ($baseline.files.Count -eq 57 -and $baseline.allowedModified.Count -eq 10) 'Phase3/4 baseline57 files;10 explicitly approved UI/read-adapter files only'
} elseif ($TrainingPhase2) {
    Assert-Foundation ($baseline.files.Count -eq 54 -and $baseline.allowedModified.Count -eq 4) 'Phase2 baseline covers54 files; only4 approved UI files allowed;50 unchanged'
} else {
    Assert-Foundation ($baseline.files.Count -eq 50 -and $baseline.allowedModified.Count -eq 3) 'Phase1 baseline covers50 existing files; only3 original foundation edits allowed'
}
Assert-Foundation ($appearance -match 'case system, light, dark' -and $appearance -match 'case \.system: nil' -and $appearance -match '\?\? \.system') 'Local preference defaults to System and System maps to no presentation override'
Assert-Foundation ($appearance -match 'defaults.set\(preference.rawValue' -and $appearance -notmatch 'Supabase|auth\.|trainerID|authUserID|\.rpc\(') 'Appearance persistence is local-only and independent of account/backend'
Assert-Foundation ($app -match 'StateObject private var appearance = ClientAppearanceStore' -and $app -match 'environmentObject\(appearance\)') 'One local appearance store is injected at app scope'
Assert-Foundation ($root -match 'preferredColorScheme\(\.dark\)' -and $root -match 'Phase1 compatibility boundary') 'Legacy Dark is deliberately preserved until approved screen adoption, not advertised as full Light support'
Assert-Foundation ($theme -match 'UIColor \{ traits in' -and $theme -match 'traits.userInterfaceStyle' -and $theme -match 'traits.accessibilityContrast' -and $theme -notmatch 'UITraitCollection.current') 'Dynamic colors resolve from supplied UIKit appearance/contrast traits'
Assert-Foundation ($theme -match 'case \.textSecondary, \.textTertiary:' -and $theme -match 'case \.borderSubtle, \.divider:') 'Increased Contrast promotes secondary text and subtle boundaries'
Assert-Foundation ($design -match 'ClientSurfaceAppearance' -and $design -match 'appearance: ClientSurfaceAppearance = \.legacyDark' -and $preview -match 'appearance: \.adaptive') 'Existing clayCard gains one opt-in adaptive variant, not a second card framework'
Assert-Foundation ($tokens -match 'legacyCardInset: CGFloat = 18' -and $tokens -match 'card: CGFloat = 22' -and $tokens -match 'hero: CGFloat = 26') 'Legacy card geometry preserved; spacing/radius exceptions explicitly named'
Assert-Foundation ($tokens -match 'minimumTarget: CGFloat = 44' -and $tokens -notmatch '\.system\(size:' -and $design -match 'font\(ClientTypography.section\)') 'Shared foundations use semantic SF text and native44pt target strategy'
Assert-Foundation ($preview -match '#if DEBUG' -and $preview -match 'appearance: \.light' -and $preview -match 'appearance: \.dark' -and $preview -match 'appearance: \.system' -and $preview -match 'accessibility3') 'Native Debug specimens define Light/Dark/System/large text, not browser screenshots'
Assert-Foundation ($nativeTests -match 'testPreferenceDefaultsToSystemAndPersistsLocally' -and $nativeTests -match 'testDynamicColorUsesSuppliedTraitsRatherThanCurrentScreen' -and $nativeTests -match 'testAllReadableTextRolesHaveContrastOnBaseSurfaces') 'Native theme tests are defined (compilation/execution NOT RUN on Windows)'

$pairs = @{}
foreach ($match in [regex]::Matches($theme, 'case \.(?<name>\w+): return ClientColorPair\(light: 0x(?<light>[0-9A-F]{6}), dark: 0x(?<dark>[0-9A-F]{6})\)')) {
    $pairs[$match.Groups['name'].Value] = @{ light = $match.Groups['light'].Value; dark = $match.Groups['dark'].Value }
}
foreach ($match in [regex]::Matches($theme, 'case \.(?<name>\w+): return ClientColorRole\.(?<target>\w+).palette')) {
    $pairs[$match.Groups['name'].Value] = $pairs[$match.Groups['target'].Value]
}
Assert-Foundation ($pairs.Count -eq 30) 'All30 semantic roles have explicit Light/Dark values or authoritative semantic aliases'
Assert-Foundation ($pairs.error.dark -ne $pairs.brandAccent.dark -and $pairs.error.light -ne $pairs.brandAccent.light) 'Error semantics are not an automatic alias of the coral brand'
function Get-Luminance([string]$Hex) {
    $components = for ($index = 0; $index -lt 6; $index += 2) {
        $component = [Convert]::ToInt32($Hex.Substring($index, 2), 16) / 255.0
        if ($component -le 0.04045) { $component / 12.92 } else { [Math]::Pow(($component + 0.055) / 1.055, 2.4) }
    }
    0.2126*$components[0] + 0.7152*$components[1] + 0.0722*$components[2]
}
function Get-Contrast([string]$Foreground, [string]$Background) {
    $front = Get-Luminance $Foreground
    $back = Get-Luminance $Background
    ([Math]::Max($front,$back)+0.05) / ([Math]::Min($front,$back)+0.05)
}
foreach ($scheme in @('light','dark')) {
    foreach ($foreground in @('textPrimary','textEmphasis','textSecondary','textTertiary')) {
        foreach ($background in @('backgroundPrimary','backgroundSecondary','surfacePrimary','surfaceSecondary','surfaceElevated','surfaceInteractive')) {
            $ratio = Get-Contrast $pairs[$foreground][$scheme] $pairs[$background][$scheme]
            Assert-Foundation ($ratio -ge 4.5) "Opaque sRGB contrast $scheme $foreground on $background >=4.5 ($([Math]::Round($ratio,2)))"
        }
    }
    $ratio = Get-Contrast $pairs.textOnAccent[$scheme] $pairs.brandAccent[$scheme]
    Assert-Foundation ($ratio -ge 4.5) "Opaque sRGB textOnAccent contrast $scheme >=4.5 ($([Math]::Round($ratio,2)))"
}

$literalPattern = '(?<![A-Za-z0-9_])(?:Color\.(?:white|black|red|green|blue|orange|yellow|gray|pink|purple|cyan|mint)|\.(?:white|black|red|green|blue|orange|yellow|gray|pink|purple|cyan|mint))\b|(?<![A-Za-z0-9_])Color\s*\(\s*(?:red|white|hue):'
$literalTotal = 0
$outsideFoundation = 0
foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.swift') {
    $relative = $file.FullName.Substring($sourceRoot.Length+1).Replace('\','/')
    $count = [regex]::Matches((Get-Content -LiteralPath $file.FullName -Raw), $literalPattern).Count
    $literalTotal += $count
    if ($relative -notin @('Core/ClientDesignSystem.swift','Core/ClientTheme.swift') -and -not $relative.StartsWith('Preview/')) { $outsideFoundation += $count }
}
if (!$TrainingPhase2 -and !$RefinementPhase34) {
    Assert-Foundation ($outsideFoundation -eq 86) 'All86 nonfoundation literal sites preserved for later approved screen migrations'
} else {
    # Exact per-file migration accounting and the50-file boundary are checked by
    # validate-ui-training.ps1. Do not weaken the original Phase1 baseline.
    Write-Output "Phase2 authorized color migration; current outside-foundation literal inventory: $outsideFoundation"
}
Write-Output "COLOR INVENTORY: initial111; now$literalTotal (includes central RGB constructor); outside foundation$outsideFoundation. Literal occurrences, not defects."
Write-Output "KNOWN DEBT: legacy white-on-coral contrast $([Math]::Round((Get-Contrast 'FFFFFF' $pairs.brandAccent.dark),2)):1; legacy buttons remain unchanged, later adoption must use textOnAccent."
Write-Output "Foundation source/mathematical checks passed: $passed"
if ($failures.Count) { $failures | ForEach-Object { Write-Output "FAILED: $_" }; exit 1 }
Write-Output 'IOS CLIENT FOUNDATION SOURCE VALIDATION: PASS — NOT A NATIVE BUILD OR RENDERED ACCESSIBILITY TEST'
