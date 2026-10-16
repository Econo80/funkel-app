// Authored questions in generic formats — port of QuestionBankProvider.swift.
// Used by General Knowledge now and by Grammar later (pure content).
import type { BankItem } from "../content/types";
import { isEligible, selectionWeight, type Difficulty } from "../domain/difficulty";
import { makeQuestion, type Question, type QuestionFormat } from "../domain/question";
import { shuffled, weightedPick, type Rng } from "../domain/random";
import type { QuestionProvider } from "./provider";

/** Wrong tiles are mixed into sequence questions from this age. */
export const SEQUENCE_DISTRACTORS_FROM_AGE = 8;
/** Picking a question halves the weight of the rest of its category. */
const SAME_CATEGORY_DAMPING = 0.5;

export function isUsable(item: BankItem): boolean {
  if (item.format === "multipleChoice") {
    return !!item.options && !!item.correct && item.options.includes(item.correct) && new Set(item.options).size >= 2;
  }
  return (item.answer?.length ?? 0) >= 2;
}

export class QuestionBankProvider implements QuestionProvider {
  constructor(readonly subjectId: string, readonly items: BankItem[]) {}

  makeQuestions(count: number, difficulty: Difficulty, recentlyCorrect: Set<string>, rng: Rng): Question[] {
    let remaining = this.items.filter((i) => isUsable(i) && isEligible(difficulty, i.minAge, i.maxAge));
    const damping = new Map<string, number>();
    const questions: Question[] = [];

    // A short bank yields a shorter round rather than repeating a question.
    while (questions.length < count && remaining.length > 0) {
      const weighted = remaining.map((i) => [
        i,
        selectionWeight(difficulty, i.minAge, recentlyCorrect.has(i.id)) * (damping.get(i.category ?? "") ?? 1),
      ] as const);
      const item = weightedPick(rng, weighted);
      if (!item) break;
      remaining = remaining.filter((i) => i !== item);
      damping.set(item.category ?? "", (damping.get(item.category ?? "") ?? 1) * SAME_CATEGORY_DAMPING);
      questions.push(this.makeQuestion(rng, item, difficulty));
    }
    return questions;
  }

  private makeQuestion(rng: Rng, item: BankItem, d: Difficulty): Question {
    let format: QuestionFormat;
    if (item.format === "multipleChoice") {
      const correct = item.correct!;
      const wrong = [...new Set(item.options!.filter((o) => o !== correct))];
      const values = shuffled(rng, [correct, ...shuffled(rng, wrong).slice(0, d.answerOptionCount - 1)]);
      format = { kind: "multipleChoice", options: values.map((text, id) => ({ id, text })), correctIndex: values.indexOf(correct) };
    } else {
      const answer = item.answer!;
      const extra = d.effectiveAge >= SEQUENCE_DISTRACTORS_FROM_AGE ? item.distractors ?? [] : [];
      format = { kind: "buildSequence", tiles: shuffled(rng, [...answer, ...extra]), answer };
    }
    return makeQuestion({
      subjectId: this.subjectId,
      contentId: item.id,
      prompt: item.prompt,
      sentence: item.sentence,
      visual: item.emoji ? { kind: "emoji", emoji: item.emoji } : undefined,
      format,
      explanation: item.explanation,
    });
  }
}
