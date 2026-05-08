# Global instructions for Codex

## Language

- Always communicate with the user in Russian.
- Be precise, technical, and practical.
- Do not guess APIs, class names, method signatures, database schemas, protocol fields, or legal/tax details.
- If data is missing, inspect the repository, logs, JAR files, documentation, OpenAPI specs, or ask for the exact source.

## Response structure

For technical tasks use this structure:

1. краткий вывод;
2. что подтверждено;
3. что является гипотезой;
4. диагностика;
5. исправление;
6. команды / код / конфиги;
7. проверка результата.

## Safety

- Never print, copy, commit, or expose secrets.
- Treat `.env`, Telegram bot tokens, API keys, database passwords, Cloudflare tokens, fiscal/OFD credentials, private certificates, and production config files as secrets.
- Before destructive commands, explain the risk and ask for confirmation.

Do not run without explicit approval:

- `rm -rf`
- `git reset --hard`
- `git clean -fdx`
- `docker system prune`
- `docker volume rm`
- `DROP`, `TRUNCATE`, or `DELETE` without `WHERE`
- production migrations
- commands that touch POS/fiscal/printer devices

## Git workflow

- Prefer small, reviewable diffs.
- Before editing, inspect the current files.
- After editing, list changed files.
- Do not commit or push unless explicitly requested.
- Remind the user to sync completed work with GitHub after important milestones.

## Java and Set Retail 10

- Default target for POS plugins: Java 8.
- For Set Retail 10 projects, use the local knowledge base first:
  `D:\Projects\set10_ai_knowledge_final_master_bundle`.
- Start Set Retail 10 knowledge lookup from:
  `99_final_master\QUICK_START.md`,
  `99_final_master\question_router.md`,
  `99_final_master\layer_usage_map.md`,
  `00_readme\bundle_manifest.json`.
- Treat the knowledge base as reference material, not as a replacement for inspecting the target repository, SDK JARs, logs, manifests, and actual source code.
- Do not introduce Spring Boot, Lombok, Kotlin, native libraries, OkHttp, or heavy dependencies into Set Retail 10 POS plugins unless explicitly approved.
- Prefer `java.net.HttpURLConnection` for lightweight POS-side HTTP clients.
- If an API signature is unclear, inspect SDK JARs with `javap` or search inside the JAR. Do not invent signatures.
- Always inspect `pom.xml`, `metainf.xml`, MANIFEST.MF generation, `strings_ru.xml`, `strings_en.xml`, and SDK JAR versions.
- Use Set10 metainf namespace: `http://crystals.ru/set10/api/metainf`
- Do not use legacy metainf namespaces unless the repository already requires them.

## SBG plugin manifest standard

For future Set Retail 10 plugins, manifest entries should include:

- `Plugin-Id`
- `Plugin-Version`
- `Implementation-Version`
- `Build-Date`
- `Project`
- `Implementation-Vendor = SBG (Soft Business Group)`
- `Vendor-URL = https://www.sbg.uz`
- `Vendor-Email`
- `Build-Machine`
- `Branch`
- `Revision`

## POS / FiscalDrive / TinyCore

- Assume target POS can be TinyCore or Ubuntu with limited resources.
- Avoid blocking POS UI flows.
- Avoid frequent polling that can affect cashier or fiscal operations.
- Use short timeouts.
- Cache stable identifiers where appropriate.
- Do not assume FiscalDrive JSON-RPC or REST endpoint availability. Inspect actual project code or logs first.
- Do not assume printer status sensors work unless verified.

## Node / Docker / PostgreSQL

- Inspect `package.json` and lock files before choosing npm, pnpm, or yarn.
- If `pnpm-lock.yaml` exists, prefer pnpm.
- If `package-lock.json` exists, prefer npm.
- Never delete Docker volumes without explicit approval.
- Before destructive DB changes, propose backup and rollback.
- Keep API, DB schema, frontend, worker, and bot contracts consistent.

## SBG product context

Important projects and domains:

- `project_3128`
- `PROJECT_A`
- `sbg.network`
- `fiscaldrive.sbg.network`
- `sellgram.uz`
- SBG MiniRetail / SBG POS
- SBG Product Data Quality

For SBG Product Data Quality:

- `mxik_code` is the canonical field.
- IKPU / MXIK are aliases/labels of the same code.
- Do not create a separate `spic_code` unless compatibility requires it.

For SBG MiniRetail / SBG POS:

- Design POS as offline-first.
- Business/legal rules should be extensible without rewriting the cashier core.
- Keep assortment item, product, barcode, and price offer as separate concepts.

## Definition of done

A task is complete only when:

- changed files are listed;
- build/test command is run or exact blocker is documented;
- operational risks are noted;
- manual verification steps are provided;
- no secrets are exposed.
