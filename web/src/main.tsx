import { render } from "preact";
import { App } from "./ui/App";
import { ContentLibrary, fetchLoader } from "./content/library";
import { loadUiStrings } from "./services/i18n";
import { loadProfiles, getMeta, requestPersistence } from "./services/storage";
import "./styles.css";

const base = import.meta.env.BASE_URL;

async function start() {
  const root = document.getElementById("app")!;
  try {
    await loadUiStrings(base);
    const [library, profiles, activeId] = await Promise.all([
      ContentLibrary.create(fetchLoader(`${base}Content/`)),
      loadProfiles(),
      getMeta<string>("activeProfileId"),
    ]);
    void requestPersistence();
    render(<App library={library} initialProfiles={profiles} initialActiveId={activeId} />, root);
  } catch (error) {
    console.error(error);
    root.innerHTML = `<p class="fatal">Funkel konnte nicht starten. Bitte die Seite neu laden.</p>`;
  }
}

void start();

// Offline support: cache the app so it works without internet after the first visit.
if ("serviceWorker" in navigator && import.meta.env.PROD) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register(`${base}sw.js`).catch((error) => console.warn("Offline mode unavailable", error));
  });
}
