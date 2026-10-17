import type { ComponentChildren } from "preact";
import { useState } from "preact/hooks";
import type { ContentLibrary } from "../content/library";
import { Tuning } from "../domain/difficulty";
import { GAMES_PER_DAY_CHOICES, GAME_COST_CHOICES, GAME_DIFFICULTIES } from "../domain/games";
import { isGateAnswerCorrect, randomGate } from "../domain/gate";
import {
  ROUND_LENGTH_CHOICES,
  allowsGentleTimer,
  applySettings,
  createProfile,
  defaultSettings,
  isLastEnabledSubject,
  isSubjectEnabled,
  resetProgress,
  withLanguage,
  withSubject,
  type Profile,
  type ProfileSettings,
} from "../domain/profile";
import { t } from "../services/i18n";
import { AVATAR_COLORS, BigButton, Pip, Sheet, avatarColor, subjectGlyph } from "./components";

/** Shows the maths gate first and the children once it's solved. */
export function GrownUpGate({ children, onCancel }: { children: ComponentChildren; onCancel: () => void }) {
  const [unlocked, setUnlocked] = useState(false);
  return unlocked ? <>{children}</> : <Gate onUnlock={() => setUnlocked(true)} onCancel={onCancel} />;
}

function Gate({ onUnlock, onCancel }: { onUnlock: () => void; onCancel: () => void }) {
  const [challenge, setChallenge] = useState(randomGate);
  const [input, setInput] = useState("");
  const [retry, setRetry] = useState(false);

  const check = () => {
    if (isGateAnswerCorrect(challenge, input)) onUnlock();
    else {
      setRetry(true);
      setInput("");
      setChallenge(randomGate());
    }
  };
  const append = (d: number) => setInput((v) => (v.length < 4 ? v + d : v));

  return (
    <Sheet label={t("gate.title")}>
      <div class="sheet-bar"><button class="link" onClick={onCancel}>{t("editor.cancel")}</button></div>
      <div class="column narrow center gate">
        <div class="lock" aria-hidden="true">🔒</div>
        <h1>{t("gate.title")}</h1>
        <p class="muted">{t(retry ? "gate.wrong" : "gate.message")}</p>
        <p class="gate-question" data-testid="gate-question">{t("gate.question %lld %lld", challenge.a, challenge.b)}</p>
        <div class="card number-display">{input || "?"}</div>
        <div class="keys">
          {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((d) => (
            <button key={d} class="card key pressable" onClick={() => append(d)} data-testid={`gate-key-${d}`}>{d}</button>
          ))}
          <span />
          <button class="card key pressable" onClick={() => append(0)} data-testid="gate-key-0">0</button>
          <button class="card key pressable" aria-label={t("round.delete")} onClick={() => setInput((v) => v.slice(0, -1))}>⌫</button>
        </div>
        <BigButton color="var(--ink)" disabled={!input} onClick={check} testId="gate-check">✓ {t("round.check")}</BigButton>
      </div>
    </Sheet>
  );
}

/** Profiles, plus the privacy statement. */
export function GrownUps({ library, profiles, onSave, onDelete, onDone }: {
  library: ContentLibrary;
  profiles: Profile[];
  onSave: (p: Profile) => Promise<void>;
  onDelete: (id: string) => Promise<void>;
  onDone: () => void;
}) {
  const [editing, setEditing] = useState<Profile | "new">();

  if (editing) {
    return (
      <ProfileEditor
        library={library}
        profile={editing === "new" ? undefined : editing}
        onSave={async (p) => { await onSave(p); setEditing(undefined); }}
        onDelete={editing === "new" ? undefined : async () => { await onDelete(editing.id); setEditing(undefined); }}
        onCancel={() => setEditing(undefined)}
      />
    );
  }

  return (
    <Sheet label={t("grownups.title")}>
      <div class="sheet-bar end"><button class="link strong" onClick={onDone} data-testid="grownups-done">{t("grownups.done")}</button></div>
      <div class="column narrow settings">
        <h1>{t("grownups.title")}</h1>
        <h3 class="section-title">{t("grownups.profiles")}</h3>
        <div class="list">
          {profiles.map((p) => (
            <button key={p.id} class="list-row" onClick={() => setEditing(p)} data-testid={`settings-profile-${p.name}`}>
              <Pip color={avatarColor(p.avatarColor)} size={44} />
              <span class="list-text"><strong>{p.name}</strong><span class="muted">{t("profile.age %lld", p.age)}</span></span>
              <span aria-hidden="true" class="chevron">›</span>
            </button>
          ))}
          <button class="list-row accent" onClick={() => setEditing("new")}>＋ {t("profiles.add")}</button>
        </div>
        <h3 class="section-title">{t("grownups.privacy.title")}</h3>
        <div class="list"><p class="list-note">{t("grownups.privacy.text")}</p></div>
      </div>
    </Sheet>
  );
}

