import type { Profile } from "../domain/profile";
import { t } from "../services/i18n";
import { BigButton, CircleButton, Pip, avatarColor } from "./components";

/** "Wer lernt heute?" — big avatar tiles, one per child. */
export function ProfilePicker({ profiles, onSelect, onAdd, onGrownUps }: {
  profiles: Profile[]; onSelect: (p: Profile) => void; onAdd: () => void; onGrownUps: () => void;
}) {
  return (
    <main class="screen">
      <div class="top-right">
        <CircleButton label={t("grownups.button")} onClick={onGrownUps} testId="grown-ups">⚙️</CircleButton>
      </div>
      <div class="column narrow center">
        <Pip color="#FFB020" mood={profiles.length ? "cheering" : "happy"} size={120} bob />
        {profiles.length === 0 ? (
          <>
            <h1>{t("profiles.empty.title")}</h1>
            <p class="muted">{t("profiles.empty.message")}</p>
            <BigButton onClick={onAdd} testId="add-profile">＋ {t("profiles.add")}</BigButton>
          </>
        ) : (
          <>
            <h1>{t("profiles.title")}</h1>
            <div class="profile-grid">
              {profiles.map((p) => (
                <button key={p.id} class="card profile-tile pressable" onClick={() => onSelect(p)} data-testid={`profile-${p.name}`}>
                  <Pip color={avatarColor(p.avatarColor)} size={88} />
                  <span class="tile-name">{p.name}</span>
                  <span class="muted">{t("profile.age %lld", p.age)}</span>
                </button>
              ))}
              <button class="card profile-tile add-tile pressable" onClick={onAdd} data-testid="add-profile">
                <span class="add-circle" aria-hidden="true">＋</span>
                <span class="muted">{t("profiles.add")}</span>
              </button>
            </div>
          </>
        )}
      </div>
    </main>
  );
}
