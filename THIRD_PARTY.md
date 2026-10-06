# Bundled rendering components

The read-only native context pane uses these browser distributions offline:

| Component | Version | License | Upstream |
| --- | --- | --- | --- |
| markdown-it | 15.0.2 | MIT | https://github.com/markdown-it/markdown-it |
| KaTeX (including distributed fonts) | 0.19.0 | MIT | https://github.com/KaTeX/KaTeX |

The markdown-it browser bundle also includes these dependencies; their original license texts are retained under `macos/assets/vendor/markdown-it/notices/`:

| Bundled dependency | Version | License |
| --- | --- | --- |
| mdurl | 2.1.0 | MIT |
| uc.micro | 3.0.0 | MIT |
| entities | 8.0.0 | BSD-2-Clause |
| linkify-it | 6.0.0 | MIT |
| punycode.js | 2.3.1 | MIT |

The additional font-source MIT notice from https://github.com/KaTeX/katex-fonts is retained in `macos/assets/vendor/katex/FONT-LICENSE`.

Original license text is retained under `macos/assets/vendor/`. `manifest.json` records npm registry package integrity and SHA-256 hashes of the files. The markdown-it browser UMD distribution is named `markdown-it.min.js` locally; distribution files are otherwise unchanged. KaTeX CSS, JavaScript and all referenced WOFF2/WOFF/TTF fonts are bundled. No CDN, package-install script or runtime download is required.

To update a renderer, fetch the exact npm package, retain its license, refresh the manifest and run both `npm test` and `npm run test:native`. Untrusted context HTML is disabled, remote images are not loaded, KaTeX trust is disabled and navigation is restricted to explicitly clicked HTTP(S) links.
