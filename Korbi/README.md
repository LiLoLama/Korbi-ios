# Korbi

Korbi ist eine SwiftUI-Einkaufsliste für iOS 17+, die Supabase als Backend und n8n für Sprachaufnahmen nutzt. Die App setzt auf ein modernes, ruhiges Designsystem mit starker Accessibility, Realtime-Updates und zuverlässiger Audioverarbeitung.

## Inhalt

- [Features](#features)
- [Architektur](#architektur)
- [Voraussetzungen](#voraussetzungen)
- [Projektstruktur](#projektstruktur)
- [Setup](#setup)
  - [1. Supabase](#1-supabase)
  - [2. n8n-Workflow](#2-n8n-workflow)
  - [3. iOS-App](#3-ios-app)
- [Tests](#tests)
- [Bekannte Limitierungen](#bekannte-limitierungen)

## Features

- Authentifizierung via Supabase (E-Mail/Passwort, Sign in with Apple)
- Haushaltsverwaltung mit Rollen & QR-Einladungen (Deep Link `korbi://invite/<token>`)
- Mehrere Einkaufslisten, Realtime-Synchronisation, Swipe-Aktionen mit Undo
- Sprachaufnahme (AAC) → n8n Webhook → STT/LLM Parsing → Supabase Writeback
- Designsystem mit semantischen Tokens, Dark Mode, Dynamic Type, VoiceOver Labels
- Unit-, UI- und Snapshot-Tests (Light/Dark, Dynamic Type Large)

## Architektur

- SwiftUI, MVVM + Services (protocol-orientiert)
- Dependency Injection über `CompositionRoot`
- `SupabaseClient` für Datenzugriff, Realtime via `RealtimeService`
- `VoiceService` kapselt Audioaufnahme, HMAC-Signatur und Upload
- Design Tokens und Komponenten für konsistente UI

## Voraussetzungen

- Xcode 15.4+
- iOS 17 SDK
- Supabase-Projekt mit aktivierten Realtime-Features
- n8n-Instanz mit Zugriff auf OpenAI Whisper & LLM

## Projektstruktur

```
Korbi/
 ├─ Sources/
 │   ├─ App/               # App-Entry & Composition Root
 │   ├─ DesignSystem/      # Tokens, Komponenten, Color Assets
 │   ├─ Features/          # Auth, Home, Listen, Haushalt, Settings
 │   ├─ Models/            # Domain-Entities
 │   ├─ Services/          # Supabase, Voice, HMAC, Realtime, ...
 │   └─ Utils/
 ├─ Tests/
 │   ├─ UnitTests/
 │   ├─ UITests/
 │   └─ SnapshotTests/
 ├─ Configuration/         # Config.plist & Beispiel
 ├─ Supabase/              # SQL-Skripte (Schema, Policies, Seeds)
 └─ n8n/                   # Workflow-Export
```

## Setup

### 1. Supabase

1. Erstelle ein neues Supabase-Projekt.
2. Importiere die SQL-Skripte in Reihenfolge:
   ```sql
   \i Supabase/01_schema.sql;
   \i Supabase/02_policies.sql;
   \i Supabase/03_seed.sql;
   ```
3. Aktiviere Realtime für die Tabellen `public.lists` und `public.items` im Supabase Dashboard.
4. Deploye die Edge Function `create_invite` aus `Supabase/functions/create_invite/index.ts`:
   ```bash
   supabase functions deploy create_invite --project-ref <your-project-ref>
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service-role-key> --project-ref <your-project-ref>
   supabase secrets set SUPABASE_URL=<supabase-url> --project-ref <your-project-ref>
   ```
   Die Funktion prüft die Rolle (owner/admin) und gibt `token`, `expires_at`, `household_name` sowie `created_by_name` zurück – sie passt somit zur Verwendung in `HouseholdService.generateInvite`.
5. Notiere dir `SUPABASE_URL` und `anon` Key.

### 2. n8n-Workflow

1. Importiere `n8n/workflow-export.json` in deine n8n-Instanz.
2. Setze folgende Umgebungsvariablen:
   - `KORBI_HMAC_SECRET`: geteilter Schlüssel zwischen App und n8n
   - `SUPABASE_SERVICE_KEY`: Service Role Key für Schreibzugriff
   - `SUPABASE_URL`: Projekt-URL
3. Konfiguriere den Supabase-Node mit Service Role Key.
4. Hinterlege beim Webhook eine **signierte** URL (z. B. `https://n8n.example.com/webhook/korbi/voice`).
5. Der Workflow führt Whisper (Speech-to-Text), LLM-Parsing und Supabase-Insert aus und liefert JSON-Response an die App zurück.

### 3. iOS-App

1. Kopiere `Configuration/Config.example.plist` nach `Configuration/Config.plist` und trage deine Werte ein.
2. Öffne `Korbi.xcodeproj` in Xcode.
3. Stelle sicher, dass die Capabilities **Microphone**, **Camera** und **Keychain Sharing** aktiviert sind.
4. Starte das Projekt auf einem iOS 17-Gerät oder Simulator.

## Tests

- Unit Tests: `⌘U` oder `xcodebuild test -scheme Korbi -destination 'platform=iOS Simulator,name=iPhone 15'`
- Snapshot Tests: laufen innerhalb des SnapshotTargets (Referenzen werden beim ersten Run erzeugt)
- UI Tests erstellen Smoke-Flows (Login → Join → Add Item → Swipe → Undo) und generieren Screenshots (Light/Dark)

## Bekannte Limitierungen

- Keine Offline-Unterstützung oder Push-Benachrichtigungen
- Upload-Fehler werden nicht gepuffert, erneutes Senden erforderlich
- n8n-Workflow benötigt Whisper/LLM-Zugang (OpenAI/alternativ)
- iPad-Layout nicht optimiert
