# HUD — Programmable macOS Notch Display

A macOS app that turns the MacBook notch into a programmable display surface with LCD, scanner, text engines, a plugin system, and a notification OS.

## Quick Start

```bash
# Build and run
cd HUD && xcodebuild -project ../HUD.xcodeproj -scheme Notchy build
open ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/Notchy.app

# Send a notification
curl -X POST localhost:7070/notify -d '{"source":"test","level":"active","title":"Hello HUD"}'

# Use the CLI
bash hud-cli.sh lcd "HELLO WORLD" --color green
bash hud-cli.sh scanner
bash hud-cli.sh rsvp "Speed reading this text" --wpm 200
```

## Display Engines

| Engine | Modes | Sizes |
|--------|-------|-------|
| **Scanner** | KITT sweep, histogram, progress bar, heartbeat, VU meter, sparkline | 4pt |
| **LCD** | 5×7 dot-matrix, 4 color themes (red/green/amber/blue), 30+ sprites | S/M/L/XL |
| **Text** | Plain monospace, RSVP speed reading | XS/S/M/L/XL |

## Composable Config

```json
{
  "statusBar": {
    "mode": "content",
    "renderer": "lcd",
    "presentation": "rsvp",
    "size": "xl",
    "color": "green",
    "data": [150]
  }
}
```

## HTTP API (localhost:7070)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/notify` | POST | Submit notification |
| `/stream` | GET | SSE event stream |
| `/queue` | GET | Current queue |
| `/notify/:id` | DELETE | Dismiss |
| `/capabilities` | GET | Discovery |
| `/config` | PUT | Update policies |
| `/plugins` | GET | List plugins |
| `/plugins/:id/start` | POST | Start plugin |
| `/focus` | GET/PUT/DELETE | Focus modes |
| `/escalation` | GET | Escalation status |
| `/acknowledge/:id` | POST | Acknowledge alert |

## Notification OS

- **Policy Engine** — rate limiter, channel config, interruption levels
- **Escalation** — yellow→red (5min) → sos (15min) → Telegram (1min)
- **Focus Modes** — work/sleep/personal profiles + quiet hours
- **RSVP Interruption** — pause speed reading for urgent alerts

## Plugins

```
plugins/
  clock/          — live time on LCD
  weather/        — temperature from wttr.in
  git-status/     — branch + changes
  now-playing/    — Music/Spotify track
  system-monitor/ — CPU load sparkline
  uptime/         — system uptime + memory
  pomodoro/       — countdown timer
```

## Architecture

```
~/.atlas/
  status.json          — current display state
  status-queue.json    — notification queue
  hud-config.json      — policies, focus modes, sizes
  hud-theme.json       — visual theme
  plugins/             — plugin directories
  logs/                — HUD + plugin logs
```

## License

MIT (forked from [adamlyttleapps/notchy](https://github.com/adamlyttleapps/notchy))
