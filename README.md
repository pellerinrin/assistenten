# Assistenten 🖋

Din stillsamma sekreterare — en installerbar PWA som samlar hela vardagen på ett ställe: barnen, karriären, hushållet och hälsan. Varje morgon lämnar den en **morgonbrief** över dagen, håller **bevakningar** på saker med och utan datum, sammanfattar **mejlen** och håller ordning på **träning, vikt och alkohol**.

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
- `assistent-halsa` — Hälsa-fliken: `{ schema, pass, vikt, alkohol, mediciner, intag, matningar, egnaTester, mal: {veckopass, veckoglas} }`
  - `schema: [{id, dag (0=måndag), namn, typ, minuter}]` — veckan som återkommer; `pass: [{id, datum, namn, typ, minuter, schemaId?}]` — genomförda pass (med `schemaId` = ett schemalagt pass avbockat den dagen)
  - `vikt: [{datum, kg}]`, `alkohol: [{datum, glas, vad}]` — en rad per datum, noteras samma dag igen skrivs den över
  - `mediciner: [{id, namn, dos, sort: medicin|tillskott, vidBehov, tider: [morgon|lunch|kvall|natt], dagar: [0–6, tom = varje dag], start, slut (tom = tills vidare), anteckning}]` — läggs in en gång och återkommer av sig själv; `intag: [{id, medicinId, datum, tid}]` — en rad per avbockad dos (`tid: "vidbehov"` för vid behov-preparat)
  - `matningar: [{id, test, datum, varde}]` — formmåtten; `test` är en nyckel ur `TESTER` i index.html eller id:t på ett eget mått i `egnaTester: [{id, namn, kategori: styrka|smidighet|kondition, enhet, riktning: upp|ner}]`. `riktning` avgör åt vilket håll som är en förbättring. Skrivs bara av den här appen; ett tomt svar från API:t rör aldrig det som redan ligger i telefonen, så data överlever även innan servern känner till nyckeln.
- `assistent-profil` — `{ uppdaterad, text }` — assistentens egna anteckningar om Anna, skrivs av morgonjobbet och läses av chattarna; visas aldrig i appens gränssnitt
- `assistent-intervjuer` — `{ halsa|karriar|varderingar: { svar: {frageId: text}, utlatande?, uppdaterad } }` — tre frågeformulär under Mer (fasta frågor, se `INTERVJUER` i index.html), svaren fylls i direkt i textfält och sparas automatiskt (inget AI-samtal krävs); en knapp låter assistenten sammanfatta ifyllda svar till ett `utlatande` som Anna redigerar fritt och sparar själv — hennes sparade text är det som vävs in i chattarna och morgonbriefen
- `assistent-samtal-ÅÅÅÅ-MM` — samtalsloggen per månad `[{ id, t, roll: jag|ass, kanal: prata|ekonomi, text }]`; skrivs via `logga`-operationen (dubblettskydd på id), raderas bara via `radera_samtal`

Båda chattarna — "Prata med mig" på förstasidan och Ekonomi-flikens — skickar `POST { ai: { system, messages } }` (med Bearer-token) till samma API; servern vidarebefordrar till Anthropic och räknar anropet mot kontots dagliga AI-tak (delas med Skrivbordet).

## Hälsa-fliken 🌿

Tre saker på ett ställe, alla lika enkla att fylla i på en telefon:

- **Träningsschemat** — veckan som återkommer (pass per veckodag med typ och längd). Dagens pass dyker upp både under Hälsa och i "Läget idag", och bockas av med ett tryck; ett tryck till ångrar. Pass utanför schemat loggas separat, även i efterhand.
- **Mediciner & kosttillskott** — läggs in **en enda gång** med dos, tider på dygnet (morgon/lunch/kväll/natt), vilka veckodagar och en period. Utan slutdatum återkommer de tills vidare, så inget behöver läggas in på nytt varje dag; "Avsluta" sätter slutdatum till idag och behåller historiken. Dagens doser bockas av var för sig, vid behov-preparat noteras i stället med "Tog en nu", och följsamheten den senaste veckan visas som *X av Y doser*.
- **Formen** — det som mäts i stället för en målvikt: **styrka** (armhävningar, planka, knäböj, hängande), **smidighet & balans** (framåtböj, axelgrepp, stå på ett ben, res dig från golvet) och **kondition** (vilopuls, 2 km på tid, trappor, återhämtningspuls). Varje mått har en enhet och vet åt vilket håll som är en förbättring — så en sjunkande vilopuls räknas som framsteg. Egna mått går att lägga till. Jämförelsen görs alltid mot din egen första mätning, aldrig mot en tabell.
- **Vikten** — en vägning per dag, kurva över de senaste tre månaderna och förändring på 7 och 30 dagar. Ingen målvikt: vikten är en siffra bland andra, och chatten är instruerad att aldrig föreslå en. Viktfälten är textfält med decimaltangentbord, så ett svenskt kommatecken funkar (ett `type=number` kastar tyst bort "68,4").
- **Alkoholen** — antal standardglas per dag, fyra veckor tillbaka som ett rutnät, veckosumma mot ett eget tak och tiden sedan senaste glaset. En alkoholfri dag noteras med en knapp.

> **Obs:** själva synkningen kräver att `api/assistent.js` i skrivbordet-repot släpper igenom nyckeln `assistent-halsa` (läsa i GET-svaret, skriva via `skriv`) — det är ett annat repo. Tills det är på plats fungerar fliken ändå fullt ut, men bara på den telefon som skrivit in uppgifterna: appen sparar alltid lokalt först och skickar upp i bakgrunden när servern tar emot.

Målen (pass per vecka, högsta antal glas per vecka) sätts längst ned på fliken. Dagens träningspass, doser kvar att ta och en påminnelse när det var länge sedan du vägde dig eller testade formen dyker upp i "Läget idag" på förstasidan.

Chatten på förstasidan ser sammanfattningen av allt detta och kan notera åt dig — "jag vägde 68,4 i morse", "det blev två glas igår", "jag hann med löprundan", "jag har tagit min Levaxin", "jag klarade 18 armhävningar" — via fältet `halsa` i svarsverktyget (`vikt`, `alkohol`, `pass`, `medicin_tagen`, `matning`). Systemprompten säger åt henne att aldrig föreslå en målvikt, aldrig moralisera om vikt, alkohol eller mediciner, och att hänvisa till läkare eller apotek i medicinska frågor — hon är sekreterare, inte doktor. Allt sparas lokalt direkt och synkas till kontot under `assistent-halsa`.

Förstasidans chatt kan även användas med rösten: mikrofonknappen använder webbläsarens taligenkänning (`SpeechRecognition`, sv-SE) och svar på röstfrågor läses upp med `speechSynthesis`. Chatten känner till hela dagsläget (brief, bevakningar, barnens vecka, jobbresor, karriärmål, ekonomi, mejl) och kan lägga till och bocka av bevakningar via `action`-fältet i AI-svaret.

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
