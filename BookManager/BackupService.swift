import Foundation
import SwiftData

// Codable-Struktur für JSON Export/Import
struct BookBackup: Codable {
    var titel: String
    var autor: String
    var erscheinungsjahr: Int
    var erstelltAm: Date
    var beschreibung: String?
    var bildDaten: Data?
    var ausgeliehenAn: String?
    var ausgeliehenAnNachname: String?
    var ausgeliehenAm: Date?
}

struct BackupDatei: Codable {
    var version: Int = 1
    var exportiertAm: Date
    var buecher: [BookBackup]
}

enum BackupFehler: LocalizedError {
    case exportFehlgeschlagen(String)
    case importFehlgeschlagen(String)
    case ungueltigesFormat

    var errorDescription: String? {
        switch self {
        case .exportFehlgeschlagen(let msg): return "Export fehlgeschlagen: \(msg)"
        case .importFehlgeschlagen(let msg): return "Import fehlgeschlagen: \(msg)"
        case .ungueltigesFormat: return "Die Datei hat kein gültiges Backup-Format."
        }
    }
}

struct ImportErgebnis {
    var neu: Int
    var aktualisiert: Int
    var uebersprungen: Int
}

class BackupService {
    static let shared = BackupService()
    private init() {}

    // MARK: - Export

    func exportiere(buecher: [Book]) throws -> URL {
        let backup = BackupDatei(
            exportiertAm: Date(),
            buecher: buecher.map { buch in
                BookBackup(
                    titel: buch.titel,
                    autor: buch.autor,
                    erscheinungsjahr: buch.erscheinungsjahr,
                    erstelltAm: buch.erstelltAm,
                    beschreibung: buch.beschreibung,
                    bildDaten: buch.bildDaten,
                    ausgeliehenAn: buch.ausgeliehenAn,
                    ausgeliehenAnNachname: buch.ausgeliehenAnNachname,
                    ausgeliehenAm: buch.ausgeliehenAm
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(backup)

        let dateiName = "BookManager_Backup_\(datumAlsString()).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(dateiName)
        try data.write(to: url)
        return url
    }

    // MARK: - Import

    func importiere(von url: URL, in context: ModelContext) throws -> ImportErgebnis {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let backup = try? decoder.decode(BackupDatei.self, from: data) else {
            throw BackupFehler.ungueltigesFormat
        }

        // Lade alle vorhandenen Bücher
        let vorhandene = try context.fetch(FetchDescriptor<Book>())

        var neu = 0
        var aktualisiert = 0
        var uebersprungen = 0

        for backupBuch in backup.buecher {
            // Duplikat-Erkennung: Titel + Autor als Schlüssel
            let duplikat = vorhandene.first {
                $0.titel.lowercased() == backupBuch.titel.lowercased() &&
                $0.autor.lowercased() == backupBuch.autor.lowercased()
            }

            if let vorhandenesBuch = duplikat {
                // Neuesten Eintrag behalten
                if backupBuch.erstelltAm > vorhandenesBuch.erstelltAm {
                    // Backup ist neuer → vorhandenes aktualisieren
                    vorhandenesBuch.titel = backupBuch.titel
                    vorhandenesBuch.autor = backupBuch.autor
                    vorhandenesBuch.erscheinungsjahr = backupBuch.erscheinungsjahr
                    vorhandenesBuch.erstelltAm = backupBuch.erstelltAm
                    vorhandenesBuch.beschreibung = backupBuch.beschreibung
                    vorhandenesBuch.bildDaten = backupBuch.bildDaten
                    vorhandenesBuch.ausgeliehenAn = backupBuch.ausgeliehenAn
                    vorhandenesBuch.ausgeliehenAnNachname = backupBuch.ausgeliehenAnNachname
                    vorhandenesBuch.ausgeliehenAm = backupBuch.ausgeliehenAm
                    aktualisiert += 1
                } else {
                    // Vorhandenes ist neuer oder gleich → überspringen
                    uebersprungen += 1
                }
            } else {
                // Neues Buch einfügen
                let neuesBuch = Book(
                    titel: backupBuch.titel,
                    autor: backupBuch.autor,
                    erscheinungsjahr: backupBuch.erscheinungsjahr,
                    erstelltAm: backupBuch.erstelltAm,
                    bildDaten: backupBuch.bildDaten,
                    beschreibung: backupBuch.beschreibung
                )
                neuesBuch.ausgeliehenAn = backupBuch.ausgeliehenAn
                neuesBuch.ausgeliehenAnNachname = backupBuch.ausgeliehenAnNachname
                neuesBuch.ausgeliehenAm = backupBuch.ausgeliehenAm
                context.insert(neuesBuch)
                neu += 1
            }
        }

        try context.save()
        return ImportErgebnis(neu: neu, aktualisiert: aktualisiert, uebersprungen: uebersprungen)
    }

    // MARK: - Hilfsfunktion

    private func datumAlsString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        return f.string(from: Date())
    }
}
