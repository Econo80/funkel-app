// "Denken": reasoning puzzles like the ones in classic reasoning tests, made
// up fresh for every round and graded by age: continue a pattern, find the odd
// one out, number sequences, 3×3 picture matrices and picture analogies.
// Groups and analogies come from Content/<lang>/logic.json; everything else is
// generated. Mirrored in the iOS app (LogicPuzzleGenerator.swift).
import type { LogicContent, LogicGroup } from "../content/types";
import type { Phrasing } from "../content/phrasing";
import { Keyframes, type Difficulty } from "../domain/difficulty";
import { makeQuestion, type AnswerOption, type Question } from "../domain/question";
import { randomInt, shuffled, weightedPick, type Rng } from "../domain/random";
import type { QuestionProvider } from "./provider";

export type LogicKind = "pattern" | "oddOneOut" | "numberSequence" | "matrix" | "analogy";
export const LOGIC_KINDS: readonly LogicKind[] = ["pattern", "oddOneOut", "numberSequence", "matrix", "analogy"];

/** How often each kind comes up, by effective age (0 = not yet). */
export const LOGIC_WEIGHTS: Record<LogicKind, Keyframes> = {
  pattern: new Keyframes([[4, 5], [7, 2], [10, 1], [14, 1]]),
  oddOneOut: new Keyframes([[4, 4], [7, 2], [10, 1.5], [14, 1]]),
  numberSequence: new Keyframes([[5.4, 0], [5.5, 1.5], [8, 3], [14, 3]]),
  matrix: new Keyframes([[6.4, 0], [6.5, 1.5], [9, 3], [14, 3]]),
  analogy: new Keyframes([[6.4, 0], [6.5, 1.5], [10, 2], [14, 2]]),
};

/** Coloured shapes: SHAPES[shape][colour], colours red, orange, yellow, green, blue, purple. */
export const SHAPES = [
  ["🔴", "🟠", "🟡", "🟢", "🔵", "🟣"],
  ["🟥", "🟧", "🟨", "🟩", "🟦", "🟪"],
  ["❤️", "🧡", "💛", "💚", "💙", "💜"],
];
/** Pictures for the youngest children's patterns. */
const PICTURES = ["🐶", "🐱", "🐭", "🐰", "🍎", "🍌", "🍇", "⭐", "🌙", "☀️", "🌸", "🚗"];
export const MISSING = "❓";

interface Puzzle { question: Question; key: string }

export class LogicPuzzleGenerator implements QuestionProvider {
  constructor(readonly subjectId: string, readonly content: LogicContent, readonly phrasing: Phrasing) {}

  makeQuestions(count: number, difficulty: Difficulty, _recentlyCorrect: Set<string>, rng: Rng): Question[] {
    const a = difficulty.effectiveAge;
    const weights = LOGIC_KINDS.map((k) => [k, Math.max(0, LOGIC_WEIGHTS[k].value(a))] as const).filter(([, w]) => w > 0);
    const questions: Question[] = [];
    const keys = new Set<string>();
    let last: LogicKind | undefined;
    for (let attempts = 0; questions.length < count && attempts < count * 20; attempts++) {
      // Variety: the same kind twice in a row only when nothing else fits.
      const kind = weightedPick(rng, weights.filter(([k]) => k !== last || weights.length === 1)) ?? "pattern";
      const puzzle = this.make(kind, difficulty, rng);
      if (!puzzle || keys.has(puzzle.key)) continue;
      keys.add(puzzle.key);
      last = kind;
      questions.push(puzzle.question);
    }
    return questions;
  }

  /** One puzzle of a kind (used by the Denk-Test to pick kinds per step). */
  make(kind: LogicKind, d: Difficulty, rng: Rng): Puzzle | undefined {
    switch (kind) {
      case "pattern": return this.pattern(d, rng);
      case "oddOneOut": return this.oddOneOut(d, rng);
      case "numberSequence": return this.numberSequence(d, rng);
      case "matrix": return this.matrix(d, rng);
      case "analogy": return this.analogy(d, rng);
    }
  }

  private choice(rng: Rng, correct: string, wrong: string[], count: number): { options: AnswerOption[]; correctIndex: number } {
    const values = shuffled(rng, [correct, ...shuffled(rng, [...new Set(wrong)].filter((w) => w !== correct)).slice(0, count - 1)]);
    return { options: values.map((v, id) => ({ id, text: v, emoji: v })), correctIndex: values.indexOf(correct) };
  }

  private question(kind: LogicKind, prompt: string, visual: Question["visual"], format: Question["format"], explanation?: string): Question {
    return { ...makeQuestion({ subjectId: this.subjectId, prompt, visual, format, explanation }), skill: kind };
  }

  // MARK: Patterns

