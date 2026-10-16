import { Phrasing } from "./phrasing";
import {
  PROVIDER_KINDS,
  type ContentLanguage,
  type MathsContent,
  type ProviderKind,
  type QuestionBank,
  type RawManifest,
  type SubjectDescriptor,
  type WordList,
} from "./types";

export const FALLBACK_LANGUAGE = "de";

/** Reads a JSON file under Content/. Injected so tests can read from disk. */
export type JsonLoader = (path: string) => Promise<unknown>;

export const fetchLoader = (base: string): JsonLoader => async (path) => {
  const response = await fetch(`${base}${path}`);
  if (!response.ok) throw new Error(`Could not load ${path} (${response.status})`);
  return response.json();
};

/**
 * Discovers content languages (Content/languages.json, written at build time)
 * and loads their files, cached. Subjects with an unknown provider kind are
 * skipped so newer content can't break the app.
 */
export class ContentLibrary {
  private cache = new Map<string, Promise<unknown>>();

  private constructor(private readonly load: JsonLoader, readonly languages: ContentLanguage[]) {}

  static async create(load: JsonLoader): Promise<ContentLibrary> {
    const codes = (await load("languages.json")) as string[];
    const languages: ContentLanguage[] = [];
    for (const code of codes) {
      try {
        const manifest = (await load(`${code}/manifest.json`)) as RawManifest;
        languages.push(makeLanguage(manifest, code));
      } catch (error) {
        console.error(`Invalid manifest for ${code}`, error);
      }
    }
    return new ContentLibrary(load, languages);
  }

  language(code: string): ContentLanguage | undefined {
    return this.languages.find((l) => l.code === code);
  }

  resolvedLanguage(code: string): ContentLanguage | undefined {
    return this.language(code) ?? this.language(FALLBACK_LANGUAGE) ?? this.languages[0];
  }

  private file<T>(language: string, file: string): Promise<T> {
    const key = `${language}/${file}`;
    if (!this.cache.has(key)) this.cache.set(key, this.load(key));
    return this.cache.get(key) as Promise<T>;
  }

  async phrasing(language: string): Promise<Phrasing> {
    return new Phrasing(await this.file<Record<string, string>>(language, "strings.json"));
  }

  mathsContent(subject: SubjectDescriptor): Promise<MathsContent> {
    return this.file(subject.languageCode, subject.file);
  }

  wordList(subject: SubjectDescriptor): Promise<WordList> {
    return this.file(subject.languageCode, subject.file);
  }

  questionBank(subject: SubjectDescriptor): Promise<QuestionBank> {
    return this.file(subject.languageCode, subject.file);
  }
}

function makeLanguage(manifest: RawManifest, folder: string): ContentLanguage {
  const subjects: SubjectDescriptor[] = [];
  for (const raw of manifest.subjects) {
    if (!PROVIDER_KINDS.includes(raw.provider as ProviderKind)) {
      console.info(`Skipping subject '${raw.id}': unknown provider '${raw.provider}'`);
      continue;
    }
    subjects.push({
      id: raw.id,
      languageCode: folder,
      provider: raw.provider as ProviderKind,
      file: raw.file,
      title: raw.title,
      icon: raw.icon ?? "star.fill",
      color: raw.color ?? "#FFB84D",
    });
  }
  return { code: folder, name: manifest.name, speechLocale: manifest.speechLocale, subjects };
}
