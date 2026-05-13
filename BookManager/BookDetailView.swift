import SwiftUI

struct BookDetailView: View {
    // Das Buch, dessen Details angezeigt werden. Wird von der Liste übergeben.
    let buch: Book

    // Sprachverwaltung für alle Texte in diesem Screen.
    @EnvironmentObject private var loc: LocalizationManager

    // Datumsformatierer, der Datumswerte in lesbaren Text umwandelt.
    // Das Format passt sich der gewählten Sprache an (deutsch oder englisch).
    private var datumFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: loc.currentLanguage == .english ? "en_US" : "de_DE")
        return f
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                coverBereich
                    .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 16) {
                    titelBereich
                    Divider()
                    hinzugefuegtBereich
                    // Beschreibung nur anzeigen, wenn eine vorhanden ist.
                    if let beschreibung = buch.beschreibung, !beschreibung.isEmpty {
                        Divider()
                        beschreibungBereich(beschreibung)
                    }
                    // Ausleih-Bereich nur anzeigen, wenn das Buch gerade verliehen ist.
                    if buch.istAusgeliehen {
                        Divider()
                        ausleihBereich
                    }
                }
                .padding()
            }
        }
        .navigationTitle(loc.bookDetails)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Stift-Symbol oben rechts öffnet die Bearbeitungsansicht.
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: EditBookView(buch: buch)) {
                    Image(systemName: "pencil")
                }
            }
        }
    }

    // MARK: - Teilansichten

    // Zeigt das Cover-Bild groß an, oder einen grauen Platzhalter wenn keines vorhanden ist.
    private var coverBereich: some View {
        Group {
            if let bildDaten = buch.bildDaten, let uiImage = UIImage(data: bildDaten) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 160, height: 220)
                    .overlay {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                    }
                    .shadow(radius: 4)
                    .padding(.top, 20)
            }
        }
    }

    // Zeigt Buchtitel, Autor und Erscheinungsjahr nebeneinander an.
    private var titelBereich: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(buch.titel)
                .font(.title2)
                .fontWeight(.bold)
            HStack(spacing: 16) {
                Label(buch.autor, systemImage: "person")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Label(String(buch.erscheinungsjahr), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Zeigt das Datum an, an dem das Buch zur App hinzugefügt wurde.
    private var hinzugefuegtBereich: some View {
        HStack {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
            Text("\(loc.added): \(datumFormatter.string(from: buch.erstelltAm))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // Zeigt die Buchbeschreibung mit einer Überschrift an.
    // Wird nur aufgerufen, wenn eine Beschreibung vorhanden ist.
    private func beschreibungBereich(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc.description)
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // Zeigt Ausleih-Infos in einem orangefarbenen Kasten an:
    // Name der Person und Datum seit wann das Buch verliehen ist.
    private var ausleihBereich: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(loc.loanedOut, systemImage: "arrow.up.forward.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            if let name = buch.ausgeliehenAnVollname {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.subheadline)
                }
            }
            if let datum = buch.ausgeliehenAm {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text("\(loc.since) \(datumFormatter.string(from: datum))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
