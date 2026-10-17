// Pip's garden, which grows into a little farm over days and weeks:
// plants grow and can be harvested, buildings take days to build, animals need
// a home, hens, cows and bees give something once a day, orders ask for goods,
// and spending stars on the farm earns XP towards farm levels that unlock more.
// Everything is paid from the wallet; lifetime stars never change here.
import { dayKey, type Profile } from "./profile";
import { randomElement, randomInt, seededRng, shuffled, type Rng } from "./random";

export type GardenCategory = "plants" | "animals" | "buildings" | "paths" | "decor";
export const GARDEN_CATEGORIES: readonly GardenCategory[] = ["plants", "animals", "buildings", "paths", "decor"];

export type Produce = "egg" | "milk" | "wheat" | "veg" | "apple" | "honey";
export const PRODUCE: readonly Produce[] = ["egg", "milk", "wheat", "veg", "apple", "honey"];
export const PRODUCE_EMOJI: Record<Produce, string> = { egg: "🥚", milk: "🥛", wheat: "🌾", veg: "🥕", apple: "🍎", honey: "🍯" };
export const emptyGoods = (): Record<Produce, number> => ({ egg: 0, milk: 0, wheat: 0, veg: 0, apple: 0, honey: 0 });

/** Animals that need a home, by the kind of home. */
export type HomeGroup = "dog" | "cat" | "chicken" | "farm" | "duck";

export interface GardenItem {
  id: string;
  price: number;
  category: GardenCategory;
  /** Farm level that unlocks it. */
  level: number;
  /** Picture per stage (emoji, or "art:<id>" for a drawn one); the last one may be a variant. */
  stages: string[];
  /** Days after placing when each stage starts (same length as stages). */
  days: number[];
  variants?: string[];
  /** Columns × rows on the grid; 1×1 if missing. */
  size?: [number, number];
  /** A building: which animals live here, and how many. */
  houses?: { group: HomeGroup; capacity: number };
  /** An animal that needs a finished home of this kind. */
  needs?: HomeGroup;
  /** Grown, it gives this once a day (hens, cows, bees, apple trees). */
  produce?: Produce;
  /** A crop: grown, it can be harvested, and then grows again. */
  harvest?: Produce;
  /** Roads, paths and fences join up with neighbours of the same kind. */
  connects?: boolean;
}

const BUILDING = "🚧";

