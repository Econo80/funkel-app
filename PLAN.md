# Funkel — Plan (living document)

Funkel is an offline, child-safe iOS learning app for vocabulary, maths and
general knowledge. The mascot is **Pip**, an original round "spark" creature
drawn purely in SwiftUI shapes (no image assets, no resemblance to any brand).

_Last updated: 2026-10-16 — All seven milestones verified in CI._

---

## 1. Status

| # | Milestone | State | Build verified? |
|---|-----------|-------|-----------------|
| 0 | PLAN.md, README.md, Xcode project scaffold, CI | done | ✅ CI (Xcode 16.4, iOS 26.2 sim) |
| 1 | Data model, age scaling, content loader, `de` manifest | done | ✅ CI, 19/19 tests |
| 2 | Home screen + profile picker | done | ✅ CI, 31/31 tests |
| 3 | Maths end-to-end (generator → round → feedback → summary → progress) | done | ✅ CI, 31/31 tests |
| 4 | Vocabulary (picture match, meaning, synonyms/opposites, spelling) | done | ✅ CI, 38/38 tests + screenshots |
| 5 | General Knowledge (question bank) | done | ✅ CI, 45/45 tests + screenshots |
| 6 | Grown-up area: gate, profiles, ages, language, toggles, round length | done | ✅ CI, 53/53 tests + screenshots |
| 7 | Polish: animations, haptics, sound, read-aloud, accessibility audit | done | ✅ CI, all tests + iPhone, large-text and iPad screenshots |

"Build verified" means the GitHub Actions workflow (`.github/workflows/ci.yml`) built the app and passed the unit tests on a macOS runner with an iOS Simulator. The tests run inside the app, so a pass also means it launches. Development happens on Windows, so CI is the only compiler; every slice is pushed and must be green before the next one starts.
The JSON
content *is* verified on every milestone via `scripts/validate_content.py`.

---

## 2. Principles & constraints

- Swift 5.10+/SwiftUI, **iOS 17+**, MVVM, SwiftData. Universal, portrait-first.
- **Fully offline.** No network code, no accounts, no analytics, no ads, no IAP,
  no tracking. The only personal data is a first name + age, stored on device.
- **No third-party dependencies.** The Xcode project uses Xcode 16
  "synchronized folders" so it needs no generator tool.
- **No hardcoded user-facing text.** UI strings → `Localizable.xcstrings`.
  Learning content and content-language phrasing → `Content/<lang>/*.json`.
- Positive, low-pressure: no failure sounds, no lives, no countdowns for young
  children.

---

## 3. Architecture

```
Funkel/                       ← app sources (Xcode synchronized folder)
  App/                        FunkelApp, RootView, AppEnvironment (DI container)
  Models/                     SwiftData @Model types (persisted)
  Domain/
    Difficulty/               Difficulty, DifficultyScale, DifficultyTuning
    Questions/                Question, QuestionFormat, AnswerOption, QuestionVisual
    Subjects/                 SubjectDescriptor, ProviderKind
  Learning/
    ContentLoading/           LanguageManifest, ContentLibrary (loader), file schemas
    Providers/                QuestionProvider protocol + Maths / WordList / QuestionBank
  Services/                   Speech, Sound, Haptics, Progress/Streak
  Features/                   Home, Round, Summary, GrownUps, Profiles (View + ViewModel)
  DesignSystem/               Palette, Typography, components, Pip mascot
  Resources/                  Assets.xcassets, Localizable.xcstrings
Content/                      ← learning content (folder reference, keeps sub-dirs)
  de/manifest.json            language declaration + which subjects it offers
  de/strings.json             content-language phrasing (prompt templates)
  de/maths.json               word-problem templates & nouns for maths
  de/vocabulary.json          word list
  de/generalknowledge.json    question bank
FunkelTests/                  unit tests: scaling, generator, content integrity
scripts/validate_content.py   JSON schema/integrity check (runs anywhere)
```

**Layering.** Views → ViewModels (`@Observable`) → Domain/Learning (pure Swift,
no SwiftUI, fully unit-testable) → Models (SwiftData). Services are injected
through `AppEnvironment` so previews/tests can swap fakes.

### 3.1 Why `Content/` is a folder reference

