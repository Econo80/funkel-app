// The Denk-Test: 24 Denken puzzles that get harder, from two years below the
// child's age to well above it (two per half year). It ends early after four
// wrong answers in a row, like real reasoning tests. The score is the number
// right and a "Denk-Niveau": the age the puzzles he still solves are made for.
// Compared only with the child's own earlier tests: there is no IQ and no
// comparison with other children. Mirrored in ThinkingTest.swift.
import { difficultyForEffectiveAge, Tuning } from "./difficulty";
import { dayKey, updatedStreak, type Profile } from "./profile";
import type { Question } from "./question";
import type { Rng } from "./random";
import type { QuestionProvider } from "../providers/provider";

export const TEST_STEPS = 12;
export const TEST_PER_STEP = 2;
export const TEST_QUESTIONS = TEST_STEPS * TEST_PER_STEP;
/** Each step is half a year harder; the first one is two years below the child's age. */
export const TEST_STEP_YEARS = 0.5;
export const TEST_START_BELOW = 2;
/** Four wrong in a row: the puzzles are too hard now, so the test ends kindly. */
export const TEST_STOP_AFTER_WRONG = 4;
/** One test a week, so the score shows a real change and isn't just practice. */
export const TEST_EVERY_DAYS = 7;
export const TEST_HISTORY_LIMIT = 100;

export interface ThinkingTestResult {
  date: string;
  /** The child's age when taking it. */
  age: number;
  points: number;
  total: number;
  /** The age the puzzles he still solved are made for, in half years. */
  levelAge: number;
}

const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

export const testStartAge = (age: number) => clamp(age - TEST_START_BELOW, Tuning.minAge, Tuning.maxAge);

/** The difficulty (effective age) of each step. */
export function testStepAges(age: number): number[] {
  const start = testStartAge(age);
  return Array.from({ length: TEST_STEPS }, (_, i) => Math.min(Tuning.maxAge, start + i * TEST_STEP_YEARS));
}

/** Two puzzles per step, easiest first. */
export function makeThinkingTest(provider: QuestionProvider, age: number, rng: Rng): Question[] {
  return testStepAges(age).flatMap((stepAge) => provider.makeQuestions(TEST_PER_STEP, difficultyForEffectiveAge(stepAge), new Set(), rng));
}

/** Stop once the last four answers were all wrong. */
export function shouldStopTest(results: boolean[]): boolean {
  return results.length >= TEST_STOP_AFTER_WRONG && results.slice(-TEST_STOP_AFTER_WRONG).every((r) => !r);
}

/**
 * Each point is a quarter year above the half year before the first step, in
 * half years and within 4–14: 0 points at age 7 → 4½, 10 points → 7½, 24 → 10½.
 */
export function testLevelAge(age: number, points: number): number {
  const raw = testStartAge(age) - TEST_STEP_YEARS + (points * TEST_STEP_YEARS) / TEST_PER_STEP;
  return clamp(Math.floor(raw * 2) / 2, Tuning.minAge, Tuning.maxAge);
}

export function lastThinkingTest(p: Pick<Profile, "thinkingTests">): ThinkingTestResult | undefined {
  const tests = p.thinkingTests ?? [];
  return tests[tests.length - 1];
}

/** The day the next test can be taken (today if never). */
export function nextTestDay(p: Pick<Profile, "thinkingTests">, now = new Date()): string {
  const last = lastThinkingTest(p);
  if (!last) return dayKey(now);
  const d = new Date(last.date);
  d.setDate(d.getDate() + TEST_EVERY_DAYS);
  return dayKey(d);
}

export const canTakeTest = (p: Pick<Profile, "thinkingTests">, now = new Date()) => nextTestDay(p, now) <= dayKey(now);

/** Days until the next test (0 = now). */
export function daysUntilTest(p: Pick<Profile, "thinkingTests">, now = new Date()): number {
  const [y, m, d] = nextTestDay(p, now).split("-").map(Number);
  const next = new Date(y, m - 1, d);
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return Math.max(0, Math.round((next.getTime() - today.getTime()) / 86_400_000));
}

/**
 * A finished test: kept in the history, stars (one per two points) into the
 * total and the wallet, the streak, and a round in the history (subject Denken)
 * for the weekly overview. Levels of the Denken subject aren't changed.
 */
export function recordThinkingTest(
  p: Profile, outcome: { points: number; total: number; skills: Record<string, [number, number]>; subjectId: string; languageCode: string }, now = new Date(),
): { profile: Profile; result: ThinkingTestResult; stars: number } {
  const result: ThinkingTestResult = { date: now.toISOString(), age: p.age, points: outcome.points, total: outcome.total, levelAge: testLevelAge(p.age, outcome.points) };
  const stars = Math.ceil(outcome.points / 2);
  const streak = updatedStreak(p.currentStreak, p.longestStreak, p.lastPlayedDay, now);
  return {
    result,
    stars,
    profile: {
      ...p,
      totalStars: p.totalStars + stars,
      walletStars: p.walletStars + stars,
      currentStreak: streak.current,
      longestStreak: streak.longest,
      lastPlayedDay: streak.lastPlayedDay,
      thinkingTests: [...(p.thinkingTests ?? []), result].slice(-TEST_HISTORY_LIMIT),
      rounds: [...p.rounds, {
        date: result.date, subjectId: outcome.subjectId, languageCode: outcome.languageCode, correct: outcome.points, total: outcome.total,
        starsEarned: stars, effectiveAge: result.levelAge, ...(Object.keys(outcome.skills).length ? { skills: outcome.skills } : {}),
      }].slice(-300),
    },
  };
}
