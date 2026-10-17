// Age → difficulty. A direct port of the iOS app's DifficultyTuning.swift and
// DifficultyScale.swift; the rules are documented in PLAN.md §5. Keep the
// numbers in sync with the Swift file when tuning.

export type MathsOperation =
  | "counting" | "numberRecognition" | "addition" | "subtraction"
  | "multiplication" | "division" | "wordProblem" | "missingNumber"
  // Web only for now: the Swiss "Zahlenhaus" (number house), splitting a number into two parts.
  | "numberHouse";

export const MATHS_OPERATIONS: readonly MathsOperation[] = [
  "counting", "numberRecognition", "addition", "subtraction",
  "multiplication", "division", "wordProblem", "missingNumber", "numberHouse",
];

export type VocabularyQuestionType = "pictureToWord" | "wordToPicture" | "meaning" | "spelling" | "opposite" | "synonym";

export const VOCABULARY_TYPES: readonly VocabularyQuestionType[] = [
  "pictureToWord", "wordToPicture", "meaning", "spelling", "opposite", "synonym",
];

/** Piecewise-linear curve over effective age, clamped at both ends. */
export class Keyframes {
  private readonly points: { age: number; value: number }[];

  constructor(pairs: [number, number][]) {
    this.points = pairs.map(([age, value]) => ({ age, value })).sort((a, b) => a.age - b.age);
  }

  value(age: number): number {
    const first = this.points[0];
    const last = this.points[this.points.length - 1];
    if (age <= first.age) return first.value;
    if (age >= last.age) return last.value;
    for (let i = 1; i < this.points.length; i++) {
      const lower = this.points[i - 1];
      const upper = this.points[i];
      if (age <= upper.age) {
        const span = upper.age - lower.age;
        if (span <= 0) return upper.value;
        return lower.value + (upper.value - lower.value) * ((age - lower.age) / span);
      }
    }
    return last.value;
  }

  /** Rounded like Swift's `.rounded()` (half away from zero). */
  intValue(age: number): number {
    const v = this.value(age);
    return Math.sign(v) * Math.round(Math.abs(v));
  }
}

