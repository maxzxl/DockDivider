# Ausgeführte Verifikation

Stand: 8. Oktober 2026.

## Umgebung

- macOS 27.0.1, Apple-Silicon (arm64).
- Apple Command Line Tools, Swift 6.4, macOS-SDK 27.
- Deployment Target: macOS 14.0.
- Kein vollständiges Xcode auf diesem Rechner installiert.

## Bestanden

- Debug-Build des SwiftUI-/AppKit-Programms und Launchers.
- Release-Build einschließlich dSYM-Erzeugung.
- Verpacken einer eigenständigen App mit eingebettetem Launcher.
- Ad-hoc-Signierung und `codesign --verify --strict` des App-Bundles.
- Syntaxprüfung von Xcode `project.pbxproj` und Info.plist mit `plutil`.
- **19 Tests in vier Swift-Testing-Suites, keine Fehler.**
- UI-Start im isolierten Demo-Modus, visuelle Prüfung der nativen Oberfläche im Dark Mode.
- Small Spacer in der Demo eingefügt, per Pfeil verschoben und angewendet; gespeicherte Reihenfolge in der Oberfläche bestätigt.

Die Tests decken den Erhalt vorhandener Einträge und unbekannter Felder, fremde Spacer, Ownership, Konflikte vor dem Schreiben sowie während des Backups, Backup-Fehler, gesperrte Preferences, ungültige Plists, No-op-Schreibvorgänge, Persistenz und Restore ab. Sie prüfen transparente Retina-Icons und die Orientierung für unten/links/rechts.

Die Helper-Integrationstests erzeugen alle drei Linien-Stile im temporären Verzeichnis, prüfen Signaturen und ICNS, führen die Launcher erfolgreich aus und prüfen das Wiedererkennen einer tatsächlichen Bundle-Darstellung nach abweichendem Manifestzustand. Light-/Dark-Varianten bleiben unter unterschiedlichen Pfaden erhalten.

Der optionale Systemtest liest die echte Domain über dieselbe CFPreferences-Implementierung wie die App und prüft, dass die Vorschau alle gespeicherten App-Einträge exakt erhält. Er setzt keine Preference-Werte.

Die Transparenzkorrektur wurde zusätzlich mit einer Kopie eines vorhandenen Divider-Bundles geprüft. Die neuen Integrationstests lesen das von `NSWorkspace.icon(forFile:)` gelieferte System-Icon, rendern es auf einen leeren RGBA-Bitmap und prüfen transparente Pixel außerhalb der Linie sowie weniger als 10 % belegte Fläche. Sie prüfen außerdem das Lesen alter v1-Datensätze, Ownership beider Versionen, getrennte Bundle-Pfade und bestehende Ressourcen-Signaturen nach dem Setzen des Datei-Icons.

Zusätzlich wurde der Build auf **DockDivider.app** umgestellt und die neue Icon-Ressource sowie die SwiftPM- und nativen Sprachressourcen in das signierte Bundle aufgenommen. Der deutsche Live-App-Start bestätigte Namen, Icon und Info-Popover. Ein separater englischer Demo-Start mit `-AppleLanguages '(en)'` bestätigte alle sichtbaren Beschriftungen, Status, Info-Popover, Accessibility-Texte und das Wiederherstellungsmenü. Zwei Lokalisierungstests prüfen identische, nicht leere Sprachschlüssel, kompatible Format-Platzhalter und die erklärten Dock-Regeln.

## Grenzen der Verifikation

- Es wurden **keine Divider in das echte Dock geschrieben** und kein Dock-Neustart als Teil der Tests ausgeführt.
- Die Darstellung der Helper im echten Dock, der komplette Launch-Services-Klickpfad und das tatsächliche Hover-/Bounce-Verhalten sind noch manuell zu prüfen.
- Die Apple-Originaltrennlinie wurde nicht pixelgenau vermessen. Die Renderparameter sind eine dokumentierte Annäherung.
- Light-Mode-UI und automatische Anpassung im echten Dock wurden nicht interaktiv geprüft.
- Die eingebundene mehrschichtige Icon-Composer-Datei ist für den nativen Liquid-Glass-Build vorbereitet; ohne vollständiges Xcode konnte diese Kompilierung nicht geprüft werden. Der lokale Build und die visuelle Prüfung verwenden das ICNS-Icon.
- Das Xcode-Projekt wurde syntaktisch geprüft; ein `xcodebuild` mit vollständigem Xcode war auf diesem Rechner nicht möglich.
- Das Deployment Target erlaubt macOS 14+, ausgeführt wurden die Tests ausschließlich auf der oben genannten Version und Architektur.

## Reproduzieren

```sh
./scripts/build.sh
DOCK_DIVIDER_TEST_SYSTEM_READ=1 \
DOCK_DIVIDER_TEST_LAUNCHER="$PWD/build/DockDivider.app/Contents/Resources/DividerLauncher" \
./scripts/test.sh
./scripts/build.sh release
```

Innerhalb der eingeschränkten Coding-Agent-Umgebung wurde für SwiftPM-Tests zusätzlich `--disable-sandbox` benötigt, um eine verschachtelte Build-Sandbox zu vermeiden. Das betrifft ausschließlich den Buildprozess; es schaltet keine macOS-Schutzfunktion aus und ist auf einem normalen Terminal nicht nötig. Apples `dsymutil` und Launch Services benötigten außerdem Ausführung außerhalb dieser Agent-Sandbox. Die eigentliche Anwendung benötigt weder administrative Berechtigungen noch Sandbox-Umgehungen.

Die lokalen Command Line Tools geben beim Linken Warnungen zu nicht existierenden zusätzlichen `Developer/usr/lib`- und `Developer/Library/Frameworks`-Suchpfaden aus. Die tatsächlich verwendeten Frameworks wurden gefunden; Build, Signaturprüfung und Tests liefen erfolgreich.

## UI polish and compact README

The content and action areas are centered with a maximum width of 860 pt. The five styles are shown as two-column cards with a visible selection mark; appearance options have a separate subtle surface. The Debug build was checked interactively at normal size (1232 x 820 pt) and zoomed size (1728 x 1006 pt). Selecting Thin Divider and then System updated the selected card and insertion tooltips correctly without applying Dock changes. The action bar stayed visible when scrolling.

The English README includes the logo and title, a short overview, features, two local SVG placeholders for app and Dock screenshots, and build/demo instructions. All linked local files and the SVG syntax were verified. The former README is preserved in Guide.md. The generated Swift cache was rebuilt after the project folder was renamed. No new unit tests were added for this presentation change.
