# Dock-Mechanismen und Rendering

## Untersuchte Möglichkeiten

| Mechanismus | Ergebnis / Verwendung |
| --- | --- |
| `persistent-apps` | Bearbeitbarer angehefteter App-Bereich. Unbekannte Einträge werden unverändert erhalten. |
| `persistent-others` | Ordner-/Dokumentenbereich. Wird vollständig im Backup gespeichert, aber niemals geschrieben. |
| `spacer-tile` | Echter leerer Dock-Tile; im MVP implementiert. |
| `small-spacer-tile` | Echter kleiner leerer Dock-Tile; im MVP implementiert. |
| Originaler Separator | Kein veröffentlichter Tile-Typ und keine öffentliche Einfüge-API gefunden. Er ist eine vom Dock verwaltete Abschnittsgrenze. |
| `NSDockTile.contentView` | Zeichnet den Inhalt eines App-/Fenster-Tiles; erzeugt keinen zusätzlichen strukturellen Separator. |
| `NSDockTile.size` | Schreibgeschützt. Icongröße, Transparenz oder Inset verkleinern die reservierte Dock-Tile-Breite nicht. |
| `NSDockTilePlugIn` | Öffentliches älteres Plug-in-Verfahren für nicht laufende Apps. Wird in einem Systemprozess geladen; für dieses Projekt unnötig und bewusst nicht verwendet. Es löst die Breitenbeschränkung ohnehin nicht. |
| Accessory-/Agent-App | Verhindert normale aktive App-UI. Keine Möglichkeit, damit einen unabhängig schmalen Tile zu erzeugen. |

Auf dem Entwicklungssystem (macOS 27.0.1, Apple-Silicon, SDK 27) wurden die Strings `spacer-tile`, `small-spacer-tile` und `flex-spacer-tile` in der vorhandenen Dock-Binary lesend gefunden. `separator-tile` und `divider-tile` wurden bei dieser String-Prüfung nicht gefunden. Das ist ein unterstützender lokaler Befund, keine vollständige Aussage über Apples interne Implementierung. Es wurden keine experimentellen Tile-Typen in das echte Dock geschrieben.

## Gewähltes Rendering

Der `System`-Stil zeichnet eine mittig platzierte Linie mit Höhe `0.82 × Icongröße`, Dicke `1/64 × Icongröße` und Alpha `0.23`. Die Farbe ist Schwarz im Light Mode und Weiß im Dark Mode. Thin verwendet `0.64` Höhe und `0.75/64` Dicke, Standard `0.82` Höhe und `2/64` Dicke bei höherem Alpha.

Diese Maße sind bewusst justierbare Näherungen und **keine vermessenen Apple-Originalmaße**. Die zentralen Werte stehen in `Models/DividerStyle.swift`. Es wurden keine Bilddaten oder Assets von Apple extrahiert.

Das Rendering verwendet CoreGraphics und ImageIO mit transparentem premultiplied Alpha. ICNS enthält 16, 32, 64, 128, 256, 512 und 1024 Pixel sowie Retina-Slots. Das Dock skaliert diese normalen Icon-Repräsentationen proportional zur eigenen Größe. Magnification betrifft den ganzen Tile: das Verhalten entspricht daher nicht exakt dem strukturellen Apple-Separator.

Bei einem Dock links/rechts dreht die Grafik die Linie horizontal; so trennt sie benachbarte Einträge auf der vertikalen Dock-Achse. Die Orientierung wird alle fünf Sekunden nachgelesen. In der Editor-Vorschau bleibt die Reihenfolge horizontal dargestellt.

Die Haupt-App reagiert auf SwiftUIs Farbschema. Für Light/Dark und Dock-Ausrichtung werden getrennte unveränderliche, lokal signierte Bundles angelegt. Neue Pfade sorgen dafür, dass das Dock frische Icons laden kann; es werden weder globale Icon-Caches gelöscht noch Systemdateien geändert. Solange ein Entwurf ungespeichert ist, werden automatische Dock-Schreibvorgänge zurückgestellt. Die Darstellungsanpassung aktualisiert ausschließlich bereits vorhandene eigene Linien.

### Transparenz unter macOS Tahoe und neuer

Ein transparentes ICNS allein genügt auf diesen Versionen nicht: Das System kann nicht konforme App-Icons auf eine graue abgerundete Fläche setzen. Die Version v2 verwendet deshalb zusätzlich ein normales Finder-Datei-Icon, gesetzt über die öffentliche API `NSWorkspace.setIcon(_:forFile:options:)`. Das System liefert so die Linie mit transparenten umgebenden Pixeln. Light-/Dark-Varianten werden weiterhin durch die Haupt-App gewechselt; Apples automatische Clear-/Tinted-Aufbereitung kommt bei benutzerdefinierten Icons nicht zum Einsatz.

Der Helper wird vor dem Setzen des Datei-Icons signiert und streng verifiziert. Anschließend fügt Finder seine üblichen Custom-Icon-Metadaten hinzu. Eine normale `codesign --verify`-Prüfung einschließlich versiegelter Ressourcen besteht weiterhin; `--strict` lehnt die zusätzlichen Finder-Metadaten ab. Die Haupt-App selbst hat keine solchen Metadaten und wird weiterhin streng verifiziert. Es werden weder Signaturen ignoriert noch Icon-Caches gelöscht.

