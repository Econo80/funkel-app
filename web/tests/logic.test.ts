import { describe, expect, it } from "vitest";
import { difficultyForAge } from "../src/domain/difficulty";
import { createProfile, defaultSettings } from "../src/domain/profile";
import { seededRng } from "../src/domain/random";
import {
  TEST_QUESTIONS, canTakeTest, daysUntilTest, makeThinkingTest, recordThinkingTest, shouldStopTest, testLevelAge, testStepAges,
} from "../src/domain/thinkingTest";
import { MISSING, SHAPES } from "../src/providers/logic";
import { weekSummary } from "../src/domain/weekly";
import { germanProvider } from "./helpers";

const shapeOf = (e: string) => SHAPES.findIndex((row) => row.includes(e));
const colourOf = (e: string) => SHAPES[shapeOf(e)].indexOf(e);

describe("Denken puzzles", () => {
  it("are fair at every age: one right answer among distinct options, kinds unlocked by age", async () => {
    const provider = await germanProvider("logic");
    const rng = seededRng(3);
    for (const age of [4, 5, 6, 7, 8, 9, 10, 11, 12, 14]) {
      const d = difficultyForAge(age);
      const questions = provider.makeQuestions(30, d, new Set(), rng);
      expect(questions.length).toBe(30);
      const kinds = new Set(questions.map((q) => q.skill));
      if (age < 5.5) expect([...kinds].sort()).toEqual(["oddOneOut", "pattern"]);
      if (age >= 9) expect(kinds.has("matrix") && kinds.has("numberSequence")).toBe(true);
      for (const q of questions) {
        if (q.format.kind === "multipleChoice") {
          const texts = q.format.options.map((o) => o.text);
          expect(new Set(texts).size, q.prompt).toBe(texts.length);
          expect(texts.length).toBe(q.skill === "oddOneOut" ? 4 : d.answerOptionCount);
          expect(q.format.correctIndex).toBeGreaterThanOrEqual(0);
        } else {
          expect(q.format.kind).toBe("numberEntry");
        }
        if (q.visual?.kind === "tiles") expect(q.visual.items.filter((x) => x === MISSING)).toHaveLength(1);
      }
    }
  });

  it("builds 3×3 fields where the answer follows both rules (shape and colour)", async () => {
    const provider = await germanProvider("logic");
    const rng = seededRng(9);
    for (const age of [7, 9]) {
      const matrices = provider.makeQuestions(40, difficultyForAge(age), new Set(), rng).filter((q) => q.skill === "matrix");
      expect(matrices.length).toBeGreaterThan(3);
      for (const q of matrices) {
        if (q.visual?.kind !== "tiles" || q.format.kind !== "multipleChoice") throw new Error("matrix shape");
        const answer = q.format.options[q.format.correctIndex].text;
        const cells = q.visual.items.map((x) => (x === MISSING ? answer : x));
        for (let r = 0; r < 3; r++) {
          const row = cells.slice(r * 3, r * 3 + 3);
          const col = [cells[r], cells[r + 3], cells[r + 6]];
          if (age >= 8) {
            // Every row and column has each shape and each colour once.
            for (const line of [row, col]) {
              expect(new Set(line.map(shapeOf)).size).toBe(3);
              expect(new Set(line.map(colourOf)).size).toBe(3);
            }
          } else {
            expect(new Set(row.map(shapeOf)).size).toBe(1);
            expect(new Set(col.map(colourOf)).size).toBe(1);
          }
        }
      }
    }
  });

  it("makes number sequences whose answer follows the rule", async () => {
    const provider = await germanProvider("logic");
    const rng = seededRng(5);
    const sequences = provider.makeQuestions(60, difficultyForAge(7), new Set(), rng).filter((q) => q.skill === "numberSequence");
    for (const q of sequences) {
      if (q.visual?.kind !== "equation" || q.format.kind !== "multipleChoice") continue;
      const answer = Number(q.format.options[q.format.correctIndex].text);
      const values = q.visual.text.split(", ").map((x) => (x === "?" ? answer : Number(x)));
      const steps = values.slice(1).map((v, i) => v - values[i]);
      expect(new Set(steps).size, q.visual.text).toBe(1); // under 8.5: always the same step
    }
  });
});

describe("Denk-Test", () => {
  it("goes from two years below the age upwards, two puzzles per half year", async () => {
    expect(testStepAges(7)).toEqual([5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10, 10.5]);
    expect(testStepAges(4)[0]).toBe(4);
    expect(Math.max(...testStepAges(14))).toBe(14);
    const test = makeThinkingTest(await germanProvider("logic"), 7, seededRng(1));
    expect(test).toHaveLength(TEST_QUESTIONS);
    // The first step is too young for matrices; the last ones have them.
    expect(test.slice(0, 2).some((q) => q.skill === "matrix")).toBe(false);
  });

  it("stops after four wrong in a row and turns points into a Denk-Niveau", () => {
    expect(shouldStopTest([true, false, false, false])).toBe(false);
    expect(shouldStopTest([true, false, false, false, false])).toBe(true);
    expect(testLevelAge(7, 0)).toBe(4.5);
    expect(testLevelAge(7, 10)).toBe(7);
    expect(testLevelAge(7, 12)).toBe(7.5);
    expect(testLevelAge(7, 24)).toBe(10.5);
    expect(testLevelAge(4, 0)).toBe(4);
    expect(testLevelAge(13, 24)).toBe(14);
  });

  it("is kept, pays stars, counts in the week, and can be taken again after seven days", () => {
    const now = new Date(2026, 10, 28, 10);
    const p = { ...createProfile({ ...defaultSettings(), name: "Emil", age: 7 }, now), totalStars: 5, walletStars: 5 };
    expect(canTakeTest(p, now)).toBe(true);
    const { profile, result, stars } = recordThinkingTest(p, { points: 15, total: 24, skills: { matrix: [3, 5] }, subjectId: "logic", languageCode: "de" }, now);
    expect(result).toMatchObject({ age: 7, points: 15, total: 24, levelAge: 8 });
    expect(stars).toBe(8);
    expect(profile).toMatchObject({ totalStars: 13, walletStars: 13, currentStreak: 1 });
    expect(profile.thinkingTests).toHaveLength(1);
    expect(profile.progress).toEqual({}); // the Denken level isn't changed
    expect(weekSummary(profile, now).subjects[0]).toMatchObject({ subjectId: "logic", rounds: 1, correct: 15, questions: 24 });
    expect(canTakeTest(profile, new Date(2026, 11, 4, 10))).toBe(false);
    expect(daysUntilTest(profile, new Date(2026, 11, 4, 10))).toBe(1);
    expect(canTakeTest(profile, new Date(2026, 11, 5, 8))).toBe(true);
  });
});
