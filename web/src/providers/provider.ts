import type { Difficulty } from "../domain/difficulty";
import type { Question } from "../domain/question";
import type { Rng } from "../domain/random";

/** Produces the questions for one round of a subject. */
export interface QuestionProvider {
  /** @param recentlyCorrect content ids answered correctly in recent rounds (down-weighted). */
  makeQuestions(count: number, difficulty: Difficulty, recentlyCorrect: Set<string>, rng: Rng): Question[];
}
