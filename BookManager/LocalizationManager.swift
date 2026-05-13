import SwiftUI

// Alle verfügbaren Sprachen der App.
// RawValue "de"/"en" wird in AppStorage gespeichert, um die Wahl dauerhaft zu merken.
enum AppLanguage: String, CaseIterable {
    case german = "de"
    case english = "en"

    // Der Name, der dem Nutzer in der Sprachauswahl angezeigt wird.
    var displayName: String {
        switch self {
        case .german: return "Deutsch"
        case .english: return "English"
        }
    }
}

// Verwaltet die Spracheinstellung der gesamten App.
// ObservableObject bedeutet: alle Views, die dieses Objekt beobachten,
// werden automatisch neu gezeichnet, wenn sich die Sprache ändert.
// @MainActor stellt sicher, dass alle Änderungen auf dem Hauptthread stattfinden.
@MainActor
final class LocalizationManager: ObservableObject {
    // @AppStorage speichert den Wert dauerhaft in den App-Einstellungen (UserDefaults).
    // Standard ist Deutsch. didSet sendet eine Änderungsmeldung an alle Views.
    @AppStorage("appLanguage") var language: String = AppLanguage.german.rawValue {
        didSet { objectWillChange.send() }
    }

    // Gibt die aktuell gewählte Sprache als AppLanguage-Wert zurück.
    // Falls ein ungültiger Wert gespeichert ist, fällt es auf Deutsch zurück.
    var currentLanguage: AppLanguage {
        AppLanguage(rawValue: language) ?? .german
    }

    // Hilfsfunktion: gibt den deutschen oder englischen Text zurück,
    // je nachdem welche Sprache gerade aktiv ist.
    func t(_ de: String, _ en: String) -> String {
        currentLanguage == .english ? en : de
    }
}

// MARK: - Alle App-Texte

// Alle sichtbaren Texte der App sind hier zentral gesammelt.
// Jede Property gibt automatisch den Text in der aktuell gewählten Sprache zurück.
extension LocalizationManager {

    // MARK: ContentView – Hauptliste
    var noBooksTitle: String       { t("Keine Bücher vorhanden", "No books yet") }
    var noBooksSubtitle: String    { t("Tippe auf + um dein erstes Buch hinzuzufügen", "Tap + to add your first book") }
    var myBooks: String            { t("Meine Bücher", "My Books") }
    var searchPrompt: String       { t("Titel oder Autor suchen", "Search title or author") }
    var sortBy: String             { t("Sortieren nach", "Sort by") }
    var order: String              { t("Reihenfolge", "Order") }
    var ascending: String          { t("Aufsteigend", "Ascending") }
    var descending: String         { t("Absteigend", "Descending") }
    var deleteBookTitle: String    { t("Buch löschen?", "Delete book?") }
    var delete: String             { t("Löschen", "Delete") }
    var cancel: String             { t("Abbrechen", "Cancel") }
    var deleteConfirm: String      { t("wird unwiderruflich gelöscht.", "will be permanently deleted.") }

    // MARK: Sortierfelder
    var sortTitle: String          { t("Titel", "Title") }
    var sortAuthor: String         { t("Autor", "Author") }
    var sortYear: String           { t("Jahr", "Year") }
    var sortAdded: String          { t("Hinzugefügt", "Added") }

    // MARK: AddBookView – Neues Buch
    var newBook: String            { t("Neues Buch", "New Book") }
    var save: String               { t("Speichern", "Save") }
    var isbnPlaceholder: String    { t("ISBN eingeben...", "Enter ISBN...") }
    var scanBarcode: String        { t("Barcode scannen", "Scan barcode") }
    var bookCover: String          { t("Buchcover", "Book Cover") }
    var choosePhoto: String        { t("Foto auswählen", "Choose photo") }
    var changePhoto: String        { t("Foto ändern", "Change photo") }
    var bookInfo: String           { t("Buchinformationen", "Book information") }
    var titleField: String         { t("Titel *", "Title *") }
    var authorField: String        { t("Autor *", "Author *") }
    var publicationYear: String    { t("Erscheinungsjahr", "Publication year") }
    var description: String        { t("Beschreibung", "Description") }
    var unknownError: String       { t("Unbekannter Fehler", "Unknown error") }

    // MARK: BookDetailView – Buchdetails
    var bookDetails: String        { t("Buchdetails", "Book Details") }
    var added: String              { t("Hinzugefügt", "Added") }
    var loanedOut: String          { t("Ausgeliehen", "On loan") }
    var since: String              { t("seit", "since") }

    // MARK: EditBookView – Buch bearbeiten
    var editBook: String           { t("Buch bearbeiten", "Edit Book") }
    var done: String               { t("Fertig", "Done") }
    var removePhoto: String        { t("Foto entfernen", "Remove photo") }
    var loanInfo: String           { t("Ausleihinformationen", "Loan information") }
    var chooseContact: String      { t("Kontakt auswählen", "Choose contact") }
    var firstName: String          { t("Vorname", "First name") }
    var lastName: String           { t("Nachname", "Last name") }
    var loaned: String             { t("Ausgeliehen", "On loan") }
    var loanedOn: String           { t("Ausgeliehen am", "Loaned on") }
    var resetLoan: String          { t("Ausleihe zurücksetzen", "Reset loan") }
    var resetLoanTitle: String     { t("Ausleihe zurücksetzen?", "Reset loan?") }
    var resetLoanMessage: String   { t("Die Ausleihinformationen werden gelöscht.", "The loan information will be deleted.") }

    // MARK: SettingsView – Einstellungen
    var settings: String           { t("Einstellungen", "Settings") }
    var backup: String             { t("Backup", "Backup") }
    var createBackup: String       { t("Backup erstellen", "Create backup") }
    var books: String              { t("Bücher", "books") }
    var backupFooter: String       { t("Speichert alle Bücher als JSON-Datei. Du kannst sie in der Dateien-App, iCloud oder per AirDrop sichern.", "Saves all books as a JSON file. You can store it in the Files app, iCloud, or share via AirDrop.") }
    var restore: String            { t("Wiederherstellen", "Restore") }
    var restoreBackup: String      { t("Backup wiederherstellen", "Restore backup") }
    var restoreFooter: String      { t("Importiert Bücher aus einer Backup-Datei. Duplikate werden erkannt — der neuere Eintrag wird behalten.", "Imports books from a backup file. Duplicates are detected — the newer entry is kept.") }
    var info: String               { t("Info", "Info") }
    var totalBooks: String         { t("Bücher gesamt", "Total books") }
    var onLoan: String             { t("Ausgeliehen", "On loan") }
    var version: String            { t("Version", "Version") }
    var author: String             { t("Autor", "Author") }
    var importSuccess: String      { t("Import erfolgreich", "Import successful") }
    var importNew: String          { t("neue Bücher hinzugefügt", "new books added") }
    var importUpdated: String      { t("Bücher aktualisiert", "books updated") }
    var importSkipped: String      { t("Duplikate übersprungen", "duplicates skipped") }
    var error: String              { t("Fehler", "Error") }
    var ok: String                 { t("OK", "OK") }
    var languageLabel: String      { t("Sprache", "Language") }
    var languageSection: String    { t("Sprache", "Language") }
}
