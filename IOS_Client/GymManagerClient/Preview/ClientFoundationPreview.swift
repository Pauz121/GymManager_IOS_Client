#if DEBUG
import SwiftUI

/// Developer specimen, not an app screen and not evidence of device acceptance.
/// No personal data, no new navigation destination, no demo backend access.
struct ClientFoundationPreview: View {
    let appearance: ClientAppearance
    private let statusRoles: [ClientColorRole] = [.success, .warning, .error, .info]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClientSpacing.section) {
                Text("GymManager — Foundation").font(ClientTypography.page)
                Text("\(appearance.title) · specimen sviluppatore").font(ClientTypography.supporting)
                    .foregroundStyle(ClientClay.color(.textSecondary))
                VStack(alignment: .leading, spacing: ClientSpacing.related) {
                    Text("Sezione").font(ClientTypography.section)
                    Text("Contenuti prima dei contenitori.").font(ClientTypography.body)
                    Text("Informazioni di supporto").font(ClientTypography.supporting)
                        .foregroundStyle(ClientClay.color(.textSecondary))
                    Text("Metadati leggibili").font(ClientTypography.caption)
                        .foregroundStyle(ClientClay.color(.textTertiary))
                }
                .clayCard(padding: ClientSpacing.page, appearance: .adaptive)
                VStack(alignment: .leading, spacing: ClientSpacing.control) {
                    ForEach(statusRoles, id: \.self) { role in
                        Label(role.rawValue, systemImage: role == .error ? "exclamationmark.circle.fill" : "circle.fill")
                            .foregroundStyle(ClientClay.color(role)).font(ClientTypography.body)
                    }
                }
                .clayCard(padding: ClientSpacing.page, appearance: .adaptive)
                HStack(spacing: ClientSpacing.group) {
                    Text("12").font(ClientTypography.metric)
                    Text("Esempio tipografico, non dati Cliente").font(ClientTypography.caption)
                }
                .clayCard(padding: ClientSpacing.page, appearance: .adaptive)
                Text("Testo su accento")
                    .font(ClientTypography.button).foregroundStyle(ClientClay.color(.textOnAccent))
                    .padding(ClientSpacing.page).frame(maxWidth: .infinity)
                    .background(ClientClay.color(.brandAccent), in: RoundedRectangle(cornerRadius: ClientRadius.control))
            }
            .foregroundStyle(ClientClay.color(.textPrimary))
            .padding(ClientSpacing.page)
        }
        .background(ClientClay.color(.backgroundPrimary))
        .clientAppearance(appearance)
    }
}

#Preview("Foundation — Light") { ClientFoundationPreview(appearance: .light) }
#Preview("Foundation — Dark") { ClientFoundationPreview(appearance: .dark) }
#Preview("Foundation — System / Dynamic Type") {
    ClientFoundationPreview(appearance: .system).dynamicTypeSize(.accessibility3)
}
#endif
