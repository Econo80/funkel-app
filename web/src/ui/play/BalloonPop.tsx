import { useRef } from "preact/hooks";
import { BALLOON_COLORS, BALLOON_COLOR_SECONDS, balloonRuleForAge, nextBalloonColor, spawnBalloon, type BalloonColor, type BalloonRule } from "../../domain/games";
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
  colorId?: BalloonColor;
  label?: string;
  good: boolean;
  poppedAt?: number;
  wobbleAt?: number;
}

/** Balloons float up; tap to pop. Most children pop only those matching a rule. */
export function BalloonPop({ age, sound, addPoints, running }: GameApi & { age: number; sound: boolean }) {
  const rule = useRef<BalloonRule>(balloonRuleForAge(age, systemRng));
  const ruleAge = useRef(0);
  const balloons = useRef<Balloon[]>([]);
  const nextId = useRef(0);
  const sinceSpawn = useRef(10);
  const spawnEvery = age < 5 ? 0.9 : age < 7 ? 0.65 : 0.75;
  const baseSpeed = age < 5 ? 0.13 : age < 7 ? 0.17 : age < 10 ? 0.18 : 0.2;

  useFrameLoop(running, (dt, now) => {
    // The colour rule switches every so often; balloons already up follow the new colour.
    const current = rule.current;
    if (current.kind === "color" && (ruleAge.current += dt) >= BALLOON_COLOR_SECONDS) {
      ruleAge.current = 0;
      const color = nextBalloonColor(current.color, systemRng);
      rule.current = { kind: "color", color };
      for (const b of balloons.current) b.good = b.colorId === color;
    }

    sinceSpawn.current += dt;
    if (sinceSpawn.current >= spawnEvery && balloons.current.length < 10) {
      sinceSpawn.current = 0;
      const { color: colorId, ...spec } = spawnBalloon(rule.current, systemRng);
      balloons.current.push({
        id: nextId.current++,
        x: 0.08 + Math.random() * 0.84,
        y: -0.15,
        speed: baseSpeed * (0.85 + Math.random() * 0.3),
        color: colorId ? BALLOON_COLORS[colorId] : COLORS[Math.floor(Math.random() * COLORS.length)],
        colorId,
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

  const r = rule.current;
  const hint =
    r.kind === "all" ? t("game.balloons.all")
    : r.kind === "color" ? t(`game.balloons.color.${r.color}`)
    : r.kind === "even" ? t("game.balloons.even")
    : t("game.balloons.product %lld", r.target);

  const now = performance.now();
  return (
    <div class="balloon-game">
      <p class="game-hint" aria-live="polite" data-testid="balloon-hint">
        {r.kind === "color" && <span class="balloon-swatch" style={{ background: BALLOON_COLORS[r.color] }} aria-hidden="true" />}
        {hint}
      </p>
      <div class="play-field sky">
        {balloons.current.map((b) => (
          <button
            key={b.id}
            class={`balloon${b.poppedAt ? " popped" : ""}${b.wobbleAt && now - b.wobbleAt < 400 ? " wobble" : ""}`}
            style={{ left: `${b.x * 100}%`, bottom: `${b.y * 100}%`, "--balloon": b.color } as never}
            aria-label={b.label ?? (b.colorId ? t(`game.balloons.name.${b.colorId}`) : "Ballon")}
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
