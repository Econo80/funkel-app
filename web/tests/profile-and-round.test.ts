import { describe, expect, it } from "vitest";
import { isGateAnswerCorrect, randomGate } from "../src/domain/gate";
import {
  applySettings,
  createProfile,
  defaultSettings,
  displayedStreak,
  isLastEnabledSubject,
  recordRound,
  addGardenTime,
  gardenSecondsLeft,
  giftSeen,
  giveStars,
  grantGardenMinutes,
  normalizeProfile,
  resetProgress,
  setSubjectAdjustment,
  subjectAdaptivity,
  subjectDifficulty,
  subjectLevelAge,
  updatedStreak,
  withLanguage,
  withSubject,
} from "../src/domain/profile";
import { makeQuestion } from "../src/domain/question";
import { seededRng } from "../src/domain/random";
import {
  appendDigit, canSubmitNumber, canSubmitSequence, choose, deleteDigit, next,
  placeTile, removeTile, startRound, submitNumber, submitSequence, toggleSign,
} from "../src/domain/round";

const day = (d: number, hour = 10) => new Date(2026, 2, d, hour);

describe("streaks (mirrors StreakCalculatorTests.swift)", () => {
  it("starts, holds, grows and resets", () => {
    expect(updatedStreak(0, 0, undefined, day(1)).current).toBe(1);
    expect(updatedStreak(3, 5, "2026-03-02", day(2, 19))).toMatchObject({ current: 3, longest: 5 });
    expect(updatedStreak(3, 3, "2026-03-02", day(3, 7))).toMatchObject({ current: 4, longest: 4 });
    expect(updatedStreak(6, 6, "2026-03-02", day(5))).toMatchObject({ current: 1, longest: 6 });
  });

  it("lapses on display after a missed day", () => {
    expect(displayedStreak({ currentStreak: 4, lastPlayedDay: "2026-03-02" }, day(3))).toBe(4);
    expect(displayedStreak({ currentStreak: 4, lastPlayedDay: "2026-03-02" }, day(4))).toBe(0);
  });
});

