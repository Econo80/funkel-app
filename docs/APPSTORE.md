# Publishing Funkel on the App Store

The plan: **port the web app's features to the native SwiftUI app**, ship it to
the family through **TestFlight** first, then publish it on the **App Store**.

| What | Value |
|---|---|
| App name | Funkel (fallback if taken: *Funkel – Lernen mit Pip*) |
| Bundle ID | `ch.flury.funkel` (fixed for good after the first upload) |
| Category | Education |
| Age rating | 4+ (no violence, ads, purchases, web access or chat) |
| Price | Free, no in-app purchases |
| Privacy | No data collected; manifest in `Funkel/Resources/PrivacyInfo.xcprivacy` |
| Privacy policy URL | <https://oflurykids.netlify.app/datenschutz.html> |

## Part 1 – One-time Apple setup (once your membership is approved)

The enrolment confirmation e-mail from Apple usually arrives within 1–2 days.
After that, follow **docs/TESTFLIGHT.md** with these values:

1. **Register the bundle ID** – developer.apple.com → Certificates, IDs &
   Profiles → Identifiers → **+** → App IDs → App → Description `Funkel`,
   Explicit Bundle ID **`ch.flury.funkel`**. No capabilities needed.
2. **Create the app** – appstoreconnect.apple.com → Apps → **+** → New App:
   iOS, name **Funkel**, primary language **German**, bundle ID
   `ch.flury.funkel`, SKU `funkel`, full access.
3. **API key** for uploads from GitHub – Users and Access → Integrations →
   App Store Connect API → **+**, access **Admin** (needed so GitHub can
   create the signing certificate itself). Download the `.p8`
   once and keep it safe; note the *Key ID* and *Issuer ID*.
4. **GitHub settings** – run these in a terminal (the key file never goes in
   the chat or the repository):

   ```bash
   gh variable set APPLE_TEAM_ID --body "<your Team ID>"
   ```
   ```bash
   gh variable set BUNDLE_ID --body "ch.flury.funkel"
   ```
   ```bash
   gh secret set ASC_KEY_ID --body "<Key ID>"
   ```
   ```bash
   gh secret set ASC_ISSUER_ID --body "<Issuer ID>"
   ```
   ```bash
   gh secret set ASC_KEY_P8 < AuthKey_XXXXXXXXXX.p8
   ```

## Part 2 – TestFlight for the family

1. GitHub → Actions → **TestFlight** → Run workflow (about 20 minutes).
2. App Store Connect → Funkel → TestFlight: the build appears after Apple's
   processing (10–30 minutes). Answer the export question: *no encryption*
   (already declared in the app).
3. **Internal testing** (no review): add yourself and other adults as App Store
   Connect users, then add them to an internal test group. Each adult installs
   the **TestFlight** app and accepts the invite; children use the iPad of an
   adult who accepted it.
4. **External testing** (other families, up to 10,000 people): needs a short
   beta review by Apple and a public link.
5. TestFlight builds expire after **90 days** – just run the workflow again.

**Moving progress from the web app:** in the web app, ⚙️ → Sicherung speichern;
in the iPhone app, ⚙️ → Sicherung laden. (The iPhone app will read the same
backup format – see Part 4.)

## Part 3 – Public App Store release

Checklist in App Store Connect (Funkel → *App Store* tab):

- **Screenshots**: iPhone 6.9″ (1320 × 2868) and iPad 13″ (2064 × 2752). The
  CI screenshot run produces them (Actions → CI → Run workflow → artifact
  *screenshots*).
- **Texts** (German, optional English): see *Store listing* below.
- **Support URL**: <https://oflurykids.netlify.app/datenschutz.html> (or a page
  with an e-mail address you want to show publicly).
- **Privacy policy URL**: <https://oflurykids.netlify.app/datenschutz.html>.
- **App Privacy** questionnaire: *Data Not Collected*.
- **Age rating** questionnaire: all "None" → 4+.
- **Kids Category**: optional. It gives visibility in the Kids section but adds
  Apple's strictest review rules (no external links or purchases without a
  parental gate, no third-party analytics). Funkel already meets them; choose the
  age band **6–8** or **9–11** if you opt in. Recommendation: start without, add
  later.
- **Review notes** for Apple (paste as is):

  > Funkel is an offline learning app for children (maths, German words,
  > general knowledge). No accounts, no network access, no data collection.
  > The grown-up area is protected by a multiplication question (e.g. 19 × 9).
  > To test: create a profile via "Profil anlegen", solve the grown-up question,
  > enter a name and age.

Then **Submit for Review** (usually 1–3 days).

### Store listing (German)

**Untertitel** (max. 30): `Mathe, Wörter & Wissen spielend`

**Beschreibung:**

> Funkel ist eine liebevolle Lern-App für Kinder von 4 bis 14 Jahren – ganz ohne
> Werbung, ohne Konten und ohne Internet.
>
> MATHE – vom Zählen bis zu Textaufgaben, mit Zahlenhäusern wie in der Schule.
> WÖRTER – Bilder, Bedeutungen, Gegenteile, Buchstabieren und Diktate.
> WISSEN – spannende Fragen zu Tieren, Natur, Körper, Welt und mehr.
>
> Funkel passt sich an: Die Aufgaben richten sich nach dem Alter und werden
> schwieriger, wenn ein Kind alles richtig hat. Pip, das kleine Maskottchen,
> lobt und ermutigt – Fehler sind ein Teil des Lernens.
>
> Mit gesammelten Sternen geht's in die Spielecke und in Pips Garten, der zu
> einem eigenen Bauernhof wächst. Eltern legen fest, wie viel Spielzeit es gibt.
>
> FÜR ELTERN
> • Mehrere Kinderprofile, Erwachsenen-Bereich mit Rechenaufgabe geschützt
> • Niveau pro Fach einstellbar, Vorlesen, Töne und Zeitlimits
> • Sicherung speichern und wiederherstellen
> • Keine Datensammlung: Alles bleibt auf dem Gerät.

**Keywords** (max. 100): `lernen,kinder,mathe,rechnen,deutsch,wörter,wissen,schule,primarschule,quiz,lernspiel`

## Part 4 – Swift port roadmap

Today the native app has Mathe, Wörter, Wissen, profiles, the grown-up area,
sounds, read-aloud and Pip. Everything below exists in the web app (`web/src`)
and gets ported in this order. Each step ships as its own TestFlight build.

| Step | Ported from the web app | Notes |
|---|---|---|
| 1 | Backup file (same JSON format), star gifts, per-subject levels with grown-up − / +, faster step-up | Lets families move from the web app first |
| 2 | Zahlenhaus questions, writing questions (picture words, copying, dictation) with on-screen keyboard | Shared `Content/` already has the sentences |
| 3 | Sudoku (picture 4×4 … 9×9) | Pure logic, well covered by tests |
| 4 | Play corner: wallet, tickets, daily limit, bonus games, game difficulty; Memory, Ballon-Pop, Sternenfänger | SwiftUI + `TimelineView` for the moving games |
| 5 | Pips Garten / farm: grid, buildings, animals, harvest, orders, levels, moving, roads; daily time limit | Biggest step; drawings as SwiftUI shapes |
| 6 | Polish: screenshots, iPad layouts, VoiceOver, store submission | |

Rule of thumb for each step: port the domain logic with the same tests as
`web/tests`, then the screens, then CI screenshots.
