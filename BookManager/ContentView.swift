import SwiftUI
import SwiftData

// Alle möglichen Felder, nach denen die Bücherliste sortiert werden kann.
enum SortierFeld: String, CaseIterable {
    case titel
    case autor
    case erscheinungsjahr
    case erstelltAm
}

struct ContentView: View {
    // Zugriff auf die SwiftData-Datenbank, um Bücher löschen zu können.
    @Environment(\.modelContext) private var modelContext

    // Lädt automatisch alle gespeicherten Bücher aus der Datenbank.
    @Query private var alleBuecher: [Book]

    // Sprachverwaltung – sorgt dafür, dass alle Texte in der gewählten Sprache erscheinen.
    @EnvironmentObject private var loc: LocalizationManager

    // Der aktuell eingetippte Suchbegriff.
    @State private var suchtext = ""

    // Steuert, ob das "Buch hinzufügen"-Formular angezeigt wird.
    @State private var zeigeHinzufuegenView = false

    // Steuert, ob die Einstellungen angezeigt werden.
    @State private var zeigeEinstellungen = false

    // Das aktuell ausgewählte Sortierfeld (Standard: Titel).
    @State private var sortierFeld: SortierFeld = .titel

    // true = aufsteigend (A→Z), false = absteigend (Z→A).
    @State private var aufsteigend = true

    // Merkt sich, welche Tabellenzeile der Nutzer zum Löschen gewischt hat.
    @State private var zuLoeschendeOffsets: IndexSet? = nil

    // Speichert den Titel des Buches, das gelöscht werden soll – für die Bestätigungsmeldung.
    @State private var zuLoeschenderTitel: String = ""

    // Steuert, ob der "Wirklich löschen?"-Dialog angezeigt wird.
    @State private var zeigeLoeschenBestaetigung = false

    // Gibt die gefilterte und sortierte Bücherliste zurück.
    // Wird jedes Mal neu berechnet, wenn sich Suchtext, Sortierung oder Daten ändern.
    private var gefiltert: [Book] {
        let liste = alleBuecher.filter { buch in
            // Zeige alle Bücher, wenn kein Suchtext eingegeben wurde.
            // Sonst nur Bücher, deren Titel oder Autor den Suchtext enthält.
            suchtext.isEmpty ||
            buch.titel.localizedCaseInsensitiveContains(suchtext) ||
            buch.autor.localizedCaseInsensitiveContains(suchtext)
        }
        return liste.sorted { a, b in
            let ergebnis: Bool
            // Vergleich der zwei Bücher anhand des gewählten Sortierfeldes.
            switch sortierFeld {
            case .titel:           ergebnis = a.titel < b.titel
            case .autor:           ergebnis = a.autor < b.autor
            case .erscheinungsjahr: ergebnis = a.erscheinungsjahr < b.erscheinungsjahr
            case .erstelltAm:      ergebnis = a.erstelltAm < b.erstelltAm
            }
            // Bei aufsteigend: Ergebnis direkt übernehmen. Bei absteigend: umkehren.
            return aufsteigend ? ergebnis : !ergebnis
        }
    }

