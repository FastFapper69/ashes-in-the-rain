# Chapter 12: Licences, AI content and stores (read before any release)

## Core Idea
Everything in the game must be licensed for *a game sold to players*. Video-creator licences usually are not. Not legal advice – the user should confirm with Artlist sales / a lawyer before release.

## Findings (2026-11-16)
- **Artlist (music, SFX, AI voice)**: the standard Pro and Social licences list "Apps, software, games and their end-users" under Enterprise / dedicated business solutions; covered uses are video projects (YouTube, films, websites…). → Our music (The Magnetic Buzz, Rotem Cinamon, Alon Peretz), SFX and the "Gravity" narration from Artlist likely need an **Enterprise/custom licence** before a commercial release. AI voice output: Social licence says Artlist claims no ownership and does not restrict commercial use, but games are not addressed → ask Artlist. Their licence also requires disclosing AI-generated assets.
- **ElevenLabs direct**: every paid plan includes a commercial licence; output generated on a paid plan stays usable after cancelling; free plan = no commercial use. Fallback if Artlist voice is not cleared (re-generate lines there).
- **Gemini images**: Google does not claim ownership; commercial use is generally read as allowed, but there is **no IP indemnity** for consumer Gemini. Nano Banana Pro images from the free / AI Pro plans carry a **visible watermark** (removed only for Ultra / AI Studio) plus invisible SynthID. [H] audit our art for watermark remnants. Pure AI images may not be copyrightable (US) → others could copy them; our edits/compositing help.
- **Store disclosure**: Steam requires an AI content survey (enforced). Google Play: declaration of AI-generated store-listing assets reported mandatory since Aug 2026 (EU AI Act context); Play also has an AI-generated content policy. Apple: no public AI label rule found – re-check at submission.
- **Voice alternatives if Artlist does not clear the narration/barks for a game** (checked 16. 11.):
  - Microsoft **VibeVoice** (MIT repo): NOT a fit – the TTS code was removed from the repo in Sept 2025 (only weights + a small realtime 0.5B model left), and Microsoft does not recommend it for commercial or real-world use without further testing. Its ASR part could time words (alternative to faster-whisper, ch10).
  - **ElevenLabs paid plan**: clear commercial rights, quality and emotion like now (barks were Eleven v3) – first choice.
  - Open-source on the PC, free to test: **Chatterbox** (MIT, Resemble AI, voice cloning, built-in watermark), **Kokoro** (Apache 2.0, fast, no cloning), CosyVoice2 (Apache 2.0). Check each model's current licence before use.
  - **Never clone Artlist's "Gravity"** (or any voice we do not own) with another tool – Artlist says users do not own voice clones. A switch = new narrator + re-record all ~88 lines and the barks (key = md5 of text, gen/voice_lines.py, gen/bark_voices.py).
  - Music and SFX need the Artlist game licence (or replacements) regardless of the voice.
- **Music for games** is usually priced per project/copies or as a perpetual buyout (e.g. libraries that name "video games" in the licence) – a cheaper alternative to Enterprise if needed.

## Checklist before release
1. Licence file per asset source (Artlist, ElevenLabs, Gemini, fonts) in the repo (`LICENSES.md`) – fonts already self-hosted? check their licences too.
2. AI disclosure text ready for each store.
3. Privacy: crash reports to Supabase = personal data (user agent) → privacy policy + consent where needed.

## Key Takeaways
1. Artlist licence for games is the #1 open risk.
2. Keep a record of plan/date for every generated asset.
3. Disclose AI content where stores ask.
