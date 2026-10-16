import { useState } from "preact/hooks";
import { GARDEN_ITEMS, clearPlot, daysUntilNextStage, placeInGarden, plotPicture } from "../../domain/games";
import type { Profile } from "../../domain/profile";
import { systemRng } from "../../domain/random";
import { playSound } from "../../services/feedback";
import { t } from "../../services/i18n";
import { CircleButton, Pip, avatarColor } from "../components";

type Tool = { kind: "item"; id: string } | { kind: "clear" } | undefined;

/** Pip's garden: buy plants and decorations with stars; plants grow day by day. No timer, no ticket. */
export function Garden({ profile, onSave, onBack }: { profile: Profile; onSave: (p: Profile) => Promise<void>; onBack: () => void }) {
  const [tool, setTool] = useState<Tool>();
  const [info, setInfo] = useState("");
  const now = new Date();

  const tapPlot = async (index: number) => {
    const plot = profile.garden[index];
    if (tool?.kind === "clear" && plot) {
      await onSave(clearPlot(profile, index));
      return;
    }
    if (tool?.kind === "item" && !plot) {
      const next = placeInGarden(profile, index, tool.id, new Date(), systemRng);
      if (next !== profile) {
        if (profile.soundEnabled) playSound("pop");
        await onSave(next);
      }
      return;
    }
    if (plot) {
      const days = daysUntilNextStage(plot, now);
      setInfo(`${t(`garden.item.${plot.itemId}`)}: ${days === undefined ? t("garden.grown") : t("garden.grows %lld", days)}`);
    }
  };

  return (
    <main class="screen">
      <div class="column wide">
        <header class="home-header">
          <CircleButton label={t("play.back")} onClick={onBack} testId="garden-back">←</CircleButton>
          <div class="stat-chip wallet" role="img" aria-label={t("play.wallet %lld", profile.walletStars)}>
            <span aria-hidden="true">⭐</span><span aria-hidden="true" class="stat-value">{profile.walletStars}</span>
          </div>
        </header>
        <div class="play-hero">
          <Pip color={avatarColor(profile.avatarColor)} size={72} bob />
          <div>
            <h1>{t("garden.title")}</h1>
            <p class="muted">{t("garden.subtitle")}</p>
          </div>
        </div>

        <div class="shop" role="toolbar" aria-label={t("garden.hint")}>
          {GARDEN_ITEMS.map((item) => {
            const affordable = profile.walletStars >= item.price;
            const selected = tool?.kind === "item" && tool.id === item.id;
            return (
              <button key={item.id} class={`card shop-item pressable${selected ? " selected" : ""}`} disabled={!affordable}
                aria-pressed={selected} aria-label={`${t(`garden.item.${item.id}`)}, ${item.price} ⭐`}
                onClick={() => setTool(selected ? undefined : { kind: "item", id: item.id })} data-testid={`shop-${item.id}`}>
                <span class="shop-emoji" aria-hidden="true">{item.variants?.[0] && item.stages.length > 1 ? item.stages[item.stages.length - 1] : item.stages[0]}</span>
                <span class="shop-price" aria-hidden="true">{item.price} ⭐</span>
              </button>
            );
          })}
          <button class={`card shop-item pressable${tool?.kind === "clear" ? " selected" : ""}`} aria-pressed={tool?.kind === "clear"}
            onClick={() => setTool(tool?.kind === "clear" ? undefined : { kind: "clear" })} aria-label={t("garden.clear")}>
            <span class="shop-emoji" aria-hidden="true">🧹</span>
            <span class="shop-price">{t("garden.clear")}</span>
          </button>
        </div>
        <p class="game-hint" aria-live="polite">{info || t("garden.hint")}</p>

        <div class="garden-grid">
          {profile.garden.map((plot, i) => (
            <button key={i} class={`plot pressable${plot ? " planted" : ""}`} onClick={() => tapPlot(i)}
              aria-label={plot ? t(`garden.item.${plot.itemId}`) : "—"} data-testid="garden-plot">
              <span aria-hidden="true">{plot ? plotPicture(plot, now) : ""}</span>
            </button>
          ))}
        </div>
      </div>
    </main>
  );
}
