# Trying Funkel on your iPhone for free (sideloading)

This puts Funkel on your iPhone without the App Store and without paying
Apple. The catch: Apple only allows this for **7 days** at a time. After that
the app won't open until you repeat the last step (takes a minute, and your
children's stars and progress are kept).

## What you need

- An **iPhone or iPad with iOS 17 or newer** (Settings → General → About → iOS Version).
- A **USB cable** for the phone.
- A **Windows computer where you're allowed to install programs.** A work laptop
  often blocks this. A personal PC is best.
- An **Apple ID.** Tip: create a separate free Apple ID just for this at
  <https://account.apple.com>. That way you never type your main Apple ID
  password into a non-Apple program.

## Step 1: get the app file

Download **`Funkel.ipa`**. It's an app file, like a zip of the app.
Either use the copy I sent you, or on GitHub open **Actions → Sideload build**,
click the latest green run, and download **Funkel-ipa** under *Artifacts*.
(GitHub wraps it in a `.zip`; double-click to get `Funkel.ipa` out.)

## Step 2: install Sideloadly on the PC

Sideloadly is a free Windows program that signs the app with your Apple ID and
copies it onto the phone.

1. Download it **only** from the official site: <https://sideloadly.io>
2. Install it. Its website says which Apple programs it also needs on Windows
   (usually **iTunes** and **iCloud**, the versions downloaded from apple.com,
   not from the Microsoft Store). Install those too.

## Step 3: connect the phone

1. Plug the iPhone into the PC with the cable and unlock it.
2. If the phone asks **"Trust This Computer?"**, tap **Trust** and enter your passcode.

## Step 4: put Funkel on the phone

1. Open **Sideloadly**.
2. Drag **`Funkel.ipa`** onto the Sideloadly window (the big IPA icon).
3. Check that your iPhone appears in the **iDevice** box.
4. Type your Apple ID email into the **Apple account** box.
5. Click **Start**, then enter your Apple ID password and the 6-digit code
   Apple sends to your devices.
6. Wait until it says **Done**. Funkel's icon (the yellow smiley) is now on the phone.

## Step 5: allow the app on the phone (first time only)

Apple blocks apps installed this way until you say you trust them.

1. **Trust yourself as the developer:** Settings → General → **VPN & Device
   Management** → tap your Apple ID email → **Trust**.
2. **Turn on Developer Mode:** Settings → Privacy & Security → scroll to the
   bottom → **Developer Mode** → on. The phone restarts; afterwards tap **Turn On**
   and enter your passcode. (If you don't see Developer Mode yet, try opening
   Funkel once first, then look again.)

Now open Funkel. To create the first child's profile, tap **Profil anlegen**
and solve the grown-up maths question.

## Every 7 days

When Funkel stops opening (or Sideloadly reminds you), plug the phone in and
repeat **Step 4**. Progress and stars are kept, as long as you don't delete the
app from the phone.

## If something goes wrong

| What you see | What to do |
|---|---|
| "Untrusted Developer" when opening Funkel | Step 5.1 |
| "Developer Mode Required" | Step 5.2 |
| Sideloadly doesn't see the phone | Unlock the phone, tap Trust, try another cable or USB port, make sure iTunes is installed. |
| "Maximum number of apps" | A free Apple ID can run 3 sideloaded apps at once. Delete another one. |
| The app opens and closes immediately | The 7 days are over. Repeat Step 4. |

Liked it? Paying for the Apple Developer Program removes the 7-day limit and
the cable: see [TESTFLIGHT.md](TESTFLIGHT.md).
