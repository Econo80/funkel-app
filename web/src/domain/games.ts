// The play corner: stars earned in quizzes can be spent on short games
// (a ticket) or on Pip's garden. Lifetime stars (`totalStars`) never go down;
// only the wallet is spent. Pure functions, like the rest of the domain.
import { dayKey, type Profile } from "./profile";
import { randomElement, randomInt, shuffled, type Rng } from "./random";

export type GameId = "memory" | "balloons" | "stars";
export const GAME_IDS: readonly GameId[] = ["memory", "balloons", "stars"];

/** One ticket lasts this long; then Pip says goodbye. */
export const GAME_SECONDS = 120;

export const GAME_COST_CHOICES = [5, 10, 15, 20] as const;
/** 0 = no daily limit. */
export const GAMES_PER_DAY_CHOICES = [1, 2, 3, 5, 0] as const;

export type GameDifficulty = "easy" | "normal" | "hard";
export const GAME_DIFFICULTIES: readonly GameDifficulty[] = ["easy", "normal", "hard"];
/** Games are pitched to the child's age, shifted by the grown-up's choice. */
const DIFFICULTY_OFFSET: Record<GameDifficulty, number> = { easy: -2, normal: 0, hard: 2 };

export const DEFAULT_GAME_SETTINGS = { gamesEnabled: true, gameCost: 10, gamesPerDay: 3, gameDifficulty: "normal" as GameDifficulty };

/** The age the games are pitched at (independent of the quiz difficulty). */
export function gameAge(p: Pick<Profile, "age" | "gameDifficulty">): number {
  return Math.min(14, Math.max(4, p.age + DIFFICULTY_OFFSET[p.gameDifficulty ?? "normal"]));
}

// MARK: Tickets

export type TicketCheck =
  | { ok: true; free: boolean }
  | { ok: false; reason: "disabled" }
  | { ok: false; reason: "notEnoughStars"; missing: number }
  | { ok: false; reason: "dailyLimit" };

export function gamesPlayedToday(p: Profile, now: Date): number {
  return p.gameDay === dayKey(now) ? p.gamesToday : 0;
}

export function gamesLeftToday(p: Profile, now: Date): number | undefined {
  return p.gamesPerDay === 0 ? undefined : Math.max(0, p.gamesPerDay - gamesPlayedToday(p, now));
}

/** Extra games a grown-up unlocked for today (free, outside the daily limit). */
export function bonusGamesLeftToday(p: Profile, now: Date): number {
  return p.bonusDay === dayKey(now) ? p.bonusGames : 0;
}

export function checkTicket(p: Profile, now: Date): TicketCheck {
  if (!p.gamesEnabled) return { ok: false, reason: "disabled" };
  if (bonusGamesLeftToday(p, now) > 0) return { ok: true, free: true };
  if (p.gamesPerDay > 0 && gamesPlayedToday(p, now) >= p.gamesPerDay) return { ok: false, reason: "dailyLimit" };
  if (p.walletStars < p.gameCost) return { ok: false, reason: "notEnoughStars", missing: p.gameCost - p.walletStars };
  return { ok: true, free: false };
}

/** Spends one ticket: a bonus game first (free), otherwise stars. Same profile if not allowed. */
export function buyTicket(p: Profile, now: Date): Profile {
  const check = checkTicket(p, now);
  if (!check.ok) return p;
  if (check.free) return { ...p, bonusGames: bonusGamesLeftToday(p, now) - 1, bonusDay: dayKey(now) };
  return { ...p, walletStars: p.walletStars - p.gameCost, gameDay: dayKey(now), gamesToday: gamesPlayedToday(p, now) + 1 };
}

export const BONUS_CHOICES = [1, 2, 3] as const;
const MAX_BONUS = 10;

/** Grown-up override: unlock extra free games for today only. */
export function grantBonusGames(p: Profile, count: number, now: Date): Profile {
  const total = Math.min(MAX_BONUS, bonusGamesLeftToday(p, now) + Math.max(0, Math.round(count)));
  return { ...p, bonusGames: total, bonusDay: dayKey(now) };
}

