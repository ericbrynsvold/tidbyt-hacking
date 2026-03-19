# Tidbyt-hacking – context for future use

Quick reference for anyone (or any agent) picking up this repo later.

## What this repo is

- **Starlark** (`.star`) apps for **Tidbyt** LED displays.
- Built with **Pixlet**: `pixlet render <file.star>` → `.webp`; `pixlet push ...` to send to devices.
- Shell scripts and **GitHub Actions** build and push apps (RangersInfo and NextGame on push + daily cron).

## Layout (important paths)

| What | Where |
|------|--------|
| Shared build/push script | `buildAndPushToTidbyt.sh` (args: installationId, fileName, directory) |
| RangersInfo (standings + odds) | `rangers-info/RangersInfo.star` |
| RangersInfo playoffs variant | `rangers-info/playoffs/RangersInfo-playoffs.star` |
| NextGame (next game + streak bar) | `next-game/NextGame.star` |
| Wild Card chase app | `wc-chase/WCChase.star` |
| CI workflow | `.github/workflows/build-and-push-rangersinfo.yml` |
| Docker actions | `.github/actions/run-docker-rangersinfo/`, `run-docker-nextgame/`, `run-docker-wc-chase/` |

## Local dev

- Copy or create `.env` with `TIDBYT_API_TOKEN`, `TIDBYT_DEVICE_ID` (and optional Kyle/Jason vars).
- Run `./build-rangersinfo.sh`, `./build-nextgame.sh`, or `./build-wcchase.sh` to build + push.
- Or: `pixlet render <dir>/<name>.star` then push manually.

## Starlark reminder

- `main()` returns `render.Root(child=...)`.
- Use `render.Box`, `Column`, `Row`, `Text`, `Image`, `Padding`.
- HTTP: `http.get(url, ttl_seconds=...)`; parse with `.json()`; `fail()` on error.
- Data sources used: MLB Stats API (`statsapi.mlb.com` for standings and schedule, including probable pitchers via hydrate), Fangraphs playoff odds API.

NextGame UI note: black background, no logo; matchup + date/time + probable pitcher last names (team-colored); left vertical streak column on black background.

## Secrets (CI)

Workflow expects: `TIDBYT_API_TOKEN`, `TIDBYT_DEVICE_ID`, and optionally `*_KYLE`, `*_JASON` pairs.

For full details, conventions, and adding new apps, see [README.md](README.md).
