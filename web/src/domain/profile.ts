// Profiles, streaks, progress and settings — ports of ChildProfile.swift,
// StreakCalculator.swift, ProgressRecorder.swift and ProfileSettings.swift.
// Pure functions over plain objects, so they're easy to store and test.
import { Tuning, difficultyForAge, effectiveAge, nextAdaptivity, type Adaptivity } from "./difficulty";
import { DEFAULT_GAME_SETTINGS, gameAge, type GameDifficulty } from "./games";
import { GARDEN_COLUMNS, GARDEN_SIZE, emptyGarden, emptyGoods, startingFarmXp, widenGarden, type FarmOrder, type Garden, type Produce } from "./garden";

export const ROUND_LENGTH_CHOICES = [5, 10, 15, 20] as const;
export const DEFAULT_ROUND_LENGTH = 10;
const RECENT_CONTENT_LIMIT = 40;
const ROUND_HISTORY_LIMIT = 300;

export interface SubjectProgress {
  roundsPlayed: number;
  questionsAnswered: number;
  correctAnswers: number;
  stars: number;
  lastPlayed?: string;
  recentCorrectContentIds: string[];
  /** This subject's level (years above/below the real age) and its run of perfect rounds. */
  adjustment?: number;
  perfectRounds?: number;
}

export interface RoundRecord {
  date: string;
  subjectId: string;
  languageCode: string;
  correct: number;
  total: number;
  starsEarned: number;
  effectiveAge: number;
}

export interface ProfileSettings {
  name: string;
  age: number;
  avatarColor: string;
  learningLanguage: string;
  /** Empty = all subjects the language offers (so new ones appear automatically). */
  enabledSubjectIds: string[];
  roundLength: number;
  soundEnabled: boolean;
  readAloudEnabled: boolean;
  hapticsEnabled: boolean;
  gentleTimerEnabled: boolean;
  /** Play corner (grown-up controls). */
  gamesEnabled: boolean;
  gameCost: number;
  /** 0 = no daily limit. */
  gamesPerDay: number;
  /** Shifts the games' difficulty by two years either way (independent of the quizzes). */
  gameDifficulty: GameDifficulty;
  /** Minutes a day in Pip's garden (0 = no limit). */
  gardenMinutesPerDay: number;
  /** Sudoku card on the home screen, with its own difficulty shift. */
  sudokuEnabled: boolean;
  sudokuDifficulty: GameDifficulty;
}

export interface Profile extends ProfileSettings {
  id: string;
  createdAt: string;
  difficultyAdjustment: number;
  /** Lifetime stars: an achievement, never goes down (except a grown-up reset). */
  totalStars: number;
  /** Spendable stars for the play corner. */
  walletStars: number;
  /** Day of the last game ticket, and how many tickets were used that day. */
  gameDay?: string;
  gamesToday: number;
  /** Free extra games a grown-up unlocked for `bonusDay` only. */
  bonusGames: number;
  bonusDay?: string;
  garden: Garden;
  /** Columns the garden was saved with (missing: the old 6-column garden). */
  gardenColumns?: number;
  /** Eggs, milk, crops … collected on the farm, not yet sold or delivered. */
  farmGoods: Record<Produce, number>;
  /** Farm XP: stars spent on the farm, collecting and orders. */
  farmXp: number;
  /** Today's orders on the order board. */
  farmOrders?: { day: string; orders: FarmOrder[] };
  /** Time spent in the garden on `gardenDay`, and extra minutes a grown-up gave for that day. */
  gardenDay?: string;
  gardenSeconds?: number;
  gardenBonusMinutes?: number;
  currentStreak: number;
  longestStreak: number;
  /** Local calendar day, "YYYY-MM-DD". */
  lastPlayedDay?: string;
  /** Keyed by `${languageCode}/${subjectId}`. */
  progress: Record<string, SubjectProgress>;
  rounds: RoundRecord[];
}

const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