Xcode copies files in normal/synchronized groups *flat* into the bundle, so
`de/vocabulary.json` and `fr/vocabulary.json` would collide. `Content/` is added
as a **folder reference**, so the bundle contains `Content/de/...`,
`Content/fr/...` exactly as on disk. Dropping in a new folder needs no project
edit.

---

## 4. Data model (SwiftData)

```
ChildProfile
  id: UUID, name: String, age: Int (4…14), avatarColor: String
  learningLanguage: String            // "de"; independent of device UI language
  difficultyAdjustment: Double        // −1.5…+1.5, nudged by performance (§5.4)
  enabledSubjectIDs: [String]         // empty = all subjects the language offers
  roundLength: Int                    // default 10 (5…20)
  soundEnabled, readAloudEnabled, hapticsEnabled, gentleTimerEnabled: Bool
  totalStars: Int
  currentStreak, longestStreak: Int, lastPlayedDay: Date?   // calendar-day streak
  createdAt: Date
  progress: [SubjectProgress]  (cascade)
  rounds:   [RoundRecord]      (cascade)

SubjectProgress     subjectID, languageCode, roundsPlayed, questionsAnswered,
                    correctAnswers, stars, lastPlayed, profile
RoundRecord         date, subjectID, languageCode, correct, total, starsEarned,
                    effectiveAge, profile
```

Progress is keyed by `(subjectID, languageCode)` so French maths and German
maths progress are tracked separately later. Runtime-only types (`Question`,
`Difficulty`, content files) are plain structs and never persisted.

---

## 5. Difficulty scaling

Difficulty is a **pure function** `DifficultyScale.difficulty(forAge:adjustment:)`.

```
effectiveAge = clamp(age + difficultyAdjustment, 4.0, 14.0)   // Double
level        = (effectiveAge − 4) / 10                        // 0.0 … 1.0
tier         = early(4–5) | lowerPrimary(6–7) | upperPrimary(8–9)
               | middle(10–11) | upper(12–14)
```

All tunable numbers live in **one file**: `Funkel/Domain/Difficulty/DifficultyTuning.swift`.
Numeric parameters are **keyframes** linearly interpolated over `effectiveAge`,
so a child aged 7 with adjustment +0.4 gets values between the 7 and 8
keyframes — the app grows smoothly, no fixed levels.

### 5.1 General parameters

| Parameter | 4 | 6 | 8 | 10 | 12 | 14 | Notes |
|---|---|---|---|---|---|---|---|
| Answer options shown | 3 | 3 | 4 | 4 | 4 | 4 | rounded |
| Pictures in options | yes | yes | no | no | no | no | `effectiveAge < 7` |
| Gentle timer allowed | – | – | – | yes | yes | yes | `≥ 9`, opt-in per profile; never shown below 9 |
| Timer seconds | – | – | – | 40 | 30 | 25 | soft: bar fades, never fails the question |
| Number pad input (maths) | – | – | yes | yes | yes | yes | `≥ 8`; younger get big multiple-choice |

### 5.2 Maths

Operation weights (relative; 0 = off). Interpolated, then normalised.

| Operation | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 12 | 14 |
|---|---|---|---|---|---|---|---|---|---|
| counting (count objects) | 6 | 4 | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| number recognition | 4 | 3 | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| addition | 0 | 3 | 5 | 4 | 3 | 2 | 2 | 2 | 2 |
| subtraction | 0 | 1 | 3 | 4 | 3 | 2 | 2 | 2 | 2 |
| multiplication | 0 | 0 | 0 | 0.5 | 3 | 3 | 3 | 3 | 3 |
| division | 0 | 0 | 0 | 0 | 1 | 2 | 3 | 3 | 3 |
| word problem | 0 | 0 | 0 | 1 | 1.5 | 2 | 2 | 2.5 | 3 |
| missing number (`3 + ? = 7`) | 0 | 0 | 0 | 1 | 1.5 | 1.5 | 2 | 2 | 2 |

Ranges:

| Parameter | 4 | 5 | 6 | 7 | 8 | 10 | 12 | 14 |
|---|---|---|---|---|---|---|---|---|
| counting max | 5 | 10 | 12 | – | – | – | – | – |
| add/sub result max | 5 | 10 | 20 | 50 | 100 | 500 | 1000 | 5000 |
| times-table max factor | – | – | – | 5 | 5 | 10 | 12 | 20 |
| second factor max | – | – | – | 10 | 10 | 10 | 20 | 25 |

