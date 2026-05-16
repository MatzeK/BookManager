import SwiftUI
import SwiftData

struct AddBookView: View {
    // Zugriff auf die Datenbank, um das neue Buch speichern zu können.
    @Environment(\.modelContext) private var modelContext

    // Schließt diesen Screen, wenn der Nutzer "Abbrechen" oder "Speichern" tippt.
    @Environment(\.dismiss) private var dismiss

    // Sprachverwaltung für alle Texte in diesem Screen.
    @EnvironmentObject private var loc: LocalizationManager

    // Eingabefelder für das neue Buch.
    @State private var isbn = ""
    @State private var titel = ""
    @State private var autor = ""
    @State private var erscheinungsjahr = Calendar.current.component(.year, from: Date())
    @State private var beschreibung = ""
    @State private var bildDaten: Data? = nil

    // Steuert, ob der ISBN-Scanner angezeigt wird.
    @State private var zeigeScanner = false

    // Steuert, ob die Bildauswahl aus der Fotobibliothek angezeigt wird.
    @State private var zeigeBildauswahl = false

    // true, während Buchdaten per API geladen werden – zeigt einen Ladeindikator.
    @State private var ladeAPIInfo = false

    // Fehlermeldung aus der API oder beim Speichern.
    @State private var fehlerMeldung: String? = nil

    // Steuert, ob der Fehler-Dialog angezeigt wird.
    @State private var zeigeFehler = false

