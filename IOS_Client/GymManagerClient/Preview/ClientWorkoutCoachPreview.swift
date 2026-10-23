#if DEBUG
import SwiftUI

// Native specimens only; no network catalog loading during Xcode previews.
#Preview("Coach · Small · Dark", traits: .fixedLayout(width: 320, height: 568)) {
    ClientGuidedWorkoutView(onSaved: {}, onEdit: { _ in })
        .environmentObject(ClientSessionStore()).preferredColorScheme(.dark)
}
#Preview("Coach · Standard · Light", traits: .fixedLayout(width: 375, height: 812)) {
    ClientGuidedWorkoutView(onSaved: {}, onEdit: { _ in })
        .environmentObject(ClientSessionStore()).preferredColorScheme(.light)
}
#Preview("Coach · Large Type", traits: .fixedLayout(width: 430, height: 932)) {
    ClientGuidedWorkoutView(onSaved: {}, onEdit: { _ in })
        .environmentObject(ClientSessionStore()).preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
#endif