export const GARDEN_ITEMS: GardenItem[] = [
  // Plants
  { id: "flower", price: 3, level: 1, category: "plants", stages: ["🌱", "🌿", "🌷"], days: [0, 1, 3], variants: ["🌷", "🌻", "🌼", "🌸", "🌹", "🪻"] },
  { id: "wheat", price: 3, level: 1, category: "plants", stages: ["🌱", "🌾"], days: [0, 1], harvest: "wheat" },
  { id: "mushroom", price: 2, level: 1, category: "plants", stages: ["🍄"], days: [0] },
  { id: "tree", price: 12, level: 1, category: "plants", stages: ["🌱", "🪴", "🌳"], days: [0, 3, 7], variants: ["🌳", "🌲"] },
  { id: "vegetable", price: 4, level: 2, category: "plants", stages: ["🌱", "🌿", "🥕"], days: [0, 1, 2], variants: ["🥕", "🥬", "🎃", "🍅", "🥔"], harvest: "veg" },
  { id: "appletree", price: 20, level: 4, category: "plants", stages: ["🌱", "🪴", "🌳"], days: [0, 2, 4], produce: "apple" },
  // Animals: small ones live anywhere; farm animals need their home first.
  { id: "snail", price: 4, level: 1, category: "animals", stages: ["🐌"], days: [0] },
  { id: "ladybug", price: 5, level: 1, category: "animals", stages: ["🐞"], days: [0] },
  { id: "butterfly", price: 6, level: 1, category: "animals", stages: ["🦋"], days: [0] },
  { id: "bee", price: 6, level: 1, category: "animals", stages: ["🐝"], days: [0] },
  { id: "rabbit", price: 8, level: 2, category: "animals", stages: ["🐇"], days: [0] },
  { id: "dog", price: 15, level: 2, category: "animals", stages: ["🐕"], days: [0], needs: "dog" },
  { id: "chick", price: 6, level: 2, category: "animals", stages: ["🐣", "🐥", "🐔"], days: [0, 2, 4], needs: "chicken", produce: "egg" },
  { id: "duck", price: 8, level: 3, category: "animals", stages: ["🦆"], days: [0], needs: "duck" },
  { id: "cat", price: 12, level: 3, category: "animals", stages: ["🐈"], days: [0], needs: "cat" },
  { id: "sheep", price: 15, level: 4, category: "animals", stages: ["🐑"], days: [0], needs: "farm" },
  { id: "goat", price: 15, level: 4, category: "animals", stages: ["🐐"], days: [0], needs: "farm" },
  { id: "pig", price: 18, level: 5, category: "animals", stages: ["🐖"], days: [0], needs: "farm" },
  { id: "cow", price: 25, level: 5, category: "animals", stages: ["🐄"], days: [0], needs: "farm", produce: "milk" },
  { id: "horse", price: 30, level: 6, category: "animals", stages: ["🐴"], days: [0], needs: "farm" },
  // Buildings take a few days to build.
  { id: "doghouse", price: 15, level: 2, category: "buildings", stages: [BUILDING, "art:doghouse"], days: [0, 1], houses: { group: "dog", capacity: 1 } },
  { id: "coop", price: 20, level: 2, category: "buildings", stages: [BUILDING, "art:coop"], days: [0, 1], houses: { group: "chicken", capacity: 4 } },
  { id: "house", price: 30, level: 3, category: "buildings", stages: ["🏡"], days: [0], houses: { group: "cat", capacity: 2 } },
  { id: "pond", price: 25, level: 3, category: "buildings", stages: [BUILDING, "art:pond"], days: [0, 1], size: [2, 1], houses: { group: "duck", capacity: 3 } },
  { id: "barn", price: 40, level: 4, category: "buildings", stages: [BUILDING, "art:barn"], days: [0, 2], size: [2, 2], houses: { group: "farm", capacity: 4 } },
  { id: "beehive", price: 25, level: 5, category: "buildings", stages: [BUILDING, "art:beehive"], days: [0, 1], produce: "honey" },
  { id: "farmhouse", price: 60, level: 6, category: "buildings", stages: [BUILDING, "art:farmhouse"], days: [0, 3], size: [2, 2], houses: { group: "cat", capacity: 2 } },
  { id: "windmill", price: 50, level: 7, category: "buildings", stages: [BUILDING, "art:windmill"], days: [0, 2], size: [1, 2] },
  // Roads, paths and fences are free, so children can lay out their farm.
  { id: "road", price: 0, level: 1, category: "paths", stages: ["art:road"], days: [0], connects: true },
  { id: "path", price: 0, level: 1, category: "paths", stages: ["art:path"], days: [0], connects: true },
  { id: "fence", price: 0, level: 1, category: "paths", stages: ["art:fence"], days: [0], connects: true },
  // Decorations
  { id: "stone", price: 1, level: 1, category: "decor", stages: ["🪨"], days: [0] },
  { id: "mailbox", price: 3, level: 2, category: "decor", stages: ["📫"], days: [0] },
  { id: "fountain", price: 20, level: 4, category: "decor", stages: ["⛲"], days: [0] },
  { id: "tractor", price: 30, level: 8, category: "decor", stages: ["🚜"], days: [0] },
];

export const gardenItem = (id: string) => GARDEN_ITEMS.find((i) => i.id === id);
export const itemSize = (item: GardenItem): [number, number] => item.size ?? [1, 1];
/** What the shop shows: the finished look. */
export const shopPicture = (item: GardenItem) => item.variants?.[0] ?? item.stages[item.stages.length - 1];

// MARK: Farm levels

/** XP needed for each level: level 2 at 10 XP, level 3 at 30, … then 100 more per level. */
const LEVEL_XP = [0, 10, 30, 60, 100, 150, 210, 280, 360, 450];
export const levelStartXp = (level: number) => (level <= LEVEL_XP.length ? LEVEL_XP[level - 1] : LEVEL_XP[LEVEL_XP.length - 1] + 100 * (level - LEVEL_XP.length));

