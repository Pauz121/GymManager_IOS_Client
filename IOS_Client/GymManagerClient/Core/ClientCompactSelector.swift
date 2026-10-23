import SwiftUI

/// Navigation chrome, not content cards. Intrinsic label widths remain readable
/// at accessibility sizes; scrolling is preferable to shrinking or truncating.
struct ClientCompactSelector<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    let accessibilityTitle: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: ClientSpacing.related) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            guard selection != value else { return }
                            selection = value
                            ClientHaptics.selection()
                        } label: {
                            Text(title(value))
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: true, vertical: true)
                                .padding(.horizontal, ClientSpacing.control)
                                .frame(minHeight: ClientControlSize.minimumTarget)
                                .foregroundStyle(ClientClay.color(selection == value ? .textPrimary : .textSecondary))
                                .background(ClientClay.color(selection == value ? .brandAccentMuted : .surfaceSecondary),
                                            in: RoundedRectangle(cornerRadius: ClientRadius.compact))
                                .overlay {
                                    RoundedRectangle(cornerRadius: ClientRadius.compact)
                                        .stroke(ClientClay.color(selection == value ? .brandAccent : .borderSubtle),
                                                lineWidth: selection == value ? ClientBorder.emphasized : ClientBorder.subtle)
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection == value ? [.isSelected] : [])
                        .id(value)
                    }
                }
                .padding(.vertical, ClientBorder.emphasized)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selection, initial: true) { _, value in
                if reduceMotion { proxy.scrollTo(value, anchor: .center) }
                else { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(value, anchor: .center) } }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityTitle)
    }
}
