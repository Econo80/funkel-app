# Funkel as a web app (free, any device)

The web version runs in the browser and can be added to the home screen of
an iPhone, iPad or Android device, where it looks and feels like an app.
It's free: no Apple account, no App Store, no 7-day limit. It works
**offline** after the first time it's opened.

It uses the same questions and rules as the iPhone app (the shared
`Content/` folder), so both stay in step automatically.

## Part 1: put it online with Netlify (about 10 minutes, once)

Netlify is a free service that puts websites on the internet. It takes the
code from GitHub and builds the app for you.

1. Go to <https://www.netlify.com> and click **Sign up**. Choose **Sign up with
   GitHub** and log in with your GitHub account (`Econo80`). Allow Netlify to
   access GitHub when asked.
2. On your Netlify dashboard click **Add new site** (or **Add new project**)
   → **Import an existing project** → **GitHub**.
3. If your repository isn't listed, click **Configure Netlify on GitHub**, allow
   access to the **funkel** repository, and come back.
4. Click **funkel**. Netlify reads the settings from `netlify.toml` in the
   repository, so you don't need to change anything. Click **Deploy**.
5. Wait about a minute. When it says **Published**, Netlify shows an address
   like `https://jolly-pony-123abc.netlify.app`. Click it: that's Funkel.
6. Optional: give it a nicer name under **Site configuration → Change site name**,
   e.g. `funkel-familie`, which makes the address `https://funkel-familie.netlify.app`.

From now on, every change pushed to GitHub is published automatically
within a minute or two.

## Part 2: put it on the children's iPhone or iPad

1. On the iPhone/iPad, open **Safari** and go to your Funkel address.
2. Tap the **Share** button (the square with an arrow pointing up).
3. Scroll down and tap **Zum Home-Bildschirm** (Add to Home Screen) → **Hinzufügen**.
4. Funkel's yellow smiley icon is now on the home screen. **Always open Funkel
   from this icon**, not from a Safari tab (see "Good to know" below).
5. Open it once while connected to the internet. After that it works offline,
   for example in the car.

On **Android** it's similar: open the address in Chrome → menu (⋮) →
**Add to Home screen** / **Install app**.

## Part 3: first start

Tap **Profil anlegen**, solve the grown-up maths question, enter the child's
first name and age, and tap **Speichern**. Add more children through the
gear button (⚙️) on the start screen.

## Zahlenhaus and Sudoku

**Zahlenhäuser** are part of **Mathe** for ages 5 to 9: the number on the roof,
and floors whose two rooms add up to it (as in first grade). They start at roof
numbers up to 6 with two floors and grow to roofs up to 20 (age 7) and 100
(age 8). Some houses for older children hide the roof number instead.

**Sudoku** has its own card on the home screen. It follows the age: picture
Sudokus (4×4) for 4–5, numbers 4×4 for 6–7, 6×6 for 8–9 and the classic 9×9
from 10. A wrong entry just wobbles; 💡 fills in one field. A solved Sudoku
earns stars (fewer with tips). Grown-ups can hide it or make it easier or harder
in the child's profile under **Sudoku**.

## The play corner (Spielecke)

Children earn one star per correct answer. In the **Spielecke** (the colourful
card on the home screen) they can spend stars:

- **Games** (2 minutes each): **Memory** (find pairs), **Ballon-Pop** (a wrong balloon costs a point; pop
  balloons; at 4 all of them, at 5–6 only one colour, which changes every 30
  seconds, from 7 only even numbers, from 9 only the multiplications that
  make a target number, e.g. 24) and **Sternenfänger** (move Pip to catch stars and dodge clouds).
- **Pips Garten**: a little farm game that fills the screen. No timer.
  - **Look around:** swipe to move over the meadow, − / + to zoom. The light
    follows the time of day.
  - **🛒 Laden:** plants, animals, buildings, roads/paths/fences (free) and
    decorations. Spending stars on the farm earns **XP** (top left); new **farm
    levels** unlock more items, celebrated with a pop-up.
  - **Growing and building take days:** crops and trees grow, buildings show a
    building site for 1–3 days. Farm animals need their home first (dog →
    Hundehütte, chicks → Hühnerstall, ducks → Teich, farm animals → Scheune).
  - **Every day:** wheat and vegetables can be harvested (then they grow again);
    hens, cows, bees and apple trees give eggs, milk, honey and apples. A bubble
    shows what's ready; tap it, or **🧺 Einsammeln** for everything at once.
  - **📋 Aufträge:** three orders a day ask for goods, e.g. "4 🥚 + 3 🥛", and pay
    stars and XP. Leftovers sell at the farm shop (5 → 1 ⭐). Learning stays the
    main way to earn stars.
  - **Daily time limit** (default 20 minutes, set per child under Spielecke →
    "Zeit in Pips Garten pro Tag": 10, 15, 20, 30, 45 or ∞). A clock shows the time
    left; at 2 minutes there's a warning, then the farm "goes to sleep" until
    tomorrow. Grown-ups can give +5/+10/+15 minutes for today via "🔓 Mehr Hofzeit".
  - **✋ Verschieben** moves things; **🧹 Wegräumen** removes them; more land is
    in the shop under "Bauen".