export function farmLevel(xp: number): { level: number; xpInLevel: number; xpForNext: number } {
  let level = 1;
  while (xp >= levelStartXp(level + 1)) level++;
  return { level, xpInLevel: xp - levelStartXp(level), xpForNext: levelStartXp(level + 1) - levelStartXp(level) };
}

/** Items a new level unlocks (for the celebration). */
export const unlockedAt = (level: number) => GARDEN_ITEMS.filter((i) => i.level === level);

export const XP_FOR_COLLECTING = 3;

/** XP for farms built before levels existed: what was spent on them. */
export function startingFarmXp(garden: Garden): number {
  const items = garden.reduce((sum, plot) => sum + (plot ? gardenItem(plot.itemId)?.price ?? 0 : 0), 0);
  const land = LAND_PRICES.slice(0, (gardenRows(garden) - GARDEN_START_ROWS) / LAND_ROWS_PER_PURCHASE).reduce((a, b) => a + b, 0);
  return items + land;
}

const withXp = (p: Profile, xp: number): Profile => ({ ...p, farmXp: p.farmXp + xp });

// MARK: Land

/** Wider than a screen: the garden scrolls. */
export const GARDEN_COLUMNS = 16;
export const GARDEN_START_ROWS = 8;
export const GARDEN_SIZE = GARDEN_COLUMNS * GARDEN_START_ROWS;
/** Each purchase adds four rows. */
export const LAND_ROWS_PER_PURCHASE = 4;
export const LAND_PRICES = [25, 40, 60];

/** Gardens saved before the farm was widened were 6 columns wide, 4 rows plus 2 per land purchase. */
export const LEGACY_COLUMNS = 6;
const LEGACY_START_ROWS = 4;
const LEGACY_ROWS_PER_PURCHASE = 2;

/**
 * Moves an old 6-column garden into the wide one: everything keeps its row and
 * column, and each piece of land bought earlier still counts as one purchase.
 */
export function widenGarden(old: Garden): Garden {
  const oldRows = Math.ceil(old.length / LEGACY_COLUMNS);
  const purchases = Math.max(0, Math.ceil((oldRows - LEGACY_START_ROWS) / LEGACY_ROWS_PER_PURCHASE));
  const rows = GARDEN_START_ROWS + Math.min(purchases, LAND_PRICES.length) * LAND_ROWS_PER_PURCHASE;
  const garden: Garden = Array.from({ length: rows * GARDEN_COLUMNS }, () => null);
  old.forEach((plot, i) => {
    if (plot) garden[Math.floor(i / LEGACY_COLUMNS) * GARDEN_COLUMNS + (i % LEGACY_COLUMNS)] = plot;
  });
  return garden;
}

export interface GardenPlot {
  itemId: string;
  plantedDay: string;
  variant?: string;
  /** Last day the daily gift (egg, milk, honey, apples) was collected. */
  collectedDay?: string;
}
export type Garden = (GardenPlot | null)[];

export const emptyGarden = (): Garden => Array.from({ length: GARDEN_SIZE }, () => null);
export const gardenRows = (garden: Garden) => Math.ceil(garden.length / GARDEN_COLUMNS);

/** Price of the next piece of land, or undefined when the garden is as big as it gets. */
export function nextLandPrice(garden: Garden): number | undefined {
  return LAND_PRICES[(gardenRows(garden) - GARDEN_START_ROWS) / LAND_ROWS_PER_PURCHASE];
}

export function buyLand(p: Profile): Profile {
  const price = nextLandPrice(p.garden);
  if (price === undefined || p.walletStars < price) return p;
  const extra: Garden = Array.from({ length: GARDEN_COLUMNS * LAND_ROWS_PER_PURCHASE }, () => null);
  return withXp({ ...p, walletStars: p.walletStars - price, garden: [...p.garden, ...extra] }, price);
}

// MARK: Time

const daysSince = (from: string, now: Date) => {
  const utc = (k: string) => { const [y, m, d] = k.split("-").map(Number); return Date.UTC(y, m - 1, d); };
  return Math.round((utc(dayKey(now)) - utc(from)) / 86_400_000);
};

