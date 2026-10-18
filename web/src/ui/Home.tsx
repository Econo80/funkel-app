import type { ContentLanguage, SubjectDescriptor } from "../content/types";
import { displayedStreak, isSubjectEnabled, progressKey, sudokusSolved, type Profile } from "../domain/profile";
import { t } from "../services/i18n";
import { BigButton, CircleButton, Confetti, Pip, ProgressRing, StatChip, avatarColor, subjectGlyph } from "./components";

/** The child's home: greeting, streak and stars, one big card per subject. */
export function Home({ profile, language, onStart, onPlay, onSudoku, onGiftSeen, onSwitchProfile, onGrownUps }: {
  profile: Profile;
  language: ContentLanguage;
  onStart: (s: SubjectDescriptor) => void;
  onPlay: () => void;
  onSudoku: () => void;
  onGiftSeen: () => void;
  onSwitchProfile: () => void;
  onGrownUps: () => void;
}) {
  const streak = displayedStreak(profile, new Date());
  const subjects = language.subjects.filter((s) => isSubjectEnabled(profile, s.id));

  return (
    <main class="screen">
      <div class="column wide">
        <header class="home-header">
          <Pip color={avatarColor(profile.avatarColor)} size={84} bob />
          <div class="row gap">
            <CircleButton label={t("grownups.button")} onClick={onGrownUps} testId="grown-ups">⚙️</CircleButton>
            <CircleButton label={t("home.switchProfile")} onClick={onSwitchProfile} testId="switch-profile">👥</CircleButton>
          </div>
        </header>
        <h1>{t("home.greeting %@", profile.name)}</h1>
        <p class="muted">{t("home.subtitle")}</p>
        <div class="row gap wrap">
          <StatChip icon="🔥" value={streak} label={t("home.streak %lld", streak)} />
          <StatChip icon="⭐" value={profile.totalStars} label={t("home.stars %lld", profile.totalStars)} />
        </div>

        {!!profile.giftStars && (
          <div class="card gift-card" role="status" data-testid="gift-card">
            <span class="gift-icon" aria-hidden="true">🎁</span>
            <span class="gift-text">
              <strong>{t("home.gift.title")}</strong>
              <span>{t("home.gift %lld", profile.giftStars)}</span>
            </span>
            <BigButton color="#E2558F" onClick={onGiftSeen} testId="gift-thanks">{t("home.gift.thanks")}</BigButton>
            <Confetti trigger={profile.giftStars} count={50} />
          </div>
        )}

        <div class="subject-grid">
          {subjects.map((subject) => {
            const progress = profile.progress[progressKey(subject.languageCode, subject.id)];
            const accuracy = progress && progress.questionsAnswered > 0 ? progress.correctAnswers / progress.questionsAnswered : undefined;
            return (
              <button
                key={subject.id}
                class="card subject-card pressable"
                style={{ background: subject.color }}
                onClick={() => onStart(subject)}
                data-testid={`subject-${subject.id}`}
              >
                <span class="subject-icon" style={{ color: subject.color }} aria-hidden="true">{subjectGlyph(subject.icon)}</span>
                <span class="subject-text">
                  <span class="subject-title">{subject.title}</span>
                  <span class="subject-sub">
                    {progress && progress.roundsPlayed > 0 ? t("home.subject.rounds %lld", progress.roundsPlayed) : t("home.subject.start")}
                  </span>
                </span>
                {accuracy !== undefined && <ProgressRing progress={accuracy} />}
              </button>
            );
          })}
          {profile.sudokuEnabled && (
            <button class="card subject-card pressable" style={{ background: "#14A3A3" }} onClick={onSudoku} data-testid="sudoku">
              <span class="subject-icon" aria-hidden="true">🧩</span>
              <span class="subject-text">
                <span class="subject-title">{t("sudoku.title")}</span>
                <span class="subject-sub">{sudokusSolved(profile) > 0 ? t("sudoku.count %lld", sudokusSolved(profile)) : t("sudoku.start")}</span>
              </span>
            </button>
          )}
          {profile.gamesEnabled && (
            <button class="card subject-card play-card pressable" onClick={onPlay} data-testid="play-corner">
              <span class="subject-icon" aria-hidden="true">🎮</span>
              <span class="subject-text">
                <span class="subject-title">{t("play.title")}</span>
                <span class="subject-sub">{t("play.wallet %lld", profile.walletStars)}</span>
              </span>
            </button>
          )}
        </div>
      </div>
    </main>
  );
}
