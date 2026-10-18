import type { ComponentChildren } from "preact";
import { useEffect, useRef, useState } from "preact/hooks";
import {
  GARDEN_CATEGORIES,
  GARDEN_COLUMNS,
  GARDEN_ITEMS,
  GOODS_PER_STAR,
  PRODUCE,
  PRODUCE_EMOJI,
  XP_FOR_COLLECTING,
  buyLand,
  canClear,
  canFulfil,
  clearPlot,
  collectProduce,
  connections,
  daysUntilNextStage,
  farmLevel,
  fulfilOrder,
  gardenItem,
  goodsCount,
  homeFor,
  homeSpace,
  isUnderConstruction,
  itemSize,
  moveItem,
  nextLandPrice,
  occupancy,
  placeInGarden,
  placementProblem,
  plotPicture,
  readyCells,
  readyProduce,
  sellGoods,
  shopPicture,
  unlockedAt,
  withTodaysOrders,
  type GardenCategory,
  type GardenItem,
} from "../../domain/garden";
import { GARDEN_BONUS_CHOICES, addGardenTime, gardenSecondsLeft, grantGardenMinutes, type Profile } from "../../domain/profile";
import { systemRng } from "../../domain/random";
import { playSound } from "../../services/feedback";
import { t } from "../../services/i18n";
import { BigButton, CircleButton, Confetti, Sheet } from "../components";
import { GrownUpGate } from "../GrownUps";
import { GardenPicture, PathArt } from "./FarmArt";

type Tool = { kind: "place"; id: string } | { kind: "move"; from?: number } | { kind: "clear" } | undefined;
type Popup = { id: number; cell: number; text: string; kind: "goods" | "xp" | "sparkle" };

const TAB_ICONS: Record<GardenCategory, string> = { plants: "🌱", animals: "🐾", buildings: "🏠", paths: "🛤️", decor: "✨" };
/** Zoom steps: the size of one square in pixels. */
const CELL_SIZES = [44, 60, 80];
/** Light over the farm, by the time of day. */
const daylight = (hour: number) => (hour >= 20 || hour < 6 ? "night" : hour < 9 ? "morning" : hour >= 17 ? "evening" : "day");

/**
 * Pip's farm, full screen: a meadow to scroll around on, with a level and XP
 * bar, a shop drawer, an order board, and lots of little feedback. Plants grow,
 * buildings take days, animals need a home, and things are ready every day.
 */
