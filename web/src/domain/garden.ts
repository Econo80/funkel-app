// Pip's garden, which grows into a little farm over days and weeks:
// plants grow, buildings take days to build, animals need a home, hens lay
// eggs and cows give milk once a day, and more land can be bought.
// Everything is paid from the wallet; lifetime stars never change here.
import { dayKey, type Profile } from "./profile";
import { randomElement, type Rng } from "./random";

export type GardenCategory = "plants" | "animals" | "buildings" | "paths" | "decor";
export const GARDEN_CATEGORIES: readonly GardenCategory[] = ["plants", "animals", "buildings", "paths", "decor"];

export type Produce = "egg" | "milk";
export const PRODUCE_EMOJI: Record<Produce, string> = { egg: "🥚", milk: "🥛" };

/** Animals that need a home, by the kind of home. */
export type HomeGroup = "dog" | "cat" | "chicken" | "farm" | "duck";

export interface GardenItem {
  id: string;
  price: number;
  category: GardenCategory;
  /** Picture per stage (emoji, or "art:<id>" for a drawn building); the last one may be a variant. */
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
  /** Grown animals give this once a day. */
  produce?: Produce;
  /** Roads, paths and fences join up with neighbours of the same kind. */
  connects?: boolean;
}

const BUILDING = "🚧";

export const GARDEN_ITEMS: GardenItem[] = [
  // Plants
  { id: "flower", price: 3, category: "plants", stages: ["🌱", "🌿", "🌷"], days: [0, 1, 3], variants: ["🌷", "🌻", "🌼", "🌸", "🌹", "🪻"] },
  { id: "wheat", price: 3, category: "plants", stages: ["🌱", "🌾"], days: [0, 2] },
  { id: "vegetable", price: 4, category: "plants", stages: ["🌱", "🌿", "🥕"], days: [0, 2, 4], variants: ["🥕", "🥬", "🎃", "🍅", "🥔"] },
  { id: "mushroom", price: 2, category: "plants", stages: ["🍄"], days: [0] },
  { id: "tree", price: 12, category: "plants", stages: ["🌱", "🪴", "🌳"], days: [0, 3, 7], variants: ["🌳", "🌲", "🍎"] },
  // Animals: small ones live anywhere; farm animals need their home first.
  { id: "snail", price: 4, category: "animals", stages: ["🐌"], days: [0] },
  { id: "ladybug", price: 5, category: "animals", stages: ["🐞"], days: [0] },
  { id: "butterfly", price: 6, category: "animals", stages: ["🦋"], days: [0] },
  { id: "bee", price: 6, category: "animals", stages: ["🐝"], days: [0] },
  { id: "rabbit", price: 8, category: "animals", stages: ["🐇"], days: [0] },
  { id: "chick", price: 6, category: "animals", stages: ["🐣", "🐥", "🐔"], days: [0, 2, 4], needs: "chicken", produce: "egg" },
  { id: "duck", price: 8, category: "animals", stages: ["🦆"], days: [0], needs: "duck" },
  { id: "cat", price: 12, category: "animals", stages: ["🐈"], days: [0], needs: "cat" },
  { id: "dog", price: 15, category: "animals", stages: ["🐕"], days: [0], needs: "dog" },
  { id: "sheep", price: 15, category: "animals", stages: ["🐑"], days: [0], needs: "farm" },
  { id: "goat", price: 15, category: "animals", stages: ["🐐"], days: [0], needs: "farm" },
  { id: "pig", price: 18, category: "animals", stages: ["🐖"], days: [0], needs: "farm" },
  { id: "cow", price: 25, category: "animals", stages: ["🐄"], days: [0], needs: "farm", produce: "milk" },
  { id: "horse", price: 30, category: "animals", stages: ["🐴"], days: [0], needs: "farm" },
  // Buildings take a few days to build.
  { id: "house", price: 30, category: "buildings", stages: ["🏡"], days: [0], houses: { group: "cat", capacity: 2 } },
  { id: "doghouse", price: 15, category: "buildings", stages: [BUILDING, "art:doghouse"], days: [0, 1], houses: { group: "dog", capacity: 1 } },
  { id: "coop", price: 20, category: "buildings", stages: [BUILDING, "art:coop"], days: [0, 1], houses: { group: "chicken", capacity: 4 } },
  { id: "pond", price: 25, category: "buildings", stages: [BUILDING, "art:pond"], days: [0, 1], size: [2, 1], houses: { group: "duck", capacity: 3 } },
  { id: "barn", price: 40, category: "buildings", stages: [BUILDING, "art:barn"], days: [0, 2], size: [2, 2], houses: { group: "farm", capacity: 4 } },
  { id: "farmhouse", price: 60, category: "buildings", stages: [BUILDING, "art:farmhouse"], days: [0, 3], size: [2, 2], houses: { group: "cat", capacity: 2 } },
  // Roads, paths and fences are free, so children can lay out their farm.
  { id: "road", price: 0, category: "paths", stages: ["art:road"], days: [0], connects: true },
  { id: "path", price: 0, category: "paths", stages: ["art:path"], days: [0], connects: true },
  { id: "fence", price: 0, category: "paths", stages: ["art:fence"], days: [0], connects: true },
  // Decorations
  { id: "stone", price: 1, category: "decor", stages: ["🪨"], days: [0] },
  { id: "mailbox", price: 3, category: "decor", stages: ["📫"], days: [0] },
  { id: "fountain", price: 20, category: "decor", stages: ["⛲"], days: [0] },
];