export const Tuning = {
  minAge: 4,
  maxAge: 14,
  /** How far below the real age a struggling child can go. */
  maxAdjustment: 1.5,
  /** How far above the real age a child who gets everything right can go (web only for now). */
  maxAdjustmentUp: 3,
  adjustmentStepUp: 0.15,
  /** After this many perfect rounds in a row, each further perfect round steps up faster. */
  perfectRoundsForBoost: 2,
  boostStepUp: 0.5,
  adjustmentStepDown: 0.3,
  promoteThreshold: 0.9,
  easeThreshold: 0.5,

  answerOptionCount: new Keyframes([[4, 3], [7.4, 3], [7.5, 4], [14, 4]]),
  pictureOptionsBelowAge: 7,
  gentleTimerFromAge: 9,
  timerSeconds: new Keyframes([[9, 45], [10, 40], [12, 30], [14, 25]]),
  numberPadFromAge: 8,

  mathsOperationWeights: {
    counting: new Keyframes([[4, 6], [5, 4], [6, 1], [7, 0]]),
    numberRecognition: new Keyframes([[4, 4], [5, 3], [6, 1], [7, 0]]),
    addition: new Keyframes([[4, 0], [5, 3], [6, 5], [7, 4], [8, 3], [9, 2], [14, 2]]),
    subtraction: new Keyframes([[4, 0], [5, 1], [6, 3], [7, 4], [8, 3], [9, 2], [14, 2]]),
    multiplication: new Keyframes([[6, 0], [7, 0.5], [8, 3], [14, 3]]),
    division: new Keyframes([[7, 0], [8, 1], [9, 2], [10, 3], [14, 3]]),
    wordProblem: new Keyframes([[6, 0], [7, 1], [8, 1.5], [9, 2], [10, 2], [12, 2.5], [14, 3]]),
    missingNumber: new Keyframes([[6, 0], [7, 1], [8, 1.5], [9, 1.5], [10, 2], [14, 2]]),
    numberHouse: new Keyframes([[4.9, 0], [5, 1.5], [6, 2], [7, 1.5], [8, 1], [9, 0.5], [9.5, 0]]),
  } satisfies Record<MathsOperation, Keyframes>,

  countingMax: new Keyframes([[4, 5], [5, 10], [6, 12]]),
  addSubResultMax: new Keyframes([[4, 5], [5, 10], [6, 20], [7, 50], [8, 100], [10, 500], [12, 1000], [14, 5000]]),
  maxFactor: new Keyframes([[7, 5], [8, 5], [10, 10], [12, 12], [14, 20]]),
  secondFactorMax: new Keyframes([[7, 10], [10, 10], [12, 20], [14, 25]]),
  easyTablesBelowAge: 8.5,
  easyTables: [2, 5, 10],
  negativeResultsFromAge: 12,
  wordProblemNumberCap: 100,
  /** Zahlenhaus: the biggest roof number and how many floors (Zahlenraum 6 → 10 → 20 → 100). */
  houseRoofMax: new Keyframes([[5, 6], [6, 10], [7, 20], [8, 100]]),
  houseFloors: new Keyframes([[5, 2], [6, 3], [7, 4]]),
  /** From this age some houses hide the roof number instead. */
  houseHiddenRoofFromAge: 7,

  vocabularyTypeWeights: {
    pictureToWord: new Keyframes([[4, 4], [7, 2], [9, 0.5], [10, 0]]),
    wordToPicture: new Keyframes([[4, 4], [7, 1], [9, 0]]),
    meaning: new Keyframes([[5.9, 0], [6, 2], [8, 3], [14, 3]]),
    spelling: new Keyframes([[5.4, 0], [5.5, 1.5], [7, 3], [14, 2.5]]),
    opposite: new Keyframes([[6.9, 0], [7, 1.5], [10, 2], [14, 2]]),
    synonym: new Keyframes([[7.9, 0], [8, 1.5], [14, 2.5]]),
  } satisfies Record<VocabularyQuestionType, Keyframes>,
  spellingMaxLength: new Keyframes([[5, 4], [7, 6], [10, 10], [12, 14]]),
  spellingDistractorLetters: new Keyframes([[7.9, 0], [8, 1], [10, 2], [12, 3]]),

  eligibilitySlack: 0.5,
  currentBandWidth: 2,
  currentBandWeight: 3,
  reviewWeight: 1,
  recentlyCorrectMultiplier: 0.2,
} as const;

export type AgeTier = "early" | "lowerPrimary" | "upperPrimary" | "middle" | "upper";

export interface MathsDifficulty {
  operationWeights: Partial<Record<MathsOperation, number>>;
  countingMax: number;
  addSubResultMax: number;
  maxFactor: number;
  secondFactorMax: number;
  restrictToEasyTables: boolean;
  allowsNegativeResults: boolean;
  usesNumberPad: boolean;
  wordProblemNumberMax: number;
  houseRoofMax: number;
  houseFloors: number;
  houseHidesRoof: boolean;
}

export interface VocabularyDifficulty {
  questionTypeWeights: Partial<Record<VocabularyQuestionType, number>>;
  spellingMaxLength: number;
  spellingDistractorLetters: number;
}

export interface Difficulty {
  effectiveAge: number;
  level: number;
  tier: AgeTier;
  answerOptionCount: number;
  usesPictureOptions: boolean;
  allowsGentleTimer: boolean;
  timerSeconds: number;
  maths: MathsDifficulty;
  vocabulary: VocabularyDifficulty;
}

const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

export function effectiveAge(age: number, adjustment: number): number {
  const adj = clamp(adjustment, -Tuning.maxAdjustment, Tuning.maxAdjustmentUp);
  return clamp(age + adj, Tuning.minAge, Tuning.maxAge);
}

function tierFor(age: number): AgeTier {
  if (age < 6) return "early";
  if (age < 8) return "lowerPrimary";
  if (age < 10) return "upperPrimary";
  if (age < 12) return "middle";
  return "upper";
}

function normalised<K extends string>(curves: Record<K, Keyframes>, keys: readonly K[], age: number): Partial<Record<K, number>> {
  const raw = keys.map((k) => [k, Math.max(0, curves[k].value(age))] as const).filter(([, v]) => v > 0);
  const total = raw.reduce((sum, [, v]) => sum + v, 0);
  const result: Partial<Record<K, number>> = {};
  if (total > 0) for (const [k, v] of raw) result[k] = v / total;
  return result;
}

