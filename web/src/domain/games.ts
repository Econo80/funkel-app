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

export const DEFAULT_GAME_SETTINGS = { gamesEnabled: true, gameCost: 10, gamesPerDay: 3 };

// MARK: Tickets

export type TicketCheck =
  | { ok: true }
  | { ok: false; reason: "disabled" }
  | { ok: false; reason: "notEnoughStars"; missing: number }
  | { ok: false; reason: "dailyLimit" };

export function gamesPlayedToday(p: Profile, now: Date): number {
  return p.gameDay === dayKey(now) ? p.gamesToday : 0;
}

export function gamesLeftToday(p: Profile, now: Date): number | undefined {
  return p.gamesPerDay === 0 ? undefined : Math.max(0, p.gamesPerDay - gamesPlayedToday(p, now));
}

export function checkTicket(p: Profile, now: Date): TicketCheck {
  if (!p.gamesEnabled) return { ok: false, reason: "disabled" };
  if (p.gamesPerDay > 0 && gamesPlayedToday(p, now) >= p.gamesPerDay) return { ok: false, reason: "dailyLimit" };
  if (p.walletStars < p.gameCost) return { ok: false, reason: "notEnoughStars", missing: p.gameCost - p.walletStars };
  return { ok: true };
}

/** Spends one ticket. Returns the same profile if a ticket isn't allowed. */
export function buyTicket(p: Profile, now: Date): Profile {
  if (!checkTicket(p, now).ok) return p;
  return { ...p, walletStars: p.walletStars - p.gameCost, gameDay: dayKey(now), gamesToday: gamesPlayedToday(p, now) + 1 };
}

// MARK: Memory

export const MEMORY_PICTURES = [
  "🐶", "🐱", "🐭", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔",
  "🐧", "🦋", "🐢", "🐙", "🦄", "🍎", "🍌", "🍓", "🍒", "🥕", "🌻", "🚗", "🚀", "🎈", "🧸",
];

export function memoryPairsForAge(age: number): number {
  if (age <= 5) return 4;
  if (age <= 7) return 6;
  if (age <= 10) return 8;
  return 10;
}

export interface MemoryCard { id: number; picture: string }

export function memoryBoard(age: number, rng: Rng): MemoryCard[] {
  const pictures = shuffled(rng, MEMORY_PICTURES).slice(0, memoryPairsForAge(age));
  return shuffled(rng, [...pictures, ...pictures]).map((picture, id) => ({ id, picture }));
}

// MARK: Ballon-Pop

export type BalloonRule =
  | { kind: "all" }
  | { kind: "even" }
  | { kind: "product"; target: number };

/** Little ones pop everything; older children pop by a maths rule. */
export function balloonRuleForAge(age: number, rng: Rng): BalloonRule {
  if (age < 7) return { kind: "all" };
  if (age < 9) return { kind: "even" };
  return { kind: "product", target: randomElement(rng, [12, 18, 24, 36]) ?? 24 };
}

export interface BalloonSpec { label?: string; good: boolean }

export function spawnBalloon(rule: BalloonRule, rng: Rng): BalloonSpec {
  switch (rule.kind) {
    case "all":
      return { good: true };
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

export interface GardenItem {
  id: string;
  price: number;
  /** Emoji per growth stage; the last one may be replaced by a variant. */
  stages: string[];
  /** Days after planting when each stage starts (same length as stages). */
  days: number[];
  variants?: string[];
}

export const GARDEN_ITEMS: GardenItem[] = [
  { id: "stone", price: 1, stages: ["🪨"], days: [0] },
  { id: "mushroom", price: 2, stages: ["🍄"], days: [0] },
  { id: "flower", price: 3, stages: ["🌱", "🌿", "🌷"], days: [0, 1, 3], variants: ["🌷", "🌻", "🌼", "🌸", "🌹", "🪻"] },
  { id: "snail", price: 4, stages: ["🐌"], days: [0] },
  { id: "ladybug", price: 5, stages: ["🐞"], days: [0] },
  { id: "butterfly", price: 6, stages: ["🦋"], days: [0] },
  { id: "bee", price: 6, stages: ["🐝"], days: [0] },
  { id: "tree", price: 12, stages: ["🌱", "🪴", "🌳"], days: [0, 3, 7], variants: ["🌳", "🌲", "🍎"] },
  { id: "fountain", price: 20, stages: ["⛲"], days: [0] },
  { id: "house", price: 30, stages: ["🏡"], days: [0] },
];

export const GARDEN_SIZE = 24;

export interface GardenPlot { itemId: string; plantedDay: string; variant?: string }
export type Garden = (GardenPlot | null)[];

export const emptyGarden = (): Garden => Array.from({ length: GARDEN_SIZE }, () => null);

const daysSince = (from: string, now: Date) => {
  const utc = (k: string) => { const [y, m, d] = k.split("-").map(Number); return Date.UTC(y, m - 1, d); };
  return Math.round((utc(dayKey(now)) - utc(from)) / 86_400_000);
};

/** The emoji a plot shows today. Plants grow by days since planting. */
export function plotPicture(plot: GardenPlot, now: Date): string {
  const item = GARDEN_ITEMS.find((i) => i.id === plot.itemId);
  if (!item) return "";
  const age = daysSince(plot.plantedDay, now);
  let stage = 0;
  item.days.forEach((d, i) => { if (age >= d) stage = i; });
  const isLast = stage === item.stages.length - 1;
  return isLast && plot.variant ? plot.variant : item.stages[stage];
}

/** Days until the next growth stage, or undefined when fully grown. */
export function daysUntilNextStage(plot: GardenPlot, now: Date): number | undefined {
  const item = GARDEN_ITEMS.find((i) => i.id === plot.itemId);
  if (!item) return undefined;
  const age = daysSince(plot.plantedDay, now);
  const next = item.days.find((d) => d > age);
  return next === undefined ? undefined : next - age;
}

export function placeInGarden(p: Profile, plotIndex: number, itemId: string, now: Date, rng: Rng): Profile {
  const item = GARDEN_ITEMS.find((i) => i.id === itemId);
  if (!item || p.walletStars < item.price || plotIndex < 0 || plotIndex >= GARDEN_SIZE || p.garden[plotIndex]) return p;
  const garden = [...p.garden];
  garden[plotIndex] = { itemId, plantedDay: dayKey(now), variant: item.variants ? randomElement(rng, item.variants) : undefined };
  return { ...p, walletStars: p.walletStars - item.price, garden };
}

/** Clears a plot (no refund — like real gardening). */
export function clearPlot(p: Profile, plotIndex: number): Profile {
  if (!p.garden[plotIndex]) return p;
  const garden = [...p.garden];
  garden[plotIndex] = null;
  return { ...p, garden };
}
