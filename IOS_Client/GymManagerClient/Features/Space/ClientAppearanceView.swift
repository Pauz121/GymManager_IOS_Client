import SwiftUI

struct ClientAppearanceView: View {
    @EnvironmentObject private var appearance: ClientAppearanceStore

    var body: some View {
        Form {
            Section {
                Picker("Aspetto", selection: Binding(get: { appearance.preference }, set: { appearance.select($0) })) {
                    ForEach(ClientAppearance.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.inline)
            } footer: {
                Text("Sistema segue l’aspetto di iOS. La scelta viene salvata solo su questo dispositivo.")
            }
        }
        .scrollContentBackground(.hidden).clientPage()
        .navigationTitle("Aspetto").navigationBarTitleDisplayMode(.inline)
    }
}