function stageIndex(item: GardenItem, plot: GardenPlot, now: Date): number {
  const age = daysSince(plot.plantedDay, now);
  let stage = 0;
  item.days.forEach((d, i) => { if (age >= d) stage = i; });
  return stage;
}

const isGrown = (item: GardenItem, plot: GardenPlot, now: Date) => stageIndex(item, plot, now) === item.stages.length - 1;

/** The picture a plot shows today: an emoji, or "art:<id>" for a drawn one. */
export function plotPicture(plot: GardenPlot, now: Date): string {
  const item = gardenItem(plot.itemId);
  if (!item) return "";
  const stage = stageIndex(item, plot, now);
  return stage === item.stages.length - 1 && plot.variant ? plot.variant : item.stages[stage];
}

/** Days until the next stage (growing, or a building being finished), or undefined when done. */
export function daysUntilNextStage(plot: GardenPlot, now: Date): number | undefined {
  const item = gardenItem(plot.itemId);
  if (!item) return undefined;
  const age = daysSince(plot.plantedDay, now);
  const next = item.days.find((d) => d > age);
  return next === undefined ? undefined : next - age;
}

export const isUnderConstruction = (plot: GardenPlot, now: Date) => plotPicture(plot, now) === BUILDING;

// MARK: Layout

/** For each cell, the index of the item covering it (an item's top-left cell is its anchor). */
export function occupancy(garden: Garden): (number | undefined)[] {
  const covered: (number | undefined)[] = garden.map(() => undefined);
  garden.forEach((plot, anchor) => {
    const item = plot && gardenItem(plot.itemId);
    if (!item) return;
    const [w, h] = itemSize(item);
    const col = anchor % GARDEN_COLUMNS, row = Math.floor(anchor / GARDEN_COLUMNS);
    for (let r = row; r < row + h; r++) for (let c = col; c < col + w; c++) covered[r * GARDEN_COLUMNS + c] = anchor;
  });
  return covered;
}

/** Where a big item goes when this cell is tapped: shifted left/up so it fits the grid. */
export function anchorFor(garden: Garden, cell: number, item: GardenItem): number {
  const [w, h] = itemSize(item);
  const col = Math.min(cell % GARDEN_COLUMNS, GARDEN_COLUMNS - w);
  const row = Math.min(Math.floor(cell / GARDEN_COLUMNS), gardenRows(garden) - h);
  return row * GARDEN_COLUMNS + col;
}

function fits(garden: Garden, anchor: number, item: GardenItem, ignore?: number): boolean {
  const [w, h] = itemSize(item);
  const covered = occupancy(garden);
  const col = anchor % GARDEN_COLUMNS, row = Math.floor(anchor / GARDEN_COLUMNS);
  if (anchor < 0 || col + w > GARDEN_COLUMNS || row + h > gardenRows(garden)) return false;
  for (let r = row; r < row + h; r++) {
    for (let c = col; c < col + w; c++) {
      const owner = covered[r * GARDEN_COLUMNS + c];
      if (owner !== undefined && owner !== ignore) return false;
    }
  }
  return true;
}

/** Which neighbours (up, right, down, left) hold the same road, path or fence. */
export function connections(garden: Garden, cell: number): { n: boolean; e: boolean; s: boolean; w: boolean } {
  const id = garden[cell]?.itemId;
  const same = (i: number) => i >= 0 && i < garden.length && garden[i]?.itemId === id;
  const col = cell % GARDEN_COLUMNS;
  return {
    n: same(cell - GARDEN_COLUMNS),
    s: same(cell + GARDEN_COLUMNS),
    w: col > 0 && same(cell - 1),
    e: col < GARDEN_COLUMNS - 1 && same(cell + 1),
  };
}

// MARK: Homes

/** Places for this kind of animal in finished homes, and how many are taken. */
export function homeSpace(garden: Garden, group: HomeGroup, now: Date): { capacity: number; used: number } {
  let capacity = 0, used = 0;
  for (const plot of garden) {
    const item = plot && gardenItem(plot.itemId);
    if (!item) continue;
    if (item.houses?.group === group && isGrown(item, plot, now)) capacity += item.houses.capacity;
    if (item.needs === group) used += 1;
  }
  return { capacity, used };
}

