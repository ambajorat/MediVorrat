import SwiftUI

struct PrescriptionView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []
    @State private var didPreselect = false
    @State private var showMail = false
    @Environment(\.openURL) private var openURL

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
                    Button {
                        if MailComposer.canSend {
                            showMail = true
                        } else if let url = mailURL(text: text) {
                            openURL(url)
                        }
                    } label: {
                        Label("Als E-Mail an die Praxis", systemImage: "envelope")
                    }
                    .disabled(selected.isEmpty)
                    ShareLink(item: text, subject: Text(store.prescriptionSubject)) {
                        Label("Senden über …", systemImage: "square.and.arrow.up")
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
                    Text("Wird die Mail aus der App gesendet, markiert MediVorrat die Medikamente automatisch als angefragt. Sie bleiben lila, bis die Packung eingebucht ist.")
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
            .sheet(isPresented: $showMail) {
                MailComposer(
                    recipients: store.settings.practiceEmail.isEmpty ? [] : [store.settings.practiceEmail],
                    subject: store.prescriptionSubject,
                    html: store.prescriptionHTML(for: selected)
                ) { result in
                    showMail = false
                    if result == .sent {
                        store.markOrdered(selected)
                        dismiss()
                    }
                }
                .ignoresSafeArea()
            }
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

    /// Ersatzweg ohne eingerichtetes Apple Mail (z. B. Gmail als Standard): nur Klartext möglich.
    private func mailURL(text: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }
        let to = store.settings.practiceEmail.trimmingCharacters(in: .whitespaces)
        let body = text.replacingOccurrences(of: "\n", with: "\r\n")
        return URL(string: "mailto:\(enc(to))?subject=\(enc(store.prescriptionSubject))&body=\(enc(body))")
    }
}