export function Garden({ profile: saved, onSave, onBack }: { profile: Profile; onSave: (p: Profile) => Promise<void>; onBack: () => void }) {
  const [tool, setTool] = useState<Tool>();
  const [sheet, setSheet] = useState<"shop" | "orders">();
  const [tab, setTab] = useState<GardenCategory>("plants");
  const [toast, setToast] = useState("");
  const [zoom, setZoom] = useState(1);
  const [popups, setPopups] = useState<Popup[]>([]);
  const [placed, setPlaced] = useState<number>();
  const [levelUp, setLevelUp] = useState<number>();
  // While drawing a road with a finger, changes collect here and are saved when the finger lifts.
  const [draft, setDraft] = useState<Profile>();
  const drawing = useRef<Profile | undefined>(undefined);
  const popupId = useRef(0);
  const [extending, setExtending] = useState(false);
  // Garden time: counted every second while the farm is on screen, saved with every change (and every 15 s).
  const latest = useRef(saved);
  const pendingSeconds = useRef(0);
  const [, setTick] = useState(0);
  useEffect(() => { latest.current = saved; }, [saved]);
  const profile = draft ?? saved;
  const now = new Date();
  const garden = profile.garden;
  const covered = occupancy(garden);
  const level = farmLevel(profile.farmXp);
  const cell = CELL_SIZES[zoom];
  const name = (id: string) => t(`garden.item.${id}`);
  const sound = (kind: "pop" | "gentle" | "finish" | "correct") => saved.soundEnabled && playSound(kind);

  // Today's orders are made when the farm opens (and once there is something to order).
  useEffect(() => {
    const withOrders = withTodaysOrders(saved, new Date());
    if (withOrders !== saved) void persist(withOrders);
  }, [saved.farmOrders?.day, saved.garden]);

  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(""), 3000);
    return () => clearTimeout(timer);
  }, [toast]);

  const pop = (cellIndex: number, text: string, kind: Popup["kind"], delay = 0) => {
    const id = ++popupId.current;
    setTimeout(() => setPopups((list) => [...list, { id, cell: cellIndex, text, kind }]), delay);
    setTimeout(() => setPopups((list) => list.filter((x) => x.id !== id)), delay + 1300);
  };

  /** Saves, together with the garden time counted so far. */
  const persist = async (next: Profile) => {
    const withTime = addGardenTime(next, pendingSeconds.current, new Date());
    pendingSeconds.current = 0;
    latest.current = withTime;
    await onSave(withTime);
  };

  /** Saves a change; celebrates a new farm level. */
  const commit = async (next: Profile) => {
    if (next === saved) return;
    const before = farmLevel(saved.farmXp).level, after = farmLevel(next.farmXp).level;
    if (after > before) setTimeout(() => { setLevelUp(after); sound("finish"); }, 500);
    await persist(next);
  };

  const secondsLeft = (() => {
    const left = gardenSecondsLeft(latest.current, now);
    return left === undefined ? undefined : Math.max(0, left - pendingSeconds.current);
  })();
  const timeUp = secondsLeft === 0;

  useEffect(() => {
    if (!saved.gardenMinutesPerDay) return;
    const timer = setInterval(() => {
      if (document.visibilityState !== "visible") return;
      const left = gardenSecondsLeft(latest.current, new Date());
      if (left === undefined || left - pendingSeconds.current <= 0) return;
      pendingSeconds.current += 1;
      setTick((n) => n + 1);
      const remaining = left - pendingSeconds.current;
      if (remaining === 120) setToast(t("garden.timeWarning"));
      if (remaining <= 0) { void persist(latest.current); sound("finish"); }
      else if (pendingSeconds.current >= 15) void persist(latest.current);
    }, 1000);
    return () => { clearInterval(timer); if (pendingSeconds.current) void persist(latest.current); };
  }, [saved.gardenMinutesPerDay]);

  const collect = (cellIndex: number, base: Profile, delay = 0): Profile => {
    const anchor = occupancy(base.garden)[cellIndex];
    const plot = anchor === undefined ? undefined : base.garden[anchor];
    const produce = plot && readyProduce(plot, now);
    if (!produce || anchor === undefined) return base;
    pop(anchor, `+1 ${PRODUCE_EMOJI[produce]}`, "goods", delay);
    pop(anchor, `+${XP_FOR_COLLECTING} XP`, "xp", delay + 150);
    return collectProduce(base, anchor, now);
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
    return name(item.id);
  };

  const problemText = (item: GardenItem, problem: string) =>
    problem === "home" ? t("garden.needs %@", name(homeFor(item.needs!).id))
    : problem === "full" ? t("garden.full %@", name(homeFor(item.needs!).id))
    : problem === "space" ? t("garden.noSpace")
    : problem === "level" ? t("garden.level %lld", item.level)
    : problem === "stars" ? t("garden.noStars")
    : "";

  const tapCell = async (cellIndex: number) => {
    const anchor = covered[cellIndex];
    const plot = anchor === undefined ? undefined : garden[anchor];

    if (tool?.kind === "move") {
      if (tool.from === undefined) {
        if (anchor === undefined) return;
        setTool({ kind: "move", from: anchor });
        return setToast("");
      }
      const next = moveItem(saved, tool.from, cellIndex);
      if (next === saved) { sound("gentle"); return setToast(t("garden.noSpace")); }
      sound("pop");
      setPlaced(occupancy(next.garden)[cellIndex]);
      setTool({ kind: "move" });
      return commit(next);
    }
    // Things ready to collect come first: a tap on a hen collects today's egg.
    if (plot && anchor !== undefined && readyProduce(plot, now) && tool?.kind !== "clear") {
      sound("pop");
      return commit(collect(anchor, saved));
    }
    if (tool?.kind === "clear" && anchor !== undefined) {
      if (!canClear(saved, cellIndex, now)) { sound("gentle"); return setToast(t("garden.clearBlocked")); }
      sound("pop");
      pop(anchor, "💨", "sparkle");
      return commit(clearPlot(saved, cellIndex, now));
    }
    if (tool?.kind === "place" && !gardenItem(tool.id)?.connects && anchor === undefined) {
      const item = gardenItem(tool.id)!;
      const problem = placementProblem(saved, cellIndex, tool.id, now);
      if (problem) { sound("gentle"); return setToast(problemText(item, problem)); }
      const next = placeInGarden(saved, cellIndex, tool.id, new Date(), systemRng);
      const at = next.garden.findIndex((x, i) => x && !saved.garden[i]);
      sound("pop");
      setPlaced(at);
      pop(at, "✨", "sparkle");
      if (item.price > 0) pop(at, `+${item.price} XP`, "xp", 200);
      if (next.walletStars < item.price) setTool(undefined); // can't afford another
      return commit(next);
    }
    if (anchor !== undefined) setToast(describe(anchor));
  };

  // Drawing roads, paths and fences: press and drag across the squares.
  const drawTool = tool?.kind === "place" && gardenItem(tool.id)?.connects ? tool.id : undefined;
  const drawAt = (target: EventTarget | null) => {
    const attr = (target as HTMLElement | null)?.closest?.("[data-cell]")?.getAttribute("data-cell");
    if (!drawTool || !drawing.current || attr == null) return;
    const next = placeInGarden(drawing.current, Number(attr), drawTool, new Date(), systemRng);
    if (next === drawing.current) return;
    drawing.current = next;
    setDraft(next);
    sound("pop");
  };
  const startDrawing = (e: PointerEvent) => {
    if (!drawTool) return;
    drawing.current = saved;
    drawAt(e.target);
  };
  const stopDrawing = async () => {
    const result = drawing.current;
    drawing.current = undefined;
    if (result && result !== saved) await persist(result);
    setDraft(undefined);
  };

  const collectAll = () => {
    let next = saved;
    readyCells(saved.garden, now).forEach((c, i) => { next = collect(c, next, Math.min(i, 12) * 90); });
    sound("correct");
    void commit(next);
  };

  const pick = (item: GardenItem) => {
    setSheet(undefined);
    setTool({ kind: "place", id: item.id });
    setToast(item.needs && homeSpace(garden, item.needs, now).capacity === 0 ? t("garden.needs %@", name(homeFor(item.needs).id)) : "");
  };

  const ready = readyCells(garden, now).length;
  const orders = profile.farmOrders?.orders ?? [];
  const deliverable = orders.filter((o) => canFulfil(profile, o)).length;
  const goods = goodsCount(profile.farmGoods);
  const landPrice = nextLandPrice(garden);
  const toolItem = tool?.kind === "place" ? gardenItem(tool.id) : undefined;
  const banner =
    toolItem ? (toolItem.connects ? t("garden.draw") : t("garden.placeWhere %@", name(toolItem.id)))
    : tool?.kind === "move" ? (tool.from === undefined ? t("garden.movePick") : t("garden.moveWhere %@", name(garden[tool.from]?.itemId ?? "")))
    : tool?.kind === "clear" ? t("garden.clearPick")
    : undefined;

  return (
    <main class={`farm time-${timeUp ? "night" : daylight(now.getHours())}`}>
      <div class="farm-world" data-testid="garden-scroll">
        <div class={`farm-ground${tool ? " placing" : ""}${drawTool ? " drawing" : ""}`}
          style={{ "--cell": `${cell}px`, gridTemplateColumns: `repeat(${GARDEN_COLUMNS}, var(--cell))` } as never}
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
            const kind = !item ? ""
              : item.connects ? " way"
              : item.category === "animals" ? " animal"
              : item.harvest || item.id === "flower" ? " crop"
              : item.category === "plants" ? " plant"
              : picture.startsWith("art:") ? " art" : "";
            const moving = tool?.kind === "move" && tool.from === i;
            return (
              <button key={i}
                class={`farm-tile${plot ? " filled" : ""}${kind}${building ? " building" : ""}${placed === i ? " pop-in" : ""}${moving ? " moving" : ""}${produce ? " ready" : ""}`}
                style={{ gridColumn: `${col + 1} / span ${w}`, gridRow: `${row + 1} / span ${h}`, zIndex: plot ? 2 + (row + h) * 2 : 1, "--delay": `${-((i * 37) % 23) / 10}s` } as never}
                onClick={() => tapCell(i)} aria-label={plot ? name(plot.itemId) : t("garden.empty")} data-testid="garden-plot" data-item={plot?.itemId} data-cell={i}>
                {item?.connects ? <PathArt id={item.id} links={connections(garden, i)} />
                  : plot && <span class="obj" aria-hidden="true"><span class="obj-picture"><GardenPicture picture={picture} /></span></span>}
                {building && <span class="hammer" aria-hidden="true">🔨</span>}
                {produce && <span class="bubble" aria-hidden="true">{PRODUCE_EMOJI[produce]}</span>}
              </button>
            );
          })}
          {popups.map((p) => (
            <span key={p.id} class={`popup ${p.kind}`} aria-hidden="true"
              style={{ left: `calc(${(p.cell % GARDEN_COLUMNS) + 0.5} * var(--cell) + 24px)`, top: `calc(${Math.floor(p.cell / GARDEN_COLUMNS)} * var(--cell) + 24px)` }}>
              {p.text}
            </span>
          ))}
        </div>
      </div>
      <div class="farm-light" aria-hidden="true" />

      <header class="farm-hud">
        <CircleButton label={t("play.back")} onClick={onBack} testId="garden-back">←</CircleButton>
        <div class="farm-level" role="img" aria-label={t("garden.levelLabel %lld", level.level)} data-testid="farm-level">
          <span class="level-badge">{level.level}</span>
          <span class="xp-bar"><span class="xp-fill" style={{ width: `${(100 * level.xpInLevel) / level.xpForNext}%` }} /></span>
        </div>
        <div class="hud-right">
          {secondsLeft !== undefined && (
            <span class={`hud-pill clock${secondsLeft <= 120 ? " low" : ""}`} role="timer" aria-label={t("garden.timeLeft %lld", Math.ceil(secondsLeft / 60))} data-testid="garden-clock">
              ⏱ {Math.floor(secondsLeft / 60)}:{String(secondsLeft % 60).padStart(2, "0")}
            </span>
          )}
          <button class="hud-pill" onClick={() => setSheet("orders")} aria-label={t("garden.goodsLabel %lld", goods)} data-testid="farm-goods">🧺 {goods}</button>
          <span class="hud-pill wallet" role="img" aria-label={t("play.wallet %lld", profile.walletStars)}>⭐ <span class="stat-value">{profile.walletStars}</span></span>
        </div>
      </header>

      {(banner || toast) && (
        <div class="farm-banner" aria-live="polite" data-testid="garden-info">
          <span>{toast || banner}</span>
          {tool && <button class="banner-close" onClick={() => { setTool(undefined); setToast(""); }} data-testid="tool-done">{t("garden.done")}</button>}
        </div>
      )}

      <div class="farm-zoom">
        <button class="round-tool" onClick={() => setZoom((z) => Math.min(CELL_SIZES.length - 1, z + 1))} aria-label={t("garden.zoomIn")} data-testid="garden-zoom-in">＋</button>
        <button class="round-tool" onClick={() => setZoom((z) => Math.max(0, z - 1))} aria-label={t("garden.zoomOut")} data-testid="garden-zoom-out">－</button>
      </div>

      <nav class="farm-bar">
        <button class="bar-button shop" onClick={() => setSheet("shop")} data-testid="farm-shop"><span aria-hidden="true">🛒</span>{t("garden.shop")}</button>
        <button class="bar-button" onClick={() => setSheet("orders")} data-testid="farm-orders">
          <span aria-hidden="true">📋</span>{t("garden.orders")}{deliverable > 0 && <span class="badge">{deliverable}</span>}
        </button>
        {ready > 0 && (
          <button class="bar-button collect" onClick={collectAll} data-testid="farm-collect">
            <span aria-hidden="true">🧺</span>{t("garden.collectAll")}<span class="badge">{ready}</span>
          </button>
        )}
        <button class={`bar-button${tool?.kind === "move" ? " active" : ""}`} onClick={() => { setTool(tool?.kind === "move" ? undefined : { kind: "move" }); setToast(""); }} data-testid="farm-move">
          <span aria-hidden="true">✋</span>{t("garden.move")}
        </button>
        <button class={`bar-button${tool?.kind === "clear" ? " active" : ""}`} onClick={() => { setTool(tool?.kind === "clear" ? undefined : { kind: "clear" }); setToast(""); }} data-testid="shop-clear">
          <span aria-hidden="true">🧹</span>{t("garden.clear")}
        </button>
      </nav>

      {sheet === "shop" && (
        <FarmSheet title={t("garden.shop")} onClose={() => setSheet(undefined)}>
          <div class="shop-tabs" role="tablist">
            {GARDEN_CATEGORIES.map((c) => (
              <button key={c} role="tab" aria-selected={tab === c} class={tab === c ? "selected" : ""} onClick={() => setTab(c)} data-testid={`garden-tab-${c}`}>
                <span aria-hidden="true">{TAB_ICONS[c]}</span> {t(`garden.tab.${c}`)}
              </button>
            ))}
          </div>
          <div class="shop-cards">
            {GARDEN_ITEMS.filter((i) => i.category === tab).map((item) => {
              const lockedLevel = level.level < item.level;
              const affordable = profile.walletStars >= item.price;
              const needsHome = !!item.needs && homeSpace(garden, item.needs, now).capacity === 0;
              const priceText = item.price === 0 ? t("garden.free") : `${item.price} ⭐`;
              return (
                <button key={item.id} class={`shop-card${lockedLevel ? " locked" : ""}`} disabled={lockedLevel || !affordable}
                  onClick={() => pick(item)} data-testid={`shop-${item.id}`}
                  aria-label={`${name(item.id)}, ${priceText}${lockedLevel ? `, ${t("garden.level %lld", item.level)}` : ""}`}>
                  <span class="card-picture" aria-hidden="true">
                    {item.connects ? <PathArt id={item.id} links={{ n: false, e: true, s: false, w: true }} /> : <GardenPicture picture={shopPicture(item)} />}
                  </span>
                  <span class="card-name" aria-hidden="true">{name(item.id)}</span>
                  {lockedLevel
                    ? <span class="card-lock" aria-hidden="true">🔒 {t("garden.level %lld", item.level)}</span>
                    : <span class={`card-price${item.price === 0 ? " free" : ""}`} aria-hidden="true">{priceText}</span>}
                  {!lockedLevel && needsHome && <span class="card-note" aria-hidden="true">🏠 {name(homeFor(item.needs!).id)}</span>}
                </button>
              );
            })}
            {tab === "buildings" && landPrice !== undefined && (
              <button class="shop-card land" disabled={profile.walletStars < landPrice} data-testid="garden-land"
                onClick={() => { void commit(buyLand(saved)); setSheet(undefined); setToast(t("garden.landBought")); sound("finish"); }}>
                <span class="card-picture" aria-hidden="true">🌄</span>
                <span class="card-name">{t("garden.landCard")}</span>
                <span class="card-price">{landPrice} ⭐</span>
              </button>
            )}
          </div>
        </FarmSheet>
      )}

      {sheet === "orders" && (
        <FarmSheet title={t("garden.orders")} onClose={() => setSheet(undefined)}>
          <h3 class="sheet-heading">{t("garden.storage")}</h3>
          <div class="goods-row">
            {PRODUCE.map((k) => (
              <span key={k} class={`goods-chip${profile.farmGoods[k] ? "" : " empty"}`}>{PRODUCE_EMOJI[k]} {profile.farmGoods[k] ?? 0}</span>
            ))}
          </div>
          <h3 class="sheet-heading">{t("garden.ordersToday")}</h3>
          {orders.length === 0 && <p class="muted">{t("garden.noOrders")}</p>}
          <div class="order-list">
            {orders.map((o) => (
              <div key={o.id} class={`order-card${o.done ? " done" : ""}`} data-testid="farm-order">
                <span class="order-wants">
                  {PRODUCE.filter((k) => o.wants[k]).map((k) => (
                    <span key={k} class={o.done || (profile.farmGoods[k] ?? 0) >= o.wants[k]! ? "have" : "need"}>{o.wants[k]} {PRODUCE_EMOJI[k]}</span>
                  ))}
                </span>
                <span class="order-reward">+{o.stars} ⭐ · +{o.xp} XP</span>
                {o.done ? <span class="order-done" aria-label={t("garden.delivered")}>✓</span> : (
                  <button class="order-deliver" disabled={!canFulfil(profile, o)} data-testid="order-deliver"
                    onClick={() => { void commit(fulfilOrder(saved, o.id)); sound("finish"); setToast(t("garden.delivered")); }}>
                    {t("garden.deliver")}
                  </button>
                )}
              </div>
            ))}
          </div>
          <h3 class="sheet-heading">{t("garden.shopFarm")}</h3>
          <p class="muted">{t("garden.sellHint %lld", GOODS_PER_STAR)}</p>
          <BigButton color="#E8A33A" disabled={goods < GOODS_PER_STAR} onClick={() => { void commit(sellGoods(saved)); sound("finish"); setToast(t("garden.sold")); }} testId="farm-sell">
            🧺 {t("garden.sell %lld", Math.floor(goods / GOODS_PER_STAR))}
          </BigButton>
        </FarmSheet>
      )}

      {timeUp && !extending && (
        <div class="game-over" role="dialog" aria-modal="true" aria-label={t("garden.timeUp")} data-testid="garden-time-up">
          <div class="card game-over-card farm-sleep">
            <div class="sleep-moon" aria-hidden="true">🌙</div>
            <h1>{t("garden.timeUp")}</h1>
            <p class="muted">{t("garden.timeUpText")}</p>
            <BigButton color="var(--ink)" onClick={onBack} testId="garden-time-back">{t("play.back")}</BigButton>
            <button class="link grown-up-link" onClick={() => setExtending(true)} data-testid="garden-more-time">🔓 {t("garden.moreTime")}</button>
          </div>
        </div>
      )}

      {extending && (
        <GrownUpGate onCancel={() => setExtending(false)}>
          <Sheet label={t("garden.moreTime")}>
            <div class="sheet-bar"><button class="link" onClick={() => setExtending(false)}>{t("editor.cancel")}</button></div>
            <div class="column narrow center">
              <div class="lock" aria-hidden="true">⏱</div>
              <h1>{t("garden.moreTime")}</h1>
              <p class="muted">{t("garden.moreTimeText %@", saved.name)}</p>
              {GARDEN_BONUS_CHOICES.map((n) => (
                <BigButton key={n} color="#34C77B" testId={`garden-bonus-${n}`} onClick={async () => {
                  await persist(grantGardenMinutes(latest.current, n, new Date()));
                  setExtending(false);
                  setToast("");
                }}>
                  {t("garden.moreTime.minutes %lld", n)}
                </BigButton>
              ))}
              <p class="footnote">{t("garden.moreTime.footer")}</p>
            </div>
          </Sheet>
        </GrownUpGate>
      )}

      {levelUp !== undefined && (
        <div class="game-over" role="dialog" aria-modal="true" aria-label={t("garden.levelUp %lld", levelUp)}>
          <div class="card game-over-card level-up-card">
            <div class="level-up-badge">{levelUp}</div>
            <h1>{t("garden.levelUp %lld", levelUp)}</h1>
            {unlockedAt(levelUp).length > 0 && (
              <>
                <p class="muted">{t("garden.unlocked")}</p>
                <div class="unlock-row">
                  {unlockedAt(levelUp).map((item) => (
                    <span key={item.id} class="unlock-item">
                      <span class="card-picture" aria-hidden="true"><GardenPicture picture={shopPicture(item)} /></span>
                      <span>{name(item.id)}</span>
                    </span>
                  ))}
                </div>
              </>
            )}
            <BigButton color="var(--ink)" onClick={() => setLevelUp(undefined)} testId="level-up-ok">{t("garden.great")}</BigButton>
          </div>
          <Confetti trigger={levelUp} count={60} />
        </div>
      )}
    </main>
  );
}

function FarmSheet({ title, onClose, children }: { title: string; onClose: () => void; children: ComponentChildren }) {
  return (
    <div class="farm-sheet-backdrop" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <section class="farm-sheet" role="dialog" aria-modal="true" aria-label={title}>
        <div class="farm-sheet-bar">
          <h2>{title}</h2>
          <button class="round-tool" onClick={onClose} aria-label={t("garden.close")} data-testid="sheet-close">✕</button>
        </div>
        {children}
      </section>
    </div>
  );
}
