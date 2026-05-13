import Foundation
import SwiftData

@Model
class Book {
    var titel: String
    var autor: String
    var erscheinungsjahr: Int
    var erstelltAm: Date
    var bildDaten: Data?
    var beschreibung: String?
    var ausgeliehenAn: String?
    var ausgeliehenAnNachname: String?
    var ausgeliehenAm: Date?

    var istAusgeliehen: Bool {
        ausgeliehenAn != nil
    }

    var ausgeliehenAnVollname: String? {
        guard let vorname = ausgeliehenAn else { return nil }
        if let nachname = ausgeliehenAnNachname, !nachname.isEmpty {
            return "\(vorname) \(nachname)"
        }
        return vorname
    }

    init(
        titel: String,
        autor: String,
        erscheinungsjahr: Int,
        erstelltAm: Date = Date(),
        bildDaten: Data? = nil,
        beschreibung: String? = nil
    ) {
        self.titel = titel
        self.autor = autor
        self.erscheinungsjahr = erscheinungsjahr
        self.erstelltAm = erstelltAm
        self.bildDaten = bildDaten
        self.beschreibung = beschreibung
    }
}