/** Which building an animal needs (for "first build a …"). */
export const homeFor = (group: HomeGroup) => GARDEN_ITEMS.find((i) => i.houses?.group === group && i.id !== "farmhouse")!;

export type PlacementProblem = "level" | "stars" | "space" | "home" | "full";

export function placementProblem(p: Profile, cell: number, itemId: string, now: Date): PlacementProblem | undefined {
  const item = gardenItem(itemId);
  if (!item) return "stars";
  if (farmLevel(p.farmXp).level < item.level) return "level";
  if (p.walletStars < item.price) return "stars";
  if (item.needs) {
    const { capacity, used } = homeSpace(p.garden, item.needs, now);
    if (capacity === 0) return "home";
    if (used >= capacity) return "full";
  }
  if (!fits(p.garden, anchorFor(p.garden, cell, item), item)) return "space";
  return undefined;
}

/** Places an item (paid from the wallet); every star spent on the farm is one XP. */
export function placeInGarden(p: Profile, cell: number, itemId: string, now: Date, rng: Rng): Profile {
  const item = gardenItem(itemId);
  if (!item || cell < 0 || cell >= p.garden.length || placementProblem(p, cell, itemId, now)) return p;
  const garden = [...p.garden];
  garden[anchorFor(p.garden, cell, item)] = {
    itemId, plantedDay: dayKey(now), variant: item.variants ? randomElement(rng, item.variants) : undefined,
  };
  return withXp({ ...p, walletStars: p.walletStars - item.price, garden }, item.price);
}

/** Moves whatever covers `from` so that `to` is its new top-left corner (shifted to fit). Keeps its age. */
export function moveItem(p: Profile, from: number, to: number): Profile {
  const anchor = occupancy(p.garden)[from];
  const plot = anchor === undefined ? undefined : p.garden[anchor];
  const item = plot && gardenItem(plot.itemId);
  if (!plot || !item || anchor === undefined) return p;
  const target = anchorFor(p.garden, to, item);
  if (target === anchor || !fits(p.garden, target, item, anchor)) return p;
  const garden = [...p.garden];
  garden[anchor] = null;
  garden[target] = plot;
  return { ...p, garden };
}

/** A home can only be cleared if its animals still have room elsewhere. */
export function canClear(p: Profile, cell: number, now: Date): boolean {
  const anchor = occupancy(p.garden)[cell];
  if (anchor === undefined) return false;
  const plot = p.garden[anchor]!;
  const item = gardenItem(plot.itemId);
  if (!item?.houses || !isGrown(item, plot, now)) return true;
  const { capacity, used } = homeSpace(p.garden, item.houses.group, now);
  return used <= capacity - item.houses.capacity;
}

/** Clears whatever covers this cell (no refund, like real gardening). */
export function clearPlot(p: Profile, cell: number, now = new Date()): Profile {
  const anchor = occupancy(p.garden)[cell];
  if (anchor === undefined || !canClear(p, cell, now)) return p;
  const garden = [...p.garden];
  garden[anchor] = null;
  return { ...p, garden };
}

// MARK: Harvest and daily gifts

/**
 * What a plot has ready: grown crops can be harvested (then they grow again);
 * hens, cows, bees and apple trees give something once a day, from the day
 * after they arrived.
 */
export function readyProduce(plot: GardenPlot, now: Date): Produce | undefined {
  const item = gardenItem(plot.itemId);
  if (!item || !isGrown(item, plot, now)) return undefined;
  if (item.harvest) return item.harvest;
  if (!item.produce || daysSince(plot.plantedDay, now) < 1) return undefined;
  return plot.collectedDay === dayKey(now) ? undefined : item.produce;
}

export function collectProduce(p: Profile, cell: number, now: Date): Profile {
  const anchor = occupancy(p.garden)[cell];
  const plot = anchor === undefined ? undefined : p.garden[anchor];
  const produce = plot && readyProduce(plot, now);
  if (!plot || !produce || anchor === undefined) return p;
  const garden = [...p.garden];
  const harvested = gardenItem(plot.itemId)?.harvest;
  // A harvested crop starts growing again; other gifts wait for tomorrow.
  garden[anchor] = harvested ? { ...plot, plantedDay: dayKey(now) } : { ...plot, collectedDay: dayKey(now) };
  return withXp({ ...p, garden, farmGoods: { ...p.farmGoods, [produce]: (p.farmGoods[produce] ?? 0) + 1 } }, XP_FOR_COLLECTING);
}

