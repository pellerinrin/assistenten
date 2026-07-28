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

- **Skrivbordet** (skrivbordet.vercel.app) äger kontot och databasen (Supabase-inloggning med e-post/lösenord).
- **Assistenten** (den här appen) och **Vardagskoll** loggar in med **samma e-post och lösenord** — ett gemensamt medlemskap, ingen kod att klistra in. Alla API-anrop skickar `Authorization: Bearer <access_token>`. Assistenten och Vardagskoll ligger på samma GitHub Pages-ursprung, så en inloggning i den ena gäller automatiskt i den andra också.
- **Vardagskoll** skickar upp barnens schema (vilka dagar barnen är hos dig, gympadagar, matplan, städschema).
- **Morgonjobbet** är en schemalagd Claude-uppgift på datorn som varje morgon läser mejlen, hämtar läget via API:t och skriver dagens brief. Det körs oberoende av Anna och använder en äldre, kvarhållen **assistentkod**-väg i `api/assistent.js`/`api/delat.js` (en scopead kod passar bättre för ett obemannat skript än att lagra det riktiga lösenordet).

Bearer-token identifierar direkt vem det är; assistentens egna nycklar plus läskopior av jobbresor och karriärmål är allt som går att nå den här vägen — aldrig profil, ämnen eller något annat på kontot (se `api/assistent.js` i skrivbordet-repot).

## Dataformat (kv_store-nycklar på kontot)

- `assistent-brief` — `{ datum, halsning, punkter: [{emoji, rubrik, text}], skriven }`
- `assistent-poster` — `[{ id, omrade: barn|karriar|hushall|halsa, text, datum?, klar, skapad }]`
- `assistent-mejl` — `{ uppdaterad, viktiga: [{fran, amne, sammanfattning}], obesvarade: [{fran, amne, dagar}], datumfynd: [{datum, text}] }`
- `assistent-vardagskoll` — skrivs av Vardagskoll: `{ barn, barnDagar, middagar, aktiviteter, stad, inkopKvar, uppdaterad }`
- `assistent-ekonomi-poster` — `[{ id, typ: in|ut, beskrivning, belopp, forfallodatum, status, klarNar?, bilaga? }]` (Ekonomi-fliken; `status: "klar"` = arkiverad för alltid, aldrig raderad automatiskt)
- `assistent-ekonomi-saldon` — `[{ konto, belopp, uppdaterad }]` (kända kontosaldon)
- `assistent-bilaga-<postId>` — `{ namn, typ, data (dataURL), uppladdad }` — fakturafoton/PDF:er, komprimerade i webbläsaren; hämtas styckvis med `?bilaga=<postId>` och raderas (via `radera_bilaga`) när posten bockas av — bilden är färskvara, uppgifterna arkiveras för alltid. Bifogar man en faktura i *Ny post* läser assistenten av den (bild-/PDF-block till AI:n) och fyller i tomma fält (typ, beskrivning, belopp, förfallodatum) automatiskt. `/api/assistent` tillåter AI-anrop upp till 4 MB (bilder/PDF) medan vanliga skrivningar hålls små.
- `assistent-profil` — `{ uppdaterad, text }` — assistentens egna anteckningar om Anna, skrivs av morgonjobbet och läses av chattarna; visas aldrig i appens gränssnitt
- `assistent-intervjuer` — `{ halsa|karriar|varderingar: { svar: {frageId: text}, utlatande?, uppdaterad } }` — tre frågeformulär under Mer (fasta frågor, se `INTERVJUER` i index.html), svaren fylls i direkt i textfält och sparas automatiskt (inget AI-samtal krävs); en knapp låter assistenten sammanfatta ifyllda svar till ett `utlatande` som Anna redigerar fritt och sparar själv — hennes sparade text är det som vävs in i chattarna och morgonbriefen
- `assistent-samtal-ÅÅÅÅ-MM` — samtalsloggen per månad `[{ id, t, roll: jag|ass, kanal: prata|ekonomi, text }]`; skrivs via `logga`-operationen (dubblettskydd på id), raderas bara via `radera_samtal`

Båda chattarna — "Prata med mig" på förstasidan och Ekonomi-flikens — skickar `POST { ai: { system, messages } }` (med Bearer-token) till samma API; servern vidarebefordrar till Anthropic och räknar anropet mot kontots dagliga AI-tak (delas med Skrivbordet).

Förstasidans chatt kan även användas med rösten: mikrofonknappen använder webbläsarens taligenkänning (`SpeechRecognition`, sv-SE) och svar på röstfrågor läses upp med `speechSynthesis`. Chatten känner till hela dagsläget (brief, bevakningar, barnens vecka, jobbresor, karriärmål, ekonomi, mejl) och kan lägga till och bocka av bevakningar via `action`-fältet i AI-svaret.

## Trädgården i 3D

`tradgard.html` är en fristående 3D-värld av trädgården, byggd efter 16 foton. Den nås från **Mer**-fliken eller direkt på `/tradgard.html` och kräver ingen inloggning.

- **74 namngivna saker** — blommor, bär, grönsaker, träd, byggnader och möbler. Varje sak har svenskt namn, latinskt namn och en kort beskrivning. Namnlapparna kan tryckas på, och **Växtlistan** har sökfält och flyger kameran till det man väljer.
- **Gå runt** med W A S D (eller styrspaken på telefon) och dra för att titta. `F` ger flygläge, `L` släcker namnlapparna.
- **Rundtur** går igenom trädgårdens 20 platser av sig själv, från gräsmattan ut genom grinden och tillbaka in i växthuset.
- **Morgon / Dag / Kväll** flyttar solen och ändrar himlen.
- Arter som var svåra att artbestämma på foto är märkta *”osäker art”* i informationsrutan.

Tomtens form och storlek är hämtade från förrättningskartan: knappt 40 meter längs gatan i norr, grundare i väster och djupare i öster, drygt tusen kvadratmeter. Huset ligger med långfasaden och entrén mot gatan. Planlösningen är därefter härledd ur fotona bild för bild: verandan vid nordösthörnet med grusplatsen nedanför östra gaveln, grusremsan med utduschen och zinkkaren längs södra långsidan, tältlinjen tält–silverpil–pool–bod österut, odlingszonen söder om husets västra del, komposten och såbädden i väster, och växthuset i sydost med luktärterna mot söder och röda ladan strax bortom gavelfönstret.

Tekniskt: ett enda HTML-dokument plus `vendor/three.min.js` (three.js r160, MIT, medföljer så sidan fungerar offline — ingen CDN). Allt statiskt slås ihop till två stora mesh:ar, så hela trädgården ritas i praktiken i två anrop och går mjukt även på telefon.

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
