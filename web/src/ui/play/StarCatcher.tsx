import { useEffect, useRef } from "preact/hooks";
import { playSound } from "../../services/feedback";
import { t } from "../../services/i18n";
import { Pip } from "../components";
import type { GameApi } from "./GameFrame";
import { useFrameLoop } from "./useFrameLoop";

interface Faller {
  id: number;
  x: number;      // 0…1 across
  y: number;      // 0 = top, 1 = bottom
  speed: number;  // heights per second
  kind: "star" | "cloud";
}

const CATCH_Y = [0.82, 0.97] as const;
const CATCH_WIDTH = 0.13;

/** Move Pip (finger, mouse or arrow keys) to catch stars; clouds make Pip dizzy for a moment. */
export function StarCatcher({ age, sound, color, addPoints, running }: GameApi & { age: number; sound: boolean; color: string }) {
  const field = useRef<HTMLDivElement>(null);
  const pipX = useRef(0.5);
  const fallers = useRef<Faller[]>([]);
  const nextId = useRef(0);
  const sinceSpawn = useRef(0);
  const dizzyUntil = useRef(0);
  const sparkleAt = useRef(0);

  const speed = age < 6 ? 0.22 : age < 9 ? 0.28 : 0.34;
  const cloudShare = age < 6 ? 0.15 : 0.25;

  useFrameLoop(running, (dt, now) => {
    sinceSpawn.current += dt;
    if (sinceSpawn.current > 0.7) {
      sinceSpawn.current = 0;
      fallers.current.push({
        id: nextId.current++,
        x: 0.06 + Math.random() * 0.88,
        y: -0.08,
        speed: speed * (0.85 + Math.random() * 0.35),
        kind: Math.random() < cloudShare ? "cloud" : "star",
      });
    }
    const dizzy = now < dizzyUntil.current;
    fallers.current = fallers.current.filter((f) => {
      f.y += f.speed * dt;
      const inReach = f.y >= CATCH_Y[0] && f.y <= CATCH_Y[1] && Math.abs(f.x - pipX.current) < CATCH_WIDTH;
      if (inReach) {
        if (f.kind === "star" && !dizzy) {
          addPoints();
          sparkleAt.current = now;
          if (sound) playSound("pop");
          return false;
        }
        if (f.kind === "cloud") {
          dizzyUntil.current = now + 1000; // a short pause, nothing lost
          return false;
        }
      }
      return f.y < 1.08;
    });
  });

  // Arrow keys for tablets with keyboards and computers.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "ArrowLeft") pipX.current = Math.max(0.05, pipX.current - 0.07);
      if (e.key === "ArrowRight") pipX.current = Math.min(0.95, pipX.current + 0.07);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const follow = (e: PointerEvent) => {
    const rect = field.current?.getBoundingClientRect();
    if (!rect || !running) return;
    pipX.current = Math.min(0.95, Math.max(0.05, (e.clientX - rect.left) / rect.width));
  };

  const now = performance.now();
  const dizzy = now < dizzyUntil.current;
  return (
    <div class="star-game">
      <p class="game-hint">{t("game.stars.hint")}</p>
      <div ref={field} class="play-field night" onPointerDown={follow} onPointerMove={follow} style={{ touchAction: "none" }}>
        {fallers.current.map((f) => (
          <span key={f.id} class="faller" style={{ left: `${f.x * 100}%`, top: `${f.y * 100}%` }} aria-hidden="true">
            {f.kind === "star" ? "⭐" : "🌧️"}
          </span>
        ))}
        <div class={`catcher${dizzy ? " dizzy" : ""}${now - sparkleAt.current < 250 ? " sparkle" : ""}`} style={{ left: `${pipX.current * 100}%` }}>
          <Pip color={color} mood={dizzy ? "thinking" : "cheering"} size={72} />
        </div>
      </div>
    </div>
  );
}
