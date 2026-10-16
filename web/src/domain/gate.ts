import { randomInt, systemRng, type Rng } from "./random";

/**
 * The grown-up gate: a two-digit × one-digit sum (e.g. 14 × 7). Easy for an
 * adult, out of reach for most young children. Light by design: not security.
 */
export interface GateChallenge {
  a: number;
  b: number;
}

export const GATE_FIRST = [12, 19] as const;
export const GATE_SECOND = [3, 9] as const;

export function randomGate(rng: Rng = systemRng): GateChallenge {
  return { a: randomInt(rng, GATE_FIRST[0], GATE_FIRST[1]), b: randomInt(rng, GATE_SECOND[0], GATE_SECOND[1]) };
}

export function isGateAnswerCorrect(c: GateChallenge, input: string): boolean {
  return Number.parseInt(input.trim(), 10) === c.a * c.b;
}
