# Korbi – SwiftUI UI-Prototyp

Korbi ist ein reiner UI-Prototyp für iOS 17+. Alle Oberflächen, Navigationen und Zustandsflüsse sind mit SwiftUI umgesetzt. Die App verwendet ausschließlich Mock-Daten und Fake-Services – es gibt **kein Backend** und keine Persistenz.

## Features

- Designsystem mit Farb-Tokens, Typografie, Abständen und Komponenten (Button, Card, Banner, MicButton, Empty State, Section Header, ItemRow).
- Vier Haupt-Tabs: Home, Listen, Haushalt und Einstellungen.
- Home-Ansicht mit Banner-Status, prominenter Mic-Steuerung, Debug-Optionen und leeren Zuständen.
- Listen-Fluss inklusive Detailansicht mit Suche, Swipe-Aktionen, Collapsible-Bereich für „Gekauft“ und Undo-Banner (5 Sekunden).
- Haushalt mit Mitgliederliste und Einlade-Sheet (QR-Platzhalter).
- Einstellungen mit Theme-Auswahl (System/Hell/Dunkel) und Debug-Schaltern.
- Light/Dark Mode vollständig unterstützt, Dynamic Type optimiert.

## Debug-Helfer

In den Einstellungen gibt es eine Debug-Sektion:

- **Leeren Zustand simulieren** – toggelt den Home-Feed zwischen echten Mock-Daten und leerem Zustand.
- **Fehler-Banner zeigen** – löst im Home-Tab einen Fehler-Banner aus.
- **Ladezustand zeigen** – zeigt im Home-Tab einen Lade-/Info-Banner an.

Zusätzlich bietet die Home-Ansicht selbst eine Debug-Sektion mit denselben Aktionen.

## Architektur

- MVVM je Feature-Bereich.
- `CompositionRoot` erstellt Fake-Services (`HouseholdFakeService`, `ListsFakeService`, `ItemsFakeService`).
- Services simulieren Netzwerkverzögerungen (300–800 ms) und sind in-memory.
- `NotificationCenter` verbindet Debug-Optionen zwischen Einstellungen und Home.

## Fake Services austauschen

Die Services implementieren schlanke Protokolle (`HouseholdServicing`, `ListsServicing`, `ItemsServicing`). Um später echte Services anzubinden, tausche einfach die Implementierungen in `CompositionRoot` aus und halte die Protokoll-Verträge ein.

## Projektaufbau

```
Sources/
  App/
  DesignSystem/
  Features/
  Utils/
Assets.xcassets/
```

Das Projekt wurde für Xcode 15/16 und iOS 17+ ausgelegt. Alle Views besitzen SwiftUI-Previews in Deutsch (de-DE). Tests sind aktuell nur als Platzhalter-Ordner angelegt.

## Start

1. Projekt `Korbi.xcodeproj` in Xcode öffnen.
2. Schema `Korbi` auf einem iOS 17+ Gerät oder Simulator starten.
3. Keine zusätzliche Konfiguration notwendig.

Viel Spaß beim Erkunden des UI-Prototyps!
