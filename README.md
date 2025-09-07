# InfinityMetrics DevBox

One-command local environment to explore InfinityMetrics with a beautiful, interactive demo.

## Quick Start (one command)

Run this from your terminal:

```bash
# Raw GitHub (main branch)
curl -fsSL https://raw.githubusercontent.com/karloscodes/infinity-metrics-devbox/refs/heads/main/setup.sh | bash
```

- Demo site: http://localhost:8080
- Dashboard: http://localhost:8080/admin

## What You Get

- Full InfinityMetrics server (Docker) via Caddy
- Beautiful demo at `/` with interactive event buttons
- Extra subpage at `/alt.html` to register a page view on a different path
- Admin dashboard under `/admin`
- Runs on http://localhost:8080 (no HTTPS needed)
- No license required — DevBox runs in test mode with a test key
  - Test key: IM-DEVBOX-TEST-ONLY (guarded; DevBox aborts if not in test mode)

## Manual Setup (clone + run)

```bash
git clone https://github.com/karloscodes/infinity-metrics-devbox.git
cd infinity-metrics-devbox
chmod +x setup.sh
./setup.sh
```

Or without the helper script:

```bash
docker compose up -d
```

## Useful Commands

```bash
# View logs
docker compose logs -f

# Stop everything
docker compose down

# Clean up (removes all data)
docker compose down -v

# Restart services
docker compose restart
```

## Troubleshooting

- Port in use: free port 8080
- Still starting: give it 1–2 minutes on first run

## Documentation

Full docs and one‑liner: https://getinfinitymetrics.com/docs/devbox/

## Contributing

Issues and PRs welcome.