/** Create or edit a profile and all its settings. Saves only on "Speichern". */
export function ProfileEditor({ library, profile, onSave, onDelete, onCancel }: {
  library: ContentLibrary;
  profile?: Profile;
  onSave: (p: Profile) => Promise<void>;
  onDelete?: () => Promise<void>;
  onCancel: () => void;
}) {
  const [s, setS] = useState<ProfileSettings>(() => (profile ? { ...profile } : defaultSettings()));
  const language = library.resolvedLanguage(s.learningLanguage);
  const subjectIds = language?.subjects.map((x) => x.id) ?? [];
  const valid = s.name.trim().length > 0;
  const set = (patch: Partial<ProfileSettings>) => setS((prev) => ({ ...prev, ...patch }));

  const save = async () => {
    if (!valid) return;
    await onSave(profile ? applySettings(profile, s) : createProfile(s));
  };

  return (
    <Sheet label={t(profile ? "editor.title.edit" : "editor.title.new")}>
      <div class="sheet-bar">
        <button class="link" onClick={onCancel}>{t("editor.cancel")}</button>
        <strong>{t(profile ? "editor.title.edit" : "editor.title.new")}</strong>
        <button class="link strong" disabled={!valid} onClick={save} data-testid="editor-save">{t("editor.save")}</button>
      </div>
      <div class="column narrow settings">
        <div class="center"><Pip color={avatarColor(s.avatarColor)} size={96} /></div>

        <label class="section-title" for="name">{t("editor.name")}</label>
        <div class="list"><input id="name" class="text-input" value={s.name} placeholder={t("editor.name.placeholder")}
          autocomplete="given-name" onInput={(e) => set({ name: e.currentTarget.value })} data-testid="editor-name" /></div>

        <h3 class="section-title">{t("editor.age")}</h3>
        <div class="list row-between">
          <strong>{t("profile.age %lld", s.age)}</strong>
          <div class="stepper">
            <button aria-label="−" disabled={s.age <= Tuning.minAge} onClick={() => set({ age: s.age - 1 })}>−</button>
            <button aria-label="+" disabled={s.age >= Tuning.maxAge} onClick={() => set({ age: s.age + 1 })}>+</button>
          </div>
        </div>

        <h3 class="section-title">{t("editor.color")}</h3>
        <div class="list colors" role="radiogroup" aria-label={t("editor.color")}>
          {AVATAR_COLORS.map(([key, hex]) => (
            <button key={key} role="radio" aria-checked={s.avatarColor === key} aria-label={t(`color.${key}`)}
              class="swatch" style={{ background: hex }} onClick={() => set({ avatarColor: key })}>
              {s.avatarColor === key ? "✓" : ""}
            </button>
          ))}
        </div>

        <label class="section-title" for="language">{t("editor.language")}</label>
        <div class="list">
          <select id="language" class="text-input" value={s.learningLanguage} onChange={(e) => setS((prev) => withLanguage(prev, e.currentTarget.value))}>
            {library.languages.map((l) => <option key={l.code} value={l.code}>{l.name}</option>)}
          </select>
        </div>
        <p class="footnote">{t("editor.language.footer")}</p>

        <h3 class="section-title">{t("editor.subjects")}</h3>
        <div class="list">
          {language?.subjects.map((subject) => {
            const on = isSubjectEnabled(s, subject.id);
            return (
              <Toggle key={subject.id} checked={on} disabled={on && isLastEnabledSubject(s, subject.id, subjectIds)}
                onChange={(v) => setS((prev) => withSubject(prev, subject.id, v, subjectIds))}>
                <span style={{ color: subject.color }} aria-hidden="true">{subjectGlyph(subject.icon)}</span> {subject.title}
              </Toggle>
            );
          })}
        </div>
        <p class="footnote">{t("editor.subjects.footer")}</p>

        <h3 class="section-title">{t("sudoku.title")}</h3>
        <div class="list">
          <Toggle checked={s.sudokuEnabled} onChange={(v) => set({ sudokuEnabled: v })}><span aria-hidden="true">🧩</span> {t("editor.sudoku.enabled")}</Toggle>
        </div>
        {s.sudokuEnabled && (
          <>
            <p class="footnote">{t("editor.sudoku.difficulty")}</p>
            <div class="list segmented" role="radiogroup" aria-label={t("editor.sudoku.difficulty")}>
              {GAME_DIFFICULTIES.map((d) => (
                <button key={d} role="radio" aria-checked={s.sudokuDifficulty === d} class={s.sudokuDifficulty === d ? "selected" : ""}
                  onClick={() => set({ sudokuDifficulty: d })} data-testid={`sudoku-difficulty-${d}`}>{t(`editor.games.difficulty.${d}`)}</button>
              ))}
            </div>
          </>
        )}
        <p class="footnote">{t("editor.sudoku.footer")}</p>

        <h3 class="section-title">{t("editor.roundLength")}</h3>
        <div class="list segmented" role="radiogroup" aria-label={t("editor.roundLength")}>
          {ROUND_LENGTH_CHOICES.map((n) => (
            <button key={n} role="radio" aria-checked={s.roundLength === n} class={s.roundLength === n ? "selected" : ""} onClick={() => set({ roundLength: n })}>{n}</button>
          ))}
        </div>

        <h3 class="section-title">{t("editor.options")}</h3>
        <div class="list">
          <Toggle checked={s.soundEnabled} onChange={(v) => set({ soundEnabled: v })}>{t("editor.sound")}</Toggle>
          <Toggle checked={s.readAloudEnabled} onChange={(v) => set({ readAloudEnabled: v })}>{t("editor.readAloud")}</Toggle>
          <Toggle checked={s.hapticsEnabled} onChange={(v) => set({ hapticsEnabled: v })}>{t("editor.haptics")}</Toggle>
          {allowsGentleTimer(s.age) && <Toggle checked={s.gentleTimerEnabled} onChange={(v) => set({ gentleTimerEnabled: v })}>{t("editor.timer")}</Toggle>}
        </div>
        {allowsGentleTimer(s.age) && <p class="footnote">{t("editor.timer.footer")}</p>}

        <h3 class="section-title">{t("editor.games")}</h3>
        <div class="list">
          <Toggle checked={s.gamesEnabled} onChange={(v) => set({ gamesEnabled: v })}>{t("editor.games.enabled")}</Toggle>
        </div>
        {s.gamesEnabled && (
          <>
            <p class="footnote">{t("editor.games.cost")}</p>
            <div class="list segmented" role="radiogroup" aria-label={t("editor.games.cost")}>
              {GAME_COST_CHOICES.map((n) => (
                <button key={n} role="radio" aria-checked={s.gameCost === n} class={s.gameCost === n ? "selected" : ""} onClick={() => set({ gameCost: n })}>{n} ⭐</button>
              ))}
            </div>
            <p class="footnote">{t("editor.games.difficulty")}</p>
            <div class="list segmented" role="radiogroup" aria-label={t("editor.games.difficulty")}>
              {GAME_DIFFICULTIES.map((d) => (
                <button key={d} role="radio" aria-checked={s.gameDifficulty === d} class={s.gameDifficulty === d ? "selected" : ""}
                  onClick={() => set({ gameDifficulty: d })} data-testid={`difficulty-${d}`}>{t(`editor.games.difficulty.${d}`)}</button>
              ))}
            </div>
            <p class="footnote">{t("editor.games.perDay")}</p>
            <div class="list segmented" role="radiogroup" aria-label={t("editor.games.perDay")}>
              {GAMES_PER_DAY_CHOICES.map((n) => (
                <button key={n} role="radio" aria-checked={s.gamesPerDay === n} class={s.gamesPerDay === n ? "selected" : ""} onClick={() => set({ gamesPerDay: n })}>{n === 0 ? "∞" : n}</button>
              ))}
            </div>
          </>
        )}
        <p class="footnote">{t("editor.games.footer")}</p>

        {profile && (
          <>
            <h3 class="section-title">{t("editor.progress")}</h3>
            <div class="list">
              <div class="row-between list-line"><span>⭐ {t("editor.stars")}</span><span class="muted">{t("home.stars %lld", profile.totalStars)}</span></div>
              <div class="row-between list-line"><span>🎮 {t("editor.wallet")}</span><span class="muted">{profile.walletStars} ⭐</span></div>
              <div class="row-between list-line"><span>✓ {t("editor.rounds")}</span><span class="muted">{t("home.subject.rounds %lld", profile.rounds.length)}</span></div>
              <button class="list-row danger" onClick={async () => { if (confirm(t("editor.reset.confirm"))) await onSave(resetProgress(profile)); }}>{t("editor.reset")}</button>
              {onDelete && <button class="list-row danger" onClick={async () => { if (confirm(t("editor.delete.confirm %@", profile.name))) await onDelete(); }}>{t("editor.delete")}</button>}
            </div>
          </>
        )}
        <p class="footnote">🔒 {t("editor.privacy")}</p>
      </div>
    </Sheet>
  );
}

function Toggle({ checked, disabled, onChange, children }: {
  checked: boolean; disabled?: boolean; onChange: (v: boolean) => void; children: ComponentChildren;
}) {
  return (
    <label class={`toggle${disabled ? " disabled" : ""}`}>
      <span>{children}</span>
      <input type="checkbox" role="switch" checked={checked} disabled={disabled} onChange={(e) => onChange(e.currentTarget.checked)} />
      <span class="switch" aria-hidden="true" />
    </label>
  );
}
