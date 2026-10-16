import type { ComponentChildren } from "preact";
import { useEffect, useRef } from "preact/hooks";
import { prefersReducedMotion } from "../services/feedback";

export const AVATAR_COLORS: [string, string][] = [
  ["sun", "#FFB020"], ["sky", "#3DA5FF"], ["leaf", "#34C77B"],
  ["berry", "#E2558F"], ["grape", "#8A63F2"], ["coral", "#FF7A59"],
];
export const avatarColor = (key: string) => AVATAR_COLORS.find(([k]) => k === key)?.[1] ?? "#FFB020";

/** SF Symbol names from the content manifest, drawn as glyphs on the web. */
const SUBJECT_GLYPHS: Record<string, string> = {
  "plus.forwardslash.minus": "+−",
  "textformat.abc": "Abc",
  "globe.europe.africa.fill": "🌍",
  "text.book.closed.fill": "📖",
  "star.fill": "⭐",
};
export const subjectGlyph = (icon: string) => SUBJECT_GLYPHS[icon] ?? "⭐";

// MARK: Pip, the mascot (same proportions as Pip.swift)

export type PipMood = "happy" | "cheering" | "thinking";

export function Pip({ color, mood = "happy", size = 120, hop = 0, bob = false }: {
  color: string; mood?: PipMood; size?: number; hop?: number; bob?: boolean;
}) {
  const id = `pip-${color.slice(1)}`;
  return (
    <svg
      key={hop}
      class={`pip${hop ? " pip-hop" : ""}${bob ? " pip-bob" : ""}`}
      width={size}
      height={size}
      viewBox="0 0 100 100"
      aria-hidden="true"
    >
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color={color} stop-opacity="0.85" />
          <stop offset="1" stop-color={color} />
        </linearGradient>
      </defs>
      <g fill={color}>
        <rect x="31" y="8" width="8" height="15" rx="4" transform="rotate(-25 35 22)" />
        <rect x="45.5" y="4" width="9" height="20" rx="4.5" />
        <rect x="61" y="8" width="8" height="15" rx="4" transform="rotate(25 65 22)" />
      </g>
      <circle cx="50" cy="58" r="40" fill={`url(#${id})`} />
      <circle cx="29" cy="65" r="5" fill="#ff6fa0" opacity="0.35" />
      <circle cx="71" cy="65" r="5" fill="#ff6fa0" opacity="0.35" />
      {mood === "cheering" ? (
        <g fill="none" stroke="#2B2540" stroke-width="3.5" stroke-linecap="round">
          <path d="M35 57 q5 -6 10 0" />
          <path d="M55 57 q5 -6 10 0" />
        </g>
      ) : (
        <g>
          <ellipse cx="40" cy="55" rx="4.5" ry="6" fill="#2B2540" />
          <ellipse cx="60" cy="55" rx="4.5" ry="6" fill="#2B2540" />
          <circle cx="41.5" cy="53" r="1.6" fill="#fff" />
          <circle cx="61.5" cy="53" r="1.6" fill="#fff" />
        </g>
      )}
      {mood === "thinking" ? (
        <rect x="45" y="67" width="10" height="3" rx="1.5" fill="#2B2540" />
      ) : (
        <path d={mood === "cheering" ? "M40 66 q10 11 20 0" : "M42 66 q8 8 16 0"} fill="none" stroke="#2B2540" stroke-width="3.5" stroke-linecap="round" />
      )}
    </svg>
  );
}

// MARK: Buttons

export function BigButton({ children, color = "var(--sun)", disabled, onClick, testId }: {
  children: ComponentChildren; color?: string; disabled?: boolean; onClick: () => void; testId?: string;
}) {
  return (
    <button class="big-button pressable" style={{ background: color }} disabled={disabled} onClick={onClick} data-testid={testId}>
      {children}
    </button>
  );
}

export function CircleButton({ label, onClick, children, testId }: {
  label: string; onClick: () => void; children: ComponentChildren; testId?: string;
}) {
  return (
    <button class="circle-button pressable" aria-label={label} title={label} onClick={onClick} data-testid={testId}>
      <span aria-hidden="true">{children}</span>
    </button>
  );
}

export function StatChip({ icon, value, label }: { icon: string; value: number; label: string }) {
  return (
    <div class="stat-chip" role="img" aria-label={label}>
      <span aria-hidden="true">{icon}</span>
      <span aria-hidden="true" class="stat-value">{value}</span>
    </div>
  );
}

