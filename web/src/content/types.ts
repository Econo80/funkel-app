// Schemas of the shared JSON files in Content/<lang>/ (same as the iOS app's
// ContentFiles.swift; scripts/validate_content.py checks them).

export type ProviderKind = "maths" | "wordList" | "questionBank";
export const PROVIDER_KINDS: readonly ProviderKind[] = ["maths", "wordList", "questionBank"];

export interface RawManifest {
  code: string;
  name: string;
  speechLocale: string;
  subjects: { id: string; provider: string; file: string; title: string; icon?: string; color?: string }[];
}

export interface SubjectDescriptor {
  id: string;
  languageCode: string;
  provider: ProviderKind;
  file: string;
  title: string;
  /** SF Symbol name from the manifest; mapped to an emoji/glyph on the web. */
  icon: string;
  color: string;
}

export interface ContentLanguage {
  code: string;
  name: string;
  speechLocale: string;
  subjects: SubjectDescriptor[];
}

export type PhrasingTemplates = Record<string, string>;

export interface MathsContent {
  names: string[];
  items: { singular: string; plural: string; emoji: string }[];
  wordProblems: { operation: "addition" | "subtraction" | "multiplication" | "division"; minAge: number; template: string }[];
}

export interface WordEntry {
  word: string;
  article?: string;
  emoji?: string;
  definition?: string;
  synonyms?: string[];
  antonyms?: string[];
  category?: string;
  minAge: number;
  maxAge?: number;
}

/** A sentence to copy (7–8) or write from dictation (9+). */
export interface SentenceEntry {
  text: string;
  minAge: number;
  maxAge?: number;
}

export interface WordList {
  words: WordEntry[];
  sentences?: SentenceEntry[];
}

export interface BankItem {
  id: string;
  category?: string;
  minAge: number;
  maxAge?: number;
  format: "multipleChoice" | "buildSequence";
  prompt: string;
  sentence?: string;
  emoji?: string;
  explanation?: string;
  options?: string[];
  correct?: string;
  answer?: string[];
  distractors?: string[];
}

export interface QuestionBank {
  questions: BankItem[];
}
