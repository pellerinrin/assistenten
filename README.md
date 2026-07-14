# Assistenten 🖋

Din stillsamma sekreterare — en installerbar PWA som samlar hela vardagen på ett ställe. Appen **formar sig efter den som loggar in**: varje konto har en egen ägarprofil (namn + kort beskrivning) som vävs in i allt assistenten gör, så samma app kan vara en personlig assistent för flera olika människor — var och en med eget inlogg och egen data.

Kärnan för alla konton: **morgonbrief**, **bevakningar**, **sociala planer**, **ekonomi utan skäll** och **mejlöversikt**. Konton som dessutom använder systerapparna får mer av sig självt: Vardagskoll ger barnens schema, Skrivbordet ger karriärläge och jobbresor — finns ingen sådan data döljs de delarna tyst.

## Så hänger allt ihop

```
Skrivbordet (karriär, jobbresor)  ─┐   (valfritt per konto)
                                   ├─►  /api/assistent  ─►  Assistenten (den här appen)
Vardagskoll (barnens schema)      ─┘         ▲
                                             │
                    Morgonjobbet (Claude, schemalagt på en dator)
                    läser mejlen + skriver morgonbriefen (per konto)
```

- **Skrivbordet** (skrivbordet.vercel.app) äger databasen och API:t (Supabase-inloggning med e-post/lösenord).
- **Assistenten** loggar in med e-post och lösenord — nya användare skapar ett eget konto direkt i appen ("Skapa konto"). Samma konto gäller automatiskt i Skrivbordet och Vardagskoll, men inget av dem krävs. Alla API-anrop skickar `Authorization: Bearer <access_token>`; all data är strikt per konto.
- **Första inloggningen** frågar appen "Vem är du?" — namn och några rader fritext som sedan styr assistentens ton och kunskap (ändras när som helst under Mer → Om mig).
- **Morgonjobbet** är en schemalagd Claude-uppgift som läser kontots mejl och skriver dagens brief. Det sätts upp separat per person; utan morgonjobb står brief- och mejlkorten tomma men resten av appen fungerar fullt ut.

## Flikarna

- **Idag** — svarar på frågan *"vad behöver jag veta just nu?"*: hemifrån-listan i rätt ögonblick, morgonbrief, läget idag, pengaläget (kr/dag och buffert i dagar), en mjuk knuff när en social plan legat för länge, och chatten "Prata med mig" (text + röst; en riktig agent som kan öppna länkar, söka på webben, sköta bevakningar/planer/ekonomi och spara minnesanteckningar).
- **Bevaka** — bevakningar per livsområde (barn, jobb & karriär, vänner & socialt, hushåll & ekonomi, hälsa).
- **Planer** — appens privata minne av den sociala samordningen, som fortfarande sker i SMS/WhatsApp/Messenger. Klistra in ett chattutdrag → AI:n gör plankort med vem/vad/när, status och citatet sparat (aldrig mer scrolla tillbaka). Status: `nämnd → föreslagen → bekräftad → i kalendern` — det är mittenläget appen finns för att fånga. "Föreslå datum" ger färdig text att kopiera ("kan du fre 3/10 eller sön 5/10, typ 18?"), och en plan som legat i `nämnd` i tre veckor ger en vänlig knuff på Idag. Inga inbjudningar, ingen delning — fungerar även om ingen annan har appen.
- **Ekonomi** — fakturor/räkningar med förfallodatum, saldon, fakturafoton med automatisk avläsning, egen chatt. Plus **grunden**: golvlön (lägsta rimliga månadslön — allt över är överskott), lönedag och fasta utgifter ger en **dagsbudget** (kvar-till-lön ÷ dagar till lön) och en **buffert mätt i dagar**, inte kronor. "Oförutsedd utgift" räknar bara om — aldrig skäll, aldrig röda siffror. Efter lönedagen ställs en enda fråga: *"Du fick X över golvet — flytta Y till bufferten?"* Saldon fylls i för hand (ingen bankintegration — tio sekunder, och du vet var du står).
- **Mejl** — morgonjobbets sammanfattning av inkorgen.
- **Mer** — konto, Om mig (ägarprofilen), hemifrån-listor, notiser, "Lär känna mig"-intervjuerna, samtalshistorik.

## Dataformat (kv_store-nycklar på kontot)

- `assistent-brief` — `{ datum, halsning, punkter: [{emoji, rubrik, text}], skriven }`
- `assistent-poster` — `[{ id, omrade: barn|karriar|vanner|hushall|halsa, text, datum?, klar, skapad }]`
- `assistent-mejl` — `{ uppdaterad, viktiga, obesvarade, datumfynd, rakningar }`
- `assistent-vardagskoll` — skrivs av Vardagskoll (valfritt): `{ barn, barnDagar, middagar, aktiviteter, stad, inkopKvar, uppdaterad }`
- `assistent-ekonomi-poster` — `[{ id, typ: in|ut, beskrivning, belopp, forfallodatum, status, klarNar?, bilaga? }]` (`status: "klar"` = arkiverad för alltid)
- `assistent-ekonomi-saldon` — `[{ konto, belopp, uppdaterad }]` — kontot vars namn innehåller "buffert" räknas som bufferten, det första övriga som huvudkontot
- `assistent-bilaga-<postId>` — fakturafoton/PDF:er, komprimerade i webbläsaren; raderas när posten bockas av
- `assistent-profil` — `{ uppdaterad, text }` — assistentens egna anteckningar om ägaren; visas aldrig i gränssnittet
- `assistent-intervjuer` — `{ halsa|karriar|varderingar: { svar, utlatande?, uppdaterad }, appdata }`. **`appdata`** är appens eget kontoinnehåll (servern skickar bara tillbaka en fast uppsättning nycklar, så allt nytt bor i den här — den enda nyckel appen både läser och skriver i sin helhet):
  - `appdata.agare` — `{ namn, beskrivning }` — ägarprofilen som personaliserar alla AI-prompter
  - `appdata.planer` — `[{ id, vem, vad, status: namnd|foreslagen|bekraftad|kalender, datum?, plats?, oavklarat?, citat?, skapad, uppdaterad, klar?, klarNar? }]`
  - `appdata.ekonomi` — `{ golvlon, lonedag, fasta, lonKollad }` (`lonKollad` = "ÅÅÅÅ-MM" när månadens efter lön-fråga är avklarad)
  - `appdata.hemifran` — `[{ id, namn, saker, dagar: [0–6], nar: morgon|dag|kvall|alltid }]`
- `assistent-samtal-ÅÅÅÅ-MM` — samtalsloggen per månad `[{ id, t, roll: jag|ass, kanal: prata|ekonomi, text }]`

Chattarna skickar `POST { ai: { system, messages, tools/tool } }` (med Bearer-token) till samma API; servern vidarebefordrar till Anthropic och räknar mot kontots dagliga AI-tak. Samma väg används för fakturaavläsning och för att läsa av inklistrade chattutdrag i Planer.

## Köra lokalt

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1
```

Öppna sedan `http://localhost:8672/`.

## Installera på telefonen

- **iPhone/Safari:** öppna sidan → tryck **Dela** → **"Lägg till på hemskärmen"**
- **Android/Chrome:** menyn ⋮ → **"Lägg till på startskärmen"**

## Teknik

Ren HTML/CSS/JavaScript utan byggverktyg. `sw.js` cachar appen för offline-bruk (nätet först, cachen som reserv). Notiser skickas lokalt när appen är öppen — bäst stöd på Android/Chrome.
