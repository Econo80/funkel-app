import { describe, expect, it } from "vitest";
import type { WordEntry } from "../src/content/types";
import { MATHS_OPERATIONS, difficultyForAge, isEligible } from "../src/domain/difficulty";
import { correctAnswerText, spokenText } from "../src/domain/question";
import { randomElement, seededRng } from "../src/domain/random";
import { apply, distractors, makeProblem, type Arithmetic } from "../src/providers/maths";
import { QuestionBankProvider, isUsable } from "../src/providers/questionBank";
import { withSeen } from "../src/domain/profile";
import { VocabularyQuestionGenerator } from "../src/providers/vocabulary";
import { AGES, germanProvider } from "./helpers";

describe("maths (mirrors MathsGeneratorTests.swift)", () => {
  it("keeps problems inside each age's ranges", () => {
    const rng = seededRng(42);
    const kinds: Arithmetic[] = ["add", "subtract", "multiply", "divide"];
    for (const age of AGES) {
      const d = difficultyForAge(age).maths;
      for (const op of MATHS_OPERATIONS) {
        for (let i = 0; i < 300; i++) {
          const kind = randomElement(rng, kinds)!;
          const p = makeProblem(rng, op, d, op === "wordProblem" ? kind : undefined);
          if (p.arithmetic) expect(apply(p.arithmetic, p.a, p.b)).toBe(p.result);
          expect(p.answer).toBe(op === "missingNumber" ? p.b : p.result);
          if (op === "counting" || op === "numberRecognition") expect(p.answer).toBeGreaterThanOrEqual(1);
          if (op === "addition") expect(p.result).toBeLessThanOrEqual(d.addSubResultMax);
          if (op === "subtraction" && !d.allowsNegativeResults) expect(p.result).toBeGreaterThan(0);
          if (op === "division") expect(p.a % p.b).toBe(0);
          if (op === "wordProblem") {
            expect(Math.min(p.a, p.b)).toBeGreaterThanOrEqual(2);
            expect(p.result).toBeGreaterThan(0);
            if (p.arithmetic === "divide") expect(p.a % p.b).toBe(0);
          }
        }
      }
    }
  });

  it("produces unique distractors that are never the answer", () => {
    const rng = seededRng(99);
    for (const age of AGES) {
      const d = difficultyForAge(age);
      for (const op of MATHS_OPERATIONS) {
        for (let i = 0; i < 100; i++) {
          const p = makeProblem(rng, op, d.maths);
          const wrong = distractors(rng, p, 3, d.maths.allowsNegativeResults);
          expect(wrong).toHaveLength(3);
          expect(new Set(wrong).size).toBe(3);
          expect(wrong).not.toContain(p.answer);
          if (!d.maths.allowsNegativeResults) expect(wrong.every((v) => v >= 0)).toBe(true);
        }
      }
    }
  });

  it("builds full rounds with the right input for each age", async () => {
    const provider = await germanProvider("maths");
    const rng = seededRng(2026);
    for (const age of AGES) {
      const d = difficultyForAge(age);
      const questions = provider.makeQuestions(10, d, new Set(), rng);
      expect(questions).toHaveLength(10);
      for (const q of questions) {
        expect(q.prompt).not.toContain("{");
        if (q.format.kind === "multipleChoice") {
          expect(d.maths.usesNumberPad).toBe(false);
          expect(q.format.options).toHaveLength(d.answerOptionCount);
          expect(new Set(q.format.options.map((o) => o.text)).size).toBe(q.format.options.length);
        } else if (q.format.kind !== "numberHouse") {
          expect(q.format.kind).toBe("numberEntry");
          expect(d.maths.usesNumberPad).toBe(true);
        }
        if (q.spoken) expect(spokenText(q)).not.toMatch(/[·−]/);
      }
    }
  });
});

describe("vocabulary (mirrors VocabularyGeneratorTests.swift)", () => {
  it("builds full rounds without repeats at every age", async () => {
    const provider = (await germanProvider("vocabulary")) as VocabularyQuestionGenerator;
    const rng = seededRng(1);
    for (const age of AGES) {
      const d = difficultyForAge(age);
      const questions = provider.makeQuestions(10, d, new Set(), rng);
      expect(questions, `age ${age}`).toHaveLength(10);
      expect(new Set(questions.map((q) => q.contentId)).size).toBe(10);
      for (const q of questions) {
        if (q.format.kind === "buildSequence") {
          expect(q.format.answer.length).toBeLessThanOrEqual(d.vocabulary.spellingMaxLength);
          const pool = [...q.format.tiles];
          for (const letter of q.format.answer) {
            const i = pool.indexOf(letter);
            expect(i).toBeGreaterThanOrEqual(0);
            pool.splice(i, 1);
          }
        } else if (q.format.kind === "multipleChoice") {
          expect(q.format.options.length).toBeLessThanOrEqual(d.answerOptionCount);
          expect(new Set(q.format.options.map((o) => o.text)).size).toBe(q.format.options.length);
        }
      }
    }
  });

  it("checks answers against the word list and never offers a related word as wrong", async () => {
    const provider = (await germanProvider("vocabulary")) as VocabularyQuestionGenerator;
    const entries = new Map<string, WordEntry>(provider.words.map((w) => [w.word, w]));
    const rng = seededRng(3);
    for (const age of [6, 9, 12]) {
      for (const q of provider.makeQuestions(80, difficultyForAge(age), new Set(), rng)) {
        const entry = entries.get(q.contentId!.replace("vocab:", ""))!;
        const answer = correctAnswerText(q.format);
        if (q.prompt.includes("Gegenteil")) expect(entry.antonyms).toContain(answer);
        if (q.prompt.includes("Gleiche")) expect(entry.synonyms).toContain(answer);
        if (q.prompt.startsWith("Was bedeutet")) expect(answer).toBe(entry.definition);
        if (q.format.kind === "buildSequence") expect(answer).toBe(entry.word);
        if ((q.prompt.includes("Gegenteil") || q.prompt.includes("Gleiche")) && q.format.kind === "multipleChoice") {
          const family = provider.family(entry);
          const fmt = q.format;
          fmt.options.forEach((o, i) => { if (i !== fmt.correctIndex) expect(family.has(o.text)).toBe(false); });
        }
      }
    }
  });
});

