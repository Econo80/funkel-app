// One screen of a round, built at runtime; all text is in the learning language.

export type QuestionVisual =
  | { kind: "emoji"; emoji: string }
  | { kind: "countable"; symbol: string; count: number }
  | { kind: "equation"; text: string };

export interface AnswerOption {
  id: number;
  text: string;
  /** Shown instead of the text: a picture (vocabulary) or a group to count (maths). */
  emoji?: string;
}

export type QuestionFormat =
  | { kind: "multipleChoice"; options: AnswerOption[]; correctIndex: number }
  | { kind: "numberEntry"; answer: number }
  | { kind: "buildSequence"; tiles: string[]; answer: string[] };

export interface Question {
  id: string;
  subjectId: string;
  /** Content id, used to avoid repeats across rounds. */
  contentId?: string;
  prompt: string;
  /** Fill-the-gap sentence containing ___. */
  sentence?: string;
  visual?: QuestionVisual;
  format: QuestionFormat;
  /** Shown gently after a wrong answer. */
  explanation?: string;
  /** What read-aloud says, e.g. "3 plus 4" instead of "3 + 4". */
  spoken?: string;
}

let counter = 0;
export function makeQuestion(q: Omit<Question, "id">): Question {
  counter += 1;
  return { id: `q${counter}`, ...q };
}

export function spokenText(q: Question): string {
  if (q.spoken) return q.spoken;
  if (!q.sentence) return q.prompt;
  return `${q.prompt} ${q.sentence.replaceAll("___", "…")}`;
}

/** The correct answer as text, for the gentle "the answer was …" reveal. */
export function correctAnswerText(format: QuestionFormat): string {
  switch (format.kind) {
    case "multipleChoice":
      return format.options[format.correctIndex]?.text ?? "";
    case "numberEntry":
      return String(format.answer);
    case "buildSequence": {
      const joiner = format.tiles.every((t) => [...t].length === 1) ? "" : " ";
      return format.answer.join(joiner);
    }
  }
}
