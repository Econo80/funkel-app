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