describe("question bank (mirrors QuestionBankTests.swift)", () => {
  it("asks country questions only in that country", async () => {
    const provider = (await germanProvider("generalKnowledge")) as QuestionBankProvider;
    const of = (country?: string) => {
      const p = new QuestionBankProvider("generalKnowledge", provider.items, { country });
      const ids = new Set<string>();
      for (let i = 0; i < 40; i++) for (const q of p.makeQuestions(20, difficultyForAge(9), new Set(), seededRng(i))) ids.add(q.contentId!);
      return [...ids].map((id) => provider.items.find((i) => i.id === id)!);
    };
    const swiss = of("CH");
    expect(swiss.every((i) => !i.countries || i.countries.includes("CH"))).toBe(true);
    expect(swiss.some((i) => i.countries?.includes("CH"))).toBe(true);
    expect(swiss.some((i) => i.prompt.includes("Bundesländer hat Deutschland"))).toBe(false);
    expect(of("DE").some((i) => i.countries?.includes("DE"))).toBe(true);
    expect(of(undefined).every((i) => !i.countries)).toBe(true);
    // Every country has enough of its own questions, for young and older children.
    for (const c of ["CH", "DE", "AT"]) {
      for (const age of [6, 9, 12]) {
        const own = provider.items.filter((i) => i.countries?.includes(c) && isEligible(difficultyForAge(age), i.minAge, i.maxAge));
        expect(own.length, `${c} at ${age}`).toBeGreaterThanOrEqual(5);
      }
    }
  });

  it("asks questions never asked before first, then the ones asked longest ago", async () => {
    const provider = (await germanProvider("generalKnowledge")) as QuestionBankProvider;
    const d = difficultyForAge(7);
    const pool = provider.items.filter((i) => isEligible(d, i.minAge, i.maxAge) && (!i.countries || i.countries.includes("CH")));
    expect(pool.length).toBeGreaterThan(150);
    // Round after round, nothing repeats until the whole pool was asked.
    let seen: string[] = [];
    const asked = new Set<string>();
    const rounds = Math.floor(pool.length / 10);
    for (let r = 0; r < rounds; r++) {
      const p = new QuestionBankProvider("generalKnowledge", provider.items, { country: "CH", seen });
      const ids = p.makeQuestions(10, d, new Set(), seededRng(r)).map((q) => q.contentId!);
      for (const id of ids) {
        expect(asked.has(id), `round ${r} repeats ${id}`).toBe(false);
        asked.add(id);
      }
      seen = withSeen(seen, ids);
    }
    // Once everything was asked, the last round's questions don't come straight back.
    const all = pool.map((i) => i.id);
    const recent = all.slice(-10);
    const p = new QuestionBankProvider("generalKnowledge", provider.items, { country: "CH", seen: withSeen(all.slice(0, -10), recent) });
    let back = 0;
    for (let i = 0; i < 20; i++) back += p.makeQuestions(10, d, new Set(), seededRng(100 + i)).filter((q) => recent.includes(q.contentId!)).length;
    expect(back).toBeLessThan(5);
  });

  it("has only usable items and fills rounds at every age", async () => {
    const provider = (await germanProvider("generalKnowledge")) as QuestionBankProvider;
    expect(provider.items.length).toBeGreaterThanOrEqual(100);
    expect(provider.items.every(isUsable)).toBe(true);
    const rng = seededRng(10);
    for (const age of AGES) {
      const d = difficultyForAge(age);
      const questions = provider.makeQuestions(10, d, new Set(), rng);
      expect(questions).toHaveLength(10);
      expect(new Set(questions.map((q) => q.contentId)).size).toBe(10);
      for (const q of questions) {
        const item = provider.items.find((i) => i.id === q.contentId)!;
        expect(isEligible(d, item.minAge, item.maxAge)).toBe(true);
        if (q.format.kind === "multipleChoice") expect(correctAnswerText(q.format)).toBe(item.correct);
      }
    }
  });

  it("adds sequence distractors only from age 8", async () => {
    const provider = (await germanProvider("generalKnowledge")) as QuestionBankProvider;
    const butterfly = provider.items.find((i) => i.id === "gk-de-0030")!;
    const solo = new QuestionBankProvider("generalKnowledge", [butterfly]);
    const young = solo.makeQuestions(1, difficultyForAge(6), new Set(), seededRng(1))[0].format;
    const older = solo.makeQuestions(1, difficultyForAge(9), new Set(), seededRng(1))[0].format;
    expect(young.kind === "buildSequence" && young.tiles.includes("Kaulquappe")).toBe(false);
    expect(older.kind === "buildSequence" && older.tiles.includes("Kaulquappe")).toBe(true);
  });

  it("gives a shorter round instead of repeating", () => {
    const items = [
      { id: "a", minAge: 4, format: "multipleChoice" as const, prompt: "?", options: ["x", "y", "z"], correct: "x" },
      { id: "b", minAge: 4, format: "multipleChoice" as const, prompt: "?", options: ["x", "y"], correct: "q" },
    ];
    expect(new QuestionBankProvider("x", items).makeQuestions(5, difficultyForAge(6), new Set(), seededRng(2)).map((q) => q.contentId)).toEqual(["a"]);
  });
});
