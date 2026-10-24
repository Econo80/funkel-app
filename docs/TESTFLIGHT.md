# TestFlight: getting Funkel onto your children's devices

No Mac needed. GitHub Actions builds, signs and uploads the app; the
TestFlight app installs it on iPhone/iPad. You do the one-time setup below
in a browser, then each release is one click.

## What you need

- **Apple Developer Program membership**: 99 USD (or local equivalent) per year.
  Enrol as an **Individual** with your **personal** Apple ID (two-factor
  authentication on). Without a Mac, the easiest way is the **Apple Developer**
  app on an iPhone or iPad. Otherwise use
  <https://developer.apple.com/programs/enroll/>. Approval can take up to 48 hours.
  As an individual, your legal name is shown as the developer if you ever
  publish publicly. TestFlight testers see it too.
- The GitHub repo `Econo80/funkel-app` (already set up) and the `gh` CLI on this
  machine (already signed in).

## One-time setup (about 20 minutes)

### 1. Choose a bundle ID

A unique reverse-domain name that will identify the app forever, for example
`com.yourname.funkel` (letters, digits, dots, hyphens). It can't be changed
after the first upload, so pick one you're happy with.

### 2. Register the bundle ID

<https://developer.apple.com/account/resources/identifiers/list>

**+** → **App IDs** → **App** → Description `Funkel` → **Explicit** Bundle ID → your
ID from step 1 → no capabilities needed → **Register**.

### 3. Create the app in App Store Connect

<https://appstoreconnect.apple.com/apps>

**+** → **New App**:

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | Must be unique on the whole App Store. "Funkel" may be taken; try e.g. "Funkel – Lernen für Kinder". You can change it later. |
| Primary Language | German |
| Bundle ID | the one from step 2 |
| SKU | anything, e.g. `funkel-001` |
| User Access | Full Access |

### 4. Create an App Store Connect API key

<https://appstoreconnect.apple.com/access/integrations/api>

The first time, click **Request Access** and accept. Then under **Team Keys**,
click **+**:
- Name: `GitHub Actions`
- Access: **Admin**. Xcode needs this to create the distribution certificate
  and provisioning profile in the cloud, so you never handle certificate files.

**Download** the key (`AuthKey_XXXXXXXXXX.p8`). Apple lets you download it
**only once**. Also note the **Key ID** (next to the key) and the **Issuer ID**
(at the top of the page).

The key can upload builds and manage signing for your account. Keep the file
private, and revoke the key on the same page if it ever leaks.

### 5. Find your Team ID

<https://developer.apple.com/account> → **Membership details** → **Team ID**
(10 characters, e.g. `ABCDE12345`).

### 6. Store everything in GitHub

Open PowerShell in the project folder and run these, replacing the values with yours.

```powershell
gh variable set APPLE_TEAM_ID --body "ABCDE12345"
gh variable set BUNDLE_ID --body "com.yourname.funkel"
gh secret set ASC_KEY_ID --body "XXXXXXXXXX"
gh secret set ASC_ISSUER_ID --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
Get-Content -Raw "$HOME\Downloads\AuthKey_XXXXXXXXXX.p8" | gh secret set ASC_KEY_P8
```

The team ID and bundle ID aren't secret, so they're stored as variables. The key is
encrypted by GitHub and never shown again, not even to you. Afterwards you can
delete the downloaded `.p8` file or keep it somewhere safe.

## Releasing a build

```powershell
gh workflow run testflight.yml
```

or **Actions → TestFlight → Run workflow** on GitHub. It takes about 10–15 minutes.
Apple then processes the build for another 5–30 minutes, and you get an email
when it's ready.

Each run uploads a new build number automatically. TestFlight builds expire
after **90 days**; just run the workflow again.

## Installing on the children's devices

In App Store Connect → your app → **TestFlight**:

**Internal testing (simplest, no review).** Create a group (e.g. "Familie") and
add yourself. Internal testers must be users of your App Store Connect team,
which you already are. On each child's iPhone/iPad:

1. Install **TestFlight** from the App Store.
2. Make sure the device's App Store account (Settings → your name → Media &
   Purchases) is your Apple ID, or one you've added as an App Store Connect user.
3. Open the invitation email (or TestFlight itself) and tap **Install**.

**External testing** is for Apple IDs that aren't team users, such as a
grandparent's iPad. Create an external group and invite by email or public
link. The first build of each version needs a brief **Beta App Review**
(usually within a day), and App Store Connect asks for a short test
description and a feedback email. Apple's TestFlight terms have age rules,
so for children's own Apple IDs check the current terms. Installing through
your own Apple ID (internal testing) avoids the question.

## Troubleshooting

| Error in the workflow summary | Fix |
|---|---|
| `Missing: …` | A secret or variable from step 6 isn't set. Check the names, which are case-sensitive. |
| `No profiles for '…' were found` / `No Accounts` | The bundle ID isn't registered (step 2), `BUNDLE_ID` doesn't match it exactly, or the API key isn't **Admin**. |
| `Error Downloading App Information` / app not found | The app record in App Store Connect is missing or uses a different bundle ID (step 3). |
| `Invalid Issuer` / `Authentication failed` | Key ID or Issuer ID swapped or mistyped, or the key was revoked. |
| `The bundle version must be higher …` | Should never happen: builds are numbered by the workflow run. If you deleted and re-created the workflow, raise `CURRENT_PROJECT_VERSION` in the run. |

To ship a new *version* (e.g. 0.2), change `MARKETING_VERSION` in the Xcode
project. New builds of the same version only need a new run.
