# HUD Layout Engine Design

**Date:** 2026-03-28
**Status:** Draft
**Depends on:** Jane + Atlas HUD Design (2026-03-28)
**Inspired by:** Hyprland/Omarchy tiling compositor philosophy

## Problem

The HUD currently hardcodes layout: ear widths, avatar size, strip height, content placement. Clients (Jane, Athena, Claude Code sessions) must know the geometry to send content. This doesn't scale — every new client needs to understand the notch's physical constraints.

## Philosophy: The Notch is a Window Manager

Borrow from Hyprland/Omarchy:

1. **Clients declare content, not geometry** — "show this status at high priority" not "put this at x=200"
2. **The layout engine decides placement** — based on available space, rules, severity, user prefs
3. **Declarative rules, not imperative positioning** — config says what goes where by type/priority
4. **Layered config** — system defaults → theme → user overrides
5. **Severity drives layout** — green = minimal, yellow = expanded, red = full takeover

## Architecture

```
Clients (Jane, Athena, Claude Code)
  │
  ▼
Content Bus (~/.atlas/status.json — content + metadata)
  │
  ▼
Layout Engine (reads rules from ~/.atlas/hud-config.json)
  ├── Geometry Detector (screen size, notch dimensions, available space)
  ├── Rule Matcher (which slot does this content go in?)
  ├── Layout Solver (arrange slots within available geometry)
  └── Animation Resolver (which banner theme for this content?)
  │
  ▼
Renderer (SwiftUI views in NotchWindow)
```

## Content Model

Clients send content, not layout instructions:

```json
{
  "source": "athena",
  "severity": "yellow",
  "message": "Traffic spike on scalable-media",
  "banner": "⚠️ TRAFFIC SPIKE ★ 3x normal",
  "bannerStyle": "typewriter",
  "slots": {
    "metric": { "label": "QPS", "value": "847", "trend": "up" },
    "status": { "label": "Athena", "value": "investigating" }
  }
}
```

The `slots` field is content-addressed — the client says "here's a metric" and the layout engine decides where to render it based on available space and rules.

## Geometry Model

The layout engine knows the physical constraints:

```yaml
screen:
  width: 1710        # detected at runtime
  height: 1107

notch:
  width: 185         # detected via auxiliaryTopLeftArea/Right
  height: 33

available:
  left: 763          # menu bar space left of notch
  right: 762         # status icon space right of notch
  below: unlimited   # can extend below notch

reserved:
  left_menu: 150     # leave room for app menus
  right_icons: 100   # leave room for status bar icons

usable:
  left: 613          # available.left - reserved.left_menu
  right: 662         # available.right - reserved.right_icons
```

This is **detected at startup and on screen change** — not hardcoded. The HUD adapts to any MacBook (14"/16", external monitors, no notch).

## Layout Zones

The notch area is divided into named zones:

```
┌─────────────────┬─────────┬───────────┐
│                 │         │           │
│   LEFT ZONE     │ NOTCH   │ RIGHT ZONE│
│                 │ (gap)   │           │
│ ┌──────┬──────┐ │         │ ┌───────┐ │
│ │avatar│panels│ │         │ │status │ │
│ └──────┴──────┘ │         │ └───────┘ │
├─────────────────┴─────────┴───────────┤
│              BOTTOM STRIP              │
│          (marquee / ticker)            │
└────────────────────────────────────────┘
```

### Zone definitions:

```yaml
zones:
  avatar:
    anchor: left-top
    size: fixed
    width: 50
    height: fill      # fills full height of left zone
    content: image     # face image from config

  panels:
    anchor: right-of-avatar
    size: fill         # takes remaining left zone width
    height: top-zone   # only in the ear area, not bottom strip
    layout: columns    # auto-arrange children as columns
    min_column_width: 60
    content: dynamic   # filled by slot data from clients

  status:
    anchor: right-top
    size: fixed
    width: from-config # rightEar value
    height: top-zone
    content: severity-indicator

  ticker:
    anchor: bottom
    size: fill-width
    height: from-config # bottomStrip value
    content: banner    # scrolling/animated text
```

## Severity-Driven Layout

Different severity levels trigger different layout sizes:

```yaml
severity_layouts:
  green:
    mode: collapsed    # just the dots flanking the notch
    zones: none        # no expanded zones

  yellow:
    mode: expanded
    left_zone: medium  # 200pt — avatar + 1-2 info columns
    right_zone: small  # 50pt — status dot
    bottom: visible    # ticker active
    animation: expand-bounce

  red:
    mode: full
    left_zone: large   # 380pt — avatar + all panels
    right_zone: small  # 50pt
    bottom: visible    # ticker active, urgent speed
    animation: expand-fast

  offline:
    mode: collapsed
    zones: none
```

This means the HUD **auto-expands based on severity** — no client needs to specify the size. Yellow gets a moderate expansion, red gets the full dashboard.

## Panel System

The `panels` zone auto-arranges content into columns based on available width:

```yaml
panel_types:
  metric:
    min_width: 60
    render: |
      [value]          # large, colored
      [label]          # small, dim
      [trend_arrow]    # optional ▲▼
    example:
      label: "QPS"
      value: "847"
      trend: "up"

  agent_status:
    min_width: 50
    render: |
      [icon]           # agent avatar or emoji
      [name]           # agent name, small
      [state_dot]      # green/yellow/red
    example:
      icon: "🏛️"
      name: "Athena"
      state: "active"

  text_label:
    min_width: 80
    render: |
      [label]          # small header
      [value]          # main text
    example:
      label: "SOURCE"
      value: "JANE"

  countdown:
    min_width: 70
    render: |
      [label]          # what we're counting
      [time]           # HH:MM:SS, large mono
    example:
      label: "NEXT SYNC"
      value: "04:32"
```

The layout engine counts available columns: `floor((panels_zone_width) / min_column_width)`. If a client sends 3 metric slots but there's only room for 2, the third is queued or hidden.

## Layered Config (Omarchy-style)

Three layers, later overrides earlier:

```
1. System defaults     ~/.atlas/hud-defaults.json     (ships with app)
2. Theme               ~/.atlas/hud-theme.json         (visual style)
3. User overrides       ~/.atlas/hud-config.json        (user prefs)
```

### Layer 1: System defaults
```json
{
  "geometry": "auto",
  "severity_layouts": { ... },
  "zones": { ... },
  "panel_types": { ... }
}
```

### Layer 2: Theme
```json
{
  "name": "lcars",
  "colors": { "info": "#9999FF", "warning": "#FF9900", ... },
  "typography": { "font": "monospaced", "size": 12, "weight": "heavy" },
  "animations": { "expand": "bounce", "collapse": "ease-out" },
  "banner_style": "typewriter"
}
```

### Layer 3: User overrides
```json
{
  "layout": "large",
  "reserved": { "left_menu": 200, "right_icons": 80 },
  "avatar": { "width": 50 }
}
```

## Content Bus Protocol

Clients write to `~/.atlas/status.json`. The layout engine reads it. This is the contract:

```typescript
interface HUDContent {
  // Identity
  source: "athena" | "jane" | string
  severity: "green" | "yellow" | "red"

  // Text content
  message: string              // hover panel
  banner?: string              // ticker text
  bannerStyle?: string         // animation theme

  // Structured content (for panel slots)
  slots?: Record<string, SlotContent>

  // Metadata
  updated: string              // ISO 8601
  priority?: number            // 0-100, higher = more important
  ttl?: number                 // seconds before auto-clear
}

interface SlotContent {
  type: "metric" | "agent_status" | "text_label" | "countdown"
  label: string
  value: string
  trend?: "up" | "down" | "flat"
  state?: "active" | "idle" | "error"
  icon?: string
}
```

## Screen Adaptation

The geometry detector runs on:
- App launch
- Screen configuration change (NSApplicationDidChangeScreenParametersNotification)
- External monitor connect/disconnect

On machines without a notch, the HUD renders as a floating panel anchored to the menu bar center.

## Implementation Plan

### Phase 1: Geometry detection + severity-driven sizing
- Detect notch/screen at runtime
- Remove hardcoded sizes
- Green = collapsed, yellow = medium, red = large
- Config still drives presets, but geometry is auto-detected

### Phase 2: Zone system
- Named zones (avatar, panels, status, ticker)
- Zones fill available space based on rules
- Content routed to zones by type

### Phase 3: Panel columns
- Dynamic column count based on available width
- Slot-based content from clients
- Auto-arrange metrics, agent status, labels

### Phase 4: Layered config + themes
- Three-layer config merge
- Theme files for visual styling
- Separate content from presentation completely