export function difficultyForEffectiveAge(a: number): Difficulty {
  const T = Tuning;
  return {
    effectiveAge: a,
    level: clamp((a - T.minAge) / (T.maxAge - T.minAge), 0, 1),
    tier: tierFor(a),
    answerOptionCount: T.answerOptionCount.intValue(a),
    usesPictureOptions: a < T.pictureOptionsBelowAge,
    allowsGentleTimer: a >= T.gentleTimerFromAge,
    timerSeconds: T.timerSeconds.intValue(a),
    maths: {
      operationWeights: normalised(T.mathsOperationWeights, MATHS_OPERATIONS, a),
      countingMax: T.countingMax.intValue(a),
      addSubResultMax: T.addSubResultMax.intValue(a),
      maxFactor: T.maxFactor.intValue(a),
      secondFactorMax: T.secondFactorMax.intValue(a),
      restrictToEasyTables: a < T.easyTablesBelowAge,
      allowsNegativeResults: a >= T.negativeResultsFromAge,
      usesNumberPad: a >= T.numberPadFromAge,
      wordProblemNumberMax: Math.min(T.addSubResultMax.intValue(a), T.wordProblemNumberCap),
      houseRoofMax: T.houseRoofMax.intValue(a),
      houseFloors: T.houseFloors.intValue(a),
      houseHidesRoof: a >= T.houseHiddenRoofFromAge,
    },
    vocabulary: {
      questionTypeWeights: normalised(T.vocabularyTypeWeights, VOCABULARY_TYPES, a),
      spellingMaxLength: T.spellingMaxLength.intValue(a),
      spellingDistractorLetters: T.spellingDistractorLetters.intValue(a),
    },
  };
}

export function difficultyForAge(age: number, adjustment = 0): Difficulty {
  return difficultyForEffectiveAge(effectiveAge(age, adjustment));
}

/** A subject's level: years above (+) or below (−) the real age, and the run of perfect rounds. */
export interface Adaptivity {
  adjustment: number;
  perfectRounds: number;
}

/**
 * Adaptivity after a round (PLAN.md §5.4): 90 %+ steps up a little; from the
 * second perfect round in a row each perfect round steps up faster ("boosted");
 * under 50 % steps back down and ends the run.
 */
export function nextAdaptivity(current: Adaptivity, correct: number, total: number): Adaptivity & { boosted: boolean } {
  if (total <= 0) return { ...current, boosted: false };
  const score = correct / total;
  const perfectRounds = score >= 1 ? current.perfectRounds + 1 : 0;
  const boosted = perfectRounds >= Tuning.perfectRoundsForBoost && current.adjustment < Tuning.maxAdjustmentUp;
  let next = current.adjustment;
  if (boosted) next += Tuning.boostStepUp;
  else if (score >= Tuning.promoteThreshold) next += Tuning.adjustmentStepUp;
  else if (score < Tuning.easeThreshold) next -= Tuning.adjustmentStepDown;
  return { adjustment: clamp(next, -Tuning.maxAdjustment, Tuning.maxAdjustmentUp), perfectRounds, boosted };
}

/** One round on its own, without a run of perfect rounds. */
export function nextAdjustment(current: number, correct: number, total: number): number {
  return nextAdaptivity({ adjustment: current, perfectRounds: 0 }, correct, total).adjustment;
}

/** Content selection (PLAN.md §5.3). */
export function isEligible(d: Difficulty, minAge: number, maxAge?: number): boolean {
  const upper = maxAge ?? Tuning.maxAge;
  return minAge <= d.effectiveAge + Tuning.eligibilitySlack && upper >= d.effectiveAge - Tuning.eligibilitySlack;
}

export function selectionWeight(d: Difficulty, minAge: number, recentlyCorrect: boolean): number {
  const inBand = minAge >= d.effectiveAge - Tuning.currentBandWidth;
  const base = inBand ? Tuning.currentBandWeight : Tuning.reviewWeight;
  return recentlyCorrect ? base * Tuning.recentlyCorrectMultiplier : base;
}