Rules: subtraction never goes negative below 12; division is always exact
(built as the inverse of a multiplication fact); at age 7–8 the first factor is
drawn from {2, 5, 10} before opening up to all tables; word problems use the
same operation set but are capped at `min(add/sub max, 100)` and phrased from
`Content/<lang>/maths.json` templates.

### 5.3 Content selection (vocabulary, general knowledge, future grammar)

Each item declares `minAge` (required) and `maxAge` (optional, default 14).
An item is **eligible** if `minAge ≤ effectiveAge + 0.5` and `maxAge ≥ effectiveAge − 0.5`.
Eligible items are weighted to keep it challenging but not stale:

```
weight = 3   if minAge ≥ effectiveAge − 2      (current band)
         1   otherwise                          (easy review)
       × 0.2 if answered correctly in the last 3 rounds (recently seen)
```

Synonym/opposite distractors exclude the word's whole *family* (its synonyms and antonyms, and theirs), so "riesig" is never a wrong answer for "Gegenteil von klein".

Vocabulary question types unlock by age: picture match (4+), word→picture (4+),
meaning (6+), spelling (5.5+, word length ≤ `spellingMaxLength`: 4 at 5 → 6 at
7 → 10 at 10 → 14 at 12), opposites (7+), synonyms (8+). Spelling adds
distractor letters from 8+ (`0 → 3`).

### 5.4 Gentle adaptivity

After each round: score ≥ 90 % → `difficultyAdjustment += 0.15`; score < 50 %
→ `−= 0.2`; clamped to ±1.5. Changing the age in the grown-up area resets the
adjustment to 0. This lets two 7-year-olds diverge naturally without a parent
touching anything.

---

## 6. Localisation

There are **two independent language axes**:

| Axis | Source | Used for |
|---|---|---|
| **UI language** | device language → `Localizable.xcstrings` | buttons, menus, grown-up area, summaries, VoiceOver hints |
| **Learning language** | `ChildProfile.learningLanguage` → `Content/<lang>/` | questions, answers, prompt phrasing, read-aloud voice |

- UI strings use semantic keys (`home.greeting`, `round.next`) with German values
  in the catalog. Development language is `de`. Adding English UI = adding `en`
  values to the catalog (+ `en` in Known Regions). No code change.
- `ContentLibrary` discovers languages at launch by scanning `Content/*/manifest.json`.
  The grown-up language picker lists whatever it finds. Adding French = add
  `Content/fr/` with a manifest. No code change.
