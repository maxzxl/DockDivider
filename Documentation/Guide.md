# DockDivider · macOS MVP

Native SwiftUI-/AppKit-App für macOS 14 oder neuer. Der vollständige ausführbare Swift-Code liegt in `DockDividerApp/` und `DividerLauncher/`. Keine externen Pakete.

Alle Swift-Dateien einschließlich Tests sind zusätzlich in [SwiftSource.md](SwiftSource.md) vollständig abgedruckt.

## Sprache und App-Icon

Die App heißt **DockDivider**. Oberfläche, Dialoge, Tooltips, Status- und eigene Fehlermeldungen sind auf Deutsch und Englisch lokalisiert. Die Auswahl folgt der macOS-Systemsprache bzw. der Sprache pro App in **Systemeinstellungen → Allgemein → Sprache & Region**. Der Info-Button neben **Aktuelles Dock / Current Dock** erklärt „Im Dock behalten / Keep in Dock“ und vorübergehend laufende Apps. Der Hinweis erscheint beim Hover und per Klick als Popover.

`Resources/AppIcon.icon` enthält drei getrennte, transparente 1024-px-Ebenen (Dock, App-Tiles, Divider), Glas-Materialparameter und eine dunkle Hintergrundvariante. Das Xcode-Projekt bindet die Datei als Icon Composer App-Icon ein. Apples aktuelles Icon-Composer-Format ist für Liquid Glass auf iOS/iPadOS/macOS geeignet: [Apple Icon Composer](https://developer.apple.com/icon-composer/). DockDivider bleibt eine macOS-App.

Das lokale Buildskript verwendet bei vollständigem Xcode `actool` für das native mehrschichtige Icon. Mit den hier installierten Command Line Tools verpackt es das hochwertige `DockDivider.icns` als statische Version desselben Designs, inklusive Retina-Repräsentationen. Die native Materialdarstellung kann hier ohne vollständiges Xcode nicht kompiliert oder geprüft werden. `swift scripts/GenerateAppIcon.swift` erzeugt die eigenen geometrischen Assets reproduzierbar neu.

Englische Demo ohne dauerhafte Spracheinstellung:

```sh
open -n build/DockDivider.app --args --demo -AppleLanguages '(en)'
```

## Technische Entscheidung

Apple veröffentlicht keine API zum Einfügen der originalen Dock-Trennlinie zwischen beliebigen App-Tiles. `NSDockTile.contentView` erlaubt eigenes Zeichnen, aber `NSDockTile.size` ist schreibgeschützt. Ein transparentes Icon ändert die vom Dock reservierte Tile-Breite nicht. Deshalb erzeugt die App sichtbare Linien als vollständig verwaltete, minimalistische Helper-Bundles. Für reine Abstände verwendet sie `spacer-tile` und `small-spacer-tile`.

`System / Apple Dock Divider` ist die Standardauswahl. Die Grafik besitzt eine dezente einzelne Linie, transparenten Hintergrund und Retina-Repräsentationen. Sie ist eine visuelle Annäherung, kein echter Apple-Systemseparator. Diese Grenze steht auch direkt in der Oberfläche.

Die Helper erhalten zusätzlich über Apples `NSWorkspace.setIcon` ein benutzerdefiniertes Datei-Icon. Das verhindert die graue Icon-Fläche, die macOS seit Tahoe um ältere App-Icons zeichnen kann. Vorhandene v1-Divider werden beim Start automatisch auf transparente v2-Varianten umgestellt; ihre IDs und Positionen bleiben erhalten. Dafür werden wie bei anderen Änderungen Backups erstellt. Bei ausgeschaltetem automatischem Dock-Neuladen danach **Dock neu laden** verwenden.

Die öffentlichen CoreFoundation-APIs lesen und schreiben die Preference-Domain `com.apple.dock`; das Schema dieser Dock-Preferences und die Spacer-Typen sind **nicht öffentlich von Apple garantiert**. Es werden keine privaten APIs aufgerufen, keine Dock-Plug-ins geladen und keine Prozessmanipulationen durchgeführt.

Details und Quellen: [Technischer Ansatz](TechnicalNotes.md).

## Lokal starten

Voraussetzung: Xcode oder passende Apple Command Line Tools mit Swift 6 oder neuer und macOS-SDK. Bei Bedarf einmal `xcode-select --install` ausführen. Der App-Code verwendet den kompatiblen Swift-5-Sprachmodus; die Tests verwenden Swift Testing.

```sh
cd /Users/max/Projects/DockDivider
./scripts/build.sh
open "build/DockDivider.app"
```

Für einen Release-Build: `./scripts/build.sh release`. Das Skript baut beide Programme, bettet den Launcher ein und signiert lokal ad hoc. `swift run DockDivider` alleine enthält den Launcher nicht und eignet sich deshalb nicht zum Anwenden sichtbarer Linien.

Eine vollständig isolierte Demo verwendet nur eine Konfiguration im Speicher:

```sh
open -n "build/DockDivider.app" --args --demo
```

Die Demo erstellt ihre Helper und Backups in einem eigenen temporären Ordner. Sie schreibt niemals `com.apple.dock` und startet das echte Dock nicht neu.

Die Demo mit **⌘Q** beenden, bevor die App ohne `--demo` für das echte Dock geöffnet wird.

## Xcode

1. `DockDivider.xcodeproj` öffnen, **nicht** erst ein neues Projekt erstellen.
2. Das geteilte Scheme **DockDivider** und als Ziel **My Mac** auswählen.
3. **Product → Build** oder **⌘B**, danach **Product → Run** / **⌘R**.
4. Das Target `DividerLauncher` wird als Abhängigkeit gebaut und über **Embed DividerLauncher** nach `Contents/Resources` kopiert.
5. Das Projekt ist für lokale ad-hoc-Signierung eingerichtet. Unter **Signing & Capabilities** ist App Sandbox ausgeschaltet; für lokale Tests ist kein Apple-Developer-Team nötig.
6. Optional: **Product → Scheme → Edit Scheme → Run → Arguments** und `--demo` als Startargument hinzufügen.
7. Für Distribution die Signierung auf ein eigenes Developer-ID-Team umstellen. Automatisch erzeugte Helper werden im MVP ad hoc signiert; Notarisierung und eine veröffentlichungsfähige Helper-Strategie sind zusätzliche Release-Arbeit.

Die automatisierten Sicherheitstests sind ein SwiftPM-Testtarget und werden über das Terminal ausgeführt. Das Xcode-Scheme enthält kein separates Testtarget.

## Bedienung

Der App-Bereich zeigt die gespeicherte Dock-Reihenfolge. Finder wird als impliziter, unveränderlicher erster Eintrag ergänzt, sofern er nicht in den Preferences steht. Laufende, nicht angeheftete Apps, Recent Apps, minimierte Fenster und der Bereich für Ordner/Papierkorb sind keine bearbeitbaren Einträge dieser Vorschau.

1. Gewünschten Stil auswählen.
2. Mit **+** oder per Kontextmenü an der passenden Stelle einfügen.
3. Weitere Divider, auch mit anderen Stilen, hinzufügen.
4. Eigene Divider per Pfeiltasten in der Vorschau oder per Drag & Drop auf eine Einfügestelle verschieben. Das Entfernen erfolgt mit **×** oder im Kontextmenü.
5. **Änderungen anwenden**. Erst jetzt wird die Dock-Konfiguration geschrieben.
6. Bei ausgeschaltetem automatischem Neustart den Button **Dock neu laden** verwenden.

Der Style-Picker bestimmt neue Divider. Zum Ändern des Stils eines vorhandenen Dividers diesen entfernen und an derselben Stelle neu hinzufügen.

## Sicherheit und Wiederherstellung

Vor jedem tatsächlichen Dock-Schreibvorgang erstellt die App eine verifizierte vollständige Kopie der Domain. Bei ungültigen Daten, Backup-Fehlern, verwalteten Dock-Preferences oder erkannten parallelen Dock-Änderungen bricht sie ab.

Normalerweise wird ausschließlich der Key `persistent-apps` geschrieben. Bestehende fremde Tiles müssen exakt und in derselben Reihenfolge erhalten bleiben. Unbekannte Preference-Keys und Tile-Felder bleiben erhalten; `persistent-others` wird niemals geschrieben.

Unter **Wiederherstellung**:

- **Vorheriges Dock wiederherstellen**: App-Bereich unmittelbar vor dem letzten erfolgreichen Schreibversuch. Die Wiederherstellung erstellt wiederum ein Backup; damit ist auch diese Aktion rückgängig machbar.
- **Ursprüngliches Dock wiederherstellen**: App-Bereich vor dem ersten tatsächlichen Schreibvorgang. Dieses Backup wird nie automatisch ersetzt.
- **Alle DockDivider-Elemente entfernen**: entfernt nur registrierte eigene Tiles aus dem aktuellen App-Bereich. Fremde Spacer werden erhalten.
- **Backups im Finder öffnen**: zeigt die vollständigen archivierten Plists.

Restore stellt absichtlich nur den gespeicherten App-Bereich wieder her. Zwischenzeitlich geänderte Dock-Größe, Position und Ordner werden dadurch nicht zurückgesetzt. Bei einer Restore-Aktion kann sich die App-Liste auf einen älteren Zustand zurückändern; die Oberfläche weist darauf hin.

Speicherort:

```text
~/Library/Application Support/DockDividerApp/
├── dividers.json                 # IDs, GUIDs, Stile, zuletzt angewendete Positionen
├── Dividers/<UUID>/*.app         # unveränderliche Darstellungsvarianten
└── Backups/
    ├── original.plist
    ├── previous.plist
    └── <Zeitstempel>-<UUID>.plist
```

Die App löscht historische Helper und Ownership-Datensätze nicht automatisch: ältere Backups können noch auf sie verweisen. Den Support-Ordner erst löschen, nachdem eigene Divider aus dem Dock entfernt sind und die Backups nicht mehr gebraucht werden. Bei fehlender Ownership-Datei werden unbekannte vorhandene Spacer nicht pauschal entfernt.

## Entitlements und Permissions

- **App Sandbox muss ausgeschaltet sein**, weil eine fremde Preference-Domain geschrieben und Helper außerhalb eines Containers erzeugt werden.
- Keine Administratorrechte, kein `sudo`, keine Accessibility-, Automation-, Bildschirmaufnahme- oder Full-Disk-Access-Berechtigung erforderlich.
- Der Haupt-App werden keine zusätzlichen Entitlements gegeben. Die Helper haben `LSUIElement = true` und `LSBackgroundOnly = true` und beenden sich sofort, ohne AppKit zu initialisieren.
- Der Dock-Neustart verwendet `/usr/bin/killall -u <aktueller Nutzer> Dock`, betrifft ausschließlich diesen Benutzer und erfolgt nur auf Anforderung bzw. nach aktivierter automatischer Aktualisierung.
- Gesperrte MDM-Preferences werden erkannt. Diese App ist mit diesem Ansatz für lokale Nutzung bzw. direkte Distribution konzipiert; sie ist kein vorbereitetes Mac-App-Store-Projekt.

## Testen

```sh
./scripts/test.sh
```

Die Tests verwenden temporäre Backups und eine Preference-Implementierung im Speicher. Sie prüfen das Erhalten unbekannter Daten und fremder Spacer, Ownership, parallele Änderungen, Backup-Fehler, Restore, verwaltete Preferences und transparente Icons in allen Dock-Ausrichtungen.

Für zusätzliche Tests der echten Helper-Bundle-Erzeugung:

```sh
./scripts/build.sh
DOCK_DIVIDER_TEST_LAUNCHER="$PWD/build/DockDivider.app/Contents/Resources/DividerLauncher" ./scripts/test.sh
```

Optional zusätzlich das echte Dock **nur lesend** prüfen: `DOCK_DIVIDER_TEST_SYSTEM_READ=1 ./scripts/test.sh`.

Ein manueller Testablauf einschließlich der Grenzen des visuellen Vergleichs steht in [LocalTesting.md](LocalTesting.md).

## Projektstruktur

```text
DockDividerApp/
├── DockDividerApp.swift
├── Models/         # DockItem, DockSnapshot, DividerStyle, DividerRecord
├── Services/       # Lesen, Validierung, Schreiben, Backups, Registry, Bundles, Rendering
├── Views/          # native Oberfläche, Vorschau, Einstellungen
└── Utilities/      # Pfade, Plist-Verarbeitung, Fehler, Prozessaufrufe
DividerLauncher/    # UI-loser Mach-O-Helper
Tests/             # Dock-Sicherheits- und Rendering-Tests
Resources/         # Info.plist
scripts/           # lokaler App-Build
DockDivider.xcodeproj/
Package.swift
```
