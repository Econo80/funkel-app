// Saves profiles on this device only (IndexedDB). Nothing leaves the device.
import { normalizeProfile, type Profile } from "../domain/profile";

const DB_NAME = "funkel";
const DB_VERSION = 1;
const PROFILES = "profiles";
const META = "meta";

let dbPromise: Promise<IDBDatabase> | undefined;

function db(): Promise<IDBDatabase> {
  dbPromise ??= new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const database = request.result;
      if (!database.objectStoreNames.contains(PROFILES)) database.createObjectStore(PROFILES, { keyPath: "id" });
      if (!database.objectStoreNames.contains(META)) database.createObjectStore(META);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  return dbPromise;
}

async function run<T>(store: string, mode: IDBTransactionMode, action: (s: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  const database = await db();
  return new Promise((resolve, reject) => {
    const request = action(database.transaction(store, mode).objectStore(store));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function loadProfiles(): Promise<Profile[]> {
  const stored = await run<Profile[]>(PROFILES, "readonly", (s) => s.getAll());
  return stored.map(normalizeProfile).sort((a, b) => a.createdAt.localeCompare(b.createdAt));
}

export async function saveProfile(profile: Profile): Promise<void> {
  // Structured clone: strip anything non-serialisable (Preact state proxies etc.).
  await run(PROFILES, "readwrite", (s) => s.put(JSON.parse(JSON.stringify(profile))));
}

export async function deleteProfile(id: string): Promise<void> {
  await run(PROFILES, "readwrite", (s) => s.delete(id));
}

export async function getMeta<T>(key: string): Promise<T | undefined> {
  return run<T | undefined>(META, "readonly", (s) => s.get(key));
}

export async function setMeta(key: string, value: unknown): Promise<void> {
  await run(META, "readwrite", (s) => s.put(value, key));
}

/** Asks the browser not to clear our data under storage pressure. */
export async function requestPersistence(): Promise<void> {
  try {
    await navigator.storage?.persist?.();
  } catch {
    // Not supported everywhere; data is still stored, just not guaranteed.
  }
}