Version und Darstellung sind Bestandteil des unveränderlichen Bundle-Pfads. Alte Registry-Datensätze ohne Versionsfeld werden als v1 gelesen, damit auch deren Ownership erhalten bleibt. Der nächste automatische Darstellungsabgleich ersetzt ausschließlich eigene v1-Tiles durch v2-Pfade. Alte Helper bleiben für Backups verfügbar.

## Helper und Klickverhalten

Die App bettet ein kompiliertes kleines Swift-Programm ein. Zur Laufzeit werden Info.plist und ICNS erzeugt und dieses Programm in die verwalteten `.app`-Bundles kopiert. Auf dem Nutzerrechner ist dafür kein Swift-Compiler nötig; `/usr/bin/codesign` signiert und prüft die erzeugten Bundles ad hoc.

`LSUIElement` und `LSBackgroundOnly` sind gesetzt. Der Mach-O-Helper ruft kein `NSApplication` auf, erstellt kein Fenster und beendet sich sofort erfolgreich. Sein sichtbarer Name ist ein Zero-Width-Space. Das minimiert UI, aktiviert keine Menüleiste und erzeugt keine normale dauerhaft laufende App. Ob das Dock trotzdem kurz eine Launch-Animation, ein Hover-Label, einen Fehler bei der Launch-Services-Verarbeitung oder ein Kontextmenü zeigt, kontrolliert macOS. Eine vollständige Garantie für unsichtbare Interaktion gibt es über öffentliche APIs nicht.

## Schutz des Docks

1. Snapshot der Preference-Domain lesen; fehlendes/falsches `persistent-apps` bedeutet Abbruch.
2. Alle bestehenden fremden Tiles samt beliebigen Feldern erhalten; nur eigene Divider sind verschiebbar/entfernbar.
3. Bundles zuerst fertig erzeugen und Ownership vor dem Preference-Schreiben dauerhaft speichern.
4. Neue Konfiguration als Property List validieren.
5. Aktuelle `persistent-apps` gegen den geladenen Snapshot vergleichen.
6. Vollständige Domain atomar in eine eindeutige Backup-Datei schreiben und zurücklesen.
7. Direkt vor dem Schreiben erneut auf parallele Änderungen prüfen.
8. Ausschließlich `persistent-apps` über `CFPreferencesSetValue` setzen und synchronisieren.
9. Gespeichertes Array zurücklesen und verifizieren; erst danach bei aktivierter Option Dock neu starten.

CFPreferences bietet kein atomisches Compare-and-Swap mit dem Dock-Prozess. Ein kleiner Konkurrenzzeitraum zwischen letzter Prüfung und Setzen bleibt systembedingt bestehen. Während des Anwendens daher nicht gleichzeitig im echten Dock umsortieren. Erkannte Konflikte werden niemals automatisch übergangen; bei unbestätigtem Schreiben erfolgt kein blinder Rollback, der möglicherweise neuere fremde Änderungen verlieren würde. Vollständige Backups bleiben verfügbar.

Bei Spacern ist die eigene im Manifest gespeicherte GUID plus exakter Tile-Typ ausschlaggebend; GUIDs werden gegen alle vorhandenen und historischen IDs geprüft. Individuelle Metadaten werden zusätzlich geschrieben, aber Dock kann sie beim Normalisieren entfernen. Linien benötigen zusätzlich den passenden Bundle-Pfad, die UUID im Info.plist und die eigene Bundle-ID. Ein fehlendes oder beschädigtes Manifest führt nicht zu einer pauschalen Entfernung fremder Tiles.

Historische Bundle-Varianten bleiben bestehen, damit Backups weiterhin funktionieren. Die App bereinigt weder andere Apps noch deren Dateien.

## Primärquellen

- [Apple: NSDockTile](https://developer.apple.com/documentation/appkit/nsdocktile)
- [Apple: NSDockTile.size](https://developer.apple.com/documentation/appkit/nsdocktile/size)
- [Apple: NSDockTile.contentView](https://developer.apple.com/documentation/appkit/nsdocktile/contentview)
- [Apple: NSDockTilePlugIn](https://developer.apple.com/documentation/appkit/nsdocktileplugin)
- [Apple: NSWorkspace.setIcon](https://developer.apple.com/documentation/appkit/nsworkspace/seticon(_:forfile:options:))
- [IconChanger: dokumentierter Custom-Icon-Ansatz gegen graue Tahoe-Flächen](https://app.snaix.homes/iconchanger/docs/changing-icons/#escape-squircle-jail-macos-tahoe)
- [Apple: Launch Services Keys / LSUIElement / LSBackgroundOnly](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html)
- [Apple: CFPreferencesSetValue](https://developer.apple.com/documentation/corefoundation/cfpreferencessetvalue(_:_:_:_:_:))
- [dockutil: Quellprojekt und Spacer-Beispiele](https://github.com/kcrawford/dockutil)
- [Blackspace: Quellprojekt mit spacer-tile / small-spacer-tile](https://github.com/peterp/Blackspace)

Zusätzlich gelesen: `NSDockTile.h` und `CFPreferences.h` aus dem lokal installierten macOS-SDK. Es wurde kein Fremdcode übernommen.