    // Gibt den lokalisierten Anzeigenamen für ein Sortierfeld zurück.
    private func sortLabel(_ field: SortierFeld) -> String {
        switch field {
        case .titel:            return loc.sortTitle
        case .autor:            return loc.sortAuthor
        case .erscheinungsjahr: return loc.sortYear
        case .erstelltAm:       return loc.sortAdded
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if alleBuecher.isEmpty {
                    // Platzhalter-Ansicht, wenn noch keine Bücher vorhanden sind.
                    VStack(spacing: 20) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text(loc.noBooksTitle)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(loc.noBooksSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // Liste aller (gefilterten) Bücher. Jedes Buch ist ein Link zur Detailansicht.
                    List {
                        ForEach(gefiltert) { buch in
                            NavigationLink(destination: BookDetailView(buch: buch)) {
                                BuchZeile(buch: buch)
                            }
                        }
                        // Wisch-nach-links löst loeschenAnfragen aus.
                        .onDelete(perform: loeschenAnfragen)
                    }
                    .searchable(text: $suchtext, prompt: loc.searchPrompt)
                }
            }
            .navigationTitle(loc.myBooks)
            .toolbar {
                // Sortier-Menü oben links.
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Section(loc.sortBy) {
                            ForEach(SortierFeld.allCases, id: \.self) { feld in
                                Button {
                                    sortierFeld = feld
                                } label: {
                                    HStack {
                                        Text(sortLabel(feld))
                                        // Häkchen beim aktuell gewählten Feld.
                                        if sortierFeld == feld {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        Section(loc.order) {
                            Button {
                                aufsteigend = true
                            } label: {
                                HStack {
                                    Text(loc.ascending)
                                    if aufsteigend { Image(systemName: "checkmark") }
                                }
                            }
                            Button {
                                aufsteigend = false
                            } label: {
                                HStack {
                                    Text(loc.descending)
                                    if !aufsteigend { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                // Plus-Button oben rechts öffnet das Formular für ein neues Buch.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        zeigeHinzufuegenView = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                // Zahnrad-Button oben rechts öffnet die Einstellungen.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        zeigeEinstellungen = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            // Sheet für das "Neues Buch"-Formular.
            // environmentObject(loc) leitet die Spracheinstellung weiter,
            // da Sheets eine eigene View-Hierarchie starten.
            .sheet(isPresented: $zeigeHinzufuegenView) {
                AddBookView().environmentObject(loc)
            }
            // Sheet für die Einstellungsansicht.
            .sheet(isPresented: $zeigeEinstellungen) {
                SettingsView().environmentObject(loc)
            }
            // Bestätigungsdialog bevor ein Buch endgültig gelöscht wird.
            .alert(loc.deleteBookTitle, isPresented: $zeigeLoeschenBestaetigung) {
                Button(loc.delete, role: .destructive) {
                    if let offsets = zuLoeschendeOffsets {
                        loescheBuecher(at: offsets)
                    }
                }
                Button(loc.cancel, role: .cancel) {
                    zuLoeschendeOffsets = nil
                }
            } message: {
                // Zeigt den gespeicherten Buchtitel – sicher, weil er nicht dynamisch
                // aus dem Array gelesen wird (würde crashen wenn das Array sich ändert).
                Text("\"\(zuLoeschenderTitel)\" \(loc.deleteConfirm)")
            }
        }
    }

    // Wird aufgerufen, wenn der Nutzer ein Buch nach links wischt.
    // Speichert die Position und den Titel des Buches und zeigt den Bestätigungsdialog.
    private func loeschenAnfragen(at offsets: IndexSet) {
        zuLoeschendeOffsets = offsets
        // Buchtitel sofort speichern – nicht im Alert lesen, da das Array sich
        // zwischenzeitlich ändern könnte und zu einem Absturz führen würde.
        zuLoeschenderTitel = offsets.first.map { gefiltert[$0].titel } ?? ""
        zeigeLoeschenBestaetigung = true
    }

    // Löscht das Buch an der angegebenen Position dauerhaft aus der Datenbank.
    private func loescheBuecher(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(gefiltert[index])
        }
    }
}

// Eine einzelne Zeile in der Bücherliste mit Cover-Bild, Titel, Autor und Ausleih-Hinweis.
struct BuchZeile: View {
    let buch: Book

    var body: some View {
        HStack(spacing: 12) {
            // Zeige das gespeicherte Cover-Bild oder einen grauen Platzhalter.
            if let bildDaten = buch.bildDaten, let uiImage = UIImage(data: bildDaten) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 70)
                    .overlay {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(buch.titel)
                    .font(.headline)
                    .lineLimit(2)
                Text(buch.autor)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(String(buch.erscheinungsjahr))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    // Wenn das Buch ausgeliehen ist, den Namen der Person orange anzeigen.
                    if buch.istAusgeliehen, let name = buch.ausgeliehenAnVollname {
                        Spacer()
                        Label(name, systemImage: "arrow.up.forward.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
