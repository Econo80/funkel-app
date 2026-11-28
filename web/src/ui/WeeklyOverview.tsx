import type { ContentLanguage } from "../content/types";
import type { Profile } from "../domain/profile";
import { weekSummary, type SkillWeek, type WeekTotals } from "../domain/weekly";
import { t } from "../services/i18n";
import { Sheet, subjectGlyph } from "./components";

const percent = (correct: number, asked: number) => (asked ? Math.round((100 * correct) / asked) : 0);

/** 8.5 → "8½", rounded to half years. */
export function formatLevelAge(age: number): string {
  const half = Math.round(age * 2) / 2;
  return `${Math.floor(half)}${half % 1 ? "½" : ""}`;
}

/** A child's last seven days for grown-ups: when, how much, how well, and what to practise. */
export function WeeklyOverview({ profile, language, onClose }: { profile: Profile; language?: ContentLanguage; onClose: () => void }) {
  const week = weekSummary(profile);
  const subject = (id: string) => language?.subjects.find((s) => s.id === id);
  const most = Math.max(1, ...week.dayRounds);
  const weekday = (day: string) => new Date(`${day}T12:00`).toLocaleDateString(document.documentElement.lang || "de-CH", { weekday: "short" });

  const tiles = (w: WeekTotals) => [
    { label: t("weekly.daysLabel"), value: `${w.daysLearned}/7`, id: "days" },
    { label: t("weekly.roundsLabel"), value: String(w.rounds), id: "rounds" },
    { label: t("weekly.questionsLabel"), value: String(w.questions), id: "questions" },
    { label: t("weekly.correct"), value: w.questions ? `${percent(w.correct, w.questions)} %` : "–", id: "correct" },
    { label: t("weekly.starsLabel"), value: String(w.stars), id: "stars" },
  ];
  const now = tiles(week.week), before = tiles(week.previous);

  const skillChip = (s: SkillWeek) => {
    const sub = subject(s.subjectId);
    return (
      <span key={`${s.subjectId}:${s.skill}`} class="skill-chip" data-testid="weekly-skill">
        <span aria-hidden="true">{sub ? subjectGlyph(sub.icon, sub.emoji) : ""}</span> {t(`skill.${s.skill}`)} · {percent(s.correct, s.asked)} %
      </span>
    );
  };

  return (
    <Sheet label={t("weekly.title %@", profile.name)}>
      <div class="sheet-bar end"><button class="link strong" onClick={onClose} data-testid="weekly-done">{t("grownups.done")}</button></div>
      <div class="column narrow settings weekly" data-testid="weekly">
        <h1>{t("weekly.title %@", profile.name)}</h1>

        <div class="week-days" role="img" aria-label={t("weekly.daysAria %lld", week.week.daysLearned)}>
          {week.days.map((day, i) => (
            <span key={day} class="week-day">
              <span class="week-bar-track"><span class={`week-bar${week.dayRounds[i] ? "" : " empty"}`} style={{ height: `${(100 * week.dayRounds[i]) / most}%` }} /></span>
              <span class="week-count">{week.dayRounds[i] || ""}</span>
              <span class="week-label">{weekday(day)}</span>
            </span>
          ))}
        </div>

        {week.week.rounds === 0 ? <p class="muted center" data-testid="weekly-empty">{t("weekly.empty")}</p> : (
          <>
            <div class="week-tiles">
              {now.map((tile, i) => (
                <div key={tile.id} class="week-tile" data-testid={`weekly-${tile.id}`}>
                  <strong>{tile.value}</strong>
                  <span>{tile.label}</span>
                  <span class="muted small">{t("weekly.before %@", before[i].value)}</span>
                </div>
              ))}
            </div>

            <h3 class="section-title">{t("weekly.subjects")}</h3>
            <div class="list">
              {week.subjects.map((s) => {
                const sub = subject(s.subjectId);
                const changed = Math.abs(s.levelEnd - s.levelStart) >= 0.25;
                return (
                  <div key={s.subjectId} class="list-line week-subject" data-testid={`weekly-subject-${s.subjectId}`}>
                    <span><span style={{ color: sub?.color }} aria-hidden="true">{sub ? subjectGlyph(sub.icon, sub.emoji) : "⭐"}</span> <strong>{sub?.title ?? s.subjectId}</strong></span>
                    <span class="muted">
                      {t("weekly.roundsCount %lld", s.rounds)} · {percent(s.correct, s.questions)} % {t("weekly.correct")}
                      {" · "}{t("editor.level %@", formatLevelAge(s.levelEnd))}
                      {changed && ` (${t("weekly.levelBefore %@", formatLevelAge(s.levelStart))})`}
                    </span>
                  </div>
                );
              })}
            </div>

            <h3 class="section-title">{t("weekly.strong")}</h3>
            <div class="skill-row">{week.strong.length ? week.strong.map(skillChip) : <span class="muted">{t("weekly.noSkills")}</span>}</div>
            <h3 class="section-title">{t("weekly.practice")}</h3>
            <div class="skill-row practice">{week.practice.length ? week.practice.map(skillChip) : <span class="muted">{t("weekly.noPractice")}</span>}</div>
          </>
        )}
        {(profile.thinkingTests ?? []).length > 0 && (
          <>
            <h3 class="section-title">{t("thinkingTest.history")}</h3>
            <div class="list" data-testid="weekly-tests">
              {[...(profile.thinkingTests ?? [])].reverse().slice(0, 6).map((test) => (
                <div key={test.date} class="row-between list-line">
                  <span>{new Date(test.date).toLocaleDateString(document.documentElement.lang || "de-CH", { day: "numeric", month: "short" })}</span>
                  <span class="muted">{t("thinkingTest.row %lld %lld %@", test.points, test.total, formatLevelAge(test.levelAge))}</span>
                </div>
              ))}
            </div>
            <p class="footnote">{t("thinkingTest.footer")}</p>
          </>
        )}
        <p class="footnote">{t("weekly.footer")}</p>
      </div>
    </Sheet>
  );
}