// MARK: Memory

export const MEMORY_PICTURES = [
  "🐶", "🐱", "🐭", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔",
  "🐧", "🦋", "🐢", "🐙", "🦄", "🍎", "🍌", "🍓", "🍒", "🥕", "🌻", "🚗", "🚀", "🎈", "🧸",
];

/** Starting board size; each cleared board adds MEMORY_GROWTH pairs. */
export function memoryPairsForAge(age: number): number {
  if (age <= 4) return 4;
  if (age <= 5) return 6;
  if (age <= 7) return 8;
  if (age <= 10) return 10;
  return 12;
}

export const MEMORY_GROWTH = 2;
export const MEMORY_MAX_PAIRS = 15;

export interface MemoryCard { id: number; picture: string }

/** @param boardsCleared boards already solved this game; the board grows with each. */
export function memoryBoard(age: number, rng: Rng, boardsCleared = 0): MemoryCard[] {
  const pairs = Math.min(MEMORY_MAX_PAIRS, memoryPairsForAge(age) + boardsCleared * MEMORY_GROWTH);
  const pictures = shuffled(rng, MEMORY_PICTURES).slice(0, pairs);
  return shuffled(rng, [...pictures, ...pictures]).map((picture, id) => ({ id, picture }));
}

// MARK: Ballon-Pop

/** Four colours that are easy to tell apart and to name. */
export const BALLOON_COLORS = { red: "#F0453A", yellow: "#FFC21A", blue: "#3D8BFF", green: "#2FBF60" } as const;
export type BalloonColor = keyof typeof BALLOON_COLORS;
const BALLOON_COLOR_IDS = Object.keys(BALLOON_COLORS) as BalloonColor[];

/** The target colour switches this often, so the child has to keep watching. */
export const BALLOON_COLOR_SECONDS = 30;

export type BalloonRule =
  | { kind: "all" }
  | { kind: "color"; color: BalloonColor }
  | { kind: "even" }
  | { kind: "product"; target: number };

/** The youngest pop everything, then by colour; older children pop by a maths rule. */
export function balloonRuleForAge(age: number, rng: Rng): BalloonRule {
  if (age < 5) return { kind: "all" };
  if (age < 7) return { kind: "color", color: randomElement(rng, BALLOON_COLOR_IDS) ?? "red" };
  if (age < 9) return { kind: "even" };
  return { kind: "product", target: randomElement(rng, [12, 18, 24, 36]) ?? 24 };
}

/** The next colour rule: always a different colour from the current one. */
export function nextBalloonColor(current: BalloonColor, rng: Rng): BalloonColor {
  return randomElement(rng, BALLOON_COLOR_IDS.filter((c) => c !== current)) ?? current;
}

export interface BalloonSpec { label?: string; color?: BalloonColor; good: boolean }

export function spawnBalloon(rule: BalloonRule, rng: Rng): BalloonSpec {
  switch (rule.kind) {
    case "all":
      return { good: true };
    case "color": {
      const color = rng() < 0.4 ? rule.color : randomElement(rng, BALLOON_COLOR_IDS.filter((c) => c !== rule.color))!;
      return { color, good: color === rule.color };
    }
    case "even": {
      const n = randomInt(rng, 1, 20);
      return { label: String(n), good: n % 2 === 0 };
    }
    case "product": {
      const factors: [number, number][] = [];
      for (let a = 2; a <= 9; a++) if (rule.target % a === 0 && rule.target / a <= 12) factors.push([a, rule.target / a]);
      if (rng() < 0.45 && factors.length) {
        const [a, b] = randomElement(rng, factors)!;
        return { label: `${a}·${b}`, good: true };
      }
      // A near miss that isn't the target.
      let a: number, b: number;
      do {
        a = randomInt(rng, 2, 9);
        b = randomInt(rng, 2, 9);
      } while (a * b === rule.target);
      return { label: `${a}·${b}`, good: false };
    }
  }
}

// MARK: Pips Garten

export * from "./garden";
