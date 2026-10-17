// Procedural maths — port of MathsProblem.swift and MathsQuestionGenerator.swift.
import type { Phrasing } from "../content/phrasing";
import type { MathsContent } from "../content/types";
import {
  MATHS_OPERATIONS,
  Tuning,
  type Difficulty,
  type MathsDifficulty,
  type MathsOperation,
} from "../domain/difficulty";
import { makeQuestion, type AnswerOption, type NumberHouse, type Question, type QuestionFormat } from "../domain/question";
import { randomElement, randomInt, shuffled, weightedPick, type Rng } from "../domain/random";
import type { QuestionProvider } from "./provider";

export type Arithmetic = "add" | "subtract" | "multiply" | "divide";

export function apply(kind: Arithmetic, a: number, b: number): number {
  switch (kind) {
    case "add": return a + b;
    case "subtract": return a - b;
    case "multiply": return a * b;
    case "divide": return b === 0 ? 0 : Math.trunc(a / b);
  }
}

const ARITHMETIC_FOR: Partial<Record<MathsOperation, Arithmetic>> = {
  addition: "add", subtraction: "subtract", multiplication: "multiply", division: "divide",
};

export interface MathsProblem {
  operation: MathsOperation;
  arithmetic?: Arithmetic;
  a: number;
  b: number;
  result: number;
  /** What the child enters: b for missing numbers, otherwise result. */
  answer: number;
}

export function unlockedArithmetic(d: MathsDifficulty): Arithmetic[] {
  const kinds: Arithmetic[] = ["add", "subtract"];
  if (d.operationWeights.multiplication !== undefined) kinds.push("multiply");
  if (d.operationWeights.division !== undefined) kinds.push("divide");
  return kinds;
}

function factor(rng: Rng, d: MathsDifficulty, wordProblem: boolean): number {
  if (d.restrictToEasyTables) return randomElement(rng, Tuning.easyTables) ?? 2;
  const upper = wordProblem ? Math.min(10, Math.max(2, d.maxFactor)) : Math.max(2, d.maxFactor);
  return randomInt(rng, 2, upper);
}

function operands(rng: Rng, kind: Arithmetic, d: MathsDifficulty, wordProblem: boolean): [number, number] {
  // Word problems avoid 0 and 1 so the plural always fits ("2 Äpfel").
  const minOperand = wordProblem ? 2 : 1;
  const maxSum = Math.max(minOperand * 2, wordProblem ? d.wordProblemNumberMax : d.addSubResultMax);

  switch (kind) {
    case "add": {
      const a = randomInt(rng, minOperand, maxSum - minOperand);
      const b = randomInt(rng, minOperand, maxSum - a);
      return [a, b];
    }
    case "subtract": {
      if (d.allowsNegativeResults && !wordProblem && rng() < 0.25) {
        const a = randomInt(rng, 1, Math.max(1, Math.floor(maxSum / 2)));
        const b = randomInt(rng, a + 1, Math.max(a + 1, maxSum));
        return [a, b];
      }
      const a = randomInt(rng, minOperand + 1, Math.max(minOperand + 1, maxSum));
      const b = randomInt(rng, minOperand, a - 1);
      return [a, b];
    }
    case "multiply": {
      const first = factor(rng, d, wordProblem);
      const secondMax = wordProblem ? 10 : Math.max(2, d.secondFactorMax);
      const second = randomInt(rng, wordProblem ? 2 : 1, secondMax);
      return rng() < 0.5 ? [first, second] : [second, first];
    }
    case "divide": {
      const divisor = factor(rng, d, wordProblem);
      const quotientMax = wordProblem ? 10 : Math.max(2, d.secondFactorMax);
      const quotient = randomInt(rng, wordProblem ? 2 : 1, quotientMax);
      return [divisor * quotient, divisor];
    }
  }
}

export function makeProblem(rng: Rng, operation: MathsOperation, d: MathsDifficulty, preferred?: Arithmetic): MathsProblem {
  switch (operation) {
    case "counting":
    case "numberRecognition": {
      const n = randomInt(rng, 1, Math.max(2, d.countingMax));
      return { operation, a: n, b: 0, result: n, answer: n };
    }
    case "missingNumber": {
      const kind = preferred ?? randomElement(rng, unlockedArithmetic(d).filter((k) => k !== "divide")) ?? "add";
      const [a, b] = operands(rng, kind, d, false);
      return { operation, arithmetic: kind, a, b, result: apply(kind, a, b), answer: b };
    }
    case "wordProblem": {
      const kind = preferred ?? "add";
      const [a, b] = operands(rng, kind, d, true);
      const result = apply(kind, a, b);
      return { operation, arithmetic: kind, a, b, result, answer: result };
    }
    default: {
      const kind = ARITHMETIC_FOR[operation] ?? "add";
      const [a, b] = operands(rng, kind, d, false);
      const result = apply(kind, a, b);
      return { operation, arithmetic: kind, a, b, result, answer: result };
    }
  }
}

