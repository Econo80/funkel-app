// One round as a pure state machine — port of RoundViewModel.swift.
// Every function returns a new state; invalid actions return the same state.
import { houseCellValue, type Question } from "./question";

export type Phase = "answering" | "correct" | "wrong" | "finished";

export interface RoundState {
  questions: Question[];
  index: number;
  phase: Phase;
  selectedOptionIndex?: number;
  numberInput: string;
  /** Indices into the current question's tiles, in placement order. */
  placedTiles: number[];
  /** Zahlenhaus: what the child typed per hidden cell, and the cell being filled. */
  houseInputs: Record<string, string>;
  houseCell?: string;
  results: boolean[];
  correctContentIds: string[];
  allowsNegative: boolean;
}

export function startRound(questions: Question[], allowsNegative: boolean): RoundState {
  return {
    questions,
    index: 0,
    phase: questions.length === 0 ? "finished" : "answering",
    numberInput: "",
    placedTiles: [],
    houseInputs: {},
    houseCell: firstHouseCell(questions[0]),
    results: [],
    correctContentIds: [],
    allowsNegative,
  };
}

export const currentQuestion = (s: RoundState): Question | undefined => s.questions[s.index];
export const correctCount = (s: RoundState) => s.results.filter(Boolean).length;
const isLast = (s: RoundState) => s.index >= s.questions.length - 1;

function record(s: RoundState, isCorrect: boolean): RoundState {
  const contentId = currentQuestion(s)?.contentId;
  return {
    ...s,
    results: [...s.results, isCorrect],
    correctContentIds: isCorrect && contentId ? [...s.correctContentIds, contentId] : s.correctContentIds,
    phase: isCorrect ? "correct" : "wrong",
  };
}

// MARK: Multiple choice

export function choose(s: RoundState, optionIndex: number): RoundState {
  const q = currentQuestion(s);
  if (s.phase !== "answering" || q?.format.kind !== "multipleChoice" || !q.format.options[optionIndex]) return s;
  return record({ ...s, selectedOptionIndex: optionIndex }, optionIndex === q.format.correctIndex);
}

// MARK: Number pad

export function maxInputLength(s: RoundState): number {
  const q = currentQuestion(s);
  return q?.format.kind === "numberEntry" ? String(Math.abs(q.format.answer)).length + 2 : 0;
}

export function appendDigit(s: RoundState, digit: number): RoundState {
  if (s.phase !== "answering" || digit < 0 || digit > 9) return s;
  const digits = s.numberInput.replace("-", "");
  if (digits.length >= maxInputLength(s)) return s;
  const numberInput = digits === "0" ? s.numberInput.replace("0", String(digit)) : s.numberInput + digit;
  return { ...s, numberInput };
}

export function deleteDigit(s: RoundState): RoundState {
  if (s.phase !== "answering" || s.numberInput === "") return s;
  const numberInput = s.numberInput.slice(0, -1);
  return { ...s, numberInput: numberInput === "-" ? "" : numberInput };
}

export function toggleSign(s: RoundState): RoundState {
  if (s.phase !== "answering" || !s.allowsNegative) return s;
  return { ...s, numberInput: s.numberInput.startsWith("-") ? s.numberInput.slice(1) : "-" + s.numberInput };
}

export function canSubmitNumber(s: RoundState): boolean {
  return s.phase === "answering" && /^-?\d+$/.test(s.numberInput);
}

export function submitNumber(s: RoundState): RoundState {
  const q = currentQuestion(s);
  if (!canSubmitNumber(s) || q?.format.kind !== "numberEntry") return s;
  return record(s, Number.parseInt(s.numberInput, 10) === q.format.answer);
}

// MARK: Tiles

export function placeTile(s: RoundState, tileIndex: number): RoundState {
  const q = currentQuestion(s);
  if (s.phase !== "answering" || q?.format.kind !== "buildSequence") return s;
  if (tileIndex < 0 || tileIndex >= q.format.tiles.length || s.placedTiles.includes(tileIndex)) return s;
  if (s.placedTiles.length >= q.format.answer.length) return s;
  return { ...s, placedTiles: [...s.placedTiles, tileIndex] };
}

