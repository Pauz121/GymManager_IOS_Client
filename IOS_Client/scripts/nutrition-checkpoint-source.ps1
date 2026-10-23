# Source-only compatibility adapter for explicitly authorized5C Nutrition edits.
# It reverses ONLY listed additions in shared files; the Phase5C validator hashes
# the result against the immutable pre-edit checkpoint. No old baseline is rewritten.
function Get-NutritionCheckpointSource([string]$Path) {
    $source = Get-Content -LiteralPath $Path -Raw
    if ($FinalUI67) {
        . (Join-Path $PSScriptRoot 'phase67-checkpoint-source.ps1')
        $source = Restore-FinalUICheckpoint $Path $source
    }
    if ($NutritionUI) {
        . (Join-Path $PSScriptRoot 'nutrition-ui-checkpoint-source.ps1')
        $source = Restore-NutritionUICheckpoint $Path $source
    }
    if ($SmartEditing) {
        . (Join-Path $PSScriptRoot 'smart-editing-checkpoint-source.ps1')
        $source = Restore-SmartEditingCheckpoint $Path $source
    }
    if (!$NutritionEngine) { return $source }
    $source = $source.Replace([string]([char]13), '')
    switch ([IO.Path]::GetFileName($Path)) {
        'ClientPersonalContent.swift' {
            $source = $source.Replace("    var nutritionEvidence: ClientNutritionFoodEvidence? = nil" + [char]10, '')
            $source = $source.Replace("    var generationMetadata: ClientNutritionGenerationMetadata? = nil" + [char]10, '')
        }
        'ClientNutritionCreation.swift' {
            $source = $source.Replace("    var coachProfile: ClientNutritionCoachProfile? = nil" + [char]10, '')
            $source = $source.Replace("        category: String?, provider: String?, gramsPerPiece: Double?," + [char]10 + "        nutritionEvidence: ClientNutritionFoodEvidence? = nil", "        category: String?, provider: String?, gramsPerPiece: Double?")
            $source = $source.Replace(', nutritionEvidence: nutritionEvidence', '')
        }
        'ClientSessionStore.swift' {
            $source = $source.Replace("        guard validateNutritionCoachBeforeSave(plan, mode: identity.mode) else { return }" + [char]10, '')
            $source = $source.Replace("        guard validateNutritionCoachBeforeSave(plan, mode: identity.mode) else { return false }" + [char]10, '')
            $source = $source.Replace('confirmed.creationAnswers == plan.creationAnswers, confirmed.generationMetadata == plan.generationMetadata else {', 'confirmed.creationAnswers == plan.creationAnswers else {')
            $source = [regex]::Replace($source, '(?s)    private func validateNutritionCoachBeforeSave\(.*?(?=    func savePersonalMealTemplate)', '')
        }
        'ClientPersonalRepository.swift' {
            $source = [regex]::Replace($source, '(?s)(    func saveNutritionPlans\(.*?\{\n).*?(?=        let rows = plans.map)', '$1')
            $source = [regex]::Replace($source, '(?s)    /// Fresh server-backed preflight;.*?(?=    func activeNutritionPlans)', '')
            $source = $source.Replace(',external_food_id,source_url,updated_at', '')
            $source = [regex]::Replace($source, '(?s)    let externalFoodID: String\?; let sourceURL: String\?; let updatedAt: String\?\n    var reviewedEvidence:.*?(?=    var catalogItem:)', '')
            $source = $source.Replace(', nutritionEvidence: reviewedEvidence', '')
            $source = $source.Replace('        case externalFoodID = "external_food_id"; case sourceURL = "source_url"; case updatedAt = "updated_at"' + [char]10, '')
            $oldMetadata = @'
private struct FoodCatalogMetadata: Decodable {
    let gramsPerPiece: Double?
    enum CodingKeys: String, CodingKey { case gramsPerPiece = "grams_per_piece" }
}
'@
            $source = [regex]::Replace($source, '(?s)private struct FoodCatalogMetadata: Decodable \{\n.*?\n\}', $oldMetadata)
        }
    }
    return $source
}
function Get-NutritionCheckpointHash([string]$Path) {
    if (!$NutritionEngine -and !$SmartEditing -and !$NutritionUI -and !$FinalUI67) { return (Get-FileHash -LiteralPath $Path).Hash }
    $value = Get-NutritionCheckpointSource $Path
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($value)))
}
function Get-NutritionHistoricalExpectedHash($Entry) {
    # Earlier5A/5B/UI approvals already changed these five modules. Compare them
    # to their immutable pre-5C bytes, NOT to an obsolete pre-Workout checkpoint.
    $laterApproved = @('Core/ClientPersonalContent.swift','Core/ClientPersonalRepository.swift',
        'Core/ClientWorkoutGenerator.swift','Features/Workout/ClientGuidedWorkoutView.swift',
        'Features/Workout/ClientPersonalWorkoutView.swift')
    if ($NutritionEngine -and $Entry.path -in $laterApproved) {
        $checkpoint = Get-Content (Join-Path $clientRoot 'docs/coach-nutrition-baseline-20261023.json') -Raw | ConvertFrom-Json
        return ($checkpoint.files | Where-Object path -eq $Entry.path).sha256
    }
    return $Entry.sha256
}
