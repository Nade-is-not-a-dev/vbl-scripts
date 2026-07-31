# vbl-scripts

Client-side scripts for Volleyball Legends (Roblox), made to run in Delta executor.

## Launcher

Paste this one-liner into your executor to open the script launcher menu:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Nade-is-not-a-dev/vbl-scripts/main/Launcher.lua"))()
```

The launcher fetches the script list from this repo and lets you run any script with one tap.

## Scripts

| File | What it does |
|---|---|
| `BallSkinChanger.lua` | Swaps the visual of every spawned ball to a skin of your choice (local-only). |
| `JerseyChanger.lua` | Shows a jersey of your choice on your character using the game's own `Tools.Jersey` (local-only, re-applies on respawn). |
| `PlayerCardSpoofer.lua` | Swaps the PlayerCard shown on your score card (FlashPlayerCard) to any other card variant (local-only). |
| `EmoteSpoof.lua` | Work in progress: tries to replace one emote's animation with another emote's locally. |
| `DexHeadless.lua` | Headless explorer / instance dump tool. |
| `spin-giver--style-spinner-open-source.lua` | Style spinner utilities (open source). |

## Notes

- All changes are **client-side only** — other players see your real appearance.
- Tested on Delta executor (mobile).
- Every script has a **"-" (minimize) button** on its title bar — collapses the menu to a small bar; tap again to expand.
- Selections are **auto-saved** to `VBLConfig.json` (Delta workspace) when you press APPLY, and **auto-restored** the next time you run the script — no need to re-setup each session.
