import type { ComponentChildren } from "preact";
import { useEffect, useState } from "preact/hooks";
import type { ContentLibrary } from "../content/library";
import { backupFileName, makeBackup, readBackup, type Backup } from "../domain/backup";
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
  GARDEN_MINUTES_CHOICES,
  effectiveAge,
  GIFT_CHOICES,
  GIFT_MAX,
  giveStars,
  resetProgress,
  setSubjectAdjustment,
  subjectAdaptivity,
  withLanguage,
  withSubject,
  type Profile,
  type ProfileSettings,
} from "../domain/profile";
import { t } from "../services/i18n";
import { getMeta, setMeta } from "../services/storage";
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

/** Profiles, backups, plus the privacy statement. */
export function GrownUps({ library, profiles, onSave, onDelete, onRestore, onDone }: {
  library: ContentLibrary;
  profiles: Profile[];
  onSave: (p: Profile) => Promise<void>;
  onDelete: (id: string) => Promise<void>;
  onRestore: (profiles: Profile[]) => Promise<void>;
  onDone: () => void;
}) {
  const [editing, setEditing] = useState<Profile | "new">();
  const [lastBackup, setLastBackup] = useState<string>();
  const [backupNote, setBackupNote] = useState("");
  const [restoring, setRestoring] = useState<Backup>();

  useEffect(() => { void getMeta<string>("lastBackupAt").then(setLastBackup); }, []);

  const saveBackup = async () => {
    const name = backupFileName();
    const file = new File([JSON.stringify(makeBackup(profiles), null, 2)], name, { type: "application/json" });
    try {
      // iPad/iPhone: the share sheet (Dateien, iCloud Drive, AirDrop, Mail …). Elsewhere: a download.
      if (navigator.canShare?.({ files: [file] })) await navigator.share({ files: [file], title: name });
      else download(file);
    } catch (error) {
      if ((error as Error).name === "AbortError") return;
      download(file);
    }
    const now = new Date().toISOString();
    await setMeta("lastBackupAt", now);
    setLastBackup(now);
    setBackupNote(t("backup.saved"));
  };

  const loadBackup = async (input: HTMLInputElement) => {
    const file = input.files?.[0];
    input.value = "";
    if (!file) return;
    const result = readBackup(await file.text());
    if ("problem" in result) setBackupNote(t(`backup.problem.${result.problem}`));
    else { setBackupNote(""); setRestoring(result.backup); }
  };

  if (restoring) {
    return (
      <Sheet label={t("backup.restoreTitle")}>
        <div class="sheet-bar"><button class="link" onClick={() => setRestoring(undefined)}>{t("editor.cancel")}</button></div>
        <div class="column narrow center">
          <div class="lock" aria-hidden="true">📂</div>
          <h1>{t("backup.restoreTitle")}</h1>
          {restoring.exportedAt && <p class="muted">{t("backup.from %@", formatDate(restoring.exportedAt))}</p>}
          <div class="list restore-list">
            {restoring.profiles.map((p) => (
              <div key={p.id} class="row-between list-line">
                <span><strong>{p.name}</strong> <span class="muted">{t("profile.age %lld", p.age)}</span></span>
                <span class="muted">⭐ {p.totalStars} · 🎮 {p.walletStars}</span>
              </div>
            ))}
          </div>
          <p class="footnote">{t("backup.restoreWarning")}</p>
          <BigButton color="var(--danger)" testId="backup-restore" onClick={async () => {
            await onRestore(restoring.profiles);
            setRestoring(undefined);
            setBackupNote(t("backup.restored"));
          }}>
            {t("backup.restore")}
          </BigButton>
        </div>
      </Sheet>
    );
  }

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

        <h3 class="section-title">{t("backup.title")}</h3>
        <div class="list">
          <button class="list-row" onClick={saveBackup} disabled={profiles.length === 0} data-testid="backup-save">💾 {t("backup.save")}</button>
          <label class="list-row" data-testid="backup-load">
            📂 {t("backup.load")}
            <input type="file" accept=".json,application/json" class="visually-hidden" onChange={(e) => loadBackup(e.currentTarget)} data-testid="backup-file" />
          </label>
        </div>
        {backupNote && <p class="backup-note" role="status" data-testid="backup-note">{backupNote}</p>}
        <p class="footnote">{lastBackup ? t("backup.last %@", formatDate(lastBackup)) : t("backup.never")} {t("backup.footer")}</p>
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
  // Per-subject levels a grown-up changed here (years above/below the age), saved with "Speichern".
  const [levels, setLevels] = useState<Record<string, number>>({});
  // Stars to give, added to the wallet on "Speichern".
  const [gift, setGift] = useState(0);
  const levelOf = (code: string, id: string) =>
    levels[`${code}/${id}`] ?? (profile && s.age === profile.age ? subjectAdaptivity(profile, code, id).adjustment : 0);

  const save = async () => {
    if (!valid) return;
    if (!profile) return onSave(createProfile(s));
    let next = applySettings(profile, s);
    for (const [key, adjustment] of Object.entries(levels)) {
      const [code, id] = key.split("/");
      next = setSubjectAdjustment(next, code, id, adjustment);
    }
    await onSave(giveStars(next, gift));
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

        {profile && (
          <>
            <h3 class="section-title">{t("editor.levels")}</h3>
            <div class="list">
              {language?.subjects.map((subject) => {
                const adjustment = levelOf(subject.languageCode, subject.id);
                const levelAge = effectiveAge(s.age, adjustment);
                const change = (step: number) => setLevels((l) => ({ ...l, [`${subject.languageCode}/${subject.id}`]: Math.round((adjustment + step) * 2) / 2 }));
                return (
                  <div key={subject.id} class="row-between list-line level-line" data-testid={`level-${subject.id}`}>
                    <span><span style={{ color: subject.color }} aria-hidden="true">{subjectGlyph(subject.icon)}</span> {subject.title}</span>
                    <span class="level-stepper">
                      <button class="level-step" aria-label={t("editor.level.easier %@", subject.title)} disabled={adjustment <= -1.5 || levelAge <= 4}
                        onClick={() => change(-0.5)} data-testid={`level-down-${subject.id}`}>−</button>
                      <span class="level-value">{t("editor.level %@", formatLevelAge(levelAge))}</span>
                      <button class="level-step" aria-label={t("editor.level.harder %@", subject.title)} disabled={adjustment >= 3 || levelAge >= 14}
                        onClick={() => change(0.5)} data-testid={`level-up-${subject.id}`}>+</button>
                    </span>
                  </div>
                );
              })}
            </div>
            <p class="footnote">{t("editor.level.footer")}</p>
          </>
        )}

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
            <p class="footnote">{t("editor.garden.minutes")}</p>
            <div class="list segmented" role="radiogroup" aria-label={t("editor.garden.minutes")}>
              {GARDEN_MINUTES_CHOICES.map((n) => (
                <button key={n} role="radio" aria-checked={s.gardenMinutesPerDay === n} class={s.gardenMinutesPerDay === n ? "selected" : ""}
                  onClick={() => set({ gardenMinutesPerDay: n })} data-testid={`garden-minutes-${n}`}>{n === 0 ? "∞" : n}</button>
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
            <h3 class="section-title">🎁 {t("editor.gift")}</h3>
            <div class="list gift">
              <div class="row-between list-line">
                <span>{t("editor.gift.amount")}</span>
                <span class="level-stepper">
                  <button class="level-step" aria-label={t("editor.gift.less")} disabled={gift <= 0} onClick={() => setGift((g) => Math.max(0, g - 5))} data-testid="gift-down">−</button>
                  <span class="level-value gift-value" aria-live="polite" data-testid="gift-amount">{gift} ⭐</span>
                  <button class="level-step" aria-label={t("editor.gift.more")} disabled={gift >= GIFT_MAX} onClick={() => setGift((g) => Math.min(GIFT_MAX, g + 5))} data-testid="gift-up">+</button>
                </span>
              </div>
              <div class="segmented">
                {GIFT_CHOICES.map((n) => (
                  <button key={n} class={gift === n ? "selected" : ""} onClick={() => setGift(n)} data-testid={`gift-${n}`}>{n} ⭐</button>
                ))}
              </div>
            </div>
            <p class="footnote">{gift > 0 ? t("editor.gift.pending %lld %@", gift, profile.name) : t("editor.gift.footer")}</p>

            <h3 class="section-title">{t("editor.progress")}</h3>
            <div class="list">
              <div class="row-between list-line"><span>⭐ {t("editor.stars")}</span><span class="muted">{t("home.stars %lld", profile.totalStars)}</span></div>
              <div class="row-between list-line"><span>🎮 {t("editor.wallet")}</span>
                <span class="muted" data-testid="editor-wallet">{profile.walletStars} ⭐{gift > 0 && <strong class="gift-preview"> → {profile.walletStars + gift} ⭐</strong>}</span>
              </div>
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

function download(file: File) {
  const url = URL.createObjectURL(file);
  const link = document.createElement("a");
  link.href = url;
  link.download = file.name;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

const formatDate = (iso: string) => new Date(iso).toLocaleString(document.documentElement.lang || undefined, { dateStyle: "medium", timeStyle: "short" });

/** 8.5 → "8½", rounded to half years. */
function formatLevelAge(age: number): string {
  const half = Math.round(age * 2) / 2;
  return `${Math.floor(half)}${half % 1 ? "½" : ""}`;
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