- Prompt phrasing that belongs to the *learning* language (e.g. "Wie viel ist
  {a} + {b}?", "Welches Wort passt zum Bild?") lives in `Content/<lang>/strings.json`,
  never in the String Catalog, so a German UI can host French questions.
- Read-aloud uses `AVSpeechSynthesisVoice(language: manifest.speechLocale)`
  (`de-DE`), falling back to the language code, then to the default voice.

### 6.1 Language-specific subjects (the Grammar slot)

A language's `manifest.json` **declares the subjects it offers**:

```json
{
  "code": "de", "name": "Deutsch", "speechLocale": "de-DE",
  "subjects": [
    { "id": "maths",            "provider": "maths",        "file": "maths.json",            "title": "Mathe",       "icon": "plus.forwardslash.minus", "color": "#FF8A3D" },
    { "id": "vocabulary",       "provider": "wordList",     "file": "vocabulary.json",       "title": "Wörter",      "icon": "textformat.abc",          "color": "#3DA5FF" },
    { "id": "generalKnowledge", "provider": "questionBank", "file": "generalknowledge.json", "title": "Wissen",      "icon": "globe.europe.africa.fill", "color": "#34C77B" }
  ]
}
```

There are three **provider kinds** in code, and subjects are just content bound
to one of them:

| Provider | Input | Used by |
|---|---|---|
| `maths` | difficulty + phrasing templates | Maths (procedural, infinite) |
| `wordList` | a word list (word, article, emoji, definition, synonyms, antonyms) | Vocabulary |
| `questionBank` | authored questions in **generic formats** | General Knowledge, **Grammar** |

`questionBank` formats are generic: `multipleChoice` (optionally with a
`sentence` containing `___` for fill-the-gap) and `buildSequence` (tap tiles in
order — letters for spelling, words for sentence building). Articles, verb
forms and sentence building are all expressible in these, so French grammar
later is just:

```json
{ "id": "grammar", "provider": "questionBank", "file": "grammar.json", "title": "Grammaire", "icon": "text.book.closed.fill", "color": "#B26BFF" }
```

German simply doesn't list `grammar`, so it never appears. Unknown provider
kinds are skipped with a debug log, so newer content can't crash an older app.

---

## 7. Screens

1. **Profile picker** — big avatar tiles (Pip in the child's colour); "+" leads to the gate.
2. **Home** — greeting, streak flame, star total, one large card per active subject with progress ring.
3. **Round** — progress dots, question card (prompt + optional visual), answers (2×2 grid / number pad / letter tiles), speaker button, optional soft timer bar.
4. **Feedback overlay** — correct: Pip bounce + confetti + chime + light haptic; wrong: correct answer highlighted gently with "Fast! Die richtige Antwort ist …", no red X.
5. **Summary** — stars earned (animated count-up), encouragement line scaled to score, "Nochmal" / "Fertig".
6. **Grown-up gate** — "Was ist 7 × 6?" style question with number pad (random, two-digit result).
7. **Grown-up area** — profiles list → profile editor (name, age stepper 4–14, colour, learning language, subject toggles, round length, sound, read-aloud, haptics, gentle timer when age ≥ 9), reset progress, about/privacy statement.

---

## 8. Build order

1. ✅ PLAN.md, README.md, project scaffold
2. ✅ SwiftData models, `DifficultyScale`, `ContentLibrary`, `de` manifest
3. ✅ Home + profile picker
4. ✅ **Maths end-to-end** — generator, `RoundViewModel`, round/feedback/summary views, progress + streak persistence. *Verify build.*
5. ✅ Vocabulary — `VocabularyQuestionGenerator` + letter-tile spelling view. *Verify build.*
6. ✅ General Knowledge — `QuestionBankProvider`. *Verify build.*
7. ✅ Grown-up gate + settings + profile management. *Verify build.*
8. ✅ Polish — Pip animations, confetti, sounds (synthesised via AVAudioEngine; no audio assets needed), haptics, read-aloud, VoiceOver/Dynamic Type audit, iPad layout pass.

---

## 9. Open questions / decisions log

- **2026-10-15** — App name "Funkel" and mascot "Pip" are placeholders; rename via `PRODUCT_NAME` and the catalog.
- **2026-10-15** — Pictures are emoji rendered large. Zero asset licensing risk, works offline, every language shares them. Can be swapped for custom illustrations later via an optional `image` field.
- **2026-10-15** — Project file is hand-written (Xcode 16 format, `objectVersion = 77`). Requires **Xcode 16+** to open.
- **2026-10-15** — Bundle ID placeholder `com.example.funkel`; set your Team in Signing & Capabilities.
- **2026-10-16** — No Mac available, so builds run on GitHub Actions (`macos-15`, private repo `Econo80/funkel`). macOS minutes are limited on the free plan, so a newer push cancels the running build.
- **2026-10-16** — Closing a round early saves nothing: no stars, no streak. Low-pressure, and it can't be gamed by quitting.
- **2026-10-16** — Maths read-aloud uses words from `strings.json` (`maths.word.*`: "plus", "mal", "geteilt durch") so the voice never has to guess at "·" or ":".
- **2026-10-16** — Sound effects moved to milestone 7 (synthesised, no assets). Haptics and visual feedback ship now.
- **2026-10-16** — `scripts/check_strings.py` runs in CI: every UI key used in Swift must exist in the String Catalog.
- **2026-10-16** — CI now also runs `FunkelUITests/ScreenshotTests`, which walks the main screens with sample profiles (Debug-only `-uiTesting` launch mode, in-memory store) and uploads PNGs as the `screenshots` artifact (kept 30 days).
- **2026-10-16** — The earliest vocabulary words carry a `maxAge` (4 → 8, 5 → 9, 6 → 11), so older children aren't offered "der Hund". **Content gap:** ages 12–14 have only 5–14 words in their current band. Needs more advanced words before release.
- **2026-10-16** — Nouns are shown with their article ("der Hund") in picture questions, so children learn the article with the word.
- **2026-10-16** — General Knowledge: 125 German questions in six categories (animals, nature, body, geography, science, everyday), ages 4–14, including tap-in-order questions (life cycles, weekdays, planets), so the `buildSequence` path that Grammar will use is already exercised. A round mixes categories: each pick halves the weight of its category for the rest of the round. A bank too small for the round length gives a shorter round, never repeats.
- **2026-10-16** — Sequence distractor tiles only appear from age 8, so younger children just order the given tiles.
- **2026-10-16** — **Content gap:** 4-year-olds have 22 general-knowledge questions, about two rounds' worth before repeats are down-weighted. Worth growing alongside the 12–14 vocabulary.
- **2026-10-16** — Grown-up gate: a two-digit × one-digit sum (12–19 × 3–9, e.g. "14 × 7"). A wrong answer quietly swaps in a new sum. It guards the gear button (picker and home) and "Profil anlegen". It's deliberately light; it isn't security.
- **2026-10-16** — Profile settings are edited as a value copy (`ProfileSettings`) and written back on save. "All subjects on" is stored as an empty list, so subjects a language adds later (e.g. Grammar) appear automatically; at least one subject always stays on. Changing the learning language turns all of its subjects on.
- **2026-10-16** — "Fortschritt zurücksetzen" clears stars, streaks, per-subject progress, history and adaptivity, but keeps name, age and settings. "Profil löschen" removes everything (cascade). Both ask for confirmation.
- **2026-10-16** — The sound toggle is stored now; sound effects arrive in milestone 7.
- **2026-10-16** — Sounds are synthesised at launch (`SoundService`): a rising chime for correct, a soft low two-note "hmm" for wrong (quieter and lower by test), and a fanfare at the end of a round. The `.ambient` audio session respects the silent switch and mixes with other audio.
- **2026-10-16** — Celebrations: Canvas confetti on every correct answer and at the summary (more for 80 %+), plus a hop from Pip. Pip bobs gently on the home screen. Everything animated is skipped under Reduce Motion.
- **2026-10-16** — Answer grids pick **one** font size, measured with UIKit so the longest *word* fits a column (`TextFitting`). Lines wrap between words, never inside them.
- **2026-10-16** — Accessibility:
  - VoiceOver reads the question card with the same words as read-aloud ("3 plus 4").
  - Feedback is announced, and auto-advance waits longer while VoiceOver is on.
  - Auto read-aloud steps aside while VoiceOver is running.
  - After a wrong answer, read-aloud speaks the right answer in the learning language (`speech.answer` in `strings.json`, required for every language).
  - Dynamic Type is capped at AX3. From the accessibility sizes up, answers stack in one column, subject cards stack their icon, and the stat chips wrap.
- **2026-10-16** — CI screenshots now include a large-text run (AX3) and an iPad run (`screenshots/ipad/`).
- **2026-10-16** — Distribution: TestFlight via GitHub Actions (`.github/workflows/testflight.yml`, run by hand). It archives Release with cloud-managed automatic signing through an App Store Connect API key (no certificates in the repo), uploads with `xcodebuild -exportArchive` (`destination: upload`), and numbers builds by workflow run. Bundle ID and team come from repo variables, so `com.example.funkel` stays the in-repo placeholder. CI also builds Release so Release-only compile errors show up before a TestFlight run. Setup: docs/TESTFLIGHT.md.
- **2026-10-16** — App icon: Pip on a warm gradient with sparkles, drawn by `scripts/make_app_icon.py` (1024 px, no alpha). `ITSAppUsesNonExemptEncryption = NO` is set, since the app uses no encryption, so TestFlight skips the export-compliance question.
- **2026-10-16** — **Web version** (`web/`): an offline PWA for any device, hosted free on Netlify (`netlify.toml`). It ports the domain logic one-to-one from Swift (difficulty, maths, vocabulary, question bank, streaks, progress, gate, round state machine), with Vitest tests mirroring the Swift tests. It reads the same `Content/` at build time and converts the iOS String Catalog into `ui-strings.json`, so content and translations stay single-source. Dependencies: Preact at runtime; Vite, TypeScript, Vitest and @types/node for development only. Storage is IndexedDB on the device, plus a service worker pre-caching all files. Strict CSP: the app only talks to its own origin. Limits vs. native: no vibration on iOS, and data isn't kept for sites used only in Safari tabs (home-screen apps are fine). CI job `web` runs `npm test` and `npm run build`.
