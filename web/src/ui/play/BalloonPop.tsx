import { useMemo, useRef } from "preact/hooks";
import { balloonRuleForAge, spawnBalloon } from "../../domain/games";
import { systemRng } from "../../domain/random";
import { playSound } from "../../services/feedback";
import { t } from "../../services/i18n";
import type { GameApi } from "./GameFrame";
import { useFrameLoop } from "./useFrameLoop";

const COLORS = ["#FF7A59", "#FFB020", "#3DA5FF", "#34C77B", "#E2558F", "#8A63F2"];

interface Balloon {
  id: number;
  x: number;        // 0…1 across
  y: number;        // 0 = bottom, 1 = top
  speed: number;    // heights per second
  color: string;
  label?: string;
  good: boolean;
  poppedAt?: number;
  wobbleAt?: number;
}

/** Balloons float up; tap to pop. Older children pop only those matching a rule. */
export function BalloonPop({ age, sound, addPoints, running }: GameApi & { age: number; sound: boolean }) {
  const rule = useMemo(() => balloonRuleForAge(age, systemRng), []);
  const balloons = useRef<Balloon[]>([]);
  const nextId = useRef(0);
  const sinceSpawn = useRef(10);
  const spawnEvery = age < 7 ? 0.9 : 0.75;
  const baseSpeed = age < 7 ? 0.13 : age < 10 ? 0.16 : 0.19;

  useFrameLoop(running, (dt, now) => {
    sinceSpawn.current += dt;
    if (sinceSpawn.current >= spawnEvery && balloons.current.length < 9) {
      sinceSpawn.current = 0;
      const spec = spawnBalloon(rule, systemRng);
      balloons.current.push({
        id: nextId.current++,
        x: 0.08 + Math.random() * 0.84,
        y: -0.15,
        speed: baseSpeed * (0.85 + Math.random() * 0.3),
        color: COLORS[Math.floor(Math.random() * COLORS.length)],
        ...spec,
      });
    }
    for (const b of balloons.current) if (!b.poppedAt) b.y += b.speed * dt;
    balloons.current = balloons.current.filter((b) => b.y < 1.15 && !(b.poppedAt && now - b.poppedAt > 350));
  });

  const tap = (b: Balloon) => {
    if (!running || b.poppedAt) return;
    if (b.good) {
      b.poppedAt = performance.now();
      if (sound) playSound("pop");
      addPoints();
    } else {
      b.wobbleAt = performance.now(); // a gentle "nope", no penalty
    }
  };

  const hint =
    rule.kind === "all" ? t("game.balloons.all")
    : rule.kind === "even" ? t("game.balloons.even")
    : t("game.balloons.product %lld", rule.target);

  const now = performance.now();
  return (
    <div class="balloon-game">
      <p class="game-hint">{hint}</p>
      <div class="play-field sky">
        {balloons.current.map((b) => (
          <button
            key={b.id}
            class={`balloon${b.poppedAt ? " popped" : ""}${b.wobbleAt && now - b.wobbleAt < 400 ? " wobble" : ""}`}
            style={{ left: `${b.x * 100}%`, bottom: `${b.y * 100}%`, "--balloon": b.color } as never}
            aria-label={b.label ?? "Ballon"}
            onPointerDown={() => tap(b)}
            data-good={b.good ? "1" : "0"}
          >
            <span class="balloon-body">{b.label}</span>
            <span class="balloon-string" aria-hidden="true" />
          </button>
        ))}
      </div>
    </div>
  );
}