    // Das Formular darf nur gespeichert werden, wenn Titel und Autor ausgefüllt sind.
    private var istFormularGueltig: Bool {
        !titel.trimmingCharacters(in: .whitespaces).isEmpty &&
        !autor.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Das aktuelle Kalenderjahr – wird als Obergrenze im Jahres-Picker verwendet.
    private var aktuellesJahr: Int { Calendar.current.component(.year, from: Date()) }

    var body: some View {
        NavigationStack {
            Form {
                isbnSektion
                bildSektion
                informationenSektion
                beschreibungSektion
            }
            .navigationTitle(loc.newBook)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Speichern ist deaktiviert, solange Titel oder Autor leer sind.
                    Button(loc.save) { speichereBuch() }
                        .disabled(!istFormularGueltig)
                        .fontWeight(.semibold)
                }
            }
            // Sheet für den Barcode-Scanner.
            .sheet(isPresented: $zeigeScanner) {
                ISBNScannerView(erkannteISBN: Binding(
                    get: { nil },
                    set: { isbn in
                        if let isbn = isbn {
                            // @MainActor explizit angeben, da der Setter aus einem
                            // GCD-Kontext (AVFoundation-Delegate) aufgerufen wird.
                            Task { @MainActor in
                                self.isbn = isbn
                                await ladeBuchInfos(isbn: isbn)
                            }
                        }
                    }
                ))
            }
            // Sheet für die Foto-Auswahl aus der Bibliothek.
            .sheet(isPresented: $zeigeBildauswahl) {
                ImagePicker(bildDaten: $bildDaten)
            }
            // Dialog bei Fehlern (z. B. ISBN nicht gefunden).
            .alert(loc.error, isPresented: $zeigeFehler) {
                Button(loc.ok, role: .cancel) {}
            } message: {
                Text(fehlerMeldung ?? loc.unknownError)
            }
        }
    }

    // MARK: - Sektionen

    // Bereich für die ISBN-Eingabe und den Barcode-Scanner.
    private var isbnSektion: some View {
        Section("ISBN") {
            HStack {
                TextField(loc.isbnPlaceholder, text: $isbn)
                    .keyboardType(.numberPad)
                // Während des Ladens Spinner zeigen, sonst Such-Button.
                if ladeAPIInfo {
                    ProgressView()
                } else {
                    Button {
                        Task { await ladeBuchInfos(isbn: isbn) }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(isbn.isEmpty)
                }
            }
            Button {
                zeigeScanner = true
            } label: {
                Label(loc.scanBarcode, systemImage: "camera")
            }
        }
    }

    // Bereich für das Buchcover: Vorschau, Auswählen oder Löschen des Bildes.
    private var bildSektion: some View {
        Section(loc.bookCover) {
            if let daten = bildDaten, let uiImage = UIImage(data: daten) {
                // Wenn ein Bild vorhanden ist: Vorschau mit Löschen-Button daneben.
                HStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Spacer()
                    Button(role: .destructive) {
                        bildDaten = nil
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            // Beschriftung wechselt je nachdem, ob schon ein Foto vorhanden ist.
            Button {
                zeigeBildauswahl = true
            } label: {
                Label(bildDaten == nil ? loc.choosePhoto : loc.changePhoto, systemImage: "photo")
            }
        }
    }

    // Bereich für Titel, Autor und Erscheinungsjahr.
    private var informationenSektion: some View {
        Section(loc.bookInfo) {
            TextField(loc.titleField, text: $titel)
            TextField(loc.authorField, text: $autor)
            // Scroll-Picker für das Erscheinungsjahr von 1800 bis heute.
            Picker(loc.publicationYear, selection: $erscheinungsjahr) {
                ForEach((1800...aktuellesJahr).reversed(), id: \.self) { jahr in
                    Text(String(jahr)).tag(jahr)
                }
            }
        }
    }

    // Bereich für eine mehrzeilige Buchbeschreibung.
    private var beschreibungSektion: some View {
        Section(loc.description) {
            TextEditor(text: $beschreibung)
                .frame(minHeight: 100)
        }
    }

    // MARK: - Aktionen

    // Lädt Buchinfos (Titel, Autor, Jahr, Cover) von einer Online-API anhand der ISBN.
    // @MainActor explizit, damit @State-Zugriffe vor und nach dem await klar isoliert sind.
    @MainActor
    private func ladeBuchInfos(isbn: String) async {
        guard !isbn.isEmpty else { return }
        ladeAPIInfo = true
        defer { ladeAPIInfo = false }

        do {
            let info = try await BookAPIService.shared.ladeBuchInfo(isbn: isbn)
            titel = info.titel
            autor = info.autor
            if info.erscheinungsjahr > 0 {
                erscheinungsjahr = info.erscheinungsjahr
            }
            if let desc = info.beschreibung {
                beschreibung = desc
            }
            if let daten = info.coverDaten {
                bildDaten = daten
            }
        } catch {
            fehlerMeldung = error.localizedDescription
            zeigeFehler = true
        }
    }

    // Erstellt ein neues Book-Objekt aus den Eingabefeldern und speichert es in der Datenbank.
    private func speichereBuch() {
        let neuesBuch = Book(
            titel: titel.trimmingCharacters(in: .whitespaces),
            autor: autor.trimmingCharacters(in: .whitespaces),
            erscheinungsjahr: erscheinungsjahr,
            bildDaten: bildDaten,
            beschreibung: beschreibung.isEmpty ? nil : beschreibung
        )
        modelContext.insert(neuesBuch)
        dismiss()
    }
}

// MARK: - ImagePicker

// Bindet den nativen iOS-Foto-Auswahl-Dialog (UIImagePickerController) in SwiftUI ein.
// UIViewControllerRepresentable ist die Brücke zwischen UIKit und SwiftUI.
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var bildDaten: Data?
    @Environment(\.dismiss) private var dismiss

    // Erstellt den nativen Foto-Auswahl-Controller und setzt diesen View als Delegate.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    // Wird von SwiftUI aufgerufen, wenn sich etwas ändert – hier nicht benötigt.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // Erstellt den Coordinator, der die Callbacks des Foto-Controllers verarbeitet.
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // Der Coordinator empfängt die Ereignisse vom UIImagePickerController
    // und leitet das gewählte Bild an SwiftUI weiter.
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) { self.parent = parent }

        // Wird aufgerufen, wenn der Nutzer ein Foto ausgewählt hat.
        // Konvertiert das Bild in JPEG-Daten und speichert es.
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.bildDaten = image.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }

        // Wird aufgerufen, wenn der Nutzer die Auswahl abbricht.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
