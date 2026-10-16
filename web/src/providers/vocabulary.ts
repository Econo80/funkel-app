// Vocabulary from a word list — port of VocabularyQuestionGenerator.swift.
import type { Phrasing } from "../content/phrasing";
import type { WordEntry } from "../content/types";
import { VOCABULARY_TYPES, isEligible, selectionWeight, type Difficulty, type VocabularyQuestionType } from "../domain/difficulty";
import { makeQuestion, type Question, type QuestionFormat } from "../domain/question";
import { randomElement, shuffled, weightedPick, type Rng } from "../domain/random";
import type { QuestionProvider } from "./provider";

const DISTRACTOR_LETTERS = [..."abcdefghiklmnoprstuäöü"];

export const contentIdFor = (word: WordEntry) => `vocab:${word.word}`;

const isLetter = (ch: string) => /\p{L}/u.test(ch);

/** Nouns with their article, as children learn them: "der Hund". */
const display = (w: WordEntry) => (w.article ? `${w.article} ${w.word}` : w.word);

export class VocabularyQuestionGenerator implements QuestionProvider {
  constructor(readonly subjectId: string, readonly words: WordEntry[], readonly phrasing: Phrasing) {}

  makeQuestions(count: number, difficulty: Difficulty, recentlyCorrect: Set<string>, rng: Rng): Question[] {
    const eligible = this.words.filter((w) => isEligible(difficulty, w.minAge, w.maxAge));
    if (eligible.length === 0) return [];

    const typeWeights = VOCABULARY_TYPES.map((t) => [t, difficulty.vocabulary.questionTypeWeights[t] ?? 0] as const);
    const used = new Set<string>();
    const questions: Question[] = [];

    for (let attempts = 0; questions.length < count && attempts < count * 20; attempts++) {
      const type = weightedPick(rng, typeWeights);
      if (!type) break;
      let candidates = eligible.filter((w) => this.supports(w, type, difficulty) && !used.has(w.word));
      // Small lists: allow repeats rather than ending the round early.
      if (candidates.length === 0) candidates = eligible.filter((w) => this.supports(w, type, difficulty));
      const word = weightedPick(rng, candidates.map((w) => [w, selectionWeight(difficulty, w.minAge, recentlyCorrect.has(contentIdFor(w)))] as const));
      if (!word) continue;
      const question = this.makeQuestion(rng, type, word, eligible, difficulty);
      if (!question) continue;
      used.add(word.word);
      questions.push(question);
    }
    return questions;
  }

  private supports(w: WordEntry, type: VocabularyQuestionType, d: Difficulty): boolean {
    switch (type) {
      case "pictureToWord":
      case "wordToPicture":
        return !!w.emoji;
      case "meaning":
        return !!w.definition;
      case "spelling":
        return [...w.word].length <= d.vocabulary.spellingMaxLength && [...w.word].every(isLetter) && (!!w.emoji || !!w.definition);
      case "opposite":
        return (w.antonyms ?? []).length > 0;
      case "synonym":
        return (w.synonyms ?? []).length > 0;
    }
  }

  /**
   * The word, its synonyms and antonyms, and theirs in turn. None may be a
   * wrong answer, because some could also be right: "riesig" (≈ groß) is
   * also an opposite of "klein".
   */
  family(word: WordEntry): Set<string> {
    const core = new Set([word.word, ...(word.synonyms ?? []), ...(word.antonyms ?? [])]);
    const family = new Set(core);
    for (const entry of this.words) {
      const related = [...(entry.synonyms ?? []), ...(entry.antonyms ?? [])];
      if (core.has(entry.word) || related.some((r) => core.has(r))) {
        family.add(entry.word);
        related.forEach((r) => family.add(r));
      }
    }
    return family;
  }

  private relatedPool(excluded: Set<string>): string[] {
    const pool = new Set<string>();
    for (const entry of this.words) {
      if (!entry.synonyms && !entry.antonyms) continue;
      pool.add(entry.word);
      (entry.synonyms ?? []).forEach((s) => pool.add(s));
      (entry.antonyms ?? []).forEach((a) => pool.add(a));
    }
    return [...pool].filter((w) => !excluded.has(w)).sort();
  }