export const GARDEN_MINUTES_CHOICES = [10, 15, 20, 30, 45, 0] as const;
export const DEFAULT_GARDEN_MINUTES = 20;

export function defaultSettings(): ProfileSettings {
  return {
    name: "",
    age: 6,
    avatarColor: "sun",
    learningLanguage: "de",
    enabledSubjectIds: [],
    roundLength: DEFAULT_ROUND_LENGTH,
    soundEnabled: true,
    readAloudEnabled: true,
    hapticsEnabled: true,
    gentleTimerEnabled: false,
    ...DEFAULT_GAME_SETTINGS,
    sudokuEnabled: true,
    sudokuDifficulty: "normal",
    gardenMinutesPerDay: DEFAULT_GARDEN_MINUTES,
  };
}

/**
 * Fills fields added after a profile was saved (older versions of the app),
 * so stored profiles keep working. Stars earned before the play corner
 * existed go into the wallet, so they can be spent right away.
 */
export function normalizeProfile(p: Partial<Profile> & Pick<Profile, "id">): Profile {
  const base = defaultSettings();
  const garden = normalizeGarden(p.garden && p.gardenColumns !== GARDEN_COLUMNS ? widenGarden(p.garden) : p.garden);
  return {
    ...base,
    createdAt: new Date(0).toISOString(),
    difficultyAdjustment: 0,
    totalStars: 0,
    currentStreak: 0,
    longestStreak: 0,
    progress: {},
    rounds: [],
    ...p,
    walletStars: p.walletStars ?? p.totalStars ?? 0,
    gamesToday: p.gamesToday ?? 0,
    bonusGames: p.bonusGames ?? 0,
    gameDifficulty: p.gameDifficulty ?? base.gameDifficulty,
    garden,
    gardenColumns: GARDEN_COLUMNS,
    farmGoods: { ...emptyGoods(), ...p.farmGoods },
    // Farms built before levels existed start with the XP of what was spent on them.
    farmXp: p.farmXp ?? startingFarmXp(garden),
    gamesEnabled: p.gamesEnabled ?? base.gamesEnabled,
    gameCost: p.gameCost ?? base.gameCost,
    gamesPerDay: p.gamesPerDay ?? base.gamesPerDay,
    sudokuEnabled: p.sudokuEnabled ?? base.sudokuEnabled,
    sudokuDifficulty: p.sudokuDifficulty ?? base.sudokuDifficulty,
    gardenMinutesPerDay: p.gardenMinutesPerDay ?? base.gardenMinutesPerDay,
  } as Profile;
}

/** At least the starting size, in whole rows. */
function normalizeGarden(garden: Garden | undefined): Garden {
  const g = garden ? [...garden] : emptyGarden();
  const size = Math.max(GARDEN_SIZE, Math.ceil(g.length / GARDEN_COLUMNS) * GARDEN_COLUMNS);
  while (g.length < size) g.push(null);
  return g;
}

