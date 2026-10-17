/** Drawn farm buildings (there are no emoji for a barn or a chicken coop). */
export function FarmArt({ id }: { id: string }) {
  switch (id) {
    case "barn":
      return (
        <svg viewBox="0 0 100 100" class="farm-art" aria-hidden="true">
          <path d="M12 46 L50 14 L88 46 V94 H12 Z" fill="#C8433A" />
          <path d="M6 49 L50 11 L94 49" fill="none" stroke="#7A2A24" stroke-width="7" stroke-linejoin="round" stroke-linecap="round" />
          <rect x="35" y="58" width="30" height="36" fill="#F4E9D8" />
          <path d="M38 61 L62 91 M62 61 L38 91" stroke="#C8433A" stroke-width="4" />
          <rect x="42" y="30" width="16" height="14" rx="2" fill="#F4E9D8" />
          <path d="M50 30 V44" stroke="#C8433A" stroke-width="3" />
        </svg>
      );
    case "farmhouse":
      return (
        <svg viewBox="0 0 100 100" class="farm-art" aria-hidden="true">
          <rect x="66" y="16" width="10" height="20" fill="#8A5A3C" />
          <rect x="16" y="46" width="68" height="48" fill="#F6E7C8" />
          <path d="M8 50 L50 14 L92 50 Z" fill="#B5542F" />
          <rect x="44" y="66" width="14" height="28" rx="2" fill="#8A5A3C" />
          <rect x="24" y="58" width="13" height="13" fill="#7EC8F0" stroke="#fff" stroke-width="2" />
          <rect x="64" y="58" width="13" height="13" fill="#7EC8F0" stroke="#fff" stroke-width="2" />
          <path d="M20 94 H84" stroke="#5DAA4F" stroke-width="5" />
        </svg>
      );
    case "coop":
      return (
        <svg viewBox="0 0 100 100" class="farm-art" aria-hidden="true">
          <path d="M18 50 L50 22 L82 50 V88 H18 Z" fill="#D9A55B" />
          <path d="M12 53 L50 19 L88 53" fill="none" stroke="#8A5A3C" stroke-width="7" stroke-linejoin="round" stroke-linecap="round" />
          <path d="M18 62 H82 M18 75 H82" stroke="#B9843E" stroke-width="2" />
          <circle cx="50" cy="62" r="10" fill="#5A3A22" />
          <path d="M40 88 L60 72" stroke="#8A5A3C" stroke-width="5" stroke-linecap="round" />
        </svg>
      );
    case "doghouse":
      return (
        <svg viewBox="0 0 100 100" class="farm-art" aria-hidden="true">
          <path d="M20 50 L50 24 L80 50 V88 H20 Z" fill="#4E8FD6" />
          <path d="M14 53 L50 21 L86 53" fill="none" stroke="#2C5E99" stroke-width="7" stroke-linejoin="round" stroke-linecap="round" />
          <path d="M38 88 V68 A12 12 0 0 1 62 68 V88 Z" fill="#23324A" />
          <rect x="40" y="38" width="20" height="8" rx="3" fill="#FFF3D6" />
        </svg>
      );
    case "pond":
      return (
        <svg viewBox="0 0 200 100" class="farm-art" aria-hidden="true">
          <ellipse cx="100" cy="56" rx="92" ry="38" fill="#8AD0F5" />
          <ellipse cx="100" cy="58" rx="80" ry="30" fill="#4FAEE8" />
          <path d="M60 52 Q75 46 90 52 M110 66 Q125 60 140 66" stroke="#BDE6FA" stroke-width="4" fill="none" stroke-linecap="round" />
          <path d="M22 50 V26 M30 52 V20 M178 52 V24" stroke="#4E9A3C" stroke-width="5" stroke-linecap="round" />
          <ellipse cx="30" cy="22" rx="4" ry="9" fill="#8A5A3C" />
          <ellipse cx="178" cy="24" rx="4" ry="9" fill="#8A5A3C" />
        </svg>
      );
    case "fence":
      return (
        <svg viewBox="0 0 100 100" class="farm-art" aria-hidden="true">
          <path d="M8 44 H92 M8 68 H92" stroke="#B07A4A" stroke-width="8" stroke-linecap="round" />
          {[18, 50, 82].map((x) => <path key={x} d={`M${x - 7} 88 V34 L${x} 24 L${x + 7} 34 V88 Z`} fill="#8A5A3C" />)}
        </svg>
      );
    default:
      return null;
  }
}

/** An emoji, or a drawn building for "art:<id>". */
export function GardenPicture({ picture }: { picture: string }) {
  return picture.startsWith("art:") ? <FarmArt id={picture.slice(4)} /> : <>{picture}</>;
}