/** Plausible wrong answers: near misses a child might actually make. */
export function distractors(rng: Rng, p: MathsProblem, count: number, allowsNegative: boolean, upperBound?: number): number[] {
  const answer = p.answer;
  const candidates = [answer - 1, answer + 1, answer - 2, answer + 2];
  if (p.arithmetic === "multiply") candidates.push(p.a * (p.b + 1), p.a * Math.max(0, p.b - 1), (p.a + 1) * p.b);
  else if ((p.arithmetic === "add" || p.arithmetic === "subtract") && Math.abs(answer) >= 10) candidates.push(answer + 10, answer - 10);
  if (answer >= 10) {
    const swapped = Number([...String(answer)].reverse().join(""));
    if (swapped !== answer) candidates.push(swapped);
  }

  const floor = p.operation === "counting" || p.operation === "numberRecognition" ? 1 : 0;
  const fits = (v: number) => (allowsNegative || v >= floor) && (upperBound === undefined || v <= upperBound);
  const seen = new Set([answer]);
  const result: number[] = [];
  for (const value of shuffled(rng, candidates)) {
    if (result.length >= count) break;
    if (fits(value) && !seen.has(value)) { seen.add(value); result.push(value); }
  }
  for (let spread = 3; result.length < count && spread < 1000; spread++) {
    const value = answer + randomInt(rng, -spread, spread);
    if (fits(value) && !seen.has(value)) { seen.add(value); result.push(value); }
  }
  return result;
}

/**
 * A Zahlenhaus for this age: from roofs up to 6 with two floors (age 5) to roofs
 * up to 100 with four floors. Each floor hides one room; from 7 some houses hide
 * the roof instead and give one floor in full. Young children get the floors in
 * order (1 + 5, 2 + 4, …) so the pattern is easy to see.
 */
export function makeNumberHouse(rng: Rng, d: MathsDifficulty): NumberHouse {
  const floorsWanted = Math.max(2, d.houseFloors);
  const roofMin = Math.max(3, floorsWanted + 1, Math.ceil(d.houseRoofMax / 2));
  const roof = randomInt(rng, roofMin, Math.max(roofMin, d.houseRoofMax));
  const withZero = d.houseRoofMax >= 10 && rng() < 0.2; // 0 + 7 is a decomposition too
  const lefts = shuffled(rng, Array.from({ length: roof + 1 }, (_, i) => i).filter((i) => withZero || (i > 0 && i < roof)))
    .slice(0, Math.min(floorsWanted, roof - 1));
  if (d.houseRoofMax <= 10) lefts.sort((a, b) => a - b);
  const floors = lefts.map((l) => [l, roof - l] as [number, number]);

  const hidesRoof = d.houseHidesRoof && rng() < 0.3;
  const hidden = floors.flatMap((_, i) => (hidesRoof && i === 0 ? [] : [`f${i}${rng() < 0.5 ? "l" : "r"}`]));
  return { roof, floors, hidden: hidesRoof ? ["roof", ...hidden] : hidden };
}

export class MathsQuestionGenerator implements QuestionProvider {
  constructor(readonly subjectId: string, readonly content: MathsContent, readonly phrasing: Phrasing) {}

  makeQuestions(count: number, difficulty: Difficulty, _recentlyCorrect: Set<string>, rng: Rng): Question[] {
    const weights = MATHS_OPERATIONS.map((op) => [op, difficulty.maths.operationWeights[op] ?? 0] as const);
    const questions: Question[] = [];
    const seenKeys = new Set<string>();
    while (questions.length < count) {
      const operation = weightedPick(rng, weights) ?? "addition";
      let candidate = this.makeQuestion(rng, operation, difficulty);
      for (let attempts = 0; seenKeys.has(candidate.key) && attempts < 8; attempts++) {
        candidate = this.makeQuestion(rng, operation, difficulty);
      }
      seenKeys.add(candidate.key);
      questions.push(candidate.question);
    }
    return questions;
  }

  private symbol(kind: Arithmetic): string {
    return this.phrasing.text({ add: "maths.symbol.plus", subtract: "maths.symbol.minus", multiply: "maths.symbol.times", divide: "maths.symbol.divide" }[kind]);
  }

  private word(kind: Arithmetic): string {
    return this.phrasing.text({ add: "maths.word.plus", subtract: "maths.word.minus", multiply: "maths.word.times", divide: "maths.word.divide" }[kind]);
  }

  private item(rng: Rng) {
    return randomElement(rng, this.content.items) ?? { singular: "Stern", plural: "Sterne", emoji: "⭐️" };
  }