export function newId(): string {
  return globalThis.crypto?.randomUUID?.() ?? `p-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

export function createProfile(settings: ProfileSettings, now = new Date()): Profile {
  return applySettings(
    {
      ...settings,
      id: newId(),
      createdAt: now.toISOString(),
      difficultyAdjustment: 0,
      totalStars: 0,
      walletStars: 0,
      gamesToday: 0,
      bonusGames: 0,
      garden: emptyGarden(),
      gardenColumns: GARDEN_COLUMNS,
      farmGoods: emptyGoods(),
      farmXp: 0,
      currentStreak: 0,
      longestStreak: 0,
      progress: {},
      rounds: [],
    },
    settings,
  );
}

/**
 * Each subject keeps its own level. Subjects without one start from the
 * profile-wide adjustment that older versions of the app shared across subjects.
 */
export function subjectAdaptivity(p: Profile, languageCode: string, subjectId: string): Adaptivity {
  const progress = p.progress[progressKey(languageCode, subjectId)];
  return { adjustment: progress?.adjustment ?? p.difficultyAdjustment, perfectRounds: progress?.perfectRounds ?? 0 };
}

export function subjectDifficulty(p: Profile, languageCode: string, subjectId: string) {
  return difficultyForAge(p.age, subjectAdaptivity(p, languageCode, subjectId).adjustment);
}

/**
 * A grown-up sets a subject's level directly (years above/below the real age).
 * Only this subject changes; stars, streaks and history stay. Adaptivity carries on from here.
 */
export function setSubjectAdjustment(p: Profile, languageCode: string, subjectId: string, adjustment: number): Profile {
  const key = progressKey(languageCode, subjectId);
  const previous: SubjectProgress = p.progress[key] ?? {
    roundsPlayed: 0, questionsAnswered: 0, correctAnswers: 0, stars: 0, recentCorrectContentIds: [],
  };
  const value = clamp(Math.round(adjustment * 2) / 2, -Tuning.maxAdjustment, Tuning.maxAdjustmentUp);
  return { ...p, progress: { ...p.progress, [key]: { ...previous, adjustment: value, perfectRounds: 0 } } };
}

// MARK: Garden time

/** Seconds of garden time left today, or undefined when there's no limit. */
export function gardenSecondsLeft(p: Profile, now: Date): number | undefined {
  if (!p.gardenMinutesPerDay) return undefined;
  const today = p.gardenDay === dayKey(now);
  const allowed = (p.gardenMinutesPerDay + (today ? p.gardenBonusMinutes ?? 0 : 0)) * 60;
  return Math.max(0, allowed - (today ? p.gardenSeconds ?? 0 : 0));
}

/** Counts time spent in the garden (a new day starts from zero). */
export function addGardenTime(p: Profile, seconds: number, now: Date): Profile {
  if (seconds <= 0) return p;
  const today = dayKey(now);
  const same = p.gardenDay === today;
  return { ...p, gardenDay: today, gardenSeconds: (same ? p.gardenSeconds ?? 0 : 0) + seconds, gardenBonusMinutes: same ? p.gardenBonusMinutes ?? 0 : 0 };
}

export const GARDEN_BONUS_CHOICES = [5, 10, 15] as const;

/** A grown-up gives extra garden minutes, for today only. */
export function grantGardenMinutes(p: Profile, minutes: number, now: Date): Profile {
  const today = dayKey(now);
  const same = p.gardenDay === today;
  return { ...p, gardenDay: today, gardenSeconds: same ? p.gardenSeconds ?? 0 : 0, gardenBonusMinutes: (same ? p.gardenBonusMinutes ?? 0 : 0) + minutes };
}

/** The age a subject's questions are made for, e.g. 8.5 for a 7-year-old who is 1½ years ahead. */
export function subjectLevelAge(p: Profile, languageCode: string, subjectId: string): number {
  return effectiveAge(p.age, subjectAdaptivity(p, languageCode, subjectId).adjustment);
}

export const progressKey = (languageCode: string, subjectId: string) => `${languageCode}/${subjectId}`;

export function isSubjectEnabled(s: Pick<ProfileSettings, "enabledSubjectIds">, id: string): boolean {
  return s.enabledSubjectIds.length === 0 || s.enabledSubjectIds.includes(id);
}

export function allowsGentleTimer(age: number): boolean {
  return difficultyForAge(age).allowsGentleTimer;
}

/** Toggles a subject; at least one stays on; "all on" is stored as empty. */
export function withSubject(s: ProfileSettings, id: string, enabled: boolean, available: string[]): ProfileSettings {
  const current = new Set(s.enabledSubjectIds.length === 0 ? available : s.enabledSubjectIds);
  if (enabled) current.add(id);
  else {
    if (current.size === 1 && current.has(id)) return s;
    current.delete(id);
  }
  const all = available.every((a) => current.has(a));
  return { ...s, enabledSubjectIds: all ? [] : [...current].sort() };
}

export function isLastEnabledSubject(s: ProfileSettings, id: string, available: string[]): boolean {
  const current = s.enabledSubjectIds.length === 0 ? available : s.enabledSubjectIds;
  return current.length === 1 && current[0] === id;
}

/** Subjects differ per language, so switching language turns them all on. */
export function withLanguage(s: ProfileSettings, code: string): ProfileSettings {
  return code === s.learningLanguage ? s : { ...s, learningLanguage: code, enabledSubjectIds: [] };
}

/** Writes settings back; a new age resets adaptivity; no timer below 9. */
export function applySettings(p: Profile, s: ProfileSettings): Profile {
  const age = clamp(Math.round(s.age), Tuning.minAge, Tuning.maxAge);
  return {
    ...p,
    name: s.name.trim(),
    age,
    avatarColor: s.avatarColor,
    learningLanguage: s.learningLanguage,
    enabledSubjectIds: [...s.enabledSubjectIds].sort(),
    roundLength: clamp(s.roundLength, 5, 20),
    soundEnabled: s.soundEnabled,
    readAloudEnabled: s.readAloudEnabled,
    hapticsEnabled: s.hapticsEnabled,
    gentleTimerEnabled: s.gentleTimerEnabled && allowsGentleTimer(age),
    gamesEnabled: s.gamesEnabled,
    gameCost: clamp(Math.round(s.gameCost), 1, 100),
    gamesPerDay: clamp(Math.round(s.gamesPerDay), 0, 20),
    gameDifficulty: s.gameDifficulty,
    sudokuEnabled: s.sudokuEnabled,
    sudokuDifficulty: s.sudokuDifficulty,
    gardenMinutesPerDay: clamp(Math.round(s.gardenMinutesPerDay), 0, 240),
    difficultyAdjustment: age === p.age ? p.difficultyAdjustment : 0,
    progress: age === p.age ? p.progress : Object.fromEntries(
      Object.entries(p.progress).map(([k, v]) => [k, { ...v, adjustment: 0, perfectRounds: 0 }]),
    ),
  };
}

// MARK: Streaks (calendar days, local time)

export function dayKey(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function daysBetween(fromKey: string, toKey: string): number {
  const toUtc = (k: string) => {
    const [y, m, d] = k.split("-").map(Number);
    return Date.UTC(y, m - 1, d);
  };
  return Math.round((toUtc(toKey) - toUtc(fromKey)) / 86_400_000);
}

export function updatedStreak(current: number, longest: number, lastPlayedDay: string | undefined, now: Date) {
  const today = dayKey(now);
  let next = 1;
  if (lastPlayedDay) {
    const days = daysBetween(lastPlayedDay, today);
    if (days < 1) next = Math.max(current, 1);
    else if (days === 1) next = current + 1;
  }
  return { current: next, longest: Math.max(longest, next), lastPlayedDay: today };
}

/** A streak whose last day is before yesterday has lapsed. */
export function displayedStreak(p: Pick<Profile, "currentStreak" | "lastPlayedDay">, now: Date): number {
  if (!p.lastPlayedDay) return 0;
  return daysBetween(p.lastPlayedDay, dayKey(now)) <= 1 ? p.currentStreak : 0;
}

// MARK: Recording a round

export interface RoundOutcome {
  subjectId: string;
  languageCode: string;
  correct: number;
  total: number;
  correctContentIds: string[];
  effectiveAge: number;
}

export interface RoundSummary {
  correct: number;
  total: number;
  starsEarned: number;
  streak: number;
  streakGrew: boolean;
  /** A run of perfect rounds made the next round harder. */
  levelUp: boolean;
}

export function scoreOf(s: Pick<RoundSummary, "correct" | "total">): number {
  return s.total === 0 ? 0 : s.correct / s.total;
}

/** Stars, streak, per-subject progress, history and gentle adaptivity. */
export function recordRound(p: Profile, outcome: RoundOutcome, now = new Date()): { profile: Profile; summary: RoundSummary } {
  const stars = outcome.correct;
  const streak = updatedStreak(p.currentStreak, p.longestStreak, p.lastPlayedDay, now);
  const key = progressKey(outcome.languageCode, outcome.subjectId);
  const previous: SubjectProgress = p.progress[key] ?? {
    roundsPlayed: 0, questionsAnswered: 0, correctAnswers: 0, stars: 0, recentCorrectContentIds: [],
  };
  const level = nextAdaptivity(subjectAdaptivity(p, outcome.languageCode, outcome.subjectId), outcome.correct, outcome.total);

  const profile: Profile = {
    ...p,
    totalStars: p.totalStars + stars,
    walletStars: p.walletStars + stars,
    currentStreak: streak.current,
    longestStreak: streak.longest,
    lastPlayedDay: streak.lastPlayedDay,
    progress: {
      ...p.progress,
      [key]: {
        roundsPlayed: previous.roundsPlayed + 1,
        questionsAnswered: previous.questionsAnswered + outcome.total,
        correctAnswers: previous.correctAnswers + outcome.correct,
        stars: previous.stars + stars,
        lastPlayed: now.toISOString(),
        recentCorrectContentIds: [...previous.recentCorrectContentIds, ...outcome.correctContentIds].slice(-RECENT_CONTENT_LIMIT),
        adjustment: level.adjustment,
        perfectRounds: level.perfectRounds,
      },
    },
    rounds: [
      ...p.rounds,
      {
        date: now.toISOString(),
        subjectId: outcome.subjectId,
        languageCode: outcome.languageCode,
        correct: outcome.correct,
        total: outcome.total,
        starsEarned: stars,
        effectiveAge: outcome.effectiveAge,
      },
    ].slice(-ROUND_HISTORY_LIMIT),
  };

  return {
    profile,
    summary: { correct: outcome.correct, total: outcome.total, starsEarned: stars, streak: streak.current, streakGrew: streak.current > p.currentStreak, levelUp: level.boosted },
  };
}

// MARK: Sudoku

export const SUDOKU_PROGRESS_KEY = progressKey("puzzle", "sudoku");

/** The age Sudokus are made for: the child's age, shifted by the grown-up setting. */
export const sudokuAge = (p: Pick<Profile, "age" | "sudokuDifficulty">) => gameAge({ age: p.age, gameDifficulty: p.sudokuDifficulty });

export const sudokusSolved = (p: Profile) => p.progress[SUDOKU_PROGRESS_KEY]?.roundsPlayed ?? 0;

/** A solved Sudoku: stars into the total and the wallet, and it counts for the streak. */
export function recordSudoku(p: Profile, stars: number, now = new Date()): Profile {
  const streak = updatedStreak(p.currentStreak, p.longestStreak, p.lastPlayedDay, now);
  const previous = p.progress[SUDOKU_PROGRESS_KEY];
  return {
    ...p,
    totalStars: p.totalStars + stars,
    walletStars: p.walletStars + stars,
    currentStreak: streak.current,
    longestStreak: streak.longest,
    lastPlayedDay: streak.lastPlayedDay,
    progress: {
      ...p.progress,
      [SUDOKU_PROGRESS_KEY]: {
        roundsPlayed: (previous?.roundsPlayed ?? 0) + 1,
        questionsAnswered: 0,
        correctAnswers: 0,
        stars: (previous?.stars ?? 0) + stars,
        lastPlayed: now.toISOString(),
        recentCorrectContentIds: [],
      },
    },
  };
}

/** Clears stars (incl. wallet and garden), streaks, progress, history and adaptivity; keeps name and settings. */
export function resetProgress(p: Profile): Profile {
  return {
    ...p,
    totalStars: 0, walletStars: 0, gamesToday: 0, gameDay: undefined, garden: emptyGarden(), farmGoods: emptyGoods(), farmXp: 0, farmOrders: undefined,
    currentStreak: 0, longestStreak: 0, lastPlayedDay: undefined, difficultyAdjustment: 0, progress: {}, rounds: [],
  };
}

export { effectiveAge };
