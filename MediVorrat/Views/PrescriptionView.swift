import SwiftUI

struct PrescriptionView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []
    @State private var didPreselect = false

    var body: some View {
        let candidates = store.items.filter { $0.forecast.status != .paused }
        let text = store.prescriptionText(for: selected)

        NavigationStack {
            Form {
                Section {
                    ForEach(candidates) { item in
                        Toggle(isOn: binding(for: item.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.med.displayName)
                                StatusTag(status: item.forecast.status)
                            }
                        }
                    }
                } header: {
                    Text("Medikamente")
                } footer: {
                    Text("Vorausgewählt ist alles, was jetzt oder bald fällig ist.")
                }

                Section("Nachricht an die Praxis") {
                    Text(text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                        .foregroundStyle(.primary)
                }

                Section {
                    ShareLink(item: text, subject: Text("Bitte um Folgerezept")) {
                        Label("Senden über …", systemImage: "square.and.arrow.up")
                    }
                    if let url = mailURL(text: text) {
                        Link(destination: url) {
                            Label("Als E-Mail an die Praxis", systemImage: "envelope")
                        }
                    }
                    Button {
                        store.markOrdered(selected)
                        dismiss()
                    } label: {
                        Label("Als angefragt markieren", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(LargeButtonStyle())
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .disabled(selected.isEmpty)
                } footer: {
                    Text("Angefragte Medikamente bleiben lila markiert, bis du „Packung erhalten“ tippst.")
                }
            }
            .navigationTitle("Rezept anfragen")
            .pageForm()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .tint(Color.accent)
            .onAppear {
                guard !didPreselect else { return }
                selected = Set(candidates.filter { $0.forecast.status.needsPrescription }.map(\.id))
                didPreselect = true
            }
        }
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selected.contains(id) },
            set: { on in if on { selected.insert(id) } else { selected.remove(id) } }
        )
    }

    private func mailURL(text: String) -> URL? {
        let to = store.settings.practiceEmail.trimmingCharacters(in: .whitespaces)
        guard !to.isEmpty else { return nil }
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = to
        c.queryItems = [
            URLQueryItem(name: "subject", value: "Bitte um Folgerezept"),
            URLQueryItem(name: "body", value: text)
        ]
        return c.url
    }
}
