import { useMemo, useState } from "preact/hooks";
import { recordSudoku, sudokuAge, type Profile } from "../domain/profile";
import { systemRng } from "../domain/random";
import { SUDOKU_PICTURES, makeSudoku, peers, sudokuLevelForAge, sudokuStars, type Sudoku } from "../domain/sudoku";
import { playSound, vibrate } from "../services/feedback";
import { t } from "../services/i18n";
import { BigButton, CircleButton, Confetti, Pip, avatarColor } from "./components";

const COLOR = "#14A3A3";

/** One Sudoku at the child's level; a wrong entry just wobbles, so mistakes never stay on the board. */
export function SudokuScreen({ profile, onSave, onBack }: {
  profile: Profile; onSave: (p: Profile) => Promise<void>; onBack: () => void;
}) {
  const [puzzle, setPuzzle] = useState<Sudoku>(() => newPuzzle(profile));
  const [values, setValues] = useState(() => startValues(puzzle));
  const [selected, setSelected] = useState<number | undefined>(() => firstEmpty(startValues(puzzle)));
  const [wobble, setWobble] = useState<{ cell: number; at: number }>();
  const [mistakes, setMistakes] = useState(0);
  const [hints, setHints] = useState(0);
  const [earned, setEarned] = useState<number>();

  const { level, solution } = puzzle;
  const symbol = (v: number) => (level.pictures ? SUDOKU_PICTURES[v - 1] : String(v));
  const related = useMemo(() => new Set(selected === undefined ? [] : peers(level, selected)), [selected, puzzle]);

  const restart = () => {
    const next = newPuzzle(profile);
    const start = startValues(next);
    setPuzzle(next);
    setValues(start);
    setSelected(firstEmpty(start));
    setMistakes(0);
    setHints(0);
    setEarned(undefined);
  };

  const fill = (cell: number, isHint: boolean) => {
    const next = [...values];
    next[cell] = solution[cell];
    setValues(next);
    setSelected(undefined);
    if (profile.soundEnabled) playSound("pop");
    if (next.every((v) => v !== 0)) {
      const stars = sudokuStars(level, mistakes, hints + (isHint ? 1 : 0));
      setEarned(stars);
      if (profile.soundEnabled) setTimeout(() => playSound("finish"), 250);
      void onSave(recordSudoku(profile, stars));
    }
  };

  const enter = (v: number) => {
    if (selected === undefined || values[selected] !== 0 || earned !== undefined) return;
    if (solution[selected] === v) return fill(selected, false);
    setWobble({ cell: selected, at: Date.now() });
    setMistakes((m) => m + 1);
    if (profile.soundEnabled) playSound("gentle");
    if (profile.hapticsEnabled) vibrate("gentle");
  };

  const hint = () => {
    const cell = selected !== undefined && values[selected] === 0 ? selected : firstEmpty(values);
    if (cell === undefined || earned !== undefined) return;
    setHints((h) => h + 1);
    fill(cell, true);
  };

  const remaining = (v: number) => level.size - values.filter((x) => x === v).length;
  const size = level.size;

  return (
    <main class="screen">
      <div class="column wide sudoku-screen">
        <header class="home-header">
          <CircleButton label={t("round.close")} onClick={onBack} testId="sudoku-close">✕</CircleButton>
          <h1 class="sudoku-title">🧩 {t("sudoku.title")}</h1>
          <CircleButton label={t("sudoku.hint")} onClick={hint} testId="sudoku-hint">💡</CircleButton>
        </header>
        <p class="game-hint">{t(level.pictures ? "sudoku.rule.pictures" : "sudoku.rule.numbers")}</p>

        <div class={`sudoku-grid size-${size}${level.pictures ? " pictures" : ""}`} style={{ gridTemplateColumns: `repeat(${size}, 1fr)` }} role="grid">
          {values.map((v, cell) => {
            const row = Math.floor(cell / size), col = cell % size;
            const classes = [
              "sudoku-cell",
              puzzle.given[cell] ? "given" : v ? "filled" : "empty",
              cell === selected ? "selected" : related.has(cell) ? "related" : "",
              selected !== undefined && v !== 0 && v === values[selected] ? "same" : "",
              (col + 1) % level.boxCols === 0 && col < size - 1 ? "box-right" : "",
              (row + 1) % level.boxRows === 0 && row < size - 1 ? "box-bottom" : "",
              wobble?.cell === cell && Date.now() - wobble.at < 450 ? "wobble" : "",
            ].filter(Boolean).join(" ");
            return (
              <button key={`${cell}-${wobble?.at ?? 0}`} class={classes} role="gridcell" style={{ "--accent": COLOR } as never}
                aria-label={v ? symbol(v) : t("sudoku.cell.empty")} aria-selected={cell === selected}
                onClick={() => setSelected(cell)} data-testid={`sudoku-cell-${cell}`}
                data-answer={import.meta.env.DEV && !v ? solution[cell] : undefined}>
                {v ? symbol(v) : ""}
              </button>
            );
          })}
        </div>

        {earned === undefined ? (
          <div class="sudoku-keys" style={{ gridTemplateColumns: `repeat(${size <= 6 ? size : 5}, 1fr)` }}>
            {Array.from({ length: size }, (_, i) => i + 1).map((v) => (
              <button key={v} class="card key pressable" disabled={remaining(v) === 0} onClick={() => enter(v)} data-testid={`sudoku-key-${v}`}
                aria-label={symbol(v)}>
                {symbol(v)}
              </button>
            ))}
          </div>
        ) : (
          <div class="card sudoku-done" aria-live="polite">
            <Pip color={avatarColor(profile.avatarColor)} mood="cheering" size={84} hop={1} />
            <h2>{t("sudoku.solved")}</h2>
            <p class="summary-stars">⭐ {t("summary.stars %lld", earned)}</p>
            <BigButton color={COLOR} onClick={restart} testId="sudoku-again">↻ {t("sudoku.again")}</BigButton>
            <BigButton color="rgba(43,37,64,.75)" onClick={onBack} testId="sudoku-done">⌂ {t("summary.done")}</BigButton>
          </div>
        )}
      </div>
      <Confetti trigger={earned === undefined ? 0 : 1} />
    </main>
  );
}

function newPuzzle(profile: Profile): Sudoku {
  return makeSudoku(sudokuLevelForAge(sudokuAge(profile)), systemRng);
}

function startValues(p: Sudoku): number[] {
  return p.solution.map((v, i) => (p.given[i] ? v : 0));
}

function firstEmpty(values: number[]): number | undefined {
  const i = values.indexOf(0);
  return i === -1 ? undefined : i;
}