/** Every cell with something ready, one per item. */
export function readyCells(garden: Garden, now: Date): number[] {
  return garden.flatMap((plot, i) => (plot && readyProduce(plot, now) ? [i] : []));
}

export const goodsCount = (goods: Partial<Record<Produce, number>>) => PRODUCE.reduce((sum, k) => sum + (goods[k] ?? 0), 0);

/** The farm shop buys goods in fives: 5 → 1 ⭐ (spendable only; lifetime stars stay learning stars). */
export const GOODS_PER_STAR = 5;

export function sellGoods(p: Profile): Profile {
  const stars = Math.floor(goodsCount(p.farmGoods) / GOODS_PER_STAR);
  if (stars === 0) return p;
  let toSell = stars * GOODS_PER_STAR;
  const farmGoods = { ...emptyGoods(), ...p.farmGoods };
  for (const kind of PRODUCE) {
    const sold = Math.min(farmGoods[kind], toSell);
    farmGoods[kind] -= sold;
    toSell -= sold;
  }
  return { ...p, walletStars: p.walletStars + stars, farmGoods };
}

// MARK: Orders

export interface FarmOrder {
  id: string;
  wants: Partial<Record<Produce, number>>;
  stars: number;
  xp: number;
  done?: boolean;
}

/** Goods this farm can make: from what's on it, grown or not. */
export function producibleGoods(garden: Garden): Produce[] {
  const kinds = new Set<Produce>();
  for (const plot of garden) {
    const item = plot && gardenItem(plot.itemId);
    const kind = item?.produce ?? item?.harvest;
    if (kind) kinds.add(kind);
  }
  return PRODUCE.filter((k) => kinds.has(k));
}

const hash = (s: string) => [...s].reduce((h, ch) => (Math.imul(h, 31) + ch.charCodeAt(0)) | 0, 7);

/**
 * Three orders a day, for goods this farm can make. They pay better than the
 * farm shop: about 1 ⭐ for every 3 goods, plus XP. Made once per day.
 */
export function withTodaysOrders(p: Profile, now: Date): Profile {
  const today = dayKey(now);
  const kinds = producibleGoods(p.garden);
  const current = p.farmOrders;
  if (current?.day === today && (current.orders.length > 0 || kinds.length === 0)) return p;
  const rng = seededRng(hash(`${p.id}:${today}`));
  const big = farmLevel(p.farmXp).level >= 5 ? 1 : 0;
  const orders: FarmOrder[] = kinds.length === 0 ? [] : Array.from({ length: 3 }, (_, i) => {
    const picked = shuffled(rng, kinds).slice(0, kinds.length > 1 && rng() < 0.5 ? 2 : 1);
    const wants: Partial<Record<Produce, number>> = {};
    for (const kind of picked) wants[kind] = randomInt(rng, 2, 3 + big);
    const total = goodsCount(wants);
    return { id: `${today}-${i}`, wants, stars: 1 + Math.floor(total / 3), xp: total * 3 };
  });
  return { ...p, farmOrders: { day: today, orders } };
}

export function canFulfil(p: Profile, order: FarmOrder): boolean {
  return !order.done && PRODUCE.every((k) => (p.farmGoods[k] ?? 0) >= (order.wants[k] ?? 0));
}

export function fulfilOrder(p: Profile, orderId: string): Profile {
  const order = p.farmOrders?.orders.find((o) => o.id === orderId);
  if (!order || !p.farmOrders || !canFulfil(p, order)) return p;
  const farmGoods = { ...emptyGoods(), ...p.farmGoods };
  for (const k of PRODUCE) farmGoods[k] -= order.wants[k] ?? 0;
  const orders = p.farmOrders.orders.map((o) => (o.id === orderId ? { ...o, done: true } : o));
  return withXp({ ...p, farmGoods, walletStars: p.walletStars + order.stars, farmOrders: { ...p.farmOrders, orders } }, order.xp);
}