describe("progress and settings (mirrors RoundFlowTests + GrownUpsTests)", () => {
  const base = () => createProfile({ ...defaultSettings(), name: "Lena", age: 7 }, day(1));

  it("records stars, streak, progress and history", () => {
    const outcome = { subjectId: "maths", languageCode: "de", correct: 10, total: 10, correctContentIds: ["a"], effectiveAge: 7 };
    const first = recordRound(base(), outcome, day(1));
    expect(first.summary).toMatchObject({ starsEarned: 10, streak: 1, streakGrew: true });
    expect(first.profile.progress["de/maths"].adjustment).toBeCloseTo(0.15);
    expect(first.summary.levelUp).toBe(false);
    const second = recordRound(first.profile, outcome, day(2));
    expect(second.summary.streak).toBe(2);
    const progress = second.profile.progress["de/maths"];
    expect(progress).toMatchObject({ roundsPlayed: 2, correctAnswers: 20, recentCorrectContentIds: ["a", "a"] });
    expect(second.profile.rounds).toHaveLength(2);

    const reset = resetProgress(second.profile);
    expect(reset).toMatchObject({ totalStars: 0, currentStreak: 0, progress: {}, rounds: [], name: "Lena" });
  });

  it("keeps at least one subject and stores 'all' as empty", () => {
    const all = ["maths", "vocabulary", "generalKnowledge"];
    let s = defaultSettings();
    s = withSubject(s, "maths", false, all);
    expect(s.enabledSubjectIds).toEqual(["generalKnowledge", "vocabulary"]);
    s = withSubject(s, "vocabulary", false, all);
    expect(isLastEnabledSubject(s, "generalKnowledge", all)).toBe(true);
    expect(withSubject(s, "generalKnowledge", false, all)).toBe(s);
    s = withSubject(withSubject(s, "maths", true, all), "vocabulary", true, all);
    expect(s.enabledSubjectIds).toEqual([]);
    expect(withLanguage({ ...s, enabledSubjectIds: ["maths"] }, "fr").enabledSubjectIds).toEqual([]);
  });

  it("resets adaptivity on a new age and allows the timer only from 9", () => {
    const emil = { ...createProfile({ ...defaultSettings(), name: "Emil", age: 10 }), difficultyAdjustment: 0.9 };
    const same = applySettings(emil, { ...emil, name: "  Emilio ", gentleTimerEnabled: true });
    expect(same).toMatchObject({ name: "Emilio", gentleTimerEnabled: true, difficultyAdjustment: 0.9 });
    const younger = applySettings(same, { ...same, age: 7 });
    expect(younger).toMatchObject({ age: 7, difficultyAdjustment: 0, gentleTimerEnabled: false });
  });

  it("keeps a level per subject, boosted by perfect rounds", () => {
    const perfect = (subjectId: string) => ({ subjectId, languageCode: "de", correct: 10, total: 10, correctContentIds: [], effectiveAge: 7 });
    let p = { ...createProfile({ ...defaultSettings(), name: "Lena", age: 5 }, day(1)), difficultyAdjustment: 0.3 };
    // Subjects without their own level start from the old shared one.
    expect(subjectAdaptivity(p, "de", "maths").adjustment).toBe(0.3);

    let summary;
    for (let i = 0; i < 3; i++) ({ profile: p, summary } = recordRound(p, perfect("maths"), day(1)));
    expect(summary!.levelUp).toBe(true);
    expect(subjectAdaptivity(p, "de", "maths")).toEqual({ adjustment: 0.3 + 0.15 + 0.5 + 0.5, perfectRounds: 3 });
    expect(subjectLevelAge(p, "de", "maths")).toBeCloseTo(6.45);
    expect(subjectDifficulty(p, "de", "maths").effectiveAge).toBeCloseTo(6.45);
    expect(subjectAdaptivity(p, "de", "vocabulary").adjustment).toBe(0.3);

    // A new age starts every subject from the real age again.
    const older = applySettings(p, { ...p, age: 6 });
    expect(subjectAdaptivity(older, "de", "maths")).toEqual({ adjustment: 0, perfectRounds: 0 });
  });

  it("gates with a two-digit × one-digit sum", () => {
    const rng = seededRng(21);
    for (let i = 0; i < 200; i++) {
      const g = randomGate(rng);
      expect(g.a * g.b).toBeGreaterThanOrEqual(36);
      expect(isGateAnswerCorrect(g, String(g.a * g.b))).toBe(true);
      expect(isGateAnswerCorrect(g, String(g.a * g.b + 1))).toBe(false);
    }
  });
});

describe("round state machine (mirrors RoundViewModel tests)", () => {
  const choiceQ = () => makeQuestion({
    subjectId: "maths", prompt: "1 + 1?",
    format: { kind: "multipleChoice", options: [{ id: 0, text: "1" }, { id: 1, text: "2" }, { id: 2, text: "3" }], correctIndex: 1 },
  });

  it("runs multiple choice", () => {
    let s = startRound([choiceQ(), choiceQ()], false);
    s = choose(s, 1);
    expect(s.phase).toBe("correct");
    expect(choose(s, 0).results).toEqual([true]);
    s = next(s);
    expect(s).toMatchObject({ phase: "answering", selectedOptionIndex: undefined });
    s = next(choose(s, 2));
    expect(s.phase).toBe("finished");
    expect(s.results).toEqual([true, false]);
  });

  it("handles the number pad", () => {
    let s = startRound([makeQuestion({ subjectId: "maths", prompt: "?", format: { kind: "numberEntry", answer: 42 } })], false);
    expect(canSubmitNumber(s)).toBe(false);
    for (const d of [0, 4, 2, 2, 2, 2]) s = appendDigit(s, d);
    expect(s.numberInput).toBe("4222");
    s = toggleSign(deleteDigit(deleteDigit(s)));
    expect(s.numberInput).toBe("42");
    expect(submitNumber(s).phase).toBe("correct");

    let neg = startRound([makeQuestion({ subjectId: "maths", prompt: "?", format: { kind: "numberEntry", answer: -7 } })], true);
    neg = toggleSign(appendDigit(neg, 7));
    expect(neg.numberInput).toBe("-7");
    expect(submitNumber(neg).phase).toBe("correct");
  });

  it("builds sequences", () => {
    let s = startRound([makeQuestion({ subjectId: "v", prompt: "?", format: { kind: "buildSequence", tiles: ["u", "H", "n", "d", "x"], answer: ["H", "u", "n", "d"] } })], false);
    s = placeTile(placeTile(s, 1), 1);
    expect(s.placedTiles).toEqual([1]);
    s = placeTile(placeTile(s, 0), 4);
    expect(canSubmitSequence(s)).toBe(false);
    s = placeTile(placeTile(s, 2), 3);
    expect(s.placedTiles).toEqual([1, 0, 4, 2]);
    s = placeTile(removeTile(s, 2), 3);
    expect(s.placedTiles).toEqual([1, 0, 2, 3]);
    expect(submitSequence(s).phase).toBe("correct");
  });
});

