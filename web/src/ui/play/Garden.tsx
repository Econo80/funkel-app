import { useRef, useState } from "preact/hooks";
import {
  GARDEN_CATEGORIES,
  GARDEN_COLUMNS,
  GARDEN_ITEMS,
  GOODS_PER_STAR,
  PRODUCE_EMOJI,
  buyLand,
  canClear,
  clearPlot,
  collectProduce,
  connections,
  daysUntilNextStage,
  gardenItem,
  homeFor,
  homeSpace,
  isUnderConstruction,
  itemSize,
  nextLandPrice,
  occupancy,
  placeInGarden,
  placementProblem,
  plotPicture,
  readyProduce,
  sellGoods,
  shopPicture,
  type GardenCategory,
  type GardenItem,
} from "../../domain/garden";
import type { Profile } from "../../domain/profile";
import { systemRng } from "../../domain/random";
import { playSound } from "../../services/feedback";
import { t } from "../../services/i18n";
import { CircleButton, Pip, avatarColor } from "../components";
import { GardenPicture, PathArt } from "./FarmArt";

type Tool = { kind: "item"; id: string } | { kind: "clear" } | undefined;

const TAB_ICONS: Record<GardenCategory, string> = { plants: "🌱", animals: "🐾", buildings: "🏠", paths: "🛤️", decor: "✨" };
/** Zoom steps: the size of one square in pixels. */
const CELL_SIZES = [40, 56, 76];

/**
 * Pip's garden, growing into a farm: plants grow, buildings take days, animals
 * need a home, hens and cows give eggs and milk every day, and there is more
 * land to buy. No timer, no ticket.
 */
