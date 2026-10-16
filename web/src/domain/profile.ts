// Profiles, streaks, progress and settings — ports of ChildProfile.swift,
// StreakCalculator.swift, ProgressRecorder.swift and ProfileSettings.swift.
// Pure functions over plain objects, so they're easy to store and test.
import { Tuning, difficultyForAge, effectiveAge, nextAdjustment } from "./difficulty";

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
}

export interface Profile extends ProfileSettings {
  id: string;
  createdAt: string;
  difficultyAdjustment: number;
  totalStars: number;
  currentStreak: number;
  longestStreak: number;
  /** Local calendar day, "YYYY-MM-DD". */
  lastPlayedDay?: string;
  /** Keyed by `${languageCode}/${subjectId}`. */
  progress: Record<string, SubjectProgress>;
  rounds: RoundRecord[];
}

const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

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
  };
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
      currentStreak: 0,
      longestStreak: 0,
      progress: {},
      rounds: [],
    },
    settings,
  );
}

export function profileDifficulty(p: Profile) {
  return difficultyForAge(p.age, p.difficultyAdjustment);
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
    difficultyAdjustment: age === p.age ? p.difficultyAdjustment : 0,
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

  const profile: Profile = {
    ...p,
    totalStars: p.totalStars + stars,
    currentStreak: streak.current,
    longestStreak: streak.longest,
    lastPlayedDay: streak.lastPlayedDay,
    difficultyAdjustment: nextAdjustment(p.difficultyAdjustment, outcome.correct, outcome.total),
    progress: {
      ...p.progress,
      [key]: {
        roundsPlayed: previous.roundsPlayed + 1,
        questionsAnswered: previous.questionsAnswered + outcome.total,
        correctAnswers: previous.correctAnswers + outcome.correct,
        stars: previous.stars + stars,
        lastPlayed: now.toISOString(),
        recentCorrectContentIds: [...previous.recentCorrectContentIds, ...outcome.correctContentIds].slice(-RECENT_CONTENT_LIMIT),
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
    summary: { correct: outcome.correct, total: outcome.total, starsEarned: stars, streak: streak.current, streakGrew: streak.current > p.currentStreak },
  };
}

/** Clears stars, streaks, progress, history and adaptivity; keeps name and settings. */
export function resetProgress(p: Profile): Profile {
  return { ...p, totalStars: 0, currentStreak: 0, longestStreak: 0, lastPlayedDay: undefined, difficultyAdjustment: 0, progress: {}, rounds: [] };
}

export { effectiveAge };
