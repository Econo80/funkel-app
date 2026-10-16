import { useEffect, useState } from "preact/hooks";
import { memoryBoard, type MemoryCard } from "../../domain/games";
import { systemRng } from "../../domain/random";
import { playSound } from "../../services/feedback";
import { t } from "../../services/i18n";
import type { GameApi } from "./GameFrame";

/** Flip two cards; matching pictures stay open. A cleared board deals a new one. */
export function MemoryGame({ age, sound, addPoints, running }: GameApi & { age: number; sound: boolean }) {
  const [board, setBoard] = useState<MemoryCard[]>(() => memoryBoard(age, systemRng));
  const [open, setOpen] = useState<number[]>([]);
  const [matched, setMatched] = useState<Set<number>>(new Set());
  const [busy, setBusy] = useState(false);

  // Board cleared: deal a fresh one.
  useEffect(() => {
    if (matched.size === 0 || matched.size < board.length) return;
    const timer = setTimeout(() => {
      setBoard(memoryBoard(age, systemRng));
      setMatched(new Set());
      setOpen([]);
    }, 900);
    return () => clearTimeout(timer);
  }, [matched]);

  const flip = (card: MemoryCard) => {
    if (!running || busy || open.includes(card.id) || matched.has(card.id)) return;
    const next = [...open, card.id];
    setOpen(next);
    if (next.length < 2) return;

    const [a, b] = next.map((id) => board.find((c) => c.id === id)!);
    if (a.picture === b.picture) {
      if (sound) playSound("pop");
      addPoints();
      setMatched((m) => new Set([...m, a.id, b.id]));
      setOpen([]);
    } else {
      setBusy(true);
      setTimeout(() => { setOpen([]); setBusy(false); }, 900);
    }
  };

  const columns = board.length <= 12 ? 4 : board.length <= 16 ? 4 : 5;
  return (
    <div class="memory">
      <p class="game-hint">{t("game.memory.hint")}</p>
      <div class="memory-grid" style={{ gridTemplateColumns: `repeat(${columns}, 1fr)` }}>
        {board.map((card) => {
          const faceUp = open.includes(card.id) || matched.has(card.id);
          return (
            <button key={`${board.length}-${card.id}-${card.picture}`}
              class={`memory-card pressable${faceUp ? " up" : ""}${matched.has(card.id) ? " matched" : ""}`}
              aria-label={faceUp ? card.picture : "?"} onClick={() => flip(card)} data-testid="memory-card" data-picture={card.picture}>
              <span aria-hidden="true">{faceUp ? card.picture : "✦"}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
