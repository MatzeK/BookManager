import SwiftUI
import SwiftData

struct SettingsView: View {
    // Zugriff auf die Datenbank – wird für Import benötigt.
    @Environment(\.modelContext) private var modelContext

    // Alle gespeicherten Bücher – für die Anzahl im Info-Bereich und beim Export.
    @Query private var alleBuecher: [Book]

    // Schließt diesen Screen, wenn der Nutzer "Fertig" tippt.
    @Environment(\.dismiss) private var dismiss

    // Sprachverwaltung für alle Texte in diesem Screen.
    @EnvironmentObject private var loc: LocalizationManager

    // Steuert, ob das System-Teilen-Menü (für den Backup-Export) angezeigt wird.
    @State private var zeigeExportSheet = false

    // Steuert, ob der Datei-Auswahl-Dialog für den Import angezeigt wird.
    @State private var zeigeImportPicker = false

    // Die URL der erstellten Backup-Datei, die geteilt werden soll.
    @State private var exportURL: URL? = nil

    // Steuert, ob der Erfolgs-Dialog (nach Import) angezeigt wird.
    @State private var zeigeErfolgAlert = false

    // Steuert, ob der Fehler-Dialog angezeigt wird.
    @State private var zeigeFehlerAlert = false

    // Titel und Inhalt des aktuell angezeigten Dialogs.
    @State private var alertTitel = ""
    @State private var alertNachricht = ""

    // true während ein Backup erstellt oder importiert wird – deaktiviert Buttons.
    @State private var ladeVorgang = false

    var body: some View {
        NavigationStack {
            Form {
                sprachSektion
                backupSektion
                wiederherstellungSektion
                infoSektion
            }
            .navigationTitle(loc.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.done) { dismiss() }
                }
            }
            // Das System-Teilen-Menü (AirDrop, Dateien, Mail etc.) für die Backup-Datei.
            .sheet(isPresented: $zeigeExportSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
            // Datei-Auswahl-Dialog, der nur .json-Dateien anzeigt.
            .fileImporter(
                isPresented: $zeigeImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                behandleImport(result: result)
            }
            // Erfolgs-Dialog nach einem Import.
            .alert(alertTitel, isPresented: $zeigeErfolgAlert) {
                Button(loc.ok, role: .cancel) {}
            } message: {
                Text(alertNachricht)
            }
            // Fehler-Dialog bei Problemen beim Export oder Import.
            .alert(loc.error, isPresented: $zeigeFehlerAlert) {
                Button(loc.ok, role: .cancel) {}
            } message: {
                Text(alertNachricht)
            }
        }
    }

    // MARK: - Sektionen

    // Bereich zur Sprachauswahl: Segmented Control mit "Deutsch" und "English".
    // Die Auswahl wird sofort gespeichert und alle Texte wechseln die Sprache.
    private var sprachSektion: some View {
        Section(loc.languageSection) {
            Picker(loc.languageLabel, selection: Binding(
                get: { loc.currentLanguage },
                set: { loc.language = $0.rawValue }
            )) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // Bereich zum Erstellen eines Backups aller Bücher als JSON-Datei.
    // Zeigt die Anzahl der Bücher an und ist deaktiviert, wenn keine vorhanden sind.
    private var backupSektion: some View {
        Section {
            Button {
                erstelleBackup()
            } label: {
                HStack {
                    Label(loc.createBackup, systemImage: "arrow.up.doc")
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    // Während des Exports Ladeindikator zeigen, sonst Bücheranzahl.
                    if ladeVorgang {
                        ProgressView()
                    } else {
                        Text("\(alleBuecher.count) \(loc.books)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            .disabled(alleBuecher.isEmpty || ladeVorgang)
        } header: {
            Text(loc.backup)
        } footer: {
            Text(loc.backupFooter)
        }
    }

    // Bereich zum Wiederherstellen eines Backups aus einer JSON-Datei.
    private var wiederherstellungSektion: some View {
        Section {
            Button {
                zeigeImportPicker = true
            } label: {
                Label(loc.restoreBackup, systemImage: "arrow.down.doc")
                    .foregroundStyle(Color.accentColor)
            }
            .disabled(ladeVorgang)
        } header: {
            Text(loc.restore)
        } footer: {
            Text(loc.restoreFooter)
        }
    }

    // Info-Bereich mit Statistiken und App-Informationen.
    private var infoSektion: some View {
        Section(loc.info) {
            LabeledContent(loc.totalBooks, value: "\(alleBuecher.count)")
            // Zählt nur die Bücher, bei denen istAusgeliehen true ist.
            LabeledContent(loc.onLoan, value: "\(alleBuecher.filter { $0.istAusgeliehen }.count)")
            LabeledContent(loc.version, value: "1.0")
            LabeledContent(loc.author, value: "Mathias Wiebe")
        }
    }

    // MARK: - Aktionen

    // Erstellt eine JSON-Datei mit allen Büchern und öffnet das Teilen-Menü.
    // defer stellt sicher, dass ladeVorgang immer auf false gesetzt wird,
    // auch wenn ein Fehler auftritt.
    private func erstelleBackup() {
        ladeVorgang = true
        defer { ladeVorgang = false }

        do {
            let url = try BackupService.shared.exportiere(buecher: alleBuecher)
            exportURL = url
            zeigeExportSheet = true
        } catch {
            alertNachricht = error.localizedDescription
            zeigeFehlerAlert = true
        }
    }

    // Verarbeitet das Ergebnis des Datei-Auswahl-Dialogs.
    // Bei Erfolg: liest die JSON-Datei ein und importiert die Bücher in die Datenbank.
    // Bei Fehler: zeigt eine Fehlermeldung an.
    private func behandleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertNachricht = error.localizedDescription
            zeigeFehlerAlert = true

        case .success(let urls):
            guard let url = urls.first else { return }

            // Security-Scoped-Resource: iOS-Sicherheitsmechanismus für Dateizugriff.
            // startAccessingSecurityScopedResource() muss vor dem Lesen aufgerufen werden,
            // stopAccessingSecurityScopedResource() danach – defer erledigt das automatisch.
            let zugriffErlaubt = url.startAccessingSecurityScopedResource()
            defer {
                if zugriffErlaubt { url.stopAccessingSecurityScopedResource() }
            }

            ladeVorgang = true
            defer { ladeVorgang = false }

            do {
                let ergebnis = try BackupService.shared.importiere(von: url, in: modelContext)
                alertTitel = loc.importSuccess
                // Ergebnis: wie viele Bücher neu hinzugefügt, aktualisiert oder übersprungen wurden.
                alertNachricht = """
                    \(ergebnis.neu) \(loc.importNew)
                    \(ergebnis.aktualisiert) \(loc.importUpdated)
                    \(ergebnis.uebersprungen) \(loc.importSkipped)
                    """
                zeigeErfolgAlert = true
            } catch {
                alertNachricht = error.localizedDescription
                zeigeFehlerAlert = true
            }
        }
    }
}

// MARK: - ShareSheet

// Bindet den nativen iOS-Teilen-Dialog (UIActivityViewController) in SwiftUI ein.
// Ermöglicht das Teilen der Backup-Datei per AirDrop, Mail, Dateien-App usw.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    // Erstellt den nativen Teilen-Dialog mit der Backup-Datei als Inhalt.
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    // Wird von SwiftUI aufgerufen, wenn sich etwas ändert – hier nicht benötigt.
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
