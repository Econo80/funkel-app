import { useState } from "preact/hooks";
import { BONUS_CHOICES, bonusGamesLeftToday, buyTicket, checkTicket, gameAge, gamesLeftToday, grantBonusGames, type GameId } from "../../domain/games";
import { gardenSecondsLeft, type Profile } from "../../domain/profile";
import { t } from "../../services/i18n";
import { BigButton, CircleButton, Pip, Sheet, avatarColor } from "../components";
import { GrownUpGate } from "../GrownUps";
import { BalloonPop } from "./BalloonPop";
import { GameFrame } from "./GameFrame";
import { Garden } from "./Garden";
import { MemoryGame } from "./MemoryGame";
import { StarCatcher } from "./StarCatcher";

const GAMES: { id: GameId; icon: string; title: string; color: string }[] = [
  { id: "memory", icon: "🃏", title: "game.memory", color: "#8A63F2" },
  { id: "balloons", icon: "🎈", title: "game.balloons", color: "#E2558F" },
  { id: "stars", icon: "⭐", title: "game.stars", color: "#3DA5FF" },
];

type View = { kind: "corner" } | { kind: "game"; id: GameId } | { kind: "garden" };

/** "Spielecke": spend stars on a 2-minute game, or on Pip's garden. */
export function PlayCorner({ profile, onSave, onBack }: {
  profile: Profile; onSave: (p: Profile) => Promise<void>; onBack: () => void;
}) {
  const [view, setView] = useState<View>({ kind: "corner" });
  const [unlocking, setUnlocking] = useState(false);
  const now = new Date();
  const ticket = checkTicket(profile, now);
  const left = gamesLeftToday(profile, now);
  const bonus = bonusGamesLeftToday(profile, now);
  const free = ticket.ok && ticket.free;
  const gardenLeft = gardenSecondsLeft(profile, now);

  if (view.kind === "garden") {
    return <Garden profile={profile} onSave={onSave} onBack={() => setView({ kind: "corner" })} />;
  }

  if (view.kind === "game") {
    const back = () => setView({ kind: "corner" });
    return (
      <GameFrame profile={profile} gameId={view.id} onDone={back}>
        {(api) =>
          view.id === "memory" ? <MemoryGame age={gameAge(profile)} sound={profile.soundEnabled} {...api} />
          : view.id === "balloons" ? <BalloonPop age={gameAge(profile)} sound={profile.soundEnabled} {...api} />
          : <StarCatcher age={gameAge(profile)} sound={profile.soundEnabled} color={avatarColor(profile.avatarColor)} {...api} />
        }
      </GameFrame>
    );
  }

  const start = async (id: GameId) => {
    if (!checkTicket(profile, new Date()).ok) return;
    await onSave(buyTicket(profile, new Date()));
    setView({ kind: "game", id });
  };

  return (
    <main class="screen">
      <div class="column wide">
        <header class="home-header">
          <CircleButton label={t("play.back")} onClick={onBack} testId="play-back">←</CircleButton>
          <div class="stat-chip wallet" aria-label={t("play.wallet %lld", profile.walletStars)} role="img">
            <span aria-hidden="true">⭐</span><span aria-hidden="true" class="stat-value">{profile.walletStars}</span>
          </div>
        </header>
        <div class="play-hero">
          <Pip color={avatarColor(profile.avatarColor)} mood="cheering" size={84} bob />
          <div>
            <h1>{t("play.title")}</h1>
            <p class="muted">{t("play.subtitle")}</p>
          </div>
        </div>

        {bonus > 0 && (
          <div class="card play-bonus" aria-live="polite">
            <span aria-hidden="true">🎁</span> <strong>{t("play.bonus %lld", bonus)}</strong>
          </div>
        )}

        <div class="card play-status" aria-live="polite">
          <strong>{t("play.ticket %lld", profile.gameCost)}</strong>
          <span class="muted">{left === undefined ? t("play.unlimited") : t("play.left %lld", left)}</span>
          {!ticket.ok && ticket.reason === "notEnoughStars" && <p class="play-note">{t("play.missing %lld", ticket.missing)}</p>}
          {!ticket.ok && ticket.reason === "dailyLimit" && <p class="play-note">{t("play.dailyLimit")}</p>}
        </div>

        <div class="subject-grid">
          {GAMES.map((g) => (
            <button key={g.id} class="card subject-card pressable" style={{ background: g.color, opacity: ticket.ok ? 1 : 0.55 }}
              disabled={!ticket.ok} onClick={() => start(g.id)} data-testid={`game-${g.id}`}>
              <span class="subject-icon" aria-hidden="true">{g.icon}</span>
              <span class="subject-text">
                <span class="subject-title">{t(g.title)}</span>
                <span class="subject-sub">{free ? t("play.startFree") : t("play.start %lld", profile.gameCost)}</span>
              </span>
            </button>
          ))}
          <button class="card subject-card pressable" style={{ background: "#34C77B" }} onClick={() => setView({ kind: "garden" })} data-testid="game-garden">
            <span class="subject-icon" aria-hidden="true">🌻</span>
            <span class="subject-text">
              <span class="subject-title">{t("garden.title")}</span>
              <span class="subject-sub">
                {gardenLeft === undefined ? t("play.wallet %lld", profile.walletStars)
                  : gardenLeft === 0 ? t("play.gardenTomorrow")
                  : t("play.gardenLeft %lld", Math.ceil(gardenLeft / 60))}
              </span>
            </span>
          </button>
        </div>

        <button class="link grown-up-link" onClick={() => setUnlocking(true)} data-testid="bonus-unlock">🔓 {t("play.unlock")}</button>
      </div>

      {unlocking && (
        <GrownUpGate onCancel={() => setUnlocking(false)}>
          <Sheet label={t("play.unlock")}>
            <div class="sheet-bar"><button class="link" onClick={() => setUnlocking(false)}>{t("editor.cancel")}</button></div>
            <div class="column narrow center">
              <div class="lock" aria-hidden="true">🎁</div>
              <h1>{t("play.unlock")}</h1>
              <p class="muted">{t("play.unlock.message %@", profile.name)}</p>
              {BONUS_CHOICES.map((n) => (
                <BigButton key={n} color="#8A63F2" testId={`bonus-${n}`} onClick={async () => {
                  await onSave(grantBonusGames(profile, n, new Date()));
                  setUnlocking(false);
                }}>
                  {t("play.unlock.count %lld", n)}
                </BigButton>
              ))}
              <p class="footnote">{t("play.unlock.footer")}</p>
            </div>
          </Sheet>
        </GrownUpGate>
      )}
    </main>
  );
}
