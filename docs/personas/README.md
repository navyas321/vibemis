# Vibemis agents — Dispatch entry point

Two long-running Claude agents drive Vibemis. To start them from scratch (e.g. from **Claude
Dispatch**), point each at this repo and have it read its persona's *"Dispatch / cold-start
bootstrap"* section — each persona is self-contained and tells the agent how to start from zero.

| # | Agent | Read this | Owns |
|---|-------|-----------|------|
| 1 | **Build / development agent** (`hostdevelop`) | **[build-agent.md](build-agent.md)** | Code, CI, PRs, merges, releases, alerts, the test queue. The **only** agent that pushes to `vibemis-main`. |
| 2 | **Test / device agent** (`clienttest`) | **[test-agent.md](test-agent.md)** | Runs test cycles on the Legion Go S Z2 (SteamOS), files `report.md` PRs. Never pushes code. |

**Repo:** `github.com/navyas321/vibemis` (private, owner `navyas321`). Both agents clone it.

**How they coordinate** — two files on `vibemis-main`, polled via `git fetch`:
- `testing/BUILD_AGENT_INBOX.md` — build → test (priority order, SKIP/PRIORITIZE/RE-RUN, answers).
- `testing/TEST_AGENT_OUTBOX.md` — test → build (progress, questions, findings).

**The one-liner you can give Dispatch:**
> "Look up the `navyas321/vibemis` repo and spin up two agents — one **build** agent (read
> `docs/personas/build-agent.md` and follow its Dispatch bootstrap) and one **test** agent (read
> `docs/personas/test-agent.md` and follow its Dispatch bootstrap)."

Each agent's bootstrap handles auth, which files to read, how to detect its environment (WSL host
vs. cloud container vs. the real test device), and how to resume the loop without redoing landed
work. Reaching the maintainer hands-off (build agent): the **"Build Agent Alert"** workflow —
`gh workflow run "Build Agent Alert" --ref vibemis-main -f message="..." -f severity="error"` —
creates+closes a transient @mention issue → GitHub iOS push.