export function Garden({ profile: saved, onSave, onBack }: { profile: Profile; onSave: (p: Profile) => Promise<void>; onBack: () => void }) {
  const [tab, setTab] = useState<GardenCategory>("plants");
  const [tool, setTool] = useState<Tool>();
  const [info, setInfo] = useState("");
  const [zoom, setZoom] = useState(1);
  // While drawing a road with a finger, changes collect here and are saved when the finger lifts.
  const [draft, setDraft] = useState<Profile>();
  const drawing = useRef<Profile | undefined>(undefined);
  const profile = draft ?? saved;
  const now = new Date();
  const garden = profile.garden;
  const covered = occupancy(garden);
  const sound = (kind: "pop" | "gentle" | "finish") => profile.soundEnabled && playSound(kind);
  const name = (id: string) => t(`garden.item.${id}`);
  const price = (item: GardenItem) => (item.price === 0 ? t("garden.free") : `${item.price} ⭐`);

  const save = async (next: Profile, message = "", kind: "pop" | "finish" = "pop") => {
    if (next === profile) return;
    sound(kind);
    setInfo(message);
    await onSave(next);
  };

  const describe = (anchor: number) => {
    const plot = garden[anchor]!;
    const item = gardenItem(plot.itemId);
    if (!item) return "";
    const days = daysUntilNextStage(plot, now);
    if (isUnderConstruction(plot, now)) return `${name(item.id)}: ${t("garden.builds %lld", days ?? 1)}`;
    if (days !== undefined) return `${name(item.id)}: ${t("garden.grows %lld", days)}`;
    if (item.houses) {
      const { capacity, used } = homeSpace(garden, item.houses.group, now);
      return `${name(item.id)}: ${t("garden.places %lld", Math.max(0, capacity - used))}`;
    }
    if (item.produce) return `${name(item.id)}: ${t("garden.tomorrow")}`;
    return `${name(item.id)}: ${item.stages.length > 1 ? t("garden.grown") : "🙂"}`;
  };

  const tapCell = async (cell: number) => {
    const anchor = covered[cell];
    const plot = anchor === undefined ? undefined : garden[anchor];

    // Eggs and milk first: tapping a hen or cow collects today's gift.
    if (plot && readyProduce(plot, now)) {
      const produce = readyProduce(plot, now)!;
      return save(collectProduce(profile, cell, now), t(`garden.collect.${produce}`));
    }
    if (drawTool) return; // roads, paths and fences are drawn (see below)
    if (tool?.kind === "clear" && anchor !== undefined) {
      if (!canClear(profile, cell, now)) { sound("gentle"); return setInfo(t("garden.clearBlocked")); }
      return save(clearPlot(profile, cell, now));
    }
    if (tool?.kind === "item" && anchor === undefined) {
      const problem = placementProblem(profile, cell, tool.id, now);
      if (problem) { sound("gentle"); return setInfo(problemText(gardenItem(tool.id)!, problem)); }
      return save(placeInGarden(profile, cell, tool.id, new Date(), systemRng));
    }
    if (anchor !== undefined) setInfo(describe(anchor));
  };

  const problemText = (item: GardenItem, problem: string) =>
    problem === "home" ? t("garden.needs %@", name(homeFor(item.needs!).id))
    : problem === "full" ? t("garden.full %@", name(homeFor(item.needs!).id))
    : problem === "space" ? t("garden.noSpace")
    : "";

  const chooseItem = (item: GardenItem) => {
    const selected = tool?.kind === "item" && tool.id === item.id;
    setTool(selected ? undefined : { kind: "item", id: item.id });
    if (selected) return setInfo("");
    if (item.needs && homeSpace(garden, item.needs, now).capacity === 0) setInfo(t("garden.needs %@", name(homeFor(item.needs).id)));
    else setInfo(item.connects ? t("garden.draw") : itemSize(item)[0] > 1 ? t("garden.big") : "");
  };

  // Drawing roads, paths and fences: press and drag across the squares.
  const drawTool = tool?.kind === "item" && gardenItem(tool.id)?.connects ? tool.id : undefined;
  const drawAt = (target: EventTarget | null) => {
    const cellAttr = (target as HTMLElement | null)?.closest?.("[data-cell]")?.getAttribute("data-cell");
    if (!drawTool || !drawing.current || cellAttr == null) return;
    const next = placeInGarden(drawing.current, Number(cellAttr), drawTool, new Date(), systemRng);
    if (next === drawing.current) return;
    drawing.current = next;
    setDraft(next);
    if (saved.soundEnabled) playSound("pop");
  };
  const startDrawing = (e: PointerEvent) => {
    if (!drawTool) return;
    drawing.current = saved;
    setInfo("");
    drawAt(e.target);
  };
  const stopDrawing = async () => {
    const result = drawing.current;
    drawing.current = undefined;
    if (result && result !== saved) await onSave(result);
    setDraft(undefined);
  };

  const goods = profile.farmGoods.egg + profile.farmGoods.milk;
  const landPrice = nextLandPrice(garden);

  return (
    <main class="screen">
      <div class="column wide">
        <header class="home-header">
          <CircleButton label={t("play.back")} onClick={onBack} testId="garden-back">←</CircleButton>
          <div class="row gap">
            {goods > 0 && (
              <div class="stat-chip" role="img" aria-label={t("garden.goods %lld %lld", profile.farmGoods.egg, profile.farmGoods.milk)} data-testid="farm-goods">
                <span aria-hidden="true">🥚 {profile.farmGoods.egg}  🥛 {profile.farmGoods.milk}</span>
              </div>
            )}
            <div class="stat-chip wallet" role="img" aria-label={t("play.wallet %lld", profile.walletStars)}>
              <span aria-hidden="true">⭐</span><span aria-hidden="true" class="stat-value">{profile.walletStars}</span>
            </div>
          </div>
        </header>
        <div class="play-hero">
          <Pip color={avatarColor(profile.avatarColor)} size={72} bob />
          <div>
            <h1>{t("garden.title")}</h1>
            <p class="muted">{t("garden.subtitle")}</p>
          </div>
        </div>

        {goods >= GOODS_PER_STAR && (
          <button class="card farm-shop pressable" onClick={() => save(sellGoods(profile), t("garden.sold"), "finish")} data-testid="farm-sell">
            🧺 {t("garden.sell %lld", Math.floor(goods / GOODS_PER_STAR))}
          </button>
        )}

        <div class="list segmented garden-tabs" role="tablist">
          {GARDEN_CATEGORIES.map((c) => (
            <button key={c} role="tab" aria-selected={tab === c} class={tab === c ? "selected" : ""} onClick={() => setTab(c)} data-testid={`garden-tab-${c}`}>
              <span aria-hidden="true">{TAB_ICONS[c]}</span> {t(`garden.tab.${c}`)}
            </button>
          ))}
        </div>

        <div class="shop" role="toolbar" aria-label={t("garden.hint")}>
          {GARDEN_ITEMS.filter((i) => i.category === tab).map((item) => {
            const affordable = profile.walletStars >= item.price;
            const selected = tool?.kind === "item" && tool.id === item.id;
            const locked = !!item.needs && homeSpace(garden, item.needs, now).capacity === 0;
            return (
              <button key={item.id} class={`card shop-item pressable${selected ? " selected" : ""}${locked ? " locked" : ""}`} disabled={!affordable}
                aria-pressed={selected} aria-label={`${name(item.id)}, ${price(item)}`}
                onClick={() => chooseItem(item)} data-testid={`shop-${item.id}`}>
                <span class="shop-emoji" aria-hidden="true">
                  {item.connects ? <PathArt id={item.id} links={{ n: false, e: true, s: false, w: true }} /> : <GardenPicture picture={shopPicture(item)} />}
                </span>
                <span class="shop-name" aria-hidden="true">{name(item.id)}</span>
                <span class="shop-price" aria-hidden="true">{locked ? "🔒 " : ""}{price(item)}</span>
              </button>
            );
          })}
          <button class={`card shop-item pressable${tool?.kind === "clear" ? " selected" : ""}`} aria-pressed={tool?.kind === "clear"}
            onClick={() => { setTool(tool?.kind === "clear" ? undefined : { kind: "clear" }); setInfo(""); }} aria-label={t("garden.clear")} data-testid="shop-clear">
            <span class="shop-emoji" aria-hidden="true">🧹</span>
            <span class="shop-price">{t("garden.clear")}</span>
          </button>
        </div>
        <p class="game-hint" aria-live="polite" data-testid="garden-info">{info || t("garden.hint")}</p>

        <div class="row-between garden-zoom">
          <span class="muted">{t("garden.scroll")}</span>
          <div class="row gap">
            <CircleButton label={t("garden.zoomOut")} onClick={() => setZoom((z) => Math.max(0, z - 1))} testId="garden-zoom-out">−</CircleButton>
            <CircleButton label={t("garden.zoomIn")} onClick={() => setZoom((z) => Math.min(CELL_SIZES.length - 1, z + 1))} testId="garden-zoom-in">+</CircleButton>
          </div>
        </div>
        <div class="garden-scroll" data-testid="garden-scroll">
          <div class={`garden-grid${drawTool ? " drawing" : ""}`}
            style={{ "--cell": `${CELL_SIZES[zoom]}px`, gridTemplateColumns: `repeat(${GARDEN_COLUMNS}, var(--cell))` } as never}
            onPointerDown={startDrawing}
            onPointerMove={(e) => drawing.current && drawAt(document.elementFromPoint(e.clientX, e.clientY))}
            onPointerUp={stopDrawing} onPointerCancel={stopDrawing} onPointerLeave={() => drawing.current && stopDrawing()}>
            {garden.map((plot, i) => {
              const col = i % GARDEN_COLUMNS, row = Math.floor(i / GARDEN_COLUMNS);
              if (covered[i] !== undefined && covered[i] !== i) return null; // part of a bigger item
              const item = plot && gardenItem(plot.itemId);
              const [w, h] = item ? itemSize(item) : [1, 1];
              const picture = plot ? plotPicture(plot, now) : "";
              const produce = plot && readyProduce(plot, now);
              const building = plot && isUnderConstruction(plot, now);
              return (
                <button key={i} class={`plot pressable${plot ? " planted" : ""}${w > 1 || h > 1 ? " big" : ""}${building ? " building" : ""}${item?.connects ? " way" : ""}`}
                  style={{ gridColumn: `${col + 1} / span ${w}`, gridRow: `${row + 1} / span ${h}` }}
                  onClick={() => tapCell(i)} aria-label={plot ? name(plot.itemId) : "—"} data-testid="garden-plot" data-item={plot?.itemId} data-cell={i}>
                  <span class="plot-picture" aria-hidden="true">
                    {item?.connects ? <PathArt id={item.id} links={connections(garden, i)} /> : <GardenPicture picture={picture} />}
                  </span>
                  {produce && <span class="plot-produce" aria-hidden="true">{PRODUCE_EMOJI[produce]}</span>}
                </button>
              );
            })}
          </div>
        </div>

        {landPrice !== undefined && (
          <button class="card land-button pressable" disabled={profile.walletStars < landPrice}
            onClick={() => save(buyLand(profile), t("garden.landBought"), "finish")} data-testid="garden-land">
            🌄 {t("garden.land %lld", landPrice)}
          </button>
        )}
      </div>
    </main>
  );
}