  private format(rng: Rng, p: MathsProblem, d: Difficulty, upperBound?: number): QuestionFormat {
    if (d.maths.usesNumberPad) return { kind: "numberEntry", answer: p.answer };
    const wrong = distractors(rng, p, d.answerOptionCount - 1, d.maths.allowsNegativeResults, upperBound);
    const values = shuffled(rng, [p.answer, ...wrong]);
    return {
      kind: "multipleChoice",
      options: values.map((v, i) => ({ id: i, text: String(v) })),
      correctIndex: Math.max(0, values.indexOf(p.answer)),
    };
  }

  private makeQuestion(rng: Rng, operation: MathsOperation, d: Difficulty): { question: Question; key: string } {
    const m = d.maths;
    const subjectId = this.subjectId;

    switch (operation) {
      case "counting": {
        const p = makeProblem(rng, "counting", m);
        const item = this.item(rng);
        return {
          question: makeQuestion({
            subjectId,
            prompt: this.phrasing.text("maths.counting", { items: item.plural }),
            visual: { kind: "countable", symbol: item.emoji, count: p.answer },
            format: this.format(rng, p, d, m.countingMax + 2),
          }),
          key: `count-${p.answer}`,
        };
      }
      case "numberRecognition": {
        const p = makeProblem(rng, "numberRecognition", m);
        const item = this.item(rng);
        const wrong = distractors(rng, p, d.answerOptionCount - 1, false, Math.max(p.answer + 2, m.countingMax));
        const values = shuffled(rng, [p.answer, ...wrong]);
        const options: AnswerOption[] = values.map((v, i) => ({ id: i, text: String(v), emoji: item.emoji.repeat(v) }));
        return {
          question: makeQuestion({
            subjectId,
            prompt: this.phrasing.text("maths.numberRecognition", { n: p.answer, items: item.plural }),
            visual: { kind: "equation", text: String(p.answer) },
            format: { kind: "multipleChoice", options, correctIndex: Math.max(0, values.indexOf(p.answer)) },
          }),
          key: `recognise-${p.answer}`,
        };
      }
      case "missingNumber": {
        const p = makeProblem(rng, "missingNumber", m);
        const kind = p.arithmetic ?? "add";
        const written = `${p.a} ${this.symbol(kind)} ? = ${p.result}`;
        const spoken = `${p.a} ${this.word(kind)} ${this.phrasing.text("maths.word.blank")} ${this.phrasing.text("maths.word.equals")} ${p.result}`;
        const prompt = this.phrasing.text("maths.missingNumber");
        return {
          question: makeQuestion({
            subjectId, prompt,
            visual: { kind: "equation", text: written },
            format: this.format(rng, p, d),
            spoken: `${prompt} ${spoken}`,
          }),
          key: written,
        };
      }
      case "numberHouse": {
        const house = makeNumberHouse(rng, m);
        const roofHidden = house.hidden.includes("roof");
        const prompt = this.phrasing.text(roofHidden ? "maths.numberHouse.roof" : "maths.numberHouse");
        return {
          question: makeQuestion({
            subjectId, prompt,
            format: { kind: "numberHouse", house },
            spoken: roofHidden ? prompt : `${prompt} ${this.phrasing.text("maths.numberHouse.spokenRoof", { roof: house.roof })}`,
          }),
          key: `house-${house.roof}`,
        };
      }
      case "wordProblem": {
        const unlocked = unlockedArithmetic(m);
        const templates = this.content.wordProblems.filter(
          (t) => t.minAge <= d.effectiveAge && unlocked.includes(ARITHMETIC_FOR[t.operation] ?? "add"),
        );
        const template = randomElement(rng, templates);
        if (!template) return this.makeQuestion(rng, "addition", d);
        const kind = ARITHMETIC_FOR[template.operation] ?? "add";
        const p = makeProblem(rng, "wordProblem", m, kind);
        const item = this.item(rng);
        const name = randomElement(rng, this.content.names) ?? "";
        let text = template.template;
        for (const [k, v] of Object.entries({ name, a: p.a, b: p.b, item: item.singular, items: item.plural })) {
          text = text.replaceAll(`{${k}}`, String(v));
        }
        return {
          question: makeQuestion({ subjectId, prompt: text, visual: { kind: "emoji", emoji: item.emoji }, format: this.format(rng, p, d) }),
          key: `word-${p.a}-${kind}-${p.b}`,
        };
      }
      default: {
        const p = makeProblem(rng, operation, m);
        const kind = p.arithmetic ?? "add";
        const written = `${p.a} ${this.symbol(kind)} ${p.b}`;
        const spoken = `${p.a} ${this.word(kind)} ${p.b}`;
        return {
          question: makeQuestion({
            subjectId,
            prompt: this.phrasing.text("maths.equation", { equation: written }),
            visual: { kind: "equation", text: `${written} = ?` },
            format: this.format(rng, p, d),
            spoken: this.phrasing.text("maths.equation", { equation: spoken }),
          }),
          key: written,
        };
      }
    }
  }
}
