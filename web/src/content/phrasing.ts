import type { PhrasingTemplates } from "./types";

/** Learning-language phrasing with {placeholder} slots (Content/<lang>/strings.json). */
export class Phrasing {
  constructor(readonly templates: PhrasingTemplates) {}

  text(key: string, values: Record<string, string | number> = {}): string {
    let result = this.templates[key];
    if (result === undefined) {
      console.warn(`Missing phrasing key '${key}'`);
      return key;
    }
    for (const [name, value] of Object.entries(values)) {
      result = result.replaceAll(`{${name}}`, String(value));
    }
    return result;
  }
}
