# 📚 BookManager

> **Eine iOS-App zur Verwaltung deiner persönlichen Bücherbibliothek** – mit ISBN-Scanner, automatischem Buchcover-Download, Ausleihverwaltung und Backup-Funktion.

---

## 🗂️ Inhaltsverzeichnis

1. [Was macht die App?](#-was-macht-die-app)
2. [Technische Grundlagen (für Nicht-iOS-Entwickler)](#-technische-grundlagen)
3. [Projektstruktur](#-projektstruktur)
4. [Funktionen im Detail](#-funktionen-im-detail)
   - [Bücherliste (Hauptansicht)](#bücherliste-hauptansicht)
   - [Buch hinzufügen](#buch-hinzufügen)
   - [ISBN-Barcode-Scanner](#isbn-barcode-scanner)
   - [Online-Buchsuche (API)](#online-buchsuche-api)
   - [Buchdetails anzeigen](#buchdetails-anzeigen)
   - [Buch bearbeiten](#buch-bearbeiten)
   - [Ausleihverwaltung](#ausleihverwaltung)
   - [Backup & Wiederherstellen](#backup--wiederherstellen)
   - [Einstellungen & Sprache](#einstellungen--sprache)
5. [Datenmodell](#-datenmodell)
6. [Architektur & Datenspeicherung](#-architektur--datenspeicherung)

---

## 🎯 Was macht die App?

BookManager ist eine **native iOS-App** (iPhone/iPad), mit der du deine persönliche Bücherbibliothek verwalten kannst. Du kannst:

- Bücher **manuell erfassen** oder per **ISBN-Barcode scannen** automatisch importieren
- Buchinfos (Titel, Autor, Cover, Beschreibung) **automatisch aus dem Internet laden**
- Verfolgen, **wem du ein Buch ausgeliehen** hast und seit wann
- Deine gesamte Bibliothek als **JSON-Datei sichern** und wiederherstellen
- Die App auf **Deutsch oder Englisch** nutzen

---

## 🔧 Technische Grundlagen

> *Dieser Abschnitt erklärt Konzepte für Kollegen, die keine iOS-Erfahrung haben.*

| Konzept | Erklärung |
|---|---|
| **Swift / SwiftUI** | Die Programmiersprache (Swift) und das UI-Framework (SwiftUI), mit dem die App gebaut wurde. SwiftUI beschreibt die Benutzeroberfläche deklarativ – man sagt *was* angezeigt werden soll, nicht *wie*. |
| **SwiftData** | Apples eingebaute Datenbank-Lösung für iOS. Bücher werden hier lokal auf dem Gerät gespeichert – ähnlich wie SQLite, aber mit weniger Boilerplate. |
| **@State / @Query** | Sogenannte *Property Wrapper*. `@State` speichert einen Wert lokal in einer View (z. B. ob ein Dialog geöffnet ist). `@Query` lädt automatisch Daten aus SwiftData und aktualisiert die View bei Änderungen. |
| **Sheet / NavigationLink** | iOS-Navigationsmuster. Ein *Sheet* ist ein Dialog, der von unten hochfährt. Ein *NavigationLink* wechselt zu einem neuen Screen. |
| **async/await** | Asynchrone Programmierung: Netzwerkanfragen laufen im Hintergrund, ohne die App einzufrieren. |
| **AVFoundation** | Apples Framework für Kamera und Video – wird für den Barcode-Scanner verwendet. |
| **Contacts / CNContactPicker** | iOS-Framework für den Zugriff auf das Adressbuch. |

---

## 📁 Projektstruktur

```
BookManager/
├── BookManagerApp.swift        # App-Einstiegspunkt, startet die Datenbank
├── Book.swift                  # Datenmodell: definiert, was ein Buch ist
├── ContentView.swift           # Hauptansicht mit der Bücherliste
├── AddBookView.swift           # Formular: neues Buch erfassen
├── BookDetailView.swift        # Detailansicht eines Buchs (nur lesen)
├── EditBookView.swift          # Formular: Buch bearbeiten + Ausleih-Info
├── ISBNScannerView.swift       # Kamera-Barcode-Scanner
├── BookAPIService.swift        # Buchinfos per ISBN aus dem Internet laden
├── ContactPickerView.swift     # Adressbuch-Auswahl für Ausleih-Person
├── BackupService.swift         # Export und Import als JSON-Datei
├── SettingsView.swift          # Einstellungen, Backup, Sprachauswahl
└── LocalizationManager.swift  # Alle App-Texte (Deutsch/Englisch)
```

---

## 🔍 Funktionen im Detail

---

### Bücherliste (Hauptansicht)

**Datei:** `ContentView.swift`

Die Hauptansicht zeigt alle gespeicherten Bücher in einer scrollbaren Liste.

**Was der Nutzer sieht:**
- Jedes Buch wird mit **Buchcover** (oder Platzhalter-Icon), **Titel**, **Autor** und **Erscheinungsjahr** angezeigt
- Ausgeliehene Bücher zeigen zusätzlich den **Namen der Ausleihperson** in 🟠 **orange**
- Ist die Bibliothek leer, erscheint ein Hinweis mit Anleitung zum ersten Buch

**Aktionen in der Toolbar:**

| Symbol | Funktion |
|---|---|
| `↑↓` (Sortier-Menü) | Bücher sortieren nach **Titel, Autor, Erscheinungsjahr oder Hinzufügedatum** – auf- oder absteigend |
| `+` | Öffnet das Formular zum Hinzufügen eines neuen Buchs |
| `⚙️` | Öffnet die Einstellungen |

**Suche:**
Über eine Suchleiste kann nach Titel oder Autor gefiltert werden – Groß-/Kleinschreibung wird ignoriert.

**Buch löschen:**
Nach links wischen auf einem Listeneintrag zeigt einen Lösch-Button. Vor dem endgültigen Löschen erscheint ein **Bestätigungsdialog** mit dem Buchtitel.

---

### Buch hinzufügen

**Datei:** `AddBookView.swift`

Ein Formular mit vier Bereichen:

#### 1. ISBN-Bereich
```
[ ISBN eingeben... ] [🔍]
[ 📷 Barcode scannen ]
```
- ISBN manuell eingeben und mit 🔍 nach Buchinfos suchen
- Oder: direkt per **Kamera-Scanner** eine ISBN scannen (öffnet den Scanner-Screen)
- Nach erfolgreicher ISBN-Suche werden **Titel, Autor, Jahr, Beschreibung und Cover automatisch befüllt**

#### 2. Buchcover-Bereich
- Gefundenes oder manuell gewähltes Bild wird als **Vorschau** gezeigt
- Foto aus der Fotobibliothek auswählen oder ändern
- Bild kann wieder gelöscht werden

#### 3. Buchinformationen
- **Titel** (Pflichtfeld, markiert mit `*`)
- **Autor** (Pflichtfeld, markiert mit `*`)
- **Erscheinungsjahr** als Scroll-Picker (1800 bis heute, neueste zuerst)

#### 4. Beschreibung
- Mehrzeiliges Textfeld für eine Buchbeschreibung

> **Hinweis:** Der **Speichern-Button** ist deaktiviert, solange Titel oder Autor leer sind.

---

### ISBN-Barcode-Scanner

**Datei:** `ISBNScannerView.swift`

Öffnet einen **vollbildschirm Kamera-Screen**:

- Schwarzer Hintergrund mit halbtransparentem Overlay
- Weißer Rahmen in der Mitte zeigt den Scan-Bereich
- Hinweistext: *"Richte die Kamera auf den ISBN-Barcode"*
- Unterstützt **EAN-8, EAN-13, UPC-E** (die gängigen Buchbarcode-Formate)
- Bei erfolgreichem Scan **vibriert das Gerät** kurz und der Screen schließt sich automatisch
- Eine Mindestwartezeit von 2 Sekunden zwischen Scans verhindert versehentliche Mehrfachscans

---

### Online-Buchsuche (API)

**Datei:** `BookAPIService.swift`

Sucht Buchinfos anhand einer ISBN über zwei Quellen (automatisches Fallback):

```
ISBN eingeben/scannen
       ↓
  Open Library API  ──(nicht gefunden?)──→  Google Books API
       ↓                                          ↓
  Titel, Autor, Jahr, Beschreibung, Cover-URL laden
       ↓
  Cover-Bild herunterladen und speichern
```

| Datenquelle | URL |
|---|---|
| **Open Library** (primär) | `https://openlibrary.org/api/books?bibkeys=ISBN:...` |
| **Google Books** (Fallback) | `https://www.googleapis.com/books/v1/volumes?q=isbn:...` |

Geladene Daten:
- `titel` – Buchtitel
- `autor` – Erster Autor (bei mehreren: kommagetrennt)
- `erscheinungsjahr` – Aus dem Veröffentlichungsdatum extrahiert
- `beschreibung` – Klappentexts (falls vorhanden)
- `coverDaten` – Cover-Bild als Binärdaten (JPEG), direkt heruntergeladen

---

### Buchdetails anzeigen

**Datei:** `BookDetailView.swift`

Scrollbare Detailansicht mit:

- **Großes Cover-Bild** (bis 280px hoch) mit abgerundeten Ecken und Schatten
- **Titel** (fett, groß), **Autor** mit Person-Icon, **Erscheinungsjahr** mit Kalender-Icon
- **Hinzufügedatum** (wann das Buch in die App eingetragen wurde)
- **Beschreibung** (nur wenn vorhanden)
- **Ausleih-Info-Kasten** (nur wenn ausgeliehen): orangefarbener Hintergrund mit Name und Datum seit wann ausgeliehen

Der **✏️ Stift-Button** oben rechts öffnet die Bearbeitungsansicht.

---

### Buch bearbeiten

**Datei:** `EditBookView.swift`

Gleiche Felder wie beim Hinzufügen, plus der Ausleih-Sektion:

#### Ausleih-Sektion

```
[ 👤 Kontakt auswählen ]   ← öffnet das iOS-Adressbuch
[ Vorname                ]
[ Nachname               ]
[ Ausgeliehen  [Toggle]  ]
[ Ausgeliehen am [Datum] ]  ← nur sichtbar wenn Toggle an
[ 🔄 Ausleihe zurücksetzen ]  ← nur sichtbar wenn ausgeliehen
```

- Über "Kontakt auswählen" wird das **iOS-Adressbuch** geöffnet – Vor- und Nachname werden automatisch übernommen
- Name kann auch manuell eingegeben werden
- **Toggle** schaltet die Ausleihe an (setzt Datum auf heute) oder aus
- **Datepicker** erscheint nur wenn der Toggle aktiv ist
- "Ausleihe zurücksetzen" löscht alle Ausleih-Daten nach Bestätigung

---

### Ausleihverwaltung

Überblick darüber, wie die Ausleihe technisch funktioniert:

**Im Datenmodell** (`Book.swift`) gibt es drei Felder:
- `ausgeliehenAn` – Vorname der Person (oder `nil` wenn nicht ausgeliehen)
- `ausgeliehenAnNachname` – Nachname
- `ausgeliehenAm` – Datum seit wann ausgeliehen

Die berechnete Eigenschaft `istAusgeliehen` gibt `true` zurück, wenn `ausgeliehenAn` einen Wert hat. So kann an allen Stellen in der App einfach geprüft werden, ob ein Buch gerade verliehen ist.

---

### Backup & Wiederherstellen

**Dateien:** `BackupService.swift`, `SettingsView.swift`

#### Export (Backup erstellen)

1. Alle Bücher werden in eine **JSON-Datei** serialisiert (inkl. Cover-Bilder als Base64)
2. Dateiname: `BookManager_Backup_YYYY-MM-DD_HHmm.json`
3. Das **iOS-Teilen-Menü** öffnet sich: AirDrop, iCloud Drive, Dateien-App, Mail, etc.

Beispiel-Struktur der JSON-Datei:
```json
{
  "version": 1,
  "exportiertAm": "2025-05-13T10:00:00Z",
  "buecher": [
    {
      "titel": "Der Herr der Ringe",
      "autor": "J.R.R. Tolkien",
      "erscheinungsjahr": 1954,
      "erstelltAm": "2025-01-01T12:00:00Z",
      "beschreibung": "...",
      "bildDaten": "...(Base64)...",
      "ausgeliehenAn": "Max",
      "ausgeliehenAnNachname": "Mustermann",
      "ausgeliehenAm": "2025-04-01T00:00:00Z"
    }
  ]
}
```

#### Import (Backup wiederherstellen)

1. Datei-Auswahl-Dialog öffnet sich (nur `.json`-Dateien)
2. Datei wird eingelesen und dekodiert
3. **Duplikat-Erkennung:** Titel + Autor werden verglichen
   - Buch noch nicht vorhanden → wird neu angelegt
   - Buch vorhanden, Backup ist **neuer** → wird aktualisiert
   - Buch vorhanden, Backup ist **älter oder gleich** → wird übersprungen
4. Ergebnis-Dialog zeigt: `X neue Bücher hinzugefügt / Y aktualisiert / Z übersprungen`

---

### Einstellungen & Sprache

**Datei:** `SettingsView.swift`, `LocalizationManager.swift`

Die Einstellungen-Ansicht (erreichbar über das ⚙️-Symbol) enthält:

| Bereich | Inhalt |
|---|---|
| **Sprache** | Umschalter zwischen 🇩🇪 Deutsch und 🇬🇧 English – **sofortige Wirkung** auf alle Texte |
| **Backup** | Button zum Erstellen einer Backup-Datei, zeigt Gesamtanzahl der Bücher |
| **Wiederherstellen** | Button zum Importieren einer Backup-Datei |
| **Info** | Bücher gesamt, Anzahl ausgeliehener Bücher, App-Version (1.0), Autor |

**Wie die Mehrsprachigkeit funktioniert:**
Alle sichtbaren Texte der App sind zentral in `LocalizationManager.swift` gesammelt. Der `LocalizationManager` ist ein `ObservableObject` – sobald die Sprache geändert wird, werden **alle Views automatisch neu gerendert**. Die gewählte Sprache wird dauerhaft in den App-Einstellungen gespeichert (`UserDefaults`) und bleibt auch nach App-Neustart erhalten.

---

## 📊 Datenmodell

**Datei:** `Book.swift`

Ein `Book`-Objekt hat folgende Felder:

| Feld | Typ | Beschreibung |
|---|---|---|
| `titel` | `String` | Buchtitel (Pflichtfeld) |
| `autor` | `String` | Autorenname (Pflichtfeld) |
| `erscheinungsjahr` | `Int` | Erscheinungsjahr (z. B. `2001`) |
| `erstelltAm` | `Date` | Zeitstempel der Erfassung in der App |
| `bildDaten` | `Data?` | Cover-Bild als JPEG-Binärdaten (optional) |
| `beschreibung` | `String?` | Buchbeschreibung / Klappentext (optional) |
| `ausgeliehenAn` | `String?` | Vorname der Ausleihperson – `nil` = nicht ausgeliehen |
| `ausgeliehenAnNachname` | `String?` | Nachname der Ausleihperson (optional) |
| `ausgeliehenAm` | `Date?` | Datum seit wann ausgeliehen (optional) |

Berechnete Eigenschaften (werden nicht gespeichert, sondern dynamisch berechnet):

| Eigenschaft | Erklärung |
|---|---|
| `istAusgeliehen` | `true` wenn `ausgeliehenAn != nil` |
| `ausgeliehenAnVollname` | Kombiniert Vor- und Nachname zu einem String |

---

## 🏗️ Architektur & Datenspeicherung

```
┌─────────────────────────────────────────────┐
│                   App                        │
│                                             │
│  ContentView  ──→  BookDetailView           │
│       │                  │                  │
│       │            EditBookView             │
│       │                                     │
│  AddBookView ──→  ISBNScannerView           │
│       │                                     │
│       └──→  BookAPIService (Internet)       │
│                  (OpenLibrary / Google)     │
│                                             │
│  SettingsView ──→  BackupService            │
│                   (JSON Export/Import)      │
│                                             │
│  LocalizationManager (Sprache DE/EN)        │
│                                             │
├─────────────────────────────────────────────┤
│            SwiftData (lokale DB)            │
│          Book-Objekte auf dem Gerät         │
└─────────────────────────────────────────────┘
```

**Datenspeicherung:**
- Alle Bücher werden **lokal auf dem Gerät** in einer SwiftData-Datenbank gespeichert
- Es gibt **keinen eigenen Server** – die Daten verlassen das Gerät nur beim Backup-Export
- Cover-Bilder werden als **JPEG-Binärdaten** direkt im Datenbankeintrag gespeichert (kein separates Dateisystem)
- Die Spracheinstellung wird in **UserDefaults** gespeichert (der systemweite Schlüssel-Wert-Speicher von iOS)

---

*Entwickelt von Mathias Kyrian · Version 1.00*
