// The weekly overview for grown-ups: the last seven days (today included)
// next to the seven before, per subject, and which kinds of questions went
// well or need practice. Built from the round history only; nothing new is
// collected except, per round, how each kind of question went (`skills`).
import { dayKey, type Profile, type RoundRecord } from "./profile";

export const WEEK_DAYS = 7;
/** A kind of question needs this many answers in the week before it counts as strong or for practice. */
export const SKILL_MIN_ANSWERS = 4;
/** Below this share right: worth practising. At or above STRONG_SHARE: going well. */
export const PRACTICE_SHARE = 0.75;
export const STRONG_SHARE = 0.9;

export interface WeekTotals {
  daysLearned: number;
  rounds: number;
  questions: number;
  correct: number;
  stars: number;
}

export interface SubjectWeek {
  subjectId: string;
  languageCode: string;
  rounds: number;
  questions: number;
  correct: number;
  /** Effective age at the first and last round of the week (the level then). */
  levelStart: number;
  levelEnd: number;
}

export interface SkillWeek {
  subjectId: string;
  skill: string;
  correct: number;
  asked: number;
}

export interface WeekSummary {
  /** Rounds per day, oldest first; the last one is today. */
  dayRounds: number[];
  /** The days, as "YYYY-MM-DD", same order. */
  days: string[];
  week: WeekTotals;
  previous: WeekTotals;
  subjects: SubjectWeek[];
  strong: SkillWeek[];
  practice: SkillWeek[];
}

const addDays = (date: Date, days: number) => { const d = new Date(date); d.setDate(d.getDate() + days); return d; };

function totals(rounds: RoundRecord[]): WeekTotals {
  return {
    daysLearned: new Set(rounds.map((r) => dayKey(new Date(r.date)))).size,
    rounds: rounds.length,
    questions: rounds.reduce((n, r) => n + r.total, 0),
    correct: rounds.reduce((n, r) => n + r.correct, 0),
    stars: rounds.reduce((n, r) => n + r.starsEarned, 0),
  };
}

export function weekSummary(p: Pick<Profile, "rounds">, now = new Date()): WeekSummary {
  const days = Array.from({ length: WEEK_DAYS }, (_, i) => dayKey(addDays(now, i - (WEEK_DAYS - 1))));
  const earlier = Array.from({ length: WEEK_DAYS }, (_, i) => dayKey(addDays(now, i - (2 * WEEK_DAYS - 1))));
  const dayOf = (r: RoundRecord) => dayKey(new Date(r.date));
  const sorted = [...p.rounds].sort((a, b) => a.date.localeCompare(b.date));
  const thisWeek = sorted.filter((r) => days.includes(dayOf(r)));
  const lastWeek = sorted.filter((r) => earlier.includes(dayOf(r)));

  const subjects = new Map<string, SubjectWeek>();
  const skills = new Map<string, SkillWeek>();
  for (const r of thisWeek) {
    const key = `${r.languageCode}/${r.subjectId}`;
    const s = subjects.get(key) ?? { subjectId: r.subjectId, languageCode: r.languageCode, rounds: 0, questions: 0, correct: 0, levelStart: r.effectiveAge, levelEnd: r.effectiveAge };
    subjects.set(key, { ...s, rounds: s.rounds + 1, questions: s.questions + r.total, correct: s.correct + r.correct, levelEnd: r.effectiveAge });
    for (const [skill, [correct, asked]] of Object.entries(r.skills ?? {})) {
      const k = `${r.subjectId}:${skill}`;
      const sk = skills.get(k) ?? { subjectId: r.subjectId, skill, correct: 0, asked: 0 };
      skills.set(k, { ...sk, correct: sk.correct + correct, asked: sk.asked + asked });
    }
  }

  const counted = [...skills.values()].filter((s) => s.asked >= SKILL_MIN_ANSWERS);
  const share = (s: SkillWeek) => s.correct / s.asked;
  const practice = counted.filter((s) => share(s) < PRACTICE_SHARE).sort((a, b) => share(a) - share(b) || b.asked - a.asked).slice(0, 3);
  const strong = counted.filter((s) => share(s) >= STRONG_SHARE).sort((a, b) => share(b) - share(a) || b.asked - a.asked).slice(0, 3);

  return {
    days,
    dayRounds: days.map((d) => thisWeek.filter((r) => dayOf(r) === d).length),
    week: totals(thisWeek),
    previous: totals(lastWeek),
    subjects: [...subjects.values()].sort((a, b) => b.rounds - a.rounds),
    strong,
    practice,
  };
}

/** How each kind of question went in one round: { skill: [right, asked] }. */
export function skillTally(skills: (string | undefined)[], results: boolean[]): Record<string, [number, number]> {
  const tally: Record<string, [number, number]> = {};
  results.forEach((right, i) => {
    const skill = skills[i];
    if (!skill) return;
    const [c, a] = tally[skill] ?? [0, 0];
    tally[skill] = [c + (right ? 1 : 0), a + 1];
  });
  return tally;
}
