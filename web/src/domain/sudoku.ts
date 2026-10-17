// Sudoku for children: picture 4×4 grids for the youngest, up to classic 9×9.
// Every puzzle has exactly one solution.
import { shuffled, type Rng } from "./random";

export interface SudokuLevel {
  size: 4 | 6 | 9;
  /** Box shape: rows × columns (6×6 uses 2×3 boxes). */
  boxRows: number;
  boxCols: number;
  /** How many cells start empty. */
  blanks: number;
  /** Pictures instead of numbers, for children who don't read numbers yet. */
  pictures: boolean;
  /** Stars for a solved puzzle without help. */
  stars: number;
}

export const SUDOKU_PICTURES = ["🍎", "🐟", "⭐", "🌼"];

/** Ages 4–5 pictures 4×4, 6–7 numbers 4×4, 8–9 6×6, from 10 the classic 9×9. */
export function sudokuLevelForAge(age: number): SudokuLevel {
  if (age < 5) return { size: 4, boxRows: 2, boxCols: 2, blanks: 5, pictures: true, stars: 3 };
  if (age < 6) return { size: 4, boxRows: 2, boxCols: 2, blanks: 7, pictures: true, stars: 3 };
  if (age < 7) return { size: 4, boxRows: 2, boxCols: 2, blanks: 9, pictures: false, stars: 4 };
  if (age < 8) return { size: 4, boxRows: 2, boxCols: 2, blanks: 11, pictures: false, stars: 4 };
  if (age < 9) return { size: 6, boxRows: 2, boxCols: 3, blanks: 14, pictures: false, stars: 6 };
  if (age < 10) return { size: 6, boxRows: 2, boxCols: 3, blanks: 19, pictures: false, stars: 6 };
  if (age < 12) return { size: 9, boxRows: 3, boxCols: 3, blanks: age < 11 ? 36 : 42, pictures: false, stars: 8 };
  return { size: 9, boxRows: 3, boxCols: 3, blanks: age < 13 ? 48 : 52, pictures: false, stars: 10 };
}

export interface Sudoku {
  level: SudokuLevel;
  /** Values 1…size, row by row. */
  solution: number[];
  /** Cells shown from the start. */
  given: boolean[];
}

/** The cells that share a row, column or box with `cell` (not the cell itself). */
export function peers(level: Pick<SudokuLevel, "size" | "boxRows" | "boxCols">, cell: number): number[] {
  const { size, boxRows, boxCols } = level;
  const row = Math.floor(cell / size), col = cell % size;
  const r0 = row - (row % boxRows), c0 = col - (col % boxCols);
  const result = new Set<number>();
  for (let i = 0; i < size; i++) {
    result.add(row * size + i);
    result.add(i * size + col);
  }
  for (let r = r0; r < r0 + boxRows; r++) for (let c = c0; c < c0 + boxCols; c++) result.add(r * size + c);
  result.delete(cell);
  return [...result];
}

function candidates(level: SudokuLevel, grid: number[], cell: number, peerList: number[][]): number[] {
  const used = new Set(peerList[cell].map((p) => grid[p]));
  return Array.from({ length: level.size }, (_, i) => i + 1).filter((v) => !used.has(v));
}

/** Fills empty (0) cells; with `rng` in random order. Stops after `limit` solutions; returns how many it found. */
function solve(level: SudokuLevel, grid: number[], peerList: number[][], limit: number, rng?: Rng): number {
  // Pick the empty cell with the fewest options.
  let best = -1, bestOptions: number[] = [];
  for (let cell = 0; cell < grid.length; cell++) {
    if (grid[cell] !== 0) continue;
    const options = candidates(level, grid, cell, peerList);
    if (options.length === 0) return 0;
    if (best === -1 || options.length < bestOptions.length) { best = cell; bestOptions = options; }
    if (options.length === 1) break;
  }
  if (best === -1) return 1;

  let found = 0;
  for (const value of rng ? shuffled(rng, bestOptions) : bestOptions) {
    grid[best] = value;
    found += solve(level, grid, peerList, limit - found, rng);
    if (found >= limit) return found; // leave the grid filled when generating
  }
  grid[best] = 0;
  return found;
}

export function countSolutions(level: SudokuLevel, puzzle: number[], limit = 2): number {
  const peerList = Array.from({ length: level.size * level.size }, (_, c) => peers(level, c));
  return solve(level, [...puzzle], peerList, limit);
}

/** A new puzzle with a unique solution and (as close as possible to) the level's number of blanks. */
export function makeSudoku(level: SudokuLevel, rng: Rng): Sudoku {
  const cells = level.size * level.size;
  const peerList = Array.from({ length: cells }, (_, c) => peers(level, c));
  const solution = new Array<number>(cells).fill(0);
  solve(level, solution, peerList, 1, rng);

  const puzzle = [...solution];
  let blanks = 0;
  for (const cell of shuffled(rng, Array.from({ length: cells }, (_, i) => i))) {
    if (blanks >= level.blanks) break;
    const keep = puzzle[cell];
    puzzle[cell] = 0;
    if (solve(level, [...puzzle], peerList, 2) === 1) blanks++;
    else puzzle[cell] = keep;
  }
  return { level, solution, given: puzzle.map((v) => v !== 0) };
}

/** Stars for a solved puzzle: one less per hint and per three mistakes, at least one. */
export function sudokuStars(level: SudokuLevel, mistakes: number, hints: number): number {
  return Math.max(1, level.stars - hints - Math.floor(mistakes / 3));
}
