# spectra — local agent notes only

Static engineering and delivery standards load from the active Skills runtime
([SylphxAI/skills](https://github.com/SylphxAI/skills) is binding instruction
SSOT). Doctrine and Mission Control are retired historical lineage and must not
be loaded as current instruction authority.

Local truth: `PROJECT.md`.

## Boundary hazards

- Keep Spectra focused on schema/spec generation from Dart models. Product API
- Do not publish pub.dev package changes without explicit release proof and
- Preserve compatibility expectations for Freezed, json_serializable, plain Dart
- Do not introduce a second source of truth for generated contracts.

## Local commands

- `dart format --set-exit-if-changed .`
- `dart analyze`
- `dart test`
- example build-runner generation for output-affecting changes
- Prefer the **narrowest** affected check before full workspace runs.
- Report layers honestly: local diff · trunk FF · deploy · prod proof (do not collapse).

## Validation notes

- Prefer the **narrowest** affected check before full workspace runs.
- Report layers honestly: local diff · trunk FF · deploy · prod proof (do not collapse).
