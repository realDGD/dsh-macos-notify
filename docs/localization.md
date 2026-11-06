# Localization

The plugin follows the official DSH `locale` service: Simplified Chinese (`zh`), English (`en`), Japanese (`ja`), Spanish (`es`), French (`fr`), German (`de`), Russian (`ru`) and Portuguese (`pt`). Regional tags resolve to their supported base language, including `pt-BR` and `pt-PT`; unsupported languages fall back to English. These are the languages exported by the [official locale catalog](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/locale/src/locales/index.ts), checked on 2026-11-06. This adds translations, not a wider DSH compatibility claim; see [compatibility](compatibility.md).

## Terminology

Use DeepSeek's official terminology first. For terms absent from DSH, prefer documented official Codex or Claude Code terminology before inventing a product-specific term. Product names, API identifiers, commands and user-authored content are preserved. Ordinary plugin-specific wording is translated naturally around those terms.

The implemented approval terms come directly from [DeepSeek's approval dictionaries](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/ui-approval/src/client/locales.ts). Session names follow the [sidebar dictionaries](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/ui-sidebar/src/client/locales.ts), subagent names the [subagent dictionaries](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/ui-subagent/src/client/locales.ts), question terminology the [question dictionaries](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/ui-user-questions/src/client/locales.ts), installation labels the [plugin manager dictionaries](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/ui-plugin-manager/src/client/locales.ts), and common actions the [common dictionaries](https://github.com/deepseek-ai/deepseek-harness/tree/master/packages/client/locale/src/locales). These core terms were available in DSH, so no Codex or Claude Code substitution was needed.

| Language | Allow once | Reject | Waiting for approval |
| --- | --- | --- | --- |
| English | Allow once | Reject | Waiting for approval |
| 简体中文 | 允许一次 | 拒绝 | 等待审批 |
| 日本語 | 1 回だけ許可 | 拒否 | 承認待ち |
| Español | permitir una vez | Rechazar | Esperando aprobación |
| Français | Autoriser une fois | Rejeter | En attente d'approbation |
| Deutsch | Einmal zulassen | Ablehnen | Warten auf Genehmigung |
| Русский | Разрешить один раз | Отклонить | Ожидание одобрения |
| Português | Permitir uma vez | Rejeitar | Aguardando aprovação |

## Editing and verification

Edit `macos/assets/ui-strings.json`. Chinese message keys are the source copy; each other language must contain the same keys and numbered placeholders. Run `node scripts/sync-locales.mjs` to update the committed client bundle and Swift catalogs, or add `--check` to detect stale generated files. Users need no generation step.

Run `npm ci --ignore-scripts`, `npm test`, `npm run test:native` on macOS and `npm run check:release`. Regression coverage checks complete catalogs, language transport, regional fallback, native notification categories, live control updates, preserved drafts and narrow native layouts. These checks do not establish live Desktop notification delivery or linguistic acceptance by native speakers. Rebuilding and installing the helper is required for native changes to take effect; follow [installation](install.md) and protect open requests and drafts.

Each language has a root README linked by the language navigation. New translated READMEs share the six English interface images and explicitly describe them as examples; [image sources](images/README.md) records their scope.