  private choice(rng: Rng, correct: string, wrong: string[]): QuestionFormat | undefined {
    const seen = new Set([correct]);
    const unique = wrong.filter((w) => (seen.has(w) ? false : (seen.add(w), true)));
    if (unique.length === 0) return undefined;
    const values = shuffled(rng, [correct, ...unique]);
    return { kind: "multipleChoice", options: values.map((text, id) => ({ id, text })), correctIndex: values.indexOf(correct) };
  }

  private makeQuestion(rng: Rng, type: VocabularyQuestionType, word: WordEntry, pool: WordEntry[], d: Difficulty): Question | undefined {
    const contentId = contentIdFor(word);
    const wrongCount = d.answerOptionCount - 1;
    const subjectId = this.subjectId;

    switch (type) {
      case "pictureToWord": {
        const others = pool.filter((w) => w.word !== word.word && w.emoji && w.emoji !== word.emoji);
        const format = this.choice(rng, display(word), shuffled(rng, others).slice(0, wrongCount).map(display));
        if (!format) return undefined;
        return makeQuestion({ subjectId, contentId, prompt: this.phrasing.text("vocab.pictureToWord"), visual: word.emoji ? { kind: "emoji", emoji: word.emoji } : undefined, format });
      }
      case "wordToPicture": {
        if (!word.emoji) return undefined;
        const others = shuffled(rng, pool.filter((w) => w.word !== word.word && w.emoji && w.emoji !== word.emoji)).slice(0, wrongCount);
        if (others.length === 0) return undefined;
        const entries = shuffled(rng, [word, ...others]);
        return makeQuestion({
          subjectId, contentId,
          prompt: this.phrasing.text("vocab.wordToPicture", { word: display(word) }),
          format: {
            kind: "multipleChoice",
            options: entries.map((w, id) => ({ id, text: display(w), emoji: w.emoji })),
            correctIndex: entries.findIndex((w) => w.word === word.word),
          },
        });
      }
      case "meaning": {
        if (!word.definition) return undefined;
        const others = [...new Set(pool.map((w) => w.definition).filter((x): x is string => !!x && x !== word.definition))].sort();
        const format = this.choice(rng, word.definition, shuffled(rng, others).slice(0, wrongCount));
        if (!format) return undefined;
        return makeQuestion({
          subjectId, contentId,
          prompt: this.phrasing.text("vocab.meaning", { word: word.word }),
          visual: d.usesPictureOptions && word.emoji ? { kind: "emoji", emoji: word.emoji } : undefined,
          format,
        });
      }
      case "opposite":
      case "synonym": {
        const related = (type === "opposite" ? word.antonyms : word.synonyms) ?? [];
        const correct = randomElement(rng, related);
        if (!correct) return undefined;
        const format = this.choice(rng, correct, shuffled(rng, this.relatedPool(this.family(word))).slice(0, wrongCount));
        if (!format) return undefined;
        return makeQuestion({
          subjectId, contentId,
          prompt: this.phrasing.text(type === "opposite" ? "vocab.opposite" : "vocab.synonym", { word: word.word }),
          format,
        });
      }
      case "spelling": {
        const letters = [...word.word];
        const extra = Array.from({ length: d.vocabulary.spellingDistractorLetters }, () => randomElement(rng, DISTRACTOR_LETTERS) ?? "e");
        return makeQuestion({
          subjectId, contentId,
          prompt: this.phrasing.text("vocab.spelling"),
          sentence: word.emoji ? undefined : word.definition,
          visual: word.emoji ? { kind: "emoji", emoji: word.emoji } : undefined,
          format: { kind: "buildSequence", tiles: shuffled(rng, [...letters, ...extra]), answer: letters },
          spoken: this.phrasing.text("vocab.spelling.spoken", { word: word.word }),
        });
      }
    }
  }
}