The lifetime star count never goes down; only the "stars to spend" are used.
Grown-ups can change the price per game, the number of games per day, or turn
the play corner off: ⚙️ → solve the question → the child's profile → **Spielecke**.
Defaults: 10 ⭐ per game, 3 games a day.

**Extra games on special occasions:** in the play corner, tap **🔓 Extra-Spiel
freischalten** (bottom), solve the grown-up question, and choose 1–3 extra games.
They're free (no stars) and outside the daily limit, and they expire at midnight.

**Game difficulty:** the games follow the child's age (Memory starts at 6 pairs
for a 5-year-old and adds 2 pairs with every cleared board). In the child's
profile under **Spielecke** you can set them to *Leicht*, *Mittel* or *Schwer*,
which works like being two years younger or older. It doesn't change the quizzes.

## Writing words and sentences

**Wörter** also asks children to write, on a big keyboard on the screen (a
real keyboard works too):

- from 6½: **write the word for a picture**, with boxes that show how many letters
- 7–8: **copy a sentence**
- from 8: **word dictation**: tap 🔊 *Anhören*, then write the word
- from 9: **sentence dictation**

From 9 the capital letters must be right. "ss" always counts for "ß", and
punctuation doesn't count. After a mistake, children see what they wrote next to
the right spelling.

## Backups (please do this now and then)

Funkel keeps everything only on the device. If the device's browser data is
cleared, or Funkel is opened from a Safari tab instead of the home-screen icon
(they keep separate data on iPhone/iPad), the children's progress isn't there.

- **Save:** ⚙️ → solve the question → **Sicherung → Sicherung speichern**. On an
  iPad the share menu opens: choose **In "Dateien" sichern** (e.g. iCloud Drive) or
  send it to yourself. The file is called `Funkel-Sicherung-<date>.json` and
  holds all profiles with stars, garden and progress.
- **Restore:** **Sicherung → Sicherung laden**, pick the file, check the names and
  stars shown, and tap **Wiederherstellen**. The profiles on the device are
  replaced by those in the file.
- The grown-up area shows when the last backup was saved.

## Giving stars

In the child's profile (⚙️ → solve the question → the child) under **🎁 Sterne
schenken**, choose any amount (− / +, or 10 / 25 / 50 / 100) and tap **Speichern**.
The stars go to the stars to spend (play corner, garden); the learning stars stay
as they are. The child sees "Ein Geschenk für dich!" on the home screen.

## Setting the level per subject

In the child's profile (⚙️ → solve the question → the child) under **Niveau pro
Fach**, − and + set each subject's level in half years, e.g. Mathe like a
9½-year-old and Wörter like an 8-year-old. Tap **Speichern**. Stars, streak and
progress stay as they are, and each subject keeps adapting from the new level.

## Getting harder by itself

Each subject adapts to the child. After **two rounds in a row with everything
right**, every further perfect round makes that subject noticeably harder, up to
**3 years above the child's age**. A round that goes badly makes it a bit easier
again. You can see each subject's level under ⚙️ → the child's profile →
**Fortschritt** (e.g. "Niveau wie mit 8½ Jahren"). Changing the age or "Fortschritt
zurücksetzen" starts again from the real age.

## Good to know

- **Each device keeps its own profiles and stars.** Nothing is sent anywhere,
  so progress doesn't move from one device to another.
- **Use the home-screen icon, not a Safari tab.** Safari may delete the data of
  websites in tabs you haven't visited for a few weeks. Apps added to the home
  screen are kept.
- **Read-aloud** uses the voices built into the device. For a nicer German voice
  on an iPhone: Settings → Accessibility → Spoken Content → Voices → German.
- **The address is public.** Anyone who knows the link could open Funkel, but
  nobody can see your children's data, because it only exists on your devices.
- **Vibration** works on Android only; iPhones don't allow it for web apps. Sounds,
  read-aloud, confetti and everything else work everywhere.
- **Updates** arrive automatically the next time Funkel is opened with internet.

## For developers

```bash
cd web
npm install
npm run dev
```

Other scripts: `npm test` runs the unit tests (which use the same rules and
content as the iOS tests) and `npm run build` builds into `web/dist`. The build
copies `../Content` and converts the iOS String Catalog to `ui-strings.json`, so
new content or translations need no web code changes.