export function removeTile(s: RoundState, position: number): RoundState {
  if (s.phase !== "answering" || position < 0 || position >= s.placedTiles.length) return s;
  return { ...s, placedTiles: s.placedTiles.filter((_, i) => i !== position) };
}

export function canSubmitSequence(s: RoundState): boolean {
  const q = currentQuestion(s);
  return s.phase === "answering" && q?.format.kind === "buildSequence" && s.placedTiles.length === q.format.answer.length;
}

export function submitSequence(s: RoundState): RoundState {
  const q = currentQuestion(s);
  if (!canSubmitSequence(s) || q?.format.kind !== "buildSequence") return s;
  const fmt = q.format;
  const built = s.placedTiles.map((i) => fmt.tiles[i]);
  return record(s, built.length === fmt.answer.length && built.every((t, i) => t === fmt.answer[i]));
}

// MARK: Zahlenhaus

function firstHouseCell(q: Question | undefined): string | undefined {
  return q?.format.kind === "numberHouse" ? q.format.house.hidden[0] : undefined;
}

export function selectHouseCell(s: RoundState, cell: string): RoundState {
  const q = currentQuestion(s);
  if (s.phase !== "answering" || q?.format.kind !== "numberHouse" || !q.format.house.hidden.includes(cell)) return s;
  return { ...s, houseCell: cell };
}

/** Types a digit into the selected room; a full room moves on to the next empty one. */
export function houseDigit(s: RoundState, digit: number): RoundState {
  const q = currentQuestion(s);
  if (s.phase !== "answering" || q?.format.kind !== "numberHouse" || !s.houseCell || digit < 0 || digit > 9) return s;
  const house = q.format.house;
  const maxLength = String(house.roof).length;
  const current = s.houseInputs[s.houseCell] ?? "";
  const value = current.length >= maxLength || current === "0" ? String(digit) : current + digit;
  const houseInputs = { ...s.houseInputs, [s.houseCell]: value };
  let houseCell = s.houseCell;
  if (value.length >= maxLength) {
    const order = house.hidden;
    const start = order.indexOf(s.houseCell);
    houseCell = [...order.slice(start + 1), ...order.slice(0, start)].find((c) => !houseInputs[c]) ?? s.houseCell;
  }
  return { ...s, houseInputs, houseCell };
}

export function houseDelete(s: RoundState): RoundState {
  if (s.phase !== "answering" || !s.houseCell || !s.houseInputs[s.houseCell]) return s;
  return { ...s, houseInputs: { ...s.houseInputs, [s.houseCell]: s.houseInputs[s.houseCell].slice(0, -1) } };
}

export function canSubmitHouse(s: RoundState): boolean {
  const q = currentQuestion(s);
  return s.phase === "answering" && q?.format.kind === "numberHouse" && q.format.house.hidden.every((c) => /^\d+$/.test(s.houseInputs[c] ?? ""));
}

/** Rooms the child filled in wrongly (after checking). */
export function wrongHouseCells(s: RoundState): string[] {
  const q = currentQuestion(s);
  if (q?.format.kind !== "numberHouse") return [];
  const house = q.format.house;
  return house.hidden.filter((c) => Number(s.houseInputs[c]) !== houseCellValue(house, c));
}

export function submitHouse(s: RoundState): RoundState {
  if (!canSubmitHouse(s)) return s;
  return record(s, wrongHouseCells(s).length === 0);
}

// MARK: Advancing

export function next(s: RoundState): RoundState {
  if (s.phase !== "correct" && s.phase !== "wrong") return s;
  if (isLast(s)) return { ...s, phase: "finished" };
  return {
    ...s, index: s.index + 1, selectedOptionIndex: undefined, numberInput: "", placedTiles: [],
    houseInputs: {}, houseCell: firstHouseCell(s.questions[s.index + 1]), phase: "answering",
  };
}
