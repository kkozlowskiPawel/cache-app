# Cache — aplikacja finansowa

Aplikacja do zarządzania budżetem: subskrypcje, transakcje, budżety, cele oszczędnościowe i rachunki. Inspirowana funkcjami Rocket Money, zbudowana od zera z natywnym wyglądem Apple.

## Stack

- **iOS:** SwiftUI (iOS 17+), Apple Charts, `supabase-swift`
- **Web:** Next.js 16 (App Router) + TypeScript + Tailwind v4 + Recharts + `@supabase/ssr`
- **Backend:** Supabase (Postgres + Auth + Realtime)

## Funkcje

- Logowanie / rejestracja / zmiana hasła / usunięcie konta
- Dashboard z wykresami i podsumowaniem miesiąca
- Transakcje (ręczne) — wydatki/przychody, kategorie, konta
- Subskrypcje cykliczne (tygodniowo/miesięcznie/kwartalnie/rocznie)
- Budżety na kategorię z paskami progresu
- Cele oszczędnościowe z ikonami i kolorami
- Rachunki z lokalnymi powiadomieniami (iOS)
- Konta finansowe z automatyczną aktualizacją salda po transakcjach
- **Synchronizacja iOS ↔ Web w czasie rzeczywistym** (Supabase Realtime)

## Struktura

```
Cache/
├── supabase/migrations/     # Schemat DB + RLS + triggery
├── ios/                     # Projekt Xcode (SwiftUI)
│   └── Cache/
└── web/                     # Next.js + Supabase SSR
```

## Uruchomienie

### Backend (Supabase)

1. Utwórz projekt na [supabase.com](https://supabase.com)
2. W SQL Editor uruchom kolejno migracje z `supabase/migrations/`:
   - `0001_init.sql`
   - `0002_account_balance_trigger.sql`
   - `0003_delete_account.sql`

### iOS

1. Otwórz `ios/Cache.xcodeproj` w Xcode 15+
2. W `ios/Cache/Services/Config.swift` wpisz swoje `supabaseURL` i `supabaseAnonKey`
3. Wybierz symulator iPhone 15 Pro Max (lub nowszy) → Cmd+R

### Web

```bash
cd web
cp .env.local.example .env.local   # uzupełnij URL i klucz
npm install
npm run dev
```

Otwórz [http://localhost:3000](http://localhost:3000).

## Licencja

MIT — kod własny, bez kopiowania zastrzeżonych elementów Rocket Money / Rocket Companies.