describe("grown-up controls (web)", () => {
  const d = (n: number, h = 10) => new Date(2026, 9, n, h);

  it("set one subject's level without touching anything else", () => {
    const base = { ...createProfile({ ...defaultSettings(), name: "Emil", age: 8 }, d(1)), totalStars: 40, currentStreak: 3 };
    const played = recordRound(base, { subjectId: "maths", languageCode: "de", correct: 10, total: 10, correctContentIds: ["x"], effectiveAge: 8 }, d(1)).profile;
    const harder = setSubjectAdjustment(played, "de", "maths", 1.5);
    expect(subjectAdaptivity(harder, "de", "maths")).toEqual({ adjustment: 1.5, perfectRounds: 0 });
    expect(subjectLevelAge(harder, "de", "maths")).toBe(9.5);
    expect(harder.progress["de/maths"]).toMatchObject({ roundsPlayed: 1, correctAnswers: 10, recentCorrectContentIds: ["x"] });
    expect(harder).toMatchObject({ totalStars: played.totalStars, currentStreak: played.currentStreak, rounds: played.rounds });
    expect(subjectAdaptivity(harder, "de", "vocabulary").adjustment).toBe(0);
    // Limits: −1.5 … +3 years, in half years.
    expect(subjectAdaptivity(setSubjectAdjustment(harder, "de", "maths", 9), "de", "maths").adjustment).toBe(3);
    expect(subjectAdaptivity(setSubjectAdjustment(harder, "de", "maths", -0.7), "de", "maths").adjustment).toBe(-0.5);
  });

  it("limits garden time per day, with extra minutes for today only", () => {
    let p = createProfile({ ...defaultSettings(), name: "Emil", age: 8 }, d(1));
    expect(p.gardenMinutesPerDay).toBe(20);
    expect(gardenSecondsLeft(p, d(1))).toBe(20 * 60);
    p = addGardenTime(p, 19 * 60, d(1));
    expect(gardenSecondsLeft(p, d(1))).toBe(60);
    p = addGardenTime(p, 120, d(1));
    expect(gardenSecondsLeft(p, d(1))).toBe(0);
    p = grantGardenMinutes(p, 10, d(1));
    expect(gardenSecondsLeft(p, d(1))).toBe(9 * 60);
    // A new day starts fresh, without yesterday's extra minutes.
    expect(gardenSecondsLeft(p, d(2))).toBe(20 * 60);
    expect(addGardenTime(p, 30, d(2))).toMatchObject({ gardenSeconds: 30, gardenBonusMinutes: 0 });
    expect(gardenSecondsLeft({ ...p, gardenMinutesPerDay: 0 }, d(1))).toBeUndefined();
    expect(normalizeProfile({ id: "old" }).gardenMinutesPerDay).toBe(20);
  });
});

describe("star gifts (web)", () => {
  it("add spendable stars only, and are thanked for once", () => {
    const p = { ...createProfile({ ...defaultSettings(), name: "Lena", age: 5 }), totalStars: 12, walletStars: 3 };
    const gifted = giveStars(giveStars(p, 50), 25);
    expect(gifted).toMatchObject({ walletStars: 78, totalStars: 12, giftStars: 75 });
    expect(giveStars(p, 0)).toBe(p);
    expect(giveStars(p, 9999).walletStars).toBe(3 + 500);
    expect(giftSeen(gifted)).toMatchObject({ walletStars: 78, giftStars: 0 });
  });
});
