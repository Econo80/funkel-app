// UI texts (menus, buttons) in the device language, from the iOS app's
// String Catalog (converted to ui-strings.json at build time). Learning
// content has its own language (the profile's), see content/phrasing.ts.

type Entry = string | Record<string, string>;
interface UiStrings {
  sourceLanguage: string;
  strings: Record<string, Record<string, Entry>>;
}

let table: Record<string, Entry> = {};
let locale = "de";

export async function loadUiStrings(base: string): Promise<void> {
  const data = (await (await fetch(`${base}ui-strings.json`)).json()) as UiStrings;
  const available = Object.keys(data.strings);
  const preferred = (navigator.languages ?? [navigator.language]).map((l) => l.split("-")[0]);
  locale = preferred.find((l) => available.includes(l)) ?? data.sourceLanguage;
  // Missing keys fall back to the source language.
  table = { ...data.strings[data.sourceLanguage], ...data.strings[locale] };
  document.documentElement.lang = locale;
}

const plurals = () => new Intl.PluralRules(locale);

/**
 * Looks up a catalog key, e.g. t("home.greeting %@", "Lena").
 * Plural keys pick their form from the first numeric argument.
 */
export function t(key: string, ...args: (string | number)[]): string {
  const entry = table[key];
  if (entry === undefined) {
    console.warn(`Missing UI string '${key}'`);
    return key;
  }
  let text: string;
  if (typeof entry === "string") {
    text = entry;
  } else {
    const n = args.find((a): a is number => typeof a === "number") ?? 0;
    text = entry[plurals().select(n)] ?? entry.other ?? Object.values(entry)[0];
  }
  return text.replace(/\{(\d+)\}/g, (_, i) => String(args[Number(i) - 1] ?? ""));
}