  /** Repeating units, longer with age; from 8 a gap in the middle; from 9 two features (shape and colour) that repeat separately. */
  private pattern(d: Difficulty, rng: Rng): Puzzle | undefined {
    const a = d.effectiveAge;
    let sequence: string[];
    let pool: string[];
    if (a >= 9) {
      // Shapes repeat every 2 and colours every 3 (or the other way round): both must be right.
      const [shapeEvery, colourEvery] = rng() < 0.5 ? [2, 3] : [3, 2];
      const shapes = shuffled(rng, [0, 1, 2]).slice(0, shapeEvery);
      const colours = shuffled(rng, [0, 1, 2, 3, 4, 5]).slice(0, colourEvery);
      sequence = Array.from({ length: 8 }, (_, i) => SHAPES[shapes[i % shapeEvery]][colours[i % colourEvery]]);
      pool = shapes.flatMap((s) => colours.map((c) => SHAPES[s][c]));
    } else {
      const units = a < 5.5 ? ["AB"] : a < 7 ? ["AB", "ABC", "AAB", "ABB"] : ["ABC", "AABB", "ABBC", "ABCD", "AABC"];
      const unit = units[randomInt(rng, 0, units.length - 1)];
      const letters = [...new Set(unit)];
      const symbols = a < 6.5 ? shuffled(rng, PICTURES).slice(0, letters.length) : shuffled(rng, SHAPES[randomInt(rng, 0, 2)]).slice(0, letters.length);
      const map = Object.fromEntries(letters.map((l, i) => [l, symbols[i]]));
      const length = Math.max(6, unit.length * 2 + 1);
      sequence = Array.from({ length: length + 1 }, (_, i) => map[unit[i % unit.length]]);
      pool = [...symbols, ...(a < 6.5 ? PICTURES : SHAPES.flat()).filter((s) => !symbols.includes(s)).slice(0, 2)];
    }
    const gap = a >= 8 && rng() < 0.5 ? randomInt(rng, 2, sequence.length - 2) : sequence.length - 1;
    const answer = sequence[gap];
    const shown = sequence.map((s, i) => (i === gap ? MISSING : s));
    return {
      key: `pattern:${shown.join("")}`,
      question: this.question("pattern", this.phrasing.text(gap === sequence.length - 1 ? "logic.pattern" : "logic.patternGap"),
        { kind: "tiles", items: shown }, { kind: "multipleChoice", ...this.choice(rng, answer, pool, d.answerOptionCount) }),
    };
  }

  // MARK: Odd one out

  /** Three from one group and one from another: under 8 from a different family (fruit vs cars), then a related one (birds vs insects). */
  private oddOneOut(d: Difficulty, rng: Rng): Puzzle | undefined {
    const a = d.effectiveAge;
    const groups = this.content.groups.filter((g) => g.minAge <= a + 0.5);
    const main = groups[randomInt(rng, 0, groups.length - 1)];
    if (!main) return undefined;
    const related = (g: LogicGroup) => g.family === main.family;
    const others = groups.filter((g) => g !== main && (a >= 8 ? related(g) : !related(g)));
    const odd = shuffled(rng, others.length ? others : groups.filter((g) => g !== main))[0];
    if (!odd) return undefined;
    // Always three that belong together: with two, either could be "the odd one".
    const same = shuffled(rng, main.items).slice(0, 3);
    const out = odd.items[randomInt(rng, 0, odd.items.length - 1)];
    const values = shuffled(rng, [...same, out]);
    return {
      key: `odd:${[...same].sort().join("")}${out}`,
      question: this.question("oddOneOut", this.phrasing.text("logic.oddOneOut"), undefined,
        { kind: "multipleChoice", options: values.map((v, id) => ({ id, text: v, emoji: v })), correctIndex: values.indexOf(out) },
        this.phrasing.text("logic.oddOneOut.explain", { item: main.label })),
    };
  }

  // MARK: Number sequences

