# Assistenten 🖋

Din stillsamma sekreterare — en installerbar PWA som samlar hela vardagen på ett ställe: barnen, karriären, hushållet och hälsan. Varje morgon lämnar den en **morgonbrief** över dagen, håller **bevakningar** på saker med och utan datum, och sammanfattar **mejlen**.

## Så hänger allt ihop

```
Skrivbordet (karriär, jobbresor)  ─┐
                                   ├─►  /api/assistent  ─►  Assistenten (den här appen)
Vardagskoll (barnens schema)      ─┘         ▲
                                             │
                    Morgonjobbet (Claude, schemalagt på datorn)
                    läser mejlen + skriver morgonbriefen
```

- **Skrivbordet** (skrivbordet.vercel.app) äger kontot och databasen. Under *Profil* skapas en **assistentkod** (XXXX-XXXX).
- **Assistenten** (den här appen) kopplas med koden under *Mer* och läser/skriver via `https://skrivbordet.vercel.app/api/assistent`.
- **Vardagskoll** kopplas med samma kod under *Mer* och skickar upp barnens schema (vilka dagar barnen är hos dig, gympadagar, matplan, städschema).
- **Morgonjobbet** är en schemalagd Claude-uppgift på datorn som varje morgon läser mejlen, hämtar läget via API:t och skriver dagens brief.

Koden ger tillgång till assistentens egna nycklar plus läskopior av jobbresor och karriärmål — aldrig profil, ämnen eller något annat på kontot (se `api/assistent.js` i skrivbordet-repot).

## Dataformat (kv_store-nycklar på kontot)

- `assistent-brief` — `{ datum, halsning, punkter: [{emoji, rubrik, text}], skriven }`
- `assistent-poster` — `[{ id, omrade: barn|karriar|hushall|halsa, text, datum?, klar, skapad }]`
- `assistent-mejl` — `{ uppdaterad, viktiga: [{fran, amne, sammanfattning}], obesvarade: [{fran, amne, dagar}], datumfynd: [{datum, text}] }`
- `assistent-vardagskoll` — skrivs av Vardagskoll: `{ barn, barnDagar, middagar, aktiviteter, stad, inkopKvar, uppdaterad }`

## Köra lokalt

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1
```

Öppna sedan `http://localhost:8672/`.

## Installera på telefonen

- **iPhone/Safari:** öppna sidan → tryck **Dela** → **"Lägg till på hemskärmen"**
- **Android/Chrome:** menyn ⋮ → **"Lägg till på startskärmen"**

## Teknik

Ren HTML/CSS/JavaScript utan byggverktyg, samma anda som Vardagskoll. `sw.js` cachar appen för offline-bruk (nätet först, cachen som reserv). Notiser skickas lokalt när appen är öppen — bäst stöd på Android/Chrome.
