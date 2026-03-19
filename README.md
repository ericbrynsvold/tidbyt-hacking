# tidbyt-hacking

Custom [Tidbyt](https://tidbyt.com) apps written in Starlark, built with [Pixlet](https://github.com/tidbyt/pixlet), and deployed to Tidbyt devices via the Tidbyt API.

## Overview

- **Tidbyt** – Small LED matrix display that runs “apps” (panels) that show time, weather, sports, etc.
- **Pixlet** – Tidbyt’s tool that compiles `.star` (Starlark) scripts into `.webp` animations and can push them to devices.
- **Starlark** – Python-like scripting language; each app has a `main()` that returns a `render.Root` tree of layout and content.

This repo holds the source for several custom panels (mostly MLB/Texas Rangers–focused), shared build/push scripts, and GitHub Actions to build and push on a schedule or on push.

## Repository structure

```
tidbyt-hacking/
├── README.md                 # This file
├── CONTEXT.md               # Short context/reference for AI or future you
├── buildAndPushToTidbyt.sh   # Shared: render .star → .webp, then push to devices
├── build-rangersinfo.sh      # Build + push RangersInfo app
├── build-nextgame.sh        # Build + push NextGame app
├── build-wcchase.sh         # Build + push WC Chase app
├── .env                      # Local env (gitignored): TIDBYT_* vars
├── .gitignore
├── LICENSE                   # Apache-2.0
│
├── rangers-info/             # Texas Rangers info app
│   ├── RangersInfo.star      # Main: standings, Fangraphs odds, AL West bars
│   └── playoffs/
│       └── RangersInfo-playoffs.star  # Playoffs variant (DS/CS/WS odds)
│
├── next-game/                # Next game + win streak app
│   └── NextGame.star         # Next game (TEX at/vs opponent + pitcher last names) + streak bar
├── wc-chase/                 # Wild Card chase app
│   └── WCChase.star          # AL West + AL East WC race (TEX, HOU, SEA, TOR)
│
└── .github/
    ├── workflows/
    │   └── build-and-push-rangersinfo.yml   # CI: build + push on push/schedule
    └── actions/
        ├── run-docker-rangersinfo/          # Docker job for RangersInfo
        │   ├── action.yml
        │   └── Dockerfile
        ├── run-docker-nextgame/             # Docker job for NextGame
        │   ├── action.yml
        │   └── Dockerfile
        └── run-docker-wc-chase/             # Docker job for WC Chase
            ├── action.yml
            └── Dockerfile
```

## Apps

| App | Path | Description |
|-----|------|-------------|
| **RangersInfo** | `rangers-info/RangersInfo.star` | Rangers logo, W–L, division rank, playoff %, and AL West division odds as colored bars (MLB API + Fangraphs). Shows “Flags Fly Forever” when playoff odds &lt; 3% after deadline. |
| **RangersInfo-playoffs** | `rangers-info/playoffs/RangersInfo-playoffs.star` | Playoffs-focused: DS/CS/WS odds; special views for WS champs, AL champs, or “great run” when eliminated. |
| **NextGame** | `next-game/NextGame.star` | Next game panel (black background, no logo): line 1 matchup (team-colored), line 2 date/time, line 3-4 probable pitchers last names (Rangers first), plus a left vertical win-streak bar with blue background (2 px per game). |
| **WCChase** | `wc-chase/WCChase.star` | Wild Card race: TEX, HOU, SEA, TOR with division/WC games back and win % (MLB standings API). |

## Toolchain

- **Pixlet** is used to:
  - **Render**: `pixlet render <app.star>` → produces `<app>.webp` in the same directory as the script.
  - **Push**: `pixlet push --installation-id <id> <device-id> <app.webp> --api-token <token>`.

Install Pixlet locally:

- macOS: `brew install tidbyt/tidbyt/pixlet`
- Or build from source: [Pixlet repo](https://github.com/tidbyt/pixlet).

## Local build and push

1. **Environment**  
   Create a `.env` in the repo root (or export vars in your shell). Required:

   - `TIDBYT_API_TOKEN` – API token for your Tidbyt account.
   - `TIDBYT_DEVICE_ID` – Device ID to push to.  
   Optional (used by `buildAndPushToTidbyt.sh` for multiple devices):
   - `TIDBYT_API_TOKEN_KYLE`, `TIDBYT_DEVICE_ID_KYLE`
   - `TIDBYT_API_TOKEN_JASON`, `TIDBYT_DEVICE_ID_JASON`

2. **Build and push one app**

   - RangersInfo:
     ```bash
     ./build-rangersinfo.sh
     ```
   - NextGame:
     ```bash
     ./build-nextgame.sh
     ```
   - WC Chase:
     ```bash
     ./build-wcchase.sh
     ```

   Each script runs `buildAndPushToTidbyt.sh` with the right app name and directory.

3. **Generic build + push**

   ```bash
   ./buildAndPushToTidbyt.sh <installation-id> <file-name> <directory>
   ```

   - `installation-id`: Tidbyt installation ID (how the app is named on the device).
   - `file-name`: Stem of the `.star` file (e.g. `RangersInfo`, `WCChase`).
   - `directory`: Directory containing `<file-name>.star` (e.g. `rangers-info`, `wc-chase`).

   Example:
   ```bash
   ./buildAndPushToTidbyt.sh RangersInfo RangersInfo rangers-info
   ./buildAndPushToTidbyt.sh NextGame NextGame next-game
   ./buildAndPushToTidbyt.sh WCChase WCChase wc-chase
   ```

   The script renders `$directory/$file-name.star` → `$directory/$file-name.webp`, then pushes that WebP to the device(s) using the env vars above.

4. **Render only (no push)**

   ```bash
   pixlet render rangers-info/RangersInfo.star
   # → rangers-info/RangersInfo.webp
   ```

## CI/CD (GitHub Actions)

- **Workflow**: `.github/workflows/build-and-push-rangersinfo.yml`
  - **Triggers**: Push to the repo, and cron `01 10 * * *` (daily at 10:01 UTC).
  - **Job**: Runs two Docker actions in sequence so **both** RangersInfo and NextGame are built and pushed on each run:
    1. `./.github/actions/run-docker-rangersinfo` – builds and pushes RangersInfo.
    2. `./.github/actions/run-docker-nextgame` – builds and pushes NextGame.
  - Each action builds a Docker image, installs Pixlet (from Tidbyt’s repo), and runs its build script inside the container.

- **Secrets** (set in repo Settings → Secrets and variables → Actions):
  - `TIDBYT_API_TOKEN`, `TIDBYT_DEVICE_ID`
  - `TIDBYT_API_TOKEN_KYLE`, `TIDBYT_DEVICE_ID_KYLE`
  - `TIDBYT_API_TOKEN_JASON`, `TIDBYT_DEVICE_ID_JASON`

- **WC Chase**: To also build and push WC Chase, uncomment the step that uses `./.github/actions/run-docker-wc-chase` in the workflow.

## Starlark app conventions

- Entry point: `main()` returning `render.Root(...)`.
- Common loads: `render`, `http`, `encoding/json`, `encoding/base64`, `time`, `humanize` (and `random` where used).
- Layout: `render.Root` → `Box` / `Column` / `Row` with `children`; use `Padding`, `Image`, `Text` for content.
- External data: `http.get(url, ttl_seconds=...)` then `.json()`; handle non-200 with `fail()`.
- Assets: small images (e.g. Rangers icon) are inlined as base64 in the script.

## Adding a new app

1. Add a directory, e.g. `my-app/`, and create `MyApp.star` with a `main()` that returns `render.Root(...)`.
2. Add a small wrapper script, e.g. `build-myapp.sh`, that calls:
   ```bash
   sh buildAndPushToTidbyt.sh MyApp MyApp my-app
   ```
3. Optional: add a Docker action under `.github/actions/run-docker-myapp/` (Dockerfile + action.yml) that installs Pixlet and runs `build-myapp.sh`, and add a step in the workflow (or a new workflow) that uses it.
4. Ensure required secrets exist if the new script pushes to devices.

## License

Apache License 2.0. See [LICENSE](LICENSE).