export function ProgressRing({ progress }: { progress: number }) {
  const r = 16;
  const c = 2 * Math.PI * r;
  return (
    <svg width="40" height="40" viewBox="0 0 40 40" aria-hidden="true" class="ring">
      <circle cx="20" cy="20" r={r} fill="none" stroke="rgba(255,255,255,.3)" stroke-width="6" />
      <circle
        cx="20" cy="20" r={r} fill="none" stroke="#fff" stroke-width="6" stroke-linecap="round"
        stroke-dasharray={`${c * Math.max(0.001, Math.min(1, progress))} ${c}`} transform="rotate(-90 20 20)"
      />
    </svg>
  );
}

/** A full-screen panel for the grown-up area. */
export function Sheet({ children, label }: { children: ComponentChildren; label: string }) {
  return (
    <div class="sheet-backdrop">
      <div class="sheet" role="dialog" aria-modal="true" aria-label={label}>
        {children}
      </div>
    </div>
  );
}

// MARK: Confetti

const CONFETTI_COLORS = ["#FFB020", "#2BB673", "#3DA5FF", "#E2558F", "#8A63F2"];

/** A burst of confetti each time `trigger` changes. Skipped under Reduce Motion. */
export function Confetti({ trigger, count = 44 }: { trigger: number; count?: number }) {
  const canvas = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const el = canvas.current;
    if (!trigger || !el || prefersReducedMotion()) return;
    const ctx = el.getContext("2d");
    if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    el.width = el.clientWidth * dpr;
    el.height = el.clientHeight * dpr;
    ctx.scale(dpr, dpr);

    const w = el.clientWidth, h = el.clientHeight;
    const particles = Array.from({ length: count }, () => ({
      angle: -Math.PI * (0.05 + Math.random() * 0.9),
      speed: 380 + Math.random() * 440,
      spin: (Math.random() - 0.5) * 16,
      size: 7 + Math.random() * 5,
      color: CONFETTI_COLORS[Math.floor(Math.random() * CONFETTI_COLORS.length)],
      circle: Math.random() < 0.5,
    }));
    const lifetime = 1.8, gravity = 900;
    const start = performance.now();
    let frame = 0;

    const draw = (now: number) => {
      const t = (now - start) / 1000;
      ctx.clearRect(0, 0, w, h);
      if (t >= lifetime) return;
      ctx.globalAlpha = t > lifetime - 0.5 ? (lifetime - t) / 0.5 : 1;
      for (const p of particles) {
        const x = w / 2 + Math.cos(p.angle) * p.speed * t;
        const y = h * 0.4 + Math.sin(p.angle) * p.speed * t + 0.5 * gravity * t * t;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(p.spin * t);
        ctx.fillStyle = p.color;
        if (p.circle) {
          ctx.beginPath();
          ctx.arc(0, 0, p.size / 2, 0, Math.PI * 2);
          ctx.fill();
        } else {
          ctx.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2);
        }
        ctx.restore();
      }
      frame = requestAnimationFrame(draw);
    };
    frame = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(frame);
  }, [trigger, count]);

  return <canvas ref={canvas} class="confetti" aria-hidden="true" />;
}

// MARK: Even text sizing

let measureCtx: CanvasRenderingContext2D | null = null;

/**
 * One font size for a group of answers: the largest at which the longest
 * *word* fits a column (port of TextFitting.swift). Lines wrap between words.
 */
export function fittingFontSize(texts: string[], width: number, maxPx: number, minPx: number, weight: number): number {
  if (width <= 0) return maxPx;
  measureCtx ??= document.createElement("canvas").getContext("2d");
  if (!measureCtx) return maxPx;
  const family = getComputedStyle(document.body).fontFamily;
  const words = texts.flatMap((t) => t.split(/\s+/)).filter(Boolean);
  const widthAt = (word: string, size: number) => {
    measureCtx!.font = `${weight} ${size}px ${family}`;
    return measureCtx!.measureText(word).width;
  };
  const longest = words.reduce((a, b) => (widthAt(b, maxPx) > widthAt(a, maxPx) ? b : a), words[0] ?? "");
  let size = Math.floor(maxPx);
  while (size > minPx && widthAt(longest, size) > width) size -= 1;
  return Math.max(size, minPx);
}

