# Cabin Crew English MVP 0.2 — API lesson generation

## Added
- AI lesson generator screen with topic, CEFR level (A2/B1/B1+), and lesson size (6/8/10/12).
- OpenAI Chat Completions-compatible API client. Default base URL: `https://router.cheap/v1`.
- API key stored in iOS Keychain; Base URL and model ID stored in app settings.
- One API request generates a complete pack: vocabulary cards plus multiple-choice exercises.
- Generated packs are stored locally and remain available offline.
- Generated lesson quiz is integrated with XP, streak, word progress, and spaced repetition.
- Exact duplicate terms are filtered against the existing local vocabulary.
- Provider errors and malformed model output are surfaced in the UI.

## Safety/content boundary
Generated material is for English language practice only. The prompt explicitly excludes operational procedures, emergency checklists, medical instructions, and claims of official airline phraseology.

## Compatibility
The generator uses `POST {baseURL}/chat/completions` with OpenAI-compatible Chat Completions messages. Native Anthropic Messages API is not supported unless accessed through an OpenAI-compatible gateway.
