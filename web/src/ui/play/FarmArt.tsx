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
    case "beehive":
      return (
        <svg viewBox="0 0 100 100" class="farm-art" aria-hidden="true">
          <rect x="44" y="78" width="12" height="16" fill="#8A5A3C" />
          <path d="M22 80 Q20 40 50 22 Q80 40 78 80 Z" fill="#F2B640" />
          {[36, 48, 60, 72].map((y) => <path key={y} d={`M${24 + (80 - y) * 0.1} ${y} Q50 ${y + 6} ${76 - (80 - y) * 0.1} ${y}`} stroke="#C98A1E" stroke-width="3" fill="none" />)}
          <path d="M42 80 A8 8 0 0 1 58 80 Z" fill="#5A3A22" />
          <circle cx="76" cy="30" r="4" fill="#FFD43B" /><path d="M72 27 L68 23 M80 27 L84 23" stroke="#5A3A22" stroke-width="2" />
        </svg>
      );
    case "windmill":
      return (
        <svg viewBox="0 0 100 200" class="farm-art tall" aria-hidden="true">
          <path d="M34 196 L42 80 H58 L66 196 Z" fill="#F3E3C3" />
          <path d="M34 196 L42 80 H58 L66 196 Z" fill="none" stroke="#C9AE80" stroke-width="2" />
          <path d="M38 84 L50 64 L62 84 Z" fill="#B5542F" />
          <rect x="44" y="160" width="12" height="36" rx="6" fill="#8A5A3C" />
          <rect x="45" y="110" width="10" height="12" fill="#7EC8F0" stroke="#fff" stroke-width="2" />
          <g class="windmill-blades">
            {[0, 90, 180, 270].map((a) => (
              <g key={a} transform={`rotate(${a} 50 72)`}>
                <rect x="47" y="22" width="6" height="50" fill="#8A5A3C" />
                <rect x="53" y="24" width="14" height="40" fill="#FFF8EA" stroke="#C9AE80" stroke-width="2" />
              </g>
            ))}
            <circle cx="50" cy="72" r="6" fill="#5A3A22" />
          </g>
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

type Links = { n: boolean; e: boolean; s: boolean; w: boolean };

/**
 * Roads, footpaths and fences drawn to join their neighbours: straight pieces,
 * corners, T-junctions and crossings all come from the same four "arms".
 * A piece on its own lies left to right.
 */
export function PathArt({ id, links }: { id: string; links: Links }) {
  const l = links.n || links.e || links.s || links.w ? links : { n: false, e: true, s: false, w: true };
  if (id === "fence") {
    const rails = (y: number) => <path d={`M${l.w ? 0 : 50} ${y} H${l.e ? 100 : 50} M${50 - (y - 50)} ${l.n ? 0 : 50} V${l.s ? 100 : 50}`} />;
    return (
      <svg viewBox="0 0 100 100" class="path-art" preserveAspectRatio="none" aria-hidden="true">
        <g stroke="#B07A4A" stroke-width="7" stroke-linecap="square" fill="none">{rails(40)}{rails(62)}</g>
        <path d="M43 80 V30 L50 22 L57 30 V80 Z" fill="#8A5A3C" />
      </svg>
    );
  }
  const road = id === "road";
  const [a, b] = road ? [20, 80] : [32, 68];
  const arms = [
    l.n && `M${a} 0 H${b} V50 H${a} Z`,
    l.s && `M${a} 50 H${b} V100 H${a} Z`,
    l.w && `M0 ${a} H50 V${b} H0 Z`,
    l.e && `M50 ${a} H100 V${b} H50 Z`,
  ].filter(Boolean).join(" ");
  const dashes = [l.n && "M50 4 V36", l.s && "M50 64 V96", l.w && "M4 50 H36", l.e && "M64 50 H96"].filter(Boolean).join(" ");
  return (
    <svg viewBox="0 0 100 100" class="path-art" preserveAspectRatio="none" aria-hidden="true">
      <path d={`${arms} M${a} ${a} H${b} V${b} H${a} Z`} fill={road ? "#6E737B" : "#E6CC9C"} />
      {road ? <path d={dashes} stroke="#F4F1E8" stroke-width="4" stroke-dasharray="10 8" fill="none" />
        : <g fill="#C9A86E"><circle cx="42" cy="44" r="3" /><circle cx="58" cy="57" r="2.5" /><circle cx="47" cy="60" r="2" /></g>}
    </svg>
  );
}

/** An emoji, or a drawn building for "art:<id>". */
export function GardenPicture({ picture }: { picture: string }) {
  return picture.startsWith("art:") ? <FarmArt id={picture.slice(4)} /> : <>{picture}</>;
}
