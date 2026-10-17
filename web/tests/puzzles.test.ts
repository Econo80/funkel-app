import { describe, expect, it } from "vitest";
import { difficultyForAge } from "../src/domain/difficulty";
import { createProfile, defaultSettings, normalizeProfile, recordSudoku, sudokuAge, sudokusSolved } from "../src/domain/profile";
import { correctAnswerText, houseCellValue, makeQuestion, type NumberHouse } from "../src/domain/question";
import { seededRng } from "../src/domain/random";
import * as R from "../src/domain/round";
import { countSolutions, makeSudoku, peers, sudokuLevelForAge, sudokuStars } from "../src/domain/sudoku";
import { makeNumberHouse } from "../src/providers/maths";
import { AGES, germanProvider } from "./helpers";

describe("Zahlenhaus", () => {
  it("only appears from age 5 and fades out after 9", () => {
    expect(difficultyForAge(4).maths.operationWeights.numberHouse).toBeUndefined();
    expect(difficultyForAge(5).maths.operationWeights.numberHouse).toBeGreaterThan(0);
    expect(difficultyForAge(6).maths.operationWeights.numberHouse).toBeGreaterThan(0);
    expect(difficultyForAge(10).maths.operationWeights.numberHouse).toBeUndefined();
  });

  it("builds correct houses that grow with age", () => {
    const rng = seededRng(7);
    for (const age of [5, 6, 7, 8, 9]) {
      const d = difficultyForAge(age).maths;
      for (let i = 0; i < 300; i++) {
        const h = makeNumberHouse(rng, d);
        expect(h.roof).toBeLessThanOrEqual(d.houseRoofMax);
        expect(h.floors.every(([l, r]) => l + r === h.roof && l >= 0 && r >= 0)).toBe(true);
        expect(new Set(h.floors.map(([l]) => l)).size).toBe(h.floors.length);
        // Every floor still has a number to go on, unless the roof is hidden and one floor is complete.
        const roofHidden = h.hidden.includes("roof");
        expect(roofHidden).toBe(roofHidden && d.houseHidesRoof);
        expect(h.hidden).toHaveLength(h.floors.length);
        if (age === 5) {
          expect(h.roof).toBeLessThanOrEqual(6);
          expect(h.floors).toHaveLength(2);
        }
      }
    }
  });

  it("appears in German maths rounds for young children", async () => {
    const provider = await germanProvider("maths");
    const rng = seededRng(11);
    const questions = Array.from({ length: 20 }, () => provider.makeQuestions(10, difficultyForAge(6), new Set(), rng)).flat();
    const houses = questions.filter((q) => q.format.kind === "numberHouse");
    expect(houses.length).toBeGreaterThan(10);
    expect(houses[0].prompt).toContain("Zahlenhaus");
    for (const age of AGES) {
      for (const q of provider.makeQuestions(10, difficultyForAge(age), new Set(), rng)) {
        if (q.format.kind === "numberHouse") expect(age).toBeGreaterThanOrEqual(5);
      }
    }
  });

  it("is filled room by room and checked as a whole", () => {
    const house: NumberHouse = { roof: 7, floors: [[2, 5], [3, 4]], hidden: ["f0r", "f1l"] };
    const q = makeQuestion({ subjectId: "maths", prompt: "", format: { kind: "numberHouse", house } });
    let s = R.startRound([q], false);
    expect(s.houseCell).toBe("f0r");
    s = R.houseDigit(s, 5);
    expect(s.houseCell).toBe("f1l"); // a full room moves on
    expect(R.canSubmitHouse(s)).toBe(false);
    s = R.houseDigit(s, 4);
    s = R.submitHouse(s);
    expect(s.phase).toBe("wrong");
    expect(R.wrongHouseCells(s)).toEqual(["f1l"]);
    expect(correctAnswerText(q.format)).toBe("7 = 2 + 5, 3 + 4");

    let t = R.startRound([q], false);
    t = R.houseDigit(R.houseDigit(t, 5), 3);
    expect(R.submitHouse(t).phase).toBe("correct");
    expect(houseCellValue(house, "f1l")).toBe(3);
  });

  it("takes two digits for bigger roofs and can be corrected", () => {
    const house: NumberHouse = { roof: 20, floors: [[12, 8]], hidden: ["roof", "f0l"] };
    const q = makeQuestion({ subjectId: "maths", prompt: "", format: { kind: "numberHouse", house } });
    let s = R.startRound([q], false);
    s = R.houseDigit(s, 2);
    expect(s.houseCell).toBe("roof");
    s = R.houseDelete(s);
    s = R.houseDigit(R.houseDigit(s, 2), 0);
    expect(s.houseInputs.roof).toBe("20");
    expect(s.houseCell).toBe("f0l");
    s = R.houseDigit(R.houseDigit(s, 1), 2);
    expect(R.submitHouse(s).phase).toBe("correct");
  });
});

describe("Sudoku", () => {
  it("grows from picture 4×4 to classic 9×9 with age", () => {
    expect(sudokuLevelForAge(4)).toMatchObject({ size: 4, pictures: true });
    expect(sudokuLevelForAge(6)).toMatchObject({ size: 4, pictures: false });
    expect(sudokuLevelForAge(8)).toMatchObject({ size: 6, boxRows: 2, boxCols: 3 });
    expect(sudokuLevelForAge(10).size).toBe(9);
    expect(sudokuLevelForAge(14).blanks).toBeGreaterThan(sudokuLevelForAge(10).blanks);
  });

  it("makes valid puzzles with exactly one solution", () => {
    const rng = seededRng(21);
    for (const age of [4, 6, 8, 9, 10, 13]) {
      const level = sudokuLevelForAge(age);
      for (let n = 0; n < (level.size === 9 ? 2 : 10); n++) {
        const { solution, given } = makeSudoku(level, rng);
        expect(solution).toHaveLength(level.size * level.size);
        solution.forEach((v, cell) => {
          expect(v).toBeGreaterThanOrEqual(1);
          expect(v).toBeLessThanOrEqual(level.size);
          for (const p of peers(level, cell)) expect(solution[p]).not.toBe(v);
        });
        const blanks = given.filter((g) => !g).length;
        expect(blanks).toBeGreaterThanOrEqual(Math.min(level.blanks, level.size === 9 ? level.blanks - 6 : level.blanks));
        expect(countSolutions(level, solution.map((v, i) => (given[i] ? v : 0)))).toBe(1);
      }
    }
  });

  it("rewards solved puzzles, a little less with help", () => {
    const level = sudokuLevelForAge(10);
    expect(sudokuStars(level, 0, 0)).toBe(level.stars);
    expect(sudokuStars(level, 3, 1)).toBe(level.stars - 2);
    expect(sudokuStars(level, 30, 30)).toBe(1);

    const p = createProfile({ ...defaultSettings(), name: "Lena", age: 5 }, new Date(2026, 9, 17));
    const after = recordSudoku(p, 3, new Date(2026, 9, 17));
    expect(after).toMatchObject({ totalStars: 3, walletStars: 3, currentStreak: 1 });
    expect(sudokusSolved(after)).toBe(1);
    expect(sudokuAge({ age: 5, sudokuDifficulty: "hard" })).toBe(7);
    expect(normalizeProfile({ id: "x" }).sudokuEnabled).toBe(true);
  });
});
