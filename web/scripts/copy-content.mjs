// Prepares shared files for the web build (run by `npm run content`):
//
// 1. Copies the learning content (../Content, also used by the iOS app) into
//    public/Content and writes languages.json, because a browser can't list
//    folders. Adding Content/fr/ therefore needs no web code change.
// 2. Converts the iOS app's String Catalog (UI texts) into public/ui-strings.json,
//    so both apps share one set of translations. Swift format specifiers
//    (%@, %lld, %1$lld) become {1}, {2}, …; plural variants are kept.
import { cpSync, existsSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, "..", "..");
const publicDir = join(here, "..", "public");

// 1. Learning content
const source = join(repo, "Content");
const target = join(publicDir, "Content");
rmSync(target, { recursive: true, force: true });
cpSync(source, target, { recursive: true });
const languages = readdirSync(target, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && existsSync(join(target, entry.name, "manifest.json")))
  .map((entry) => entry.name)
  .sort();
writeFileSync(join(target, "languages.json"), JSON.stringify(languages) + "\n");

// 2. UI strings
const catalog = JSON.parse(readFileSync(join(repo, "Funkel", "Resources", "Localizable.xcstrings"), "utf8"));

function convertFormat(value) {
  let next = 0;
  return value.replace(/%(?:(\d+)\$)?(?:lld|ld|d|@)/g, (_, position) => `{${position ?? ++next}}`);
}

const strings = {};
for (const [key, entry] of Object.entries(catalog.strings)) {
  for (const [lang, localization] of Object.entries(entry.localizations ?? {})) {
    strings[lang] ??= {};
    const plural = localization.variations?.plural;
    if (plural) {
      strings[lang][key] = Object.fromEntries(Object.entries(plural).map(([form, v]) => [form, convertFormat(v.stringUnit.value)]));
    } else if (localization.stringUnit) {
      strings[lang][key] = convertFormat(localization.stringUnit.value);
    }
  }
}
writeFileSync(
  join(publicDir, "ui-strings.json"),
  JSON.stringify({ sourceLanguage: catalog.sourceLanguage, strings }, null, 1) + "\n",
);

console.log(`Content: ${languages.join(", ")} · UI strings: ${Object.keys(strings).join(", ")}`);