  /** Steps get bigger, then go down, double, alternate, grow, and finally squares and sums. */
  private numberSequence(d: Difficulty, rng: Rng): Puzzle | undefined {
    const a = d.effectiveAge;
    const rules: (() => number[])[] = [];
    const up = (start: number, step: number, n = 6) => Array.from({ length: n }, (_, i) => start + i * step);
    if (a < 7) {
      rules.push(() => up(randomInt(rng, 1, 5), 1), () => up(randomInt(rng, 0, 4) * 2, 2), () => up(5, 5));
      if (a >= 6.5) rules.push(() => up(10, 10), () => up(randomInt(rng, 12, 20), -1));
    } else if (a < 8.5) {
      rules.push(() => up(randomInt(rng, 1, 9), randomInt(rng, 3, 5)), () => up(randomInt(rng, 25, 40), -randomInt(rng, 2, 5)), () => up(randomInt(rng, 1, 9) * 10, 10));
    } else if (a < 10) {
      rules.push(
        () => { const s = randomInt(rng, 1, 5); return Array.from({ length: 6 }, (_, i) => s * 2 ** i); },
        () => { const s = randomInt(rng, 1, 5); let v = s; return Array.from({ length: 6 }, (_, i) => (v += i)); },
        () => { const x = randomInt(rng, 2, 5), y = randomInt(rng, 1, 3); let v = randomInt(rng, 1, 10); return Array.from({ length: 7 }, (_, i) => (i === 0 ? v : (v += i % 2 ? x : -y))); },
      );
    } else {
      rules.push(
        () => { const s = randomInt(rng, 1, 3); return Array.from({ length: 6 }, (_, i) => (i + s) ** 2); },
        () => { const s = randomInt(rng, 1, 3); return Array.from({ length: 6 }, (_, i) => s * 3 ** i); },
        () => { const first = randomInt(rng, 1, 3); const f = [first, first + randomInt(rng, 1, 3)]; while (f.length < 7) f.push(f[f.length - 1] + f[f.length - 2]); return f; },
        () => { const s = randomInt(rng, 1, 4); let v = s; return Array.from({ length: 6 }, (_, i) => (i === 0 ? v : (v = v * 2 + 1))); },
        () => { const big = randomInt(rng, 2, 6) * 64; return Array.from({ length: 6 }, (_, i) => big / 2 ** i); },
      );
    }
    const seq = rules[randomInt(rng, 0, rules.length - 1)]();
    if (seq.some((v) => v < 0 || !Number.isInteger(v) || v > 9999)) return undefined;
    const gap = a >= 8.5 && rng() < 0.35 ? randomInt(rng, 1, seq.length - 2) : seq.length - 1;
    const answer = seq[gap];
    const text = seq.map((v, i) => (i === gap ? "?" : String(v))).join(", ");
    const step = Math.abs(seq[seq.length - 1] - seq[seq.length - 2]) || 1;
    const wrong = [answer + 1, answer - 1, answer + step, answer - step, answer + 2, answer + 10].filter((v) => v >= 0 && v !== answer).map(String);
    const format: Question["format"] = d.maths.usesNumberPad
      ? { kind: "numberEntry", answer }
      : (() => { const c = this.choice(rng, String(answer), wrong, d.answerOptionCount); return { kind: "multipleChoice" as const, options: c.options.map(({ id, text }) => ({ id, text })), correctIndex: c.correctIndex }; })();
    return {
      key: `numbers:${text}`,
      question: { ...this.question("numberSequence", this.phrasing.text(gap === seq.length - 1 ? "logic.numbers" : "logic.numbersGap"), { kind: "equation", text }, format), spoken: `${this.phrasing.text(gap === seq.length - 1 ? "logic.numbers" : "logic.numbersGap")} ${text.replaceAll("?", "…")}` },
    };
  }

  // MARK: Matrices

  /**
   * A 3×3 field with one picture missing. Under 8: each row one shape, each
   * column one colour. Under 10: every row and column has each shape and each
   * colour once (a Latin square), and the gap can be anywhere. From 10: also
   * one, two or three of them, growing along the row.
   */
  private matrix(d: Difficulty, rng: Rng): Puzzle | undefined {
    const a = d.effectiveAge;
    const shapes = shuffled(rng, [0, 1, 2]);
    const colours = shuffled(rng, [0, 1, 2, 3, 4, 5]).slice(0, 3);
    const counted = a >= 10;
    const latin = a >= 8;
    const cell = (r: number, c: number) => {
      const s = latin ? shapes[(r + c) % 3] : shapes[r];
      const col = latin ? colours[(r + 2 * c) % 3] : colours[c];
      return SHAPES[s][col].repeat(counted ? c + 1 : 1);
    };
    const cells = Array.from({ length: 9 }, (_, i) => cell(Math.floor(i / 3), i % 3));
    const gap = latin ? randomInt(rng, 0, 8) : 8;
    const answer = cells[gap];
    const r = Math.floor(gap / 3), c = gap % 3;
    const s0 = latin ? shapes[(r + c) % 3] : shapes[r], c0 = latin ? colours[(r + 2 * c) % 3] : colours[c];
    const n = counted ? c + 1 : 1;
    const wrong = [
      ...shapes.filter((s) => s !== s0).map((s) => SHAPES[s][c0].repeat(n)),
      ...colours.filter((x) => x !== c0).map((x) => SHAPES[s0][x].repeat(n)),
      ...(counted ? [1, 2, 3].filter((k) => k !== n).map((k) => SHAPES[s0][c0].repeat(k)) : []),
    ];
    return {
      key: `matrix:${cells.join("")}:${gap}`,
      question: this.question("matrix", this.phrasing.text("logic.matrix"),
        { kind: "tiles", items: cells.map((x, i) => (i === gap ? MISSING : x)), columns: 3 },
        { kind: "multipleChoice", ...this.choice(rng, answer, shuffled(rng, wrong), d.answerOptionCount) }),
    };
  }

  // MARK: Analogies

  private analogy(d: Difficulty, rng: Rng): Puzzle | undefined {
    const pool = this.content.analogies.filter((x) => x.minAge <= d.effectiveAge + 0.5);
    const item = pool[randomInt(rng, 0, pool.length - 1)];
    if (!item) return undefined;
    return {
      key: `analogy:${item.a}${item.c}`,
      question: this.question("analogy", this.phrasing.text("logic.analogy"),
        { kind: "tiles", items: [item.a, "➡️", item.b, item.c, "➡️", MISSING], columns: 3 },
        { kind: "multipleChoice", ...this.choice(rng, item.answer, item.wrong, d.answerOptionCount) }, item.explanation),
    };
  }
}
