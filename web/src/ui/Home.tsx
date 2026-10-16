import type { ContentLanguage, SubjectDescriptor } from "../content/types";
import { displayedStreak, isSubjectEnabled, progressKey, type Profile } from "../domain/profile";
import { t } from "../services/i18n";
import { CircleButton, Pip, ProgressRing, StatChip, avatarColor, subjectGlyph } from "./components";

/** The child's home: greeting, streak and stars, one big card per subject. */
export function Home({ profile, language, onStart, onSwitchProfile, onGrownUps }: {
  profile: Profile;
  language: ContentLanguage;
  onStart: (s: SubjectDescriptor) => void;
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
        </div>
      </div>
    </main>
  );
}
