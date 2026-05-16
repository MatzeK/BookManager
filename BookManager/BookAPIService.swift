import Foundation

struct BookInfo {
    var titel: String
    var autor: String
    var erscheinungsjahr: Int
    var beschreibung: String?
    var coverURL: URL?
    var coverDaten: Data?
}

enum BookAPIFehler: LocalizedError {
    case nichtGefunden
    case netzwerkFehler(Error)
    case ungueltigeAntwort(Int)

    var errorDescription: String? {
        switch self {
        case .nichtGefunden:
            return "Buch nicht gefunden. Bitte prüfe die ISBN oder gib die Daten manuell ein."
        case .netzwerkFehler(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        case .ungueltigeAntwort(let statusCode):
            return "Serverfehler (HTTP \(statusCode)). Bitte erneut versuchen."
        }
    }
}

class BookAPIService {
    static let shared = BookAPIService()
    private init() {}

    func ladeBuchInfo(isbn: String) async throws -> BookInfo {
        let bereinigteISBN = isbn.filter { $0.isNumber }
        print("[BookAPI] Suche ISBN: \(bereinigteISBN)")

        do {
            let info = try await ladeVonOpenLibrary(isbn: bereinigteISBN)
            print("[BookAPI] Open Library: gefunden")
            return info
        } catch {
            print("[BookAPI] Open Library fehlgeschlagen: \(error.localizedDescription)")
        }

        do {
            let info = try await ladeVonGoogleBooks(isbn: bereinigteISBN)
            print("[BookAPI] Google Books: gefunden")
            return info
        } catch {
            print("[BookAPI] Google Books fehlgeschlagen: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Open Library

    private func ladeVonOpenLibrary(isbn: String) async throws -> BookInfo {
        let urlString = "https://openlibrary.org/api/books?bibkeys=ISBN:\(isbn)&format=json&jscmd=data"
        guard let url = URL(string: urlString) else { throw BookAPIFehler.ungueltigeAntwort(0) }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                if (400...499).contains(httpResponse.statusCode) {
                    throw BookAPIFehler.nichtGefunden
                }
                throw BookAPIFehler.ungueltigeAntwort(httpResponse.statusCode)
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let buchDaten = json["ISBN:\(isbn)"] as? [String: Any] else {
            throw BookAPIFehler.nichtGefunden
        }

        let titel = buchDaten["title"] as? String ?? "Unbekannter Titel"

        var autor = "Unbekannter Autor"
        if let autoren = buchDaten["authors"] as? [[String: Any]],
           let ersterAutor = autoren.first,
           let name = ersterAutor["name"] as? String {
            autor = name
        }

        var jahr = 0
        if let publishDate = buchDaten["publish_date"] as? String {
            let jahrString = publishDate.filter { $0.isNumber }
            if jahrString.count >= 4 {
                jahr = Int(String(jahrString.prefix(4))) ?? 0
            }
        }

        var beschreibung: String? = nil
        if let desc = buchDaten["description"] as? [String: Any] {
            beschreibung = desc["value"] as? String
        } else if let desc = buchDaten["description"] as? String {
            beschreibung = desc
        }

        var coverURL: URL? = nil
        if let cover = buchDaten["cover"] as? [String: Any],
           let largeURL = cover["large"] as? String {
            coverURL = URL(string: largeURL)
        }

        var info = BookInfo(
            titel: titel,
            autor: autor,
            erscheinungsjahr: jahr,
            beschreibung: beschreibung,
            coverURL: coverURL
        )

        if let url = coverURL {
            info.coverDaten = try? await ladeBild(von: url)
        }

        return info
    }

    // MARK: - Google Books

    private func ladeVonGoogleBooks(isbn: String) async throws -> BookInfo {
        let urlString = "https://www.googleapis.com/books/v1/volumes?q=isbn:\(isbn)"
        guard let url = URL(string: urlString) else { throw BookAPIFehler.ungueltigeAntwort(0) }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                if (400...499).contains(httpResponse.statusCode) {
                    throw BookAPIFehler.nichtGefunden
                }
                throw BookAPIFehler.ungueltigeAntwort(httpResponse.statusCode)
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let totalItems = json["totalItems"] as? Int, totalItems > 0,
              let items = json["items"] as? [[String: Any]],
              let erstesItem = items.first,
              let volumeInfo = erstesItem["volumeInfo"] as? [String: Any] else {
            throw BookAPIFehler.nichtGefunden
        }

        let titel = volumeInfo["title"] as? String ?? "Unbekannter Titel"

        var autor = "Unbekannter Autor"
        if let autoren = volumeInfo["authors"] as? [String], let erster = autoren.first {
            autor = autoren.count > 1 ? autoren.joined(separator: ", ") : erster
        }

        var jahr = 0
        if let publishedDate = volumeInfo["publishedDate"] as? String {
            let teile = publishedDate.components(separatedBy: "-")
            if let erstesTeil = teile.first {
                jahr = Int(erstesTeil) ?? 0
            }
        }

        let beschreibung = volumeInfo["description"] as? String

        var coverURL: URL? = nil
        if let imageLinks = volumeInfo["imageLinks"] as? [String: Any] {
            let urlString = (imageLinks["large"] as? String) ??
                           (imageLinks["medium"] as? String) ??
                           (imageLinks["thumbnail"] as? String)
            if let urlStr = urlString {
                let httpsURL = urlStr.replacingOccurrences(of: "http://", with: "https://")
                coverURL = URL(string: httpsURL)
            }
        }

        var info = BookInfo(
            titel: titel,
            autor: autor,
            erscheinungsjahr: jahr,
            beschreibung: beschreibung,
            coverURL: coverURL
        )

        if let url = coverURL {
            info.coverDaten = try? await ladeBild(von: url)
        }

        return info
    }

    // MARK: - Hilfsfunktionen

    private func ladeBild(von url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}
