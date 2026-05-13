import SwiftUI
import SwiftData

struct EditBookView: View {
    // Das Buch, das bearbeitet wird. @Bindable erlaubt direkte Änderungen am Objekt.
    @Bindable var buch: Book

    // Schließt diesen Screen, wenn der Nutzer "Abbrechen" oder "Fertig" tippt.
    @Environment(\.dismiss) private var dismiss

    // Sprachverwaltung für alle Texte in diesem Screen.
    @EnvironmentObject private var loc: LocalizationManager

    // Steuert, ob die Foto-Auswahl angezeigt wird.
    @State private var zeigeBildauswahl = false

    // Steuert, ob der Kontakt-Picker (Adressbuch) angezeigt wird.
    @State private var zeigeKontaktPicker = false

    // Steuert, ob der Bestätigungsdialog zum Zurücksetzen der Ausleihe erscheint.
    @State private var zeigeAusleiheZuruecksetzenBestaetigung = false

    // Das aktuelle Jahr – als Obergrenze für den Erscheinungsjahr-Picker.
    private var aktuellesJahr: Int { Calendar.current.component(.year, from: Date()) }

    // Speichern ist nur erlaubt, wenn Titel und Autor nicht leer sind.
    private var istFormularGueltig: Bool {
        !buch.titel.trimmingCharacters(in: .whitespaces).isEmpty &&
        !buch.autor.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                bildSektion
                informationenSektion
                beschreibungSektion
                ausleiheSektion
            }
            .navigationTitle(loc.editBook)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // "Fertig" ist deaktiviert, solange Titel oder Autor leer sind.
                    Button(loc.done) { dismiss() }
                        .disabled(!istFormularGueltig)
                        .fontWeight(.semibold)
                }
            }
            // Sheet für die Foto-Auswahl. Schreibt direkt in buch.bildDaten.
            .sheet(isPresented: $zeigeBildauswahl) {
                ImagePicker(bildDaten: $buch.bildDaten)
            }
            // Sheet für den Kontakt-Picker aus dem Adressbuch.
            .sheet(isPresented: $zeigeKontaktPicker) {
                ContactPickerView { vorname, nachname in
                    buch.ausgeliehenAn = vorname
                    buch.ausgeliehenAnNachname = nachname
                }
            }
            // Bestätigungsdialog, bevor die Ausleih-Daten gelöscht werden.
            .confirmationDialog(
                loc.resetLoanTitle,
                isPresented: $zeigeAusleiheZuruecksetzenBestaetigung,
                titleVisibility: .visible
            ) {
                Button(loc.resetLoan, role: .destructive) {
                    // Alle Ausleih-Felder auf nil setzen = Ausleihe aufgehoben.
                    buch.ausgeliehenAn = nil
                    buch.ausgeliehenAnNachname = nil
                    buch.ausgeliehenAm = nil
                }
                Button(loc.cancel, role: .cancel) {}
            } message: {
                Text(loc.resetLoanMessage)
            }
        }
    }

    // MARK: - Sektionen

    // Bereich für das Buchcover: Vorschau, Auswählen, Ändern oder Entfernen.
    private var bildSektion: some View {
        Section(loc.bookCover) {
            if let daten = buch.bildDaten, let uiImage = UIImage(data: daten) {
                // Vorschau des aktuellen Cover-Bildes.
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            // Beschriftung wechselt zwischen "Foto auswählen" und "Foto ändern".
            Button {
                zeigeBildauswahl = true
            } label: {
                Label(buch.bildDaten == nil ? loc.choosePhoto : loc.changePhoto, systemImage: "photo")
            }
            // Löschen-Button nur anzeigen, wenn bereits ein Bild vorhanden ist.
            if buch.bildDaten != nil {
                Button(role: .destructive) {
                    buch.bildDaten = nil
                } label: {
                    Label(loc.removePhoto, systemImage: "trash")
                }
            }
        }
    }

    // Bereich zum Bearbeiten von Titel, Autor und Erscheinungsjahr.
    private var informationenSektion: some View {
        Section(loc.bookInfo) {
            TextField(loc.titleField, text: $buch.titel)
            TextField(loc.authorField, text: $buch.autor)
            // Scroll-Picker für das Erscheinungsjahr, neueste Jahre zuerst.
            Picker(loc.publicationYear, selection: $buch.erscheinungsjahr) {
                ForEach((1800...aktuellesJahr).reversed(), id: \.self) { jahr in
                    Text(String(jahr)).tag(jahr)
                }
            }
        }
    }

    // Bereich für die mehrzeilige Beschreibung des Buches.
    // Leere Eingabe wird als nil gespeichert (= keine Beschreibung vorhanden).
    private var beschreibungSektion: some View {
        Section(loc.description) {
            TextEditor(text: Binding(
                get: { buch.beschreibung ?? "" },
                set: { buch.beschreibung = $0.isEmpty ? nil : $0 }
            ))
            .frame(minHeight: 100)
        }
    }

    // Bereich für alle Ausleih-Informationen: Kontakt, Name, Datum und Zurücksetzen.
    private var ausleiheSektion: some View {
        Section(loc.loanInfo) {
            // Öffnet das Adressbuch, um eine Person auszuwählen.
            Button {
                zeigeKontaktPicker = true
            } label: {
                Label(loc.chooseContact, systemImage: "person.badge.plus")
            }

            // Vorname und Nachname können auch manuell eingegeben werden.
            // nil-Werte werden als leerer String angezeigt und bei Leerinput wieder auf nil gesetzt.
            TextField(loc.firstName, text: Binding(
                get: { buch.ausgeliehenAn ?? "" },
                set: { buch.ausgeliehenAn = $0.isEmpty ? nil : $0 }
            ))
            TextField(loc.lastName, text: Binding(
                get: { buch.ausgeliehenAnNachname ?? "" },
                set: { buch.ausgeliehenAnNachname = $0.isEmpty ? nil : $0 }
            ))

            // Toggle: Einschalten setzt ausgeliehenAm auf heute, Ausschalten auf nil.
            Toggle(loc.loaned, isOn: Binding(
                get: { buch.ausgeliehenAm != nil },
                set: { istAusgeliehen in
                    if istAusgeliehen {
                        buch.ausgeliehenAm = Date()
                    } else {
                        buch.ausgeliehenAm = nil
                    }
                }
            ))

            // Datumspicker nur anzeigen, wenn der Toggle aktiviert ist.
            if buch.ausgeliehenAm != nil {
                DatePicker(
                    loc.loanedOn,
                    selection: Binding(
                        get: { buch.ausgeliehenAm ?? Date() },
                        set: { buch.ausgeliehenAm = $0 }
                    ),
                    displayedComponents: .date
                )
            }

            // "Ausleihe zurücksetzen"-Button nur anzeigen, wenn das Buch verliehen ist.
            if buch.istAusgeliehen {
                Button(role: .destructive) {
                    zeigeAusleiheZuruecksetzenBestaetigung = true
                } label: {
                    Label(loc.resetLoan, systemImage: "arrow.uturn.backward")
                }
            }
        }
    }
}
