# Lokaler Testablauf

## Automatisch und ohne echte Dock-Schreibvorgänge

1. `./scripts/build.sh` ausführen. Das Ergebnis liegt unter `build/DockDivider.app`.
2. `./scripts/test.sh` ausführen; alle normalen Tests arbeiten im Speicher und in temporären Verzeichnissen.
3. Für Bundle-Integrationstests `DOCK_DIVIDER_TEST_LAUNCHER="$PWD/build/DockDivider.app/Contents/Resources/DividerLauncher" ./scripts/test.sh` ausführen.
4. `open -n "build/DockDivider.app" --args --demo` starten.
5. Alle fünf Stile hinzufügen, eigene Divider verschieben, speichern und entfernen. In der Demo wird das echte Dock nicht geschrieben oder neu gestartet.
6. Restore previous und Original-Restore in der Demo prüfen.

## Manueller Test im echten Dock

1. Die App ohne `--demo` starten. Die erste Ansicht liest nur die vorhandene Konfiguration.
2. Dock-Reihenfolge mit dem Original vergleichen. Finder ist implizit; nicht angeheftete laufende Apps und Recent Apps erscheinen nicht in dieser Vorschau.
3. Zunächst je einen Spacer und Small Spacer zwischen vorhandenen Apps hinzufügen und anwenden.
4. Prüfen, dass alle bestehenden Apps und Ordner erhalten sind.
5. System, Thin und Standard jeweils zusätzlich einfügen; Reihenfolge und unterschiedliche Stile prüfen.
6. Auf eine Linie klicken: Es sollte kein Fenster und keine bleibende aktivierte App erscheinen. Das tatsächliche Dock-Verhalten einschließlich eventueller kurzer Animationen prüfen.
7. Dock-Größe und Magnification verändern; Retina-Schärfe, Kontrast und Skalierung prüfen.
8. Light/Dark wechseln, während DockDivider geöffnet und die Vorschau gespeichert ist. Die App sollte die eigenen Linien aktualisieren. Bei deaktiviertem automatischem Neustart auf **Dock neu laden** klicken.
9. Dock links/rechts platzieren. Die eigenen Linien sollten horizontal gezeichnet werden.
10. Einen fremden Spacer beibehalten und **Alle DockDivider-Elemente entfernen** ausführen: Nur eigene Elemente dürfen verschwinden.
11. **Vorheriges Dock wiederherstellen** und **Ursprüngliches Dock wiederherstellen** testen. Dock-Position/Größe und Ordnerbereich dürfen durch diese Aktionen nicht zurückgesetzt werden.
12. Einen Entwurf bearbeiten und dann im echten Dock eine App verschieben. Anwenden muss mit einer Konfliktmeldung abbrechen; anschließend neu einlesen.

## Visueller Vergleich mit dem Apple-Separator

Eine pixelgenaue Übereinstimmung wurde nicht behauptet oder anhand eines Screenshots des echten Docks vermessen. Vergleiche die sichtbare Linie manuell bei gleicher Dock-Größe, Darstellung, Bildschirm-Skalierung und Magnification. Der vorhandene originale Separator befindet sich an der Abschnittsgrenze; je nach Dock-Konfiguration sind weitere Abschnittsgrenzen sichtbar.

Notiere Linienhöhe, Dicke, Kontrast und die reservierte Breite. `DividerStyle.swift` enthält die drei Renderparameter. Die reservierte Breite des App-Tiles lässt sich damit nicht verändern. Die App-Vorschau dient der Reihenfolge und Style-Auswahl und ist keine maßstabsgetreue Dock-Simulation.

## Verifikation dieses MVP

Siehe `Verification.md` für die tatsächlich auf diesem Entwicklungsrechner ausgeführten Prüfungen. Ein Test mit geschriebenen Einträgen im echten Dock ist ein separater manueller Schritt; die automatischen Tests verändern das echte Dock nicht.
