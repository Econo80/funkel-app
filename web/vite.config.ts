import { createHash } from "node:crypto";
import { readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { defineConfig, type Plugin } from "vite";

/**
 * Writes dist/sw.js after the build: a service worker that pre-caches every
 * built file (app, content, icons) so Funkel works offline after the first
 * visit. The cache name is a hash of the files, so a new deploy replaces it.
 */
function offlineServiceWorker(): Plugin {
  let outDir = "dist";
  return {
    name: "funkel-offline-sw",
    apply: "build",
    configResolved(config) {
      outDir = config.build.outDir;
    },
    closeBundle() {
      const files: string[] = [];
      const walk = (dir: string) => {
        for (const name of readdirSync(dir)) {
          const path = join(dir, name);
          if (statSync(path).isDirectory()) walk(path);
          else if (name !== "sw.js" && !name.endsWith(".map")) files.push(path);
        }
      };
      walk(outDir);
      const hash = createHash("sha256");
      for (const file of files.sort()) hash.update(file).update(readFileSync(file));
      const urls = ["./", ...files.map((f) => "./" + relative(outDir, f).split(sep).join("/"))];
      const sw = readFileSync("src/sw-template.js", "utf8")
        .replace("__CACHE_NAME__", `funkel-${hash.digest("hex").slice(0, 12)}`)
        .replace("__PRECACHE__", JSON.stringify(urls, null, 2));
      writeFileSync(join(outDir, "sw.js"), sw);
      console.log(`sw.js: ${urls.length} files pre-cached for offline use`);
    },
  };
}

export default defineConfig({
  // Relative paths: works at the site root (Netlify) and in sub-folders.
  base: "./",
  esbuild: { jsx: "automatic", jsxImportSource: "preact" },
  plugins: [offlineServiceWorker()],
  build: { target: "es2020", sourcemap: false },
  test: { include: ["tests/**/*.test.ts"] },
} as never);
