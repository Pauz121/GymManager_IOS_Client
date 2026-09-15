import SwiftUI

struct PersonalAgendaView: View {
    let appointments: [ClientAppointment]
    @EnvironmentObject private var session: ClientSessionStore
    @State private var showingComposer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Agenda", eyebrow: "Solo tua", subtitle: "Attività e promemoria locali, sempre separati dagli appuntamenti del Trainer.")
                Label("Salvata su questo dispositivo per il profilo attivo. Evita informazioni sensibili.", systemImage: "iphone.gen3")
                    .font(.footnote).foregroundStyle(ClientClay.secondaryInk).clayCard(padding: 14)
                Button { showingComposer = true } label: { Label("Nuova attività", systemImage: "plus") }.buttonStyle(ClayPrimaryButtonStyle())

                Text("Agenda personale").font(.title3.weight(.bold))
                if session.agenda.isEmpty {
                    ClientEmptyState(symbol: "checklist", title: "Uno spazio tutto tuo", message: "Aggiungi la prima attività, nota o promemoria.")
                } else {
                    ForEach(session.agenda.sorted(by: Self.sort)) { task in
                        HStack(alignment: .top, spacing: 12) {
                            Button { session.toggleAgendaTask(task.id) } label: { Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(ClientClay.sage) }.accessibilityLabel(task.isCompleted ? "Riapri \(task.title)" : "Completa \(task.title)")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title).font(.headline).strikethrough(task.isCompleted)
                                Text([task.kind.rawValue, task.priority.rawValue, task.date?.formatted(date: .abbreviated, time: .shortened)].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(ClientClay.secondaryInk)
                                if !task.notes.isEmpty { Text(task.notes).font(.subheadline).foregroundStyle(ClientClay.secondaryInk) }
                            }
                            Spacer()
                            Button(role: .destructive) { session.deleteAgendaTask(task.id) } label: { Image(systemName: "trash") }.accessibilityLabel("Elimina \(task.title)")
                        }
                        .clayCard(padding: 15)
                        .overlay { RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous).stroke(task.isCompleted ? ClientClay.sage.opacity(0.30) : ClientClay.border) }
                    }
                }

                Text("Appuntamenti del Trainer").font(.title3.weight(.bold)).padding(.top, 5)
                if appointments.isEmpty {
                    ClientEmptyState(symbol: "calendar", title: "Nessun appuntamento", message: "Gli appuntamenti visibili fissati dal Trainer compariranno qui.")
                } else {
                    ForEach(appointments) { appointment in
                        VStack(alignment: .leading, spacing: 7) {
                            ClientBadge(text: "Fissato dal Trainer", tint: ClientClay.accent, symbol: "lock.fill")
                            Text(appointment.title).font(.headline)
                            Text(appointment.startsAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                            if let location = appointment.location { Label(location, systemImage: "mappin.and.ellipse").font(.caption) }
                        }.clayCard()
                    }
                }
            }.padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
        }
        .clientPage().navigationTitle("Agenda").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingComposer) { PersonalAgendaComposer() }
    }

    private static func sort(_ lhs: PersonalAgendaTask, _ rhs: PersonalAgendaTask) -> Bool {
        if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
        return (lhs.date ?? .distantFuture) < (rhs.date ?? .distantFuture)
    }
}

private struct PersonalAgendaComposer: View {
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var kind = PersonalAgendaKind.activity
    @State private var priority = PersonalAgendaPriority.normal
    @State private var hasDate = false
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Attività") {
                    TextField("Titolo", text: $title)
                    Picker("Tipo", selection: $kind) { ForEach(PersonalAgendaKind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    Picker("Priorità", selection: $priority) { ForEach(PersonalAgendaPriority.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    Toggle("Aggiungi data e ora", isOn: $hasDate)
                    if hasDate { DatePicker("Quando", selection: $date) }
                    TextField("Note facoltative", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                Section { Text("Questa voce resta locale e non viene inviata al Trainer.").font(.footnote).foregroundStyle(.secondary) }
            }
            .scrollContentBackground(.hidden)
            .background(ClientClay.canvas)
            .navigationTitle("Nuova attività").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salva") { session.addAgendaTask(title: title, date: hasDate ? date : nil, notes: notes, kind: kind, priority: priority); if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { dismiss() } } }
            }
        }
    }
}
