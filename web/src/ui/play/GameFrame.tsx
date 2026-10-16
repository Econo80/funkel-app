import type { ComponentChildren } from "preact";
import { useEffect, useState } from "preact/hooks";
import { GAME_SECONDS, type GameId } from "../../domain/games";
import type { Profile } from "../../domain/profile";
import { playSound } from "../../services/feedback";
import { t } from "../../services/i18n";
import { BigButton, CircleButton, Confetti, Pip, avatarColor } from "../components";

export interface GameApi {
  /** Adds points; games call this when something good happens. */
  addPoints: (n?: number) => void;
  /** False once the time is up; games should stop spawning/accepting input. */
  running: boolean;
}

const TITLES: Record<GameId, string> = { memory: "game.memory", balloons: "game.balloons", stars: "game.stars" };

/**
 * Wraps a game: a soft 2-minute bar, a point counter and a friendly goodbye.
 * When time is up, Pip suggests a learning round — the game is the treat.
 */
export function GameFrame({ profile, gameId, onDone, children }: {
  profile: Profile; gameId: GameId; onDone: () => void; children: (api: GameApi) => ComponentChildren;
}) {
  const [points, setPoints] = useState(0);
  const [running, setRunning] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => setRunning(false), GAME_SECONDS * 1000);
    return () => clearTimeout(timer);
  }, []);

  useEffect(() => {
    if (!running && profile.soundEnabled) playSound("finish");
  }, [running]);

  return (
    <main class="screen game-screen">
      <div class="round-top">
        <CircleButton label={t("game.end")} onClick={() => setRunning(false)} testId="game-end">✕</CircleButton>
        <div class="timer game-timer" aria-hidden="true">
          <div class="timer-fill" style={{ background: "var(--sun)", animationDuration: `${GAME_SECONDS}s`, animationPlayState: running ? "running" : "paused" }} />
        </div>
        <div class="stat-chip" role="status" aria-label={t("game.points %lld", points)}>
          <span aria-hidden="true">🏅</span><span aria-hidden="true" class="stat-value">{points}</span>
        </div>
      </div>
      <h2 class="game-title">{t(TITLES[gameId])}</h2>
      <div class="game-area">
        {children({ addPoints: (n = 1) => running && setPoints((p) => p + n), running })}
      </div>

      {!running && (
        <div class="game-over" role="dialog" aria-modal="true" aria-label={t("game.timeUp")}>
          <div class="card game-over-card">
            <Pip color={avatarColor(profile.avatarColor)} mood="cheering" size={110} hop={1} />
            <h1>{t("game.timeUp")}</h1>
            <p class="summary-stars">🏅 {t("game.points %lld", points)}</p>
            <p class="muted">{t("game.goodbye")}</p>
            <BigButton color="var(--ink)" onClick={onDone} testId="game-done">{t("play.back")}</BigButton>
          </div>
          <Confetti trigger={1} count={40} />
        </div>
      )}
    </main>
  );
}
