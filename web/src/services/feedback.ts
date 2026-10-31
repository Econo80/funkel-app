// Read-aloud (Web Speech API), synthesised sounds (Web Audio) and vibration.
// All on-device; nothing is downloaded or sent anywhere.

// MARK: Read-aloud

function voiceFor(locale: string): SpeechSynthesisVoice | undefined {
  const voices = speechSynthesis.getVoices();
  const language = locale.split(/[-_]/)[0];
  return (
    voices.find((v) => v.lang.replace("_", "-") === locale) ??
    voices.find((v) => v.lang.toLowerCase().startsWith(language))
  );
}

let audio: AudioContext | undefined;
let speechUnlocked = false;

/** What the last attempt to speak reported (shown by "Vorlesen testen" in the grown-up area). */
export interface SpeechStatus { supported: boolean; voices: number; germanVoices: number; started: boolean; error?: string }
let lastStarted = false;
let lastError: string | undefined;

export function speechStatus(): SpeechStatus {
  if (!("speechSynthesis" in window)) return { supported: false, voices: 0, germanVoices: 0, started: false };
  const voices = speechSynthesis.getVoices();
  return { supported: true, voices: voices.length, germanVoices: voices.filter((v) => v.lang.toLowerCase().startsWith("de")).length, started: lastStarted, error: lastError };
}

/**
 * iPhone/iPad: treat Funkel's sound like media playback, so it isn't silenced
 * and the audio session doesn't get stuck in web apps on the home screen
 * (an iOS 26 problem). Safari 16.4+; ignored elsewhere.
 */
function useMediaAudioSession(): void {
  const session = (navigator as Navigator & { audioSession?: { type: string } }).audioSession;
  if (session && session.type !== "playback") {
    try { session.type = "playback"; } catch { /* not allowed here */ }
  }
}

/**
 * Safari on iPhone/iPad only lets a page speak once speech has been started
 * from a tap, and only a finished tap counts (touchend/click, not the first
 * touch). Questions are read automatically a moment *after* a tap (once they
 * are loaded), so the first tap starts a silent utterance that unlocks speech,
 * and wakes sounds, for the rest of the visit.
 */
export function installSpeechUnlock(): void {
  useMediaAudioSession();
  if (!("speechSynthesis" in window)) return;
  const events = ["touchend", "click", "keydown"] as const;
  const unlock = () => {
    useMediaAudioSession();
    if (audio?.state === "suspended") void audio.resume();
    if (speechUnlocked) return;
    speechUnlocked = true;
    const silent = new SpeechSynthesisUtterance(" ");
    silent.volume = 0;
    speechSynthesis.speak(silent);
  };
  // Kept for the whole visit: iOS can suspend audio again after the app was in the background.
  for (const e of events) window.addEventListener(e, unlock, true);
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") speechUnlocked = false;
  });
  // Voices load in the background; asking once makes them ready sooner.
  speechSynthesis.getVoices();
}

let pending: ReturnType<typeof setTimeout> | undefined;

export function speak(text: string, locale: string): void {
  if (!("speechSynthesis" in window) || !text) return;
  useMediaAudioSession();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = locale;
  const voice = voiceFor(locale);
  if (voice) utterance.voice = voice;
  utterance.rate = 0.9; // a little slower, for young listeners
  lastStarted = false;
  lastError = undefined;
  utterance.onstart = () => { lastStarted = true; };
  utterance.onerror = (e) => { lastError = (e as SpeechSynthesisErrorEvent).error ?? "error"; };

  // After the app was in the background, iOS can leave speech paused.
  if (speechSynthesis.paused) speechSynthesis.resume();
  clearTimeout(pending);
  if (speechSynthesis.speaking || speechSynthesis.pending) {
    // Safari sometimes drops a new utterance spoken right after cancel(); give it a moment.
    speechSynthesis.cancel();
    pending = setTimeout(() => speechSynthesis.speak(utterance), 80);
  } else {
    speechSynthesis.speak(utterance);
  }
}

export function stopSpeaking(): void {
  clearTimeout(pending);
  if ("speechSynthesis" in window) speechSynthesis.cancel();
}

// MARK: Sounds (same notes as the iOS app's SoundService)

export type Effect = "correct" | "gentle" | "finish" | "pop";

interface Note { frequency: number; start: number; duration: number; volume: number }

export const NOTES: Record<Effect, Note[]> = {
  correct: [
    { frequency: 1046.5, start: 0, duration: 0.22, volume: 0.22 },
    { frequency: 1318.5, start: 0.08, duration: 0.22, volume: 0.22 },
    { frequency: 1568.0, start: 0.16, duration: 0.35, volume: 0.24 },
  ],
  gentle: [
    { frequency: 392.0, start: 0, duration: 0.22, volume: 0.14 },
    { frequency: 329.6, start: 0.14, duration: 0.32, volume: 0.12 },
  ],
  pop: [
    { frequency: 880, start: 0, duration: 0.09, volume: 0.12 },
    { frequency: 1320, start: 0.03, duration: 0.08, volume: 0.08 },
  ],
  finish: [
    { frequency: 523.3, start: 0, duration: 0.2, volume: 0.2 },
    { frequency: 659.3, start: 0.1, duration: 0.2, volume: 0.2 },
    { frequency: 784.0, start: 0.2, duration: 0.2, volume: 0.2 },
    { frequency: 1046.5, start: 0.3, duration: 0.6, volume: 0.24 },
  ],
};


export function playSound(effect: Effect): void {
  const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!Ctx) return;
  audio ??= new Ctx();
  if (audio.state === "suspended") void audio.resume();
  const now = audio.currentTime + 0.01;
  for (const note of NOTES[effect]) {
    const osc = audio.createOscillator();
    const gain = audio.createGain();
    osc.type = "sine";
    osc.frequency.value = note.frequency;
    const t0 = now + note.start;
    gain.gain.setValueAtTime(0.0001, t0);
    gain.gain.exponentialRampToValueAtTime(note.volume, t0 + 0.008);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + note.duration);
    osc.connect(gain).connect(audio.destination);
    osc.start(t0);
    osc.stop(t0 + note.duration + 0.02);
  }
}

// MARK: Vibration (Android; iPhones ignore it)

export function vibrate(kind: "correct" | "gentle"): void {
  // Browsers only allow vibration after the user has really touched the page.
  const activated = (navigator as Navigator & { userActivation?: { hasBeenActive: boolean } }).userActivation?.hasBeenActive ?? true;
  if (activated) navigator.vibrate?.(kind === "correct" ? [18, 40, 18] : 12);
}

export const prefersReducedMotion = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;
