/** A source of random numbers in [0, 1). `Math.random` in the app, seeded in tests. */
export type Rng = () => number;

export const systemRng: Rng = Math.random;

/** Deterministic generator (mulberry32) so tests are reproducible. */
export function seededRng(seed: number): Rng {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Integer in [min, max], inclusive. */
export function randomInt(rng: Rng, min: number, max: number): number {
  if (max <= min) return min;
  return min + Math.floor(rng() * (max - min + 1));
}

export function randomElement<T>(rng: Rng, items: readonly T[]): T | undefined {
  return items.length === 0 ? undefined : items[Math.floor(rng() * items.length)];
}

export function shuffled<T>(rng: Rng, items: readonly T[]): T[] {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

/** Picks one item proportionally to its weight; items with weight ≤ 0 never win. */
export function weightedPick<T>(rng: Rng, items: readonly (readonly [T, number])[]): T | undefined {
  const positive = items.filter(([, weight]) => weight > 0);
  const total = positive.reduce((sum, [, weight]) => sum + weight, 0);
  if (total <= 0) return items[0]?.[0];
  let roll = rng() * total;
  for (const [item, weight] of positive) {
    if (roll < weight) return item;
    roll -= weight;
  }
  return positive[positive.length - 1][0];
}