export const gardenItem = (id: string) => GARDEN_ITEMS.find((i) => i.id === id);
export const itemSize = (item: GardenItem): [number, number] => item.size ?? [1, 1];
/** What the shop shows: the finished look. */
export const shopPicture = (item: GardenItem) => item.variants?.[0] ?? item.stages[item.stages.length - 1];

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
  /** Last day the produce (egg, milk) was collected. */
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
  return { ...p, walletStars: p.walletStars - price, garden: [...p.garden, ...extra] };
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

/** The picture a plot shows today: an emoji, or "art:<id>" for a drawn building. */
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

function fits(garden: Garden, anchor: number, item: GardenItem): boolean {
  const [w, h] = itemSize(item);
  const covered = occupancy(garden);
  const col = anchor % GARDEN_COLUMNS, row = Math.floor(anchor / GARDEN_COLUMNS);
  if (anchor < 0 || col + w > GARDEN_COLUMNS || row + h > gardenRows(garden)) return false;
  for (let r = row; r < row + h; r++) for (let c = col; c < col + w; c++) if (covered[r * GARDEN_COLUMNS + c] !== undefined) return false;
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

export type PlacementProblem = "stars" | "space" | "home" | "full";

export function placementProblem(p: Profile, cell: number, itemId: string, now: Date): PlacementProblem | undefined {
  const item = gardenItem(itemId);
  if (!item || p.walletStars < item.price) return "stars";
  if (item.needs) {
    const { capacity, used } = homeSpace(p.garden, item.needs, now);
    if (capacity === 0) return "home";
    if (used >= capacity) return "full";
  }
  if (!fits(p.garden, anchorFor(p.garden, cell, item), item)) return "space";
  return undefined;
}

export function placeInGarden(p: Profile, cell: number, itemId: string, now: Date, rng: Rng): Profile {
  const item = gardenItem(itemId);
  if (!item || cell < 0 || cell >= p.garden.length || placementProblem(p, cell, itemId, now)) return p;
  const garden = [...p.garden];
  garden[anchorFor(p.garden, cell, item)] = {
    itemId, plantedDay: dayKey(now), variant: item.variants ? randomElement(rng, item.variants) : undefined,
  };
  return { ...p, walletStars: p.walletStars - item.price, garden };
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

// MARK: Eggs and milk

/** Grown hens and cows give something once a day, from the day after they arrived. */
export function readyProduce(plot: GardenPlot, now: Date): Produce | undefined {
  const item = gardenItem(plot.itemId);
  if (!item?.produce || !isGrown(item, plot, now) || daysSince(plot.plantedDay, now) < 1) return undefined;
  return plot.collectedDay === dayKey(now) ? undefined : item.produce;
}

export function collectProduce(p: Profile, cell: number, now: Date): Profile {
  const anchor = occupancy(p.garden)[cell];
  const plot = anchor === undefined ? undefined : p.garden[anchor];
  const produce = plot && readyProduce(plot, now);
  if (!plot || !produce || anchor === undefined) return p;
  const garden = [...p.garden];
  garden[anchor] = { ...plot, collectedDay: dayKey(now) };
  return { ...p, garden, farmGoods: { ...p.farmGoods, [produce]: p.farmGoods[produce] + 1 } };
}

/** The farm shop buys eggs and milk in fives: 5 → 1 ⭐ (spendable only; lifetime stars stay learning stars). */
export const GOODS_PER_STAR = 5;

export function sellGoods(p: Profile): Profile {
  const total = p.farmGoods.egg + p.farmGoods.milk;
  const stars = Math.floor(total / GOODS_PER_STAR);
  if (stars === 0) return p;
  let toSell = stars * GOODS_PER_STAR;
  const egg = Math.min(p.farmGoods.egg, toSell);
  toSell -= egg;
  return { ...p, walletStars: p.walletStars + stars, farmGoods: { egg: p.farmGoods.egg - egg, milk: p.farmGoods.milk - toSell } };
}
