# Chapter 13: Business model and release

## Core Idea
A story-driven, few-hours game fits premium-style models, not ad/free-to-play economies. The real choice is how players pay once and where the game lives (web vs native stores).

## Models seen on mobile
- **Premium** (pay up front): quality signal, but a high barrier on mobile.
- **Free-to-start / "Try Before You Buy"** (Apple's name): free download, one in-app purchase unlocks the rest. Works when players are engaged before the paywall (Loop Hero, Shapez did well; others disappointed) – the paywall position needs testing.
- **Premium + optional DLC** (Dead Cells model) – fits the user's idea of a later case for Frank.
- **Subscription services** (Apple Arcade, Netflix Games, Play Pass): pitch-based; good for narrative premium games.
- Subscriptions on a single-player story game fail (players cancel after the story).
- Western audiences show renewed interest in premium narrative mobile games.

## Native vs web
- The web build (GitHub Pages) cannot sell through stores and has iOS limits: no `navigator.vibrate` in Safari (haptics only via a hidden-switch hack in Safari 17.4+ or natively), page memory caps (ch06).
- Native iOS export needs **macOS + Xcode** (signing, TestFlight, App Store). A Mac mini is linked to the user's account – [ask] whether it can be used. Apple Silicon Macs run iOS builds natively. There are Godot add-ons/GitHub Actions for TestFlight / Play uploads.
- Native also brings real haptics, more memory, no browser address bar, offline play, and store visibility.

## Questions for the user (not decided yet)
1. Model: premium, free-to-start with one unlock, or pitch to a subscription service?
2. Native apps (iOS/Android) or web only? Can the Mac mini do iOS builds?
3. Release window and languages (English only? subtitles in more languages?).

## Key Takeaways
1. One-time unlock after a strong free first chapter is the usual fit for this game.
2. Native builds unlock stores, haptics and memory – but need the Mac.
3. Decide before monetisation code or store work starts.
