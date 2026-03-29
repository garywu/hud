# Programmable Notch Display — Market Analysis, Monetization, and Open Source Strategy

**Is HUD a business, a developer tool, an open source project, or a toy?**

HUD turns the MacBook notch into a programmable display surface with LCD dot-matrix rendering, scanner animations, RSVP speed reading, an HTTP API on localhost:7070, a plugin system, a notification OS with a policy engine, escalation timers, focus modes, and themes. It is currently open source (MIT) at [garywu/hud](https://github.com/garywu/hud).

This article answers the question every side-project creator eventually faces: **what is this thing, and what should I do with it?** Through competitive analysis, market sizing, monetization modeling, and risk assessment, we build a framework for deciding HUD's future.

**What you will learn:**

- The complete landscape of macOS notch apps — who charges what, who's open source, who's winning
- Adjacent markets (menu bar utilities, AI assistants, developer tools) and their monetization patterns
- A realistic total addressable market estimate for notch software
- Seven monetization models with revenue projections for each
- Why Apple's 2026 Dynamic Island for Mac changes everything
- An open source strategy recommendation with concrete next steps
- Anti-patterns that kill indie Mac app projects

---

## Table of Contents

1. [The Competitive Landscape](#1-the-competitive-landscape)
   - [Direct Competitors — Notch Apps](#11-direct-competitors--notch-apps)
   - [Adjacent Market — Menu Bar Utilities](#12-adjacent-market--menu-bar-utilities)
   - [AI Assistant Market on Desktop](#13-ai-assistant-market-on-desktop)
   - [Developer Tools and API-First Products](#14-developer-tools-and-api-first-products)
2. [Total Addressable Market](#2-total-addressable-market)
3. [Unique Differentiators](#3-unique-differentiators)
4. [Monetization Models](#4-monetization-models)
5. [Open Source Strategy](#5-open-source-strategy)
6. [Distribution Channels](#6-distribution-channels)
7. [Developer Adoption Playbook](#7-developer-adoption-playbook)
8. [Revenue Modeling Deep Dive](#8-revenue-modeling-deep-dive)
9. [The Apple Risk — Dynamic Island for Mac](#9-the-apple-risk--dynamic-island-for-mac)
10. [Risk Analysis](#10-risk-analysis)
11. [Recommendation — What HUD Should Be](#11-recommendation--what-hud-should-be)
12. [Anti-Patterns](#12-anti-patterns)
13. [Execution Plan](#13-execution-plan)
14. [References](#14-references)

---

## 1. The Competitive Landscape

### 1.1 Direct Competitors — Notch Apps

The macOS notch app market is small but established. Every app in this space emerged after Apple introduced the notch with the 2021 MacBook Pro redesign. Most fall into one of three categories: **cosmetic** (hide or decorate the notch), **Dynamic Island clones** (media controls and widgets around the notch), and **utility layers** (use the notch area for actual work).

#### NotchNook (lo.cafe)

NotchNook is the market leader by revenue and feature completeness.

| Attribute | Details |
|-----------|---------|
| **Developer** | [lo.cafe](https://lo.cafe/notchnook) (indie, small team) |
| **Pricing** | $3/month (2 devices) or $25 one-time (5 devices). Also on [Setapp](https://setapp.com/apps/notchnook). |
| **Revenue** | ~$100K+ confirmed (7,700 purchases at time of Stripe incident in Aug 2024) |
| **Features** | Media controls, calendar widget, notes widget, mirror (webcam preview), folder shelf, AirDrop, shortcuts integration |
| **Approach** | Dynamic Island clone — turn the notch into an interactive widget shelf |
| **Reviews** | Mixed. Users love the concept and polish. Complaints center on battery drain (especially M1), macOS compatibility breakage on beta releases, and Stripe payment issues that [withheld $100K from the developer](https://appleinsider.com/articles/24/08/07/stripe-withholding-100k-from-popular-mac-utility-developer). |

**Key insight:** NotchNook proved the notch app market exists and can generate six-figure revenue. But $100K total (not annual recurring) from 7,700 purchases at $13 average is modest — this is a hobby business, not a venture-scale opportunity. The Stripe incident also revealed how fragile indie payment infrastructure can be.

**What NotchNook does well:** Polish, mainstream appeal, widget variety.
**What NotchNook does poorly:** No API, no plugin system, no programmability. It's a consumer product — you use what they ship.

#### Boring Notch (TheBoredTeam)

The open source alternative that is growing fast.

| Attribute | Details |
|-----------|---------|
| **Developer** | [TheBoredTeam](https://github.com/TheBoredTeam/boring.notch) (community-driven) |
| **Pricing** | Free, open source |
| **GitHub Stars** | 7,600+ |
| **Features** | Music control center with visualizer, calendar integration, file shelf with AirDrop, macOS HUD replacement, battery status |
| **Approach** | Open source Dynamic Island — community contributions drive feature development |
| **Monetization** | GitHub Sponsors (available but no public revenue data) |
| **Reviews** | Strong community adoption. Some internal surveys claim 46% of team members said it improved workflow. |

**Key insight:** Boring Notch demonstrates that the open source model can achieve significant adoption (7.6K stars) in this niche. But stars do not equal revenue. The project appears to be a labor of love, not a business.

**What Boring Notch does well:** Community growth, music integration, free.
**What Boring Notch does poorly:** No API, no plugin system, limited extensibility, music-centric feature set.

#### Other Notch Apps

| App | Type | Price | Key Feature | Notes |
|-----|------|-------|-------------|-------|
| **[Notchmeister](https://apps.apple.com/us/app/notchmeister/id1599169747?mt=12)** | Cosmetic | Free | Visual effects around notch (glow, radar, holiday lights) | By The Iconfactory. Fun but not functional. |
| **[TopNotch](https://topnotch.app/)** | Cosmetic | Free | Hides notch by making menu bar black | Simplest possible notch app. Just wallpaper masking. |
| **[MediaMate](https://wouter01.github.io/MediaMate/)** | Utility | ~$5 | Replaces macOS volume/brightness indicators with notch-style HUD | Focused scope. Does one thing well. |
| **[Alcove](https://tryalcove.com/)** | Widget shelf | ~$5 | Dynamic Island with media, calendar, quick actions | Polished. Positioned as NotchNook alternative. |
| **[Perch](https://apps.apple.com/us/app/dynamic-notch-island-perch/id6742724228?mt=12)** | Smart shelf | ~$5 | Cursor-proximity shelf in notch area | Minimal design. Triggered by cursor near notch. |
| **[NotchPrompt](https://hunted.space/product/notchprompt)** | Teleprompter | ~$10 | Script reader around notch for video calls. Invisible during screen share. | 147 upvotes on Product Hunt. Clever niche. |
| **[Atoll](https://github.com/Ebullioscopic/Atoll)** | Dynamic Island | Free/OSS | Media controls, live activities, Focus/battery indicators | Newer open source entrant. |
| **[DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit)** | Framework | Free/OSS | SwiftUI framework for building notch-aware views | Developer tool, not end-user app. |

#### Competitive Landscape Summary

```
                    Programmable
                         ▲
                         │
                    HUD ◆│
                         │
           ──────────────┼──────────────►
          Cosmetic       │         Functional
                         │
              Notchmeister  NotchNook ◆
              TopNotch ◆  │    Boring Notch ◆
                         │  Alcove ◆
                         │   MediaMate ◆
                         ▼
                    Fixed Feature
```

**HUD occupies a unique position.** Every competitor is either cosmetic (Notchmeister, TopNotch) or a fixed-feature Dynamic Island clone (NotchNook, Boring Notch, Alcove). None of them are programmable. None expose an API. None have a plugin system. None have a notification OS with a policy engine.

This is both HUD's greatest strength and its greatest challenge: it's in a category of one, which means there's no proven market for what it does.

---

### 1.2 Adjacent Market — Menu Bar Utilities

The menu bar utility market is the closest analog to what HUD could become at scale. These apps occupy a similar physical space (top of screen), serve a similar audience (Mac power users), and face similar monetization challenges.

#### Key Players

| App | Type | Pricing | Revenue Model | Notes |
|-----|------|---------|---------------|-------|
| **[iStat Menus](https://bjango.com/mac/istatmenus/)** | System monitoring | $12 one-time (also on Setapp) | Direct license + Setapp | Gold standard for menu bar monitoring. Version 7 is mature. By Bjango. |
| **[Bartender](https://www.macbartender.com/)** | Menu bar management | $15 one-time (moving toward subscription) | Direct license | Controversial ownership change in 2024. Users wary of subscription pivot. |
| **[Ice](https://github.com/jordanbaird/Ice)** | Menu bar management | Free, open source | Community / donations | Direct competitor to Bartender. Growing fast due to being free. |
| **[Stats](https://github.com/exelban/stats)** | System monitoring | Free, open source | GitHub Sponsors | Open source iStat Menus alternative. 24K+ stars. |
| **[Hand Mirror](https://handmirror.app/)** | Webcam preview | $4 one-time | Mac App Store | Simple, focused. One feature done perfectly. |
| **[One Switch](https://fireball.studio/oneswitch)** | Quick toggles | $5 one-time | Direct license | Dark mode, AirPods connect, screen lock — one-click toggles. |
| **[Dato](https://sindresorhus.com/dato)** | Calendar in menu bar | $5 one-time | Mac App Store | By Sindre Sorhus. Simple date/time/calendar. |

#### What Menu Bar Apps Teach Us

1. **$5-15 is the comfort zone.** Successful menu bar utilities charge a one-time fee in this range. Anything above $20 gets scrutiny. Subscriptions provoke backlash (see Bartender).

2. **Open source competitors erode paid markets.** Ice is eating Bartender's market share. Stats is eating iStat Menus' market share. The pattern is clear: if an open source alternative reaches feature parity, the paid product's value proposition collapses.

3. **Setapp was a viable distribution channel.** Note the past tense: Setapp's iOS marketplace shut down in February 2026. The Mac desktop subscription service continues, but its long-term trajectory is uncertain. Relying on Setapp as a primary channel is risky.

4. **Focused beats broad.** Hand Mirror does one thing (webcam preview) and charges $4. Dato does one thing (calendar) and charges $5. These tiny apps succeed because the value proposition is immediately clear. iStat Menus succeeds despite breadth because it has 15+ years of brand equity.

> **Key insight:** The menu bar utility market has a ceiling. The most successful apps generate low-to-mid six figures annually. This is a lifestyle business, not a growth business. HUD's ambitions to be a "notification OS" or "programmable display platform" exceed what this market typically rewards.

---

### 1.3 AI Assistant Market on Desktop

HUD's notification OS and escalation engine position it as a potential AI assistant surface — a heads-up display for AI agents. This market is exploding.

| Product | Pricing | Model | Notch-Relevant? |
|---------|---------|-------|-----------------|
| **[Raycast AI](https://www.raycast.com/pricing)** | $8/mo Pro, $12/user/mo Teams | Freemium + AI upsell | Raycast is the closest comp for "developer productivity on Mac" |
| **[MacGPT](https://goodsnooze.gumroad.com/l/menugpt)** | ~$20 one-time | BYOK (bring your own API key) | Menu bar ChatGPT access. Simple. |
| **[Cursor](https://cursor.sh/)** | $20/mo Pro | IDE subscription | AI coding assistant. Not notch-related but shows willingness to pay for AI tools. |
| **ChatGPT Desktop** | Free (Plus: $20/mo) | Freemium | Official macOS app. Global shortcut. Not notch-aware. |
| **[Claude Desktop](https://claude.ai/)** | Free (Pro: $20/mo) | Freemium | Official macOS app. No notch integration. |

#### The AI HUD Opportunity

None of these AI assistants use the notch. None of them provide an always-visible status surface for AI agents. HUD already has:

- **Escalation engine** — yellow to red to SOS to Telegram, with configurable timers
- **Policy engine** — rate limiting, interruption levels (passive/active/time-sensitive/critical)
- **HTTP API** — any AI agent can POST to localhost:7070/notify
- **SSE stream** — real-time event delivery for monitoring

The scenario: you have Claude Code running a long task, Athena monitoring your infrastructure, and a build pipeline reporting status. All three push to HUD. The notch shows a severity-colored status, scrolling ticker text, and LCD panels with metrics. If something goes unacknowledged for 5 minutes, it escalates. After 15 minutes, it sends a Telegram alert.

This is not what any current notch app does. This is not what any current AI assistant surface provides. This is a genuinely new product category.

**But there is a problem:** the AI assistant market expects $8-20/mo subscriptions tied to AI model access. HUD does not provide AI — it provides a display surface for AI. Charging a subscription for a display surface is a hard sell when the AI itself is what users pay for.

> **Key insight:** HUD's value in the AI space is as infrastructure, not as an AI product. It is the dashboard, not the brain. The monetization path is either (a) being the official HUD for an AI platform (partnership), or (b) being the open source standard that all AI agents target (adoption play).

---

### 1.4 Developer Tools and API-First Products

HUD's HTTP API and plugin system place it in the developer tool category. The question is whether developers will build on it.

#### Comparable Developer Tool Models

| Product | Model | Free Tier | Paid Tier | Revenue |
|---------|-------|-----------|-----------|---------|
| **[Alfred](https://www.alfredapp.com/)** | Freemium | Basic launcher | Powerpack: ~$40 one-time (workflows, clipboard, snippets) | Undisclosed. Estimated low millions annually. |
| **[Raycast](https://www.raycast.com/)** | Freemium | Extensions, launcher | Pro: $8/mo (AI, cloud sync). Teams: $12/user/mo. | $5.2M ARR (2025). 500K+ active users. |
| **[Homebrew](https://brew.sh/)** | Open source | Everything | Nothing | $0 direct. Funded by sponsors (GitHub Sponsors, corporate). |
| **[Hammerspoon](https://www.hammerspoon.org/)** | Open source | Everything | Nothing | $0 direct. Lua scripting for macOS automation. |

#### HUD's API Surface

```
POST /notify          — Submit notification (source, level, title, body)
GET  /stream          — SSE event stream (real-time)
GET  /queue           — Current notification queue
DELETE /notify/:id    — Dismiss notification
GET  /capabilities    — Discovery endpoint
PUT  /config          — Update policies
GET  /plugins         — List installed plugins
POST /plugins/:id/start — Start a plugin
GET  /focus           — Current focus mode
PUT  /focus           — Set focus mode
DELETE /focus         — Clear focus mode
GET  /escalation      — Escalation status
POST /acknowledge/:id — Acknowledge alert
```

This is a real API. It is more complete than what most notch apps offer (which is nothing). But an API without developers building on it is just an empty restaurant.

#### The Platform Question

Could HUD become a platform that other apps build on? Consider what's needed:

1. **SDK/library** — A Swift package or npm module that wraps the HTTP API. Currently HUD uses raw HTTP + shell scripts for plugins. This is fine for power users but not for mainstream developer adoption.

2. **Plugin ecosystem** — HUD has 7 plugins (clock, weather, git-status, now-playing, system-monitor, uptime, pomodoro). These are shell scripts reading a manifest.json. The plugin model works but lacks a distribution mechanism (no plugin marketplace, no `hud install weather`).

3. **Documentation** — The README covers the basics. There's a layout engine design doc. But there's no "Build Your First HUD Plugin" tutorial, no API reference, no cookbook.

4. **Community** — Zero external contributors currently. No Discord, no forum, no GitHub Discussions.

Without all four, HUD is a developer tool for one developer: you.

> **Key insight:** The path from "HTTP API exists" to "developers build on it" is long and requires sustained investment in DX (developer experience). Alfred took years to build its workflow ecosystem. Raycast invested millions. HUD would need to prioritize plugin DX over new features to have any chance at platform status.

---

## 2. Total Addressable Market

### MacBooks with Notches

The notch was introduced with the 2021 MacBook Pro (14" and 16"). It was later added to the 2022 MacBook Air (M2) and all subsequent MacBook models.

**Estimating the installed base:**

| Year | Macs Shipped | Est. % with Notch | Notch Macs |
|------|-------------|-------------------|------------|
| 2021 (Q4 only) | ~7M (annual: 28.6M) | ~15% (Pro only, Q4 launch) | ~1M |
| 2022 | ~26M | ~50% (M2 Air launched) | ~13M |
| 2023 | ~22M | ~70% (most new models have notch) | ~15M |
| 2024 | ~23M | ~85% (almost all current models) | ~20M |
| 2025 | ~25M (projected) | ~90% | ~22M |
| **Cumulative (accounting for ~5yr lifecycle)** | | | **~60-70M** |

Approximately **60-70 million Macs in active use have a notch** as of early 2026. This is a rough estimate — Apple does not publish model-specific installed base data. The Mac installed base overall is approximately 100-120 million.

### Notch App Market Penetration

| Metric | Estimate | Source |
|--------|----------|--------|
| NotchNook purchases | ~10K+ | Stripe incident reporting: 7,700 at time of incident |
| Boring Notch downloads | ~50K+ (estimated from 7.6K stars, typical star-to-download ratio 5-10x) | GitHub stars |
| All notch apps combined | ~100-200K users | Estimate based on above + MediaMate, Alcove, TopNotch |
| As % of notch Mac base | **0.15-0.3%** | 100-200K / 65M |

**The notch app market is tiny.** Even the most generous estimate puts total users at under 200K across all apps combined. NotchNook, the market leader, has roughly 10K paid customers generating roughly $100-150K total revenue (not annual).

### Addressable Segments

| Segment | Size | Willingness to Pay | HUD Fit |
|---------|------|-------------------|---------|
| **Mac power users** (customize everything) | ~5M | $5-25 one-time | Good — these users already buy Alfred, Bartender, etc. |
| **Developers** (want APIs, CLI, automation) | ~2M | $0-40 (prefer free/OSS) | Excellent — HUD's API and plugin system are unique |
| **AI/ML practitioners** (agent dashboards) | ~500K | $0-20/mo (tied to AI tools) | Strong — HUD's notification OS is purpose-built |
| **Casual Mac users** (just want it to look cool) | ~50M | $0-5 | Weak — NotchNook and Boring Notch serve them better |

### Realistic Revenue Potential

Using the most favorable segment (power users + developers + AI practitioners):

| Scenario | Users | ARPU | Annual Revenue |
|----------|-------|------|----------------|
| **Pessimistic** (niche OSS tool) | 5,000 | $0 (donations: $2/user/yr avg) | ~$10K |
| **Moderate** (paid indie app) | 10,000 | $15 one-time (amortized: $5/yr) | ~$50K/yr |
| **Optimistic** (freemium with Pro tier) | 50,000 free / 2,500 paid | $40/yr subscription | ~$100K/yr |
| **Stretch** (platform with plugin marketplace) | 100,000 free / 5,000 paid | $60/yr | ~$300K/yr |

> **Key insight:** The notch app market is a $100K-300K/yr opportunity at best. This is a solid lifestyle business or a meaningful side project, but it is not venture-scale. Plan accordingly.

---

## 3. Unique Differentiators

What does HUD do that **no competitor does**?

### Feature Uniqueness Matrix

| Feature | HUD | NotchNook | Boring Notch | Alcove | MediaMate |
|---------|-----|-----------|-------------|--------|-----------|
| **HTTP API** (localhost:7070) | Yes | No | No | No | No |
| **Plugin system** (manifest.json + shell) | Yes | No | No | No | No |
| **Notification OS** (queue, policies, priority) | Yes | No | No | No | No |
| **Escalation engine** (yellow->red->SOS->Telegram) | Yes | No | No | No | No |
| **Focus modes** (work/sleep/personal + quiet hours) | Yes | Partial | No | No | No |
| **LCD dot-matrix display** (5x7 font, sprites) | Yes | No | No | No | No |
| **Scanner animations** (KITT, histogram, VU meter) | Yes | No | No | No | No |
| **RSVP speed reading** in the notch | Yes | No | No | No | No |
| **Themes** (JSON-based, swappable) | Yes | Partial | Partial | No | No |
| **CLI tool** (bash hud-cli.sh) | Yes | No | No | No | No |
| **SSE event stream** | Yes | No | No | No | No |
| **Multi-machine support** (via API) | Yes | No | No | No | No |
| Media controls | No | Yes | Yes | Yes | Yes |
| Calendar widget | No | Yes | Partial | Yes | No |
| File shelf / AirDrop | No | Yes | Yes | No | No |
| Webcam preview | No | Yes | No | No | No |

### What's Genuinely Novel

**1. The HTTP API makes HUD scriptable by anything.**

Any language, any tool, any AI agent can push to the notch:

```bash
# From a shell script
curl -X POST localhost:7070/notify \
  -d '{"source":"deploy","level":"active","title":"Production deploy started"}'

# From a Python AI agent
import requests
requests.post("http://localhost:7070/notify", json={
    "source": "athena",
    "level": "timeSensitive",
    "title": "Traffic spike detected",
    "body": "3x normal QPS on scalable-media"
})

# From a Node.js build tool
fetch("http://localhost:7070/notify", {
  method: "POST",
  body: JSON.stringify({
    source: "ci",
    level: "passive",
    title: "Build #4521 passed"
  })
})
```

No competitor offers this. NotchNook and Boring Notch are closed systems — you use what they ship.

**2. The notification OS treats notifications as first-class objects.**

HUD does not just display text. It has:
- A **priority queue** — notifications compete for display based on interruption level
- A **policy engine** — rate limiting, channel configuration, per-source rules
- **Escalation** — unacknowledged alerts escalate: yellow (5min) -> red (15min) -> SOS (1min) -> Telegram
- **Focus modes** — work/sleep/personal profiles with quiet hours
- **RSVP interruption** — speed reading pauses for urgent alerts, resumes after

This is closer to PagerDuty than to a notch decoration app.

**3. The LCD dot-matrix aesthetic is unique.**

No other notch app renders a 5x7 dot-matrix display. HUD can display text in red, green, amber, and blue LCD themes with 30+ custom sprites. This gives it a distinctive retro-tech aesthetic that stands apart from the smooth, iOS-inspired look of NotchNook and Boring Notch.

**4. RSVP speed reading in the notch has no equivalent.**

Rapid Serial Visual Presentation in the notch — reading long text one word at a time at 200+ WPM. Combined with the interruption manager that pauses for urgent notifications and resumes after. This is a genuinely novel interaction pattern.

**5. The plugin system enables community extension.**

Plugins are simple: a `manifest.json` declares the plugin's identity, display preferences, schedule, and a shell command to run on each tick. The plugin writes output to stdout. HUD picks it up and renders it.

```json
{
  "id": "weather",
  "name": "Weather",
  "schedule": { "type": "interval", "interval": 1800 },
  "display": { "renderer": "lcd", "presentation": "static", "size": "large" },
  "command": "bash ~/.atlas/plugins/weather/run.sh"
}
```

This is not a complex SDK. It is shell scripts with JSON metadata. Any developer who can write a bash script can build a HUD plugin. The barrier to entry is near zero.

> **Key insight:** HUD's differentiators are real and substantial. The question is not "does HUD do unique things?" — it clearly does. The question is "do enough people want these unique things to build a sustainable project/business?" That depends entirely on positioning and distribution.

---

## 4. Monetization Models

Seven options, from least to most ambitious. Each includes a revenue model, target audience, and honest assessment.

### Model 1: Free + Open Source (Status Quo)

| Attribute | Details |
|-----------|---------|
| **Price** | Free |
| **Revenue** | GitHub Sponsors + donations. Realistic: $0-500/mo. |
| **License** | MIT (current) |
| **Target** | Developers, tinkerers, AI agent builders |
| **Distribution** | GitHub, Homebrew cask |

**Pros:**
- Maximum adoption potential
- Community contributions (Boring Notch's 7.6K stars prove open source notch apps attract attention)
- No support burden — community helps itself
- Builds personal brand and portfolio

**Cons:**
- No revenue (GitHub Sponsors rarely exceed $500/mo for niche tools)
- No incentive to polish (you ship what you want, not what users need)
- Forks can take the project in directions you don't control

**Verdict:** This is the default. It works if HUD is a portfolio piece or a personal tool. It does not work if you want to sustain active development.

---

### Model 2: Freemium — Free Base + Paid Pro

| Attribute | Details |
|-----------|---------|
| **Free tier** | Core display (LCD, scanner, text), 3 built-in plugins, HTTP API, basic themes |
| **Pro tier** | $25 one-time or $5/mo. All plugins, all themes, custom themes, escalation engine, focus modes, RSVP, multi-machine support |
| **Revenue** | At 2% conversion of 10K users: 200 * $25 = $5K. At 50K users: $25K. |
| **Target** | Power users who hit the limits of free |

**Pros:**
- Proven model (Alfred Powerpack: ~$40, Raycast Pro: $8/mo)
- Free tier drives adoption, Pro converts serious users
- Aligns incentives — you build features people pay for

**Cons:**
- Deciding the free/pro split is agonizing. Too much free = no conversions. Too much paid = no adoption.
- One-time purchases are simple but create upgrade pressure (Alfred model). Subscriptions are predictable but face Mac user resistance.
- Requires a licensing system (Paddle, Gumroad, or custom)

**Verdict:** The most conventional choice. Works if HUD reaches 10K+ users. The $25 one-time price matches NotchNook's pricing and is in the Mac utility comfort zone.

---

### Model 3: One-Time Purchase ($15-30)

| Attribute | Details |
|-----------|---------|
| **Price** | $20 one-time |
| **Revenue** | At 5K purchases over 2 years: $100K total. |
| **Target** | Mac power users (same audience as NotchNook) |
| **Distribution** | Direct (Paddle/Gumroad), Homebrew cask for trial |

**Pros:**
- Simple. Users understand "pay once, use forever."
- NotchNook proved the $25 price point works for notch apps
- No recurring billing complexity

**Cons:**
- Revenue is front-loaded and decays unless you ship major updates
- Creates pressure for paid upgrades (v2, v3) that fragment the user base
- Cannot fund ongoing development without a growing user base

**Verdict:** Safe choice. Matches market expectations. Ceiling is ~$100-150K total unless you continually attract new users.

---

### Model 4: Subscription ($3-5/mo)

| Attribute | Details |
|-----------|---------|
| **Price** | $4/mo or $36/yr |
| **Revenue** | At 500 subscribers: $24K/yr. At 2,000: $86K/yr. |
| **Target** | Users who value ongoing development and updates |

**Pros:**
- Predictable revenue. $2K/mo from 500 subscribers covers basic costs.
- Aligns development incentives — you ship continuously to retain subscribers
- Setapp integration possible (70% revenue share, though Setapp's future is uncertain)

**Cons:**
- Mac users hate subscriptions for utility apps. Bartender's subscription pivot caused a user revolt.
- Churn is high in this category — users cancel when the novelty wears off
- Requires continuous feature delivery to justify recurring cost

**Verdict:** Risky for a utility app. Only viable if tied to a continuously improving service (cloud sync, AI features, or a plugin marketplace).

---

### Model 5: Plugin Marketplace

| Attribute | Details |
|-----------|---------|
| **Price** | HUD is free. Premium plugins: $2-10 each. HUD takes 30% cut. |
| **Revenue** | Highly speculative. Need 50+ paid plugins and thousands of active users to generate meaningful marketplace revenue. |
| **Target** | Plugin developers who want to monetize, users who want specialized features |

**Pros:**
- Shifts development burden to the community
- Recurring revenue from new plugin purchases
- Network effects — more plugins attract more users attract more plugin developers

**Cons:**
- Requires a massive user base to attract plugin developers (chicken-and-egg problem)
- Marketplace infrastructure is complex (payments, reviews, updates, dispute resolution)
- No Mac notch app has ever achieved this. The market may be too small.

**Verdict:** This is the "platform dream." It only works at scale (100K+ users). Do not build marketplace infrastructure until you have proven demand.

---

### Model 6: Enterprise — Team Dashboards

| Attribute | Details |
|-----------|---------|
| **Price** | $10-20/user/mo for team features |
| **Revenue** | At 10 teams of 20 users: $24K-48K/yr |
| **Target** | DevOps teams, SRE teams, on-call engineers |
| **Features** | Centralized notification policies, fleet-wide push (one API call reaches all team members' notches), incident escalation, PagerDuty/Opsgenie integration |

**Pros:**
- Enterprise budgets are larger than consumer budgets
- The notification OS / escalation engine maps directly to incident management
- Per-seat recurring revenue is the best model for sustainability

**Cons:**
- Enterprise sales require a sales motion, support SLAs, and security compliance
- The notch is a personal device feature — enterprise IT may resist installing custom software on employee machines
- Competes with established incident management tools (PagerDuty, Opsgenie, Rootly) that already have Mac notification support

**Verdict:** Interesting but premature. If HUD achieves organic adoption among developers at tech companies, enterprise features become a natural upsell. Do not build enterprise features first.

---

### Model 7: SaaS — Cloud-Connected HUD

| Attribute | Details |
|-----------|---------|
| **Price** | $8/mo for cloud features |
| **Revenue** | At 1,000 subscribers: $96K/yr |
| **Features** | Remote push (send notifications to your notch from anywhere via cloud API), dashboard (web view of your notification history), multi-device sync, mobile app for remote HUD control |

**Pros:**
- SaaS revenue is predictable and valued by investors (if that matters)
- Remote push is genuinely useful — push to your laptop from a server, a phone, another machine
- Opens up Tailscale mesh / API Mom integration scenarios

**Cons:**
- Requires cloud infrastructure (servers, auth, billing, compliance)
- The core value of HUD is local — adding cloud features feels like scope creep
- Users who want a local tool may resist sending notification data to a cloud service

**Verdict:** Possible as a V2 feature. The remote push capability (send a notification to your notch from a CI pipeline, a server, or a mobile app) is genuinely compelling. But this is 6-12 months of infrastructure work.

---

### Monetization Comparison Table

| Model | Revenue Ceiling | Time to Revenue | Risk | Complexity |
|-------|----------------|-----------------|------|------------|
| **Free + OSS** | ~$5K/yr (sponsors) | Never | None | None |
| **Freemium** | ~$50-100K/yr | 3-6 months | Low | Medium (licensing) |
| **One-time** | ~$100-150K total | 1-3 months | Low | Low |
| **Subscription** | ~$100K/yr | 3-6 months | Medium (churn) | Medium |
| **Plugin marketplace** | ~$300K/yr (at scale) | 12-18 months | High | Very High |
| **Enterprise** | ~$500K/yr (at scale) | 12-24 months | High | Very High |
| **SaaS** | ~$100K-500K/yr | 6-12 months | Medium | High |

---

## 5. Open Source Strategy

### License Options

| License | Allows | Prevents | Used By |
|---------|--------|----------|---------|
| **MIT** (current) | Everything. Forks, commercial use, proprietary derivatives. | Nothing. | Boring Notch, most JS/Swift libraries |
| **GPL v3** | Forks must also be GPL. Commercial use OK if source is shared. | Proprietary forks. | Hammerspoon, many GNU tools |
| **AGPL v3** | Like GPL but also covers network use (SaaS must share source). | Proprietary SaaS based on your code. | Few macOS apps. Mostly web/server tools. |
| **BSL (Business Source License)** | Source is viewable. Free for non-commercial use. Converts to open source after X years. | Commercial use without a license. | CockroachDB, Sentry, HashiCorp (controversial) |
| **FSL (Functional Source License)** | Like BSL but with clearer terms. Converts to Apache 2.0 after 2 years. | Competing commercial use. | Sentry (adopted FSL in 2024) |

### Open Source Models for HUD

#### Option A: Stay MIT, Monetize Support/Services

Keep everything MIT. Revenue from:
- Consulting (set up HUD for your team)
- Custom plugin development
- Sponsorships

**Realistic revenue:** $0-10K/yr. This is the Homebrew model — widely used, never profitable.

#### Option B: Open Core (Recommended)

Core is MIT. Premium features are proprietary.

```
MIT (free, open source):
├── Core display engines (LCD, scanner, text)
├── HTTP API (all endpoints)
├── Plugin system (manifest.json + shell)
├── 5 built-in plugins (clock, weather, git-status, system-monitor, uptime)
├── 2 themes (minimal, cyberpunk)
├── CLI tool
└── Basic notification queue

Proprietary (paid, $25 one-time or $5/mo):
├── Notification OS (policy engine, escalation, focus modes)
├── RSVP speed reading + interruption manager
├── Premium themes (LCARS, etc.)
├── Premium plugins (now-playing, pomodoro, + future ones)
├── Theme editor / custom theme support
├── Multi-machine support
└── Priority email support
```

**Why this split works:**
- The free tier is genuinely useful. Developers can script the notch, build plugins, and use the API.
- The paid tier adds "intelligence" — the notification OS, escalation, and focus modes are what transform HUD from a display into an operating system.
- The split is natural, not crippled. Free HUD is a complete product. Paid HUD is a professional tool.

#### Option C: Sponsorware

Features are developed in a private repo. When N sponsors are reached, the feature is released publicly.

Example: "The escalation engine will be open-sourced when HUD reaches 100 GitHub Sponsors."

**Pros:** Creates urgency and community engagement.
**Cons:** Complex to manage. Users may perceive it as holding features hostage.

Caleb Porzio (Livewire creator) [famously reached $100K/yr on GitHub Sponsors](https://calebporzio.com/i-just-hit-dollar-100000yr-on-github-sponsors-heres-how-i-did-it) using this model. But he had a massive existing audience from Laravel. HUD does not.

#### Option D: Dual License (GPL + Commercial)

Core is GPL v3. Companies that want to embed HUD in proprietary products buy a commercial license.

**Pros:** Prevents proprietary forks while keeping the project open.
**Cons:** GPL is unfamiliar in the macOS indie dev world. May discourage contributions.

### Recommendation: Open Core (Option B)

The open core model is the best fit for HUD because:

1. **The free/paid split is natural.** Display engines and API = free. Intelligence (policies, escalation, focus) = paid.
2. **It maximizes adoption.** A free, MIT-licensed HTTP API for the notch is inherently viral among developers.
3. **It creates a clear upgrade path.** Users who outgrow "push text to the notch" naturally want escalation, focus modes, and RSVP.
4. **It's proven.** Alfred, Raycast, GitLens, Sidekiq — open core works for developer tools.

---

## 6. Distribution Channels

### Channel Comparison

| Channel | Commission | Reach | Sandboxing | Best For |
|---------|-----------|-------|------------|----------|
| **Direct download** (own website) | 0% (+ payment processor: 3-10%) | Must drive own traffic | No restrictions | Power users, developers |
| **Mac App Store** | 30% (15% for small business < $1M/yr) | Massive (all Mac users) | Yes — restricted APIs, no localhost server | Consumer apps |
| **Homebrew Cask** | 0% | Developers only | No restrictions | Open source, developer tools |
| **Setapp** | ~10-30% (70% to developer, complex formula) | ~1M subscribers | No restrictions | Mac power users |
| **Paddle** (MoR) | 5% + $0.50/txn | You drive traffic | N/A (payment only) | Indie apps, handles tax compliance |
| **Gumroad** | 10%/txn | Creator audience | N/A (payment only) | Simple digital products |
| **Product Hunt launch** | Free | 1-day spike | N/A | Initial awareness |

### Mac App Store: Probably Not

HUD runs a localhost HTTP server on port 7070. Mac App Store sandboxing would likely prevent this. The policy engine reads/writes files in `~/.atlas/`. Sandboxing would restrict this. The plugin system executes shell commands. Sandboxing would prevent this.

HUD's architecture is fundamentally incompatible with Mac App Store sandboxing. This eliminates the largest distribution channel but also eliminates the 30% commission.

### Recommended Distribution Strategy

1. **Primary: Direct download from GitHub + own website**
   - Homebrew cask for developers: `brew install --cask hud`
   - DMG download for non-developers
   - Payment via Paddle (handles tax compliance, MoR, 5% fee)

2. **Launch: Product Hunt**
   - NotchPrompt got 147 upvotes. HUD's feature set is more ambitious.
   - Prepare a demo video showing: LCD display, scanner, RSVP, escalation, AI agent integration
   - Target: "Show HN" on Hacker News simultaneously

3. **Community: GitHub**
   - MIT-licensed core on GitHub
   - GitHub Discussions for community
   - GitHub Sponsors for recurring support

4. **Optional: Setapp**
   - If the Mac desktop service continues and HUD reaches feature stability
   - 70% revenue share is better than App Store's 70%
   - But Setapp's long-term viability is uncertain after the iOS marketplace shutdown


---

## 7. Developer Adoption Playbook

HUD's best chance at building a sustainable project (or business) is developer adoption. An HTTP API is only valuable if developers integrate with it. A plugin system is only valuable if people write plugins. This section provides concrete integration patterns, SDK designs, and adoption strategies.

### 7.1 Integration Patterns

#### Pattern 1: CI/CD Pipeline Notifications

The simplest high-value integration. Every developer runs builds. Every build has a result. Push it to the notch.

```bash
#!/bin/bash
# .github/scripts/notify-hud.sh
# Call from GitHub Actions via self-hosted runner or SSH tunnel

HUD_URL="${HUD_URL:-http://localhost:7070}"

notify_hud() {
  local level="$1"
  local title="$2"
  local body="$3"
  local source="${4:-ci}"

  curl -s -X POST "${HUD_URL}/notify" \
    -H "Content-Type: application/json" \
    -d "{
      \"source\": \"${source}\",
      \"level\": \"${level}\",
      \"title\": \"${title}\",
      \"body\": \"${body}\"
    }" > /dev/null 2>&1
}

# Usage in a build script
npm run build 2>&1
if [ $? -eq 0 ]; then
  notify_hud "passive" "Build passed" "main branch, commit $(git rev-parse --short HEAD)"
else
  notify_hud "timeSensitive" "BUILD FAILED" "main branch — check terminal"
fi

npm test 2>&1
if [ $? -eq 0 ]; then
  notify_hud "passive" "Tests passed" "47/47 specs green"
else
  notify_hud "active" "Tests failed" "3 specs red — see output"
fi
```

#### Pattern 2: AI Agent Status Dashboard

Claude Code, Cursor, Copilot — any AI agent that runs long tasks benefits from a persistent status display.

```typescript
// hud-agent-bridge.ts
// Bridges Claude Code hook events to HUD notifications

interface ClaudeCodeEvent {
  type: "task_start" | "task_complete" | "tool_use" | "error";
  session_id: string;
  message?: string;
  tool?: string;
  duration_ms?: number;
}

const HUD_URL = "http://localhost:7070";

async function pushToHUD(event: ClaudeCodeEvent): Promise<void> {
  const levelMap: Record<string, string> = {
    task_start: "active",
    task_complete: "passive",
    tool_use: "passive",
    error: "timeSensitive",
  };

  const notification = {
    source: "claude-code",
    level: levelMap[event.type] || "passive",
    title: formatTitle(event),
    body: event.message || "",
  };

  await fetch(`${HUD_URL}/notify`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(notification),
  });
}

function formatTitle(event: ClaudeCodeEvent): string {
  switch (event.type) {
    case "task_start":
      return "Claude Code: task started";
    case "task_complete":
      return `Claude Code: done (${Math.round((event.duration_ms || 0) / 1000)}s)`;
    case "tool_use":
      return `Claude Code: using ${event.tool}`;
    case "error":
      return "Claude Code: ERROR";
  }
}

// Hook integration — called from Claude Code's hook system
export async function onClaudeCodeEvent(event: ClaudeCodeEvent) {
  try {
    await pushToHUD(event);
  } catch {
    // HUD not running — silently ignore
  }
}
```

#### Pattern 3: System Monitoring with Sparklines

Use the scanner engine's sparkline mode to show real-time CPU/memory/network data.

```bash
#!/bin/bash
# plugins/system-monitor/run.sh
# Reports CPU usage as a sparkline-compatible number

# Get CPU usage (macOS)
cpu=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%.0f", s}')

# Get memory pressure
mem_pressure=$(memory_pressure | grep "System-wide memory free percentage" \
  | awk '{print 100-$NF}')

# Get network throughput (bytes/sec on en0)
rx_bytes=$(netstat -I en0 -b | tail -1 | awk '{print $7}')

# Output for HUD (the plugin system reads stdout)
echo "${cpu}"
```

The HUD renders this as a sparkline in the scanner display:

```json
{
  "statusBar": {
    "mode": "content",
    "renderer": "scanner",
    "scannerMode": "sparkline",
    "size": "small",
    "color": "green",
    "data": [12, 15, 18, 22, 19, 14, 11, 8, 10, 15, 22, 35, 28, 20]
  }
}
```

#### Pattern 4: PagerDuty / Opsgenie Integration

On-call engineers need escalation-aware notifications. HUD's escalation engine maps directly to incident management.

```python
#!/usr/bin/env python3
# plugins/pagerduty/run.py
# Polls PagerDuty for triggered incidents and pushes to HUD.

import json
import os
import urllib.request

PAGERDUTY_TOKEN = os.environ.get("PAGERDUTY_TOKEN", "")
PAGERDUTY_USER = os.environ.get("PAGERDUTY_USER_ID", "")
HUD_URL = "http://localhost:7070"

def get_incidents():
    url = (
        f"https://api.pagerduty.com/incidents"
        f"?user_ids[]={PAGERDUTY_USER}"
        f"&statuses[]=triggered&statuses[]=acknowledged"
    )
    req = urllib.request.Request(url, headers={
        "Authorization": f"Token token={PAGERDUTY_TOKEN}",
        "Content-Type": "application/json"
    })
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())["incidents"]

def push_to_hud(incident):
    urgency = incident.get("urgency", "low")
    level = "timeSensitive" if urgency == "high" else "active"

    payload = json.dumps({
        "source": "pagerduty",
        "level": level,
        "title": incident["title"][:60],
        "body": f"Service: {incident['service']['summary']}"
    }).encode()

    req = urllib.request.Request(
        f"{HUD_URL}/notify",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    urllib.request.urlopen(req)

def main():
    incidents = get_incidents()
    for incident in incidents[:3]:
        push_to_hud(incident)

    if not incidents:
        payload = json.dumps({
            "source": "pagerduty",
            "level": "passive",
            "title": "PagerDuty: all clear"
        }).encode()
        req = urllib.request.Request(
            f"{HUD_URL}/notify",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        urllib.request.urlopen(req)

if __name__ == "__main__":
    main()
```

#### Pattern 5: GitHub Actions Workflow Status

```bash
#!/bin/bash
# plugins/github-actions/run.sh
# Shows latest workflow run status for a repo

REPO="${GITHUB_REPO:-garywu/hud}"

status=$(gh run list --repo "$REPO" --limit 1 --json status,conclusion,name \
  --jq '.[0] | "\(.name): \(.conclusion // .status)"')

conclusion=$(gh run list --repo "$REPO" --limit 1 \
  --json conclusion --jq '.[0].conclusion')

case "$conclusion" in
  "success")
    level="passive"
    ;;
  "failure")
    level="timeSensitive"
    ;;
  *)
    level="active"
    ;;
esac

curl -s -X POST "http://localhost:7070/notify" \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": \"github-actions\",
    \"level\": \"${level}\",
    \"title\": \"${status}\"
  }"
```

#### Pattern 6: Pomodoro Timer with LCD Display

```bash
#!/bin/bash
# plugins/pomodoro/run.sh
# Displays countdown timer on LCD

REMAINING_FILE="$HOME/.atlas/plugins/pomodoro/remaining.txt"

if [ ! -f "$REMAINING_FILE" ]; then
  echo "25:00" > "$REMAINING_FILE"
fi

remaining=$(cat "$REMAINING_FILE")
minutes=${remaining%:*}
seconds=${remaining#*:}

# Decrement
total_seconds=$((minutes * 60 + seconds))
if [ $total_seconds -gt 0 ]; then
  total_seconds=$((total_seconds - 1))
  new_min=$((total_seconds / 60))
  new_sec=$((total_seconds % 60))
  printf "%02d:%02d" $new_min $new_sec > "$REMAINING_FILE"
  echo "$(printf '%02d:%02d' $new_min $new_sec)"
else
  # Timer complete — escalate
  curl -s -X POST "http://localhost:7070/notify" \
    -H "Content-Type: application/json" \
    -d '{"source":"pomodoro","level":"timeSensitive","title":"BREAK TIME"}'
  echo "25:00" > "$REMAINING_FILE"
  echo "00:00"
fi
```

### 7.2 SDK Design for Developer Adoption

For HUD to become a platform, developers need an SDK, not raw HTTP calls. Here is what an ideal TypeScript SDK would look like:

```typescript
// @hud/sdk — proposed npm package

interface HUDClient {
  notify(opts: NotifyOptions): Promise<string>;
  dismiss(id: string): Promise<void>;
  acknowledge(id: string): Promise<void>;
  getQueue(): Promise<Notification[]>;
  getCapabilities(): Promise<Capabilities>;
  setFocus(mode: FocusMode): Promise<void>;
  clearFocus(): Promise<void>;
  subscribe(callback: (event: HUDEvent) => void): () => void;
}

interface NotifyOptions {
  source: string;
  level: "passive" | "active" | "timeSensitive" | "critical";
  title: string;
  body?: string;
  ttl?: number;
  sound?: boolean;
  sticky?: boolean;
}

interface FocusMode {
  name: "work" | "sleep" | "personal";
  until?: Date;
}

type HUDEventType =
  | "notification"
  | "escalation"
  | "dismiss"
  | "focus_change"
  | "plugin_output";

interface HUDEvent {
  type: HUDEventType;
  id?: string;
  timestamp: string;
  data: Record<string, unknown>;
}

interface Capabilities {
  version: string;
  engines: string[];        // ["lcd", "scanner", "text"]
  plugins: string[];        // installed plugin IDs
  focusModes: string[];     // available focus modes
  escalation: boolean;      // escalation engine available
  rsvp: boolean;            // RSVP engine available
}

// Implementation sketch
function createHUDClient(opts?: { port?: number }): HUDClient {
  const baseUrl = `http://localhost:${opts?.port ?? 7070}`;

  return {
    async notify(options) {
      const resp = await fetch(`${baseUrl}/notify`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(options),
      });
      const data = await resp.json();
      return data.id;
    },

    async dismiss(id) {
      await fetch(`${baseUrl}/notify/${id}`, { method: "DELETE" });
    },

    async acknowledge(id) {
      await fetch(`${baseUrl}/acknowledge/${id}`, { method: "POST" });
    },

    async getQueue() {
      const resp = await fetch(`${baseUrl}/queue`);
      return resp.json();
    },

    async getCapabilities() {
      const resp = await fetch(`${baseUrl}/capabilities`);
      return resp.json();
    },

    async setFocus(mode) {
      await fetch(`${baseUrl}/focus`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(mode),
      });
    },

    async clearFocus() {
      await fetch(`${baseUrl}/focus`, { method: "DELETE" });
    },

    subscribe(callback) {
      const eventSource = new EventSource(`${baseUrl}/stream`);
      eventSource.onmessage = (e) => {
        callback(JSON.parse(e.data));
      };
      return () => eventSource.close();
    },
  };
}

export { createHUDClient, HUDClient, NotifyOptions, HUDEvent };
```

A Python SDK would follow the same pattern:

```python
# hud_sdk — proposed pip package

import json
import urllib.request
from dataclasses import dataclass
from typing import Optional, Iterator

@dataclass
class NotifyOptions:
    source: str
    level: str  # "passive" | "active" | "timeSensitive" | "critical"
    title: str
    body: Optional[str] = None
    ttl: Optional[int] = None

@dataclass
class HUDEvent:
    type: str
    id: Optional[str]
    data: dict

class HUDClient:
    def __init__(self, port: int = 7070):
        self.base_url = f"http://localhost:{port}"

    def notify(self, source: str, level: str, title: str,
               body: str = "", ttl: int = 0) -> str:
        payload = json.dumps({
            "source": source, "level": level,
            "title": title, "body": body, "ttl": ttl
        }).encode()
        req = urllib.request.Request(
            f"{self.base_url}/notify",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read()).get("id", "")

    def dismiss(self, notification_id: str) -> None:
        req = urllib.request.Request(
            f"{self.base_url}/notify/{notification_id}",
            method="DELETE"
        )
        urllib.request.urlopen(req)

    def acknowledge(self, notification_id: str) -> None:
        req = urllib.request.Request(
            f"{self.base_url}/acknowledge/{notification_id}",
            method="POST"
        )
        urllib.request.urlopen(req)

    def stream(self) -> Iterator[HUDEvent]:
        """Subscribe to SSE event stream."""
        req = urllib.request.Request(f"{self.base_url}/stream")
        with urllib.request.urlopen(req) as resp:
            for line in resp:
                line = line.decode().strip()
                if line.startswith("data: "):
                    data = json.loads(line[6:])
                    yield HUDEvent(
                        type=data.get("type", ""),
                        id=data.get("id"),
                        data=data
                    )
```

### 7.3 Plugin Template and Developer Experience

The fastest path to developer adoption is a plugin template repository that works in under 60 seconds.

```bash
# Desired developer experience
gh repo create my-hud-plugin --template garywu/hud-plugin-template
cd my-hud-plugin

# Edit manifest.json and run.sh
vim manifest.json
vim run.sh

# Install to HUD
hud install .
# -> Copies to ~/.atlas/plugins/my-hud-plugin/
# -> Validates manifest.json
# -> Starts the plugin

# Test it
hud test my-hud-plugin
# -> Runs the plugin command once
# -> Shows what would be rendered in the notch
```

The `hud` CLI tool needs these subcommands for developer adoption:

| Command | Description |
|---------|-------------|
| `hud install <path>` | Install a plugin from a local directory |
| `hud install <github-url>` | Install a plugin from a GitHub repo |
| `hud uninstall <id>` | Remove a plugin |
| `hud test <id>` | Run a plugin once and show output |
| `hud list` | List installed plugins with status |
| `hud start <id>` | Start a stopped plugin |
| `hud stop <id>` | Stop a running plugin |
| `hud logs <id>` | Show plugin logs |
| `hud lcd <text>` | Display text on LCD (already exists) |
| `hud scanner` | Show scanner animation (already exists) |
| `hud rsvp <text>` | Start RSVP reading (already exists) |
| `hud notify <title>` | Send a quick notification |
| `hud status` | Show current HUD state |

### 7.4 Adoption Metrics and Targets

To validate whether developers are actually adopting HUD, track these metrics:

| Metric | Week 4 Target | Week 12 Target | Week 24 Target |
|--------|---------------|----------------|----------------|
| GitHub stars | 500 | 2,000 | 5,000 |
| Homebrew installs | 200 | 1,000 | 3,000 |
| Community plugins | 3 (first-party) | 10 (3 community) | 25 (15 community) |
| API calls/day (from unique sources) | 50 | 500 | 2,000 |
| Discord members | 50 | 200 | 500 |
| Pro conversions | 0 (not launched) | 100 | 500 |

If HUD is not hitting 1,000 GitHub stars by week 12, the developer positioning is not working. Reconsider the strategy.

---

## 8. Revenue Modeling Deep Dive

### Scenario Analysis

Each scenario below models a specific strategic choice with 12-month and 24-month revenue projections. All numbers are conservative.

### Scenario A: Pure Open Source (Baseline)

No revenue strategy. Community-driven development. GitHub Sponsors as the only income.

| Period | Sponsors | Monthly Revenue | Cumulative |
|--------|----------|-----------------|------------|
| Month 1-3 | 0 | $0 | $0 |
| Month 4-6 | 10 | $50 | $150 |
| Month 7-12 | 25 | $125 | $900 |
| Month 13-24 | 50 | $250 | $3,900 |

**Year 1 total: ~$750. Year 2 total: ~$3,000.**

This funds about one month of a single developer's coffee budget. It is not a business.

### Scenario B: Open Core with $25 One-Time Pro

Free core drives adoption. Pro tier captures 2-5% of engaged users.

| Period | Free Users | Pro Purchases | Incremental Revenue |
|--------|-----------|---------------|-------------------|
| Month 1-3 | 2,000 | 40 (2%) | $1,000 |
| Month 4-6 | 5,000 | 110 (3% of new) | $2,750 |
| Month 7-12 | 10,000 | 250 (4% of new) | $6,250 |
| Month 13-24 | 25,000 | 600 (4% of new) | $15,000 |

**Year 1 total: ~$10,000. Year 2 total: ~$15,000. Cumulative: ~$25,000.**

Decent for a side project. Not enough to go full-time. The problem with one-time purchases is you need new users every month to maintain revenue.

### Scenario C: Open Core with $5/mo Pro Subscription

Same free core. Pro is a subscription that justifies continuous development.

| Period | Free Users | Subscribers | Churn (10%/mo) | MRR (end) |
|--------|-----------|-------------|-----------------|-----------|
| Month 1-3 | 2,000 | 30 | ~3/mo | $135 |
| Month 4-6 | 5,000 | 80 | ~8/mo | $320 |
| Month 7-12 | 10,000 | 150 | ~15/mo | $675 |
| Month 13-24 | 25,000 | 300 | ~30/mo | $1,350 |

**Year 1 total: ~$4,120. Year 2 total: ~$13,500. MRR at M24: ~$1,350.**

Lower absolute revenue than one-time in year 1, but growing MRR. At $1,350/mo by month 24, the trajectory is promising if growth continues.

### Scenario D: Hybrid — $25 One-Time + Optional $3/mo Cloud Tier

Base Pro is a one-time purchase. Cloud features (remote push, sync, web dashboard) are a subscription.

| Period | Pro Sales | Cloud Subs | Monthly Cloud Rev | Period Total |
|--------|----------|------------|-------------------|-------------|
| Month 1-3 | $1,000 | 5 | $15 | $1,045 |
| Month 4-6 | $2,750 | 20 | $60 | $2,930 |
| Month 7-12 | $6,250 | 50 | $150 | $7,150 |
| Month 13-24 | $15,000 | 120 | $360 | $19,320 |

**Year 1 total: ~$11,125. Year 2 total: ~$19,320. Cumulative: ~$30,445.**

This is the best of both worlds -- captures one-time buyers AND builds recurring revenue from power users. The challenge is building and maintaining the cloud infrastructure.

### Cost Structure

What does it cost to run HUD as a product?

| Expense | Monthly Cost | Notes |
|---------|-------------|-------|
| Domain + hosting (landing page) | $10 | Cloudflare Pages or similar |
| Paddle subscription (payment) | $0 base + 5% of sales | No fixed cost |
| Apple Developer Program | $8.25/mo ($99/yr) | Required for code signing and notarization |
| Cloud infrastructure (if SaaS tier) | $50-200 | Cloudflare Workers, R2, D1 |
| Design assets (one-time) | $500-1,000 amortized | Logo, screenshots, Product Hunt assets |
| Your time | Priceless | The real cost |

**Breakeven with Scenario B:** ~$20/mo in fixed costs. Breakeven at 1 Pro sale per month. Trivially achievable.

**Breakeven with Scenario D (cloud):** ~$100-250/mo in fixed + cloud costs. Breakeven at 4-10 Pro sales + 30 cloud subscribers per month. Achievable by month 6-9.

### Revenue Per Hour Analysis

Assuming you spend 10 hours/week on HUD:

| Scenario | Year 1 Revenue | Hours (520) | $/Hour |
|----------|---------------|-------------|--------|
| Pure OSS | $750 | 520 | $1.44 |
| Open Core (one-time) | $10,000 | 520 | $19.23 |
| Open Core (subscription) | $4,120 | 520 | $7.92 |
| Hybrid | $11,125 | 520 | $21.39 |

None of these replace a salary. At $21/hour (best case year 1), HUD is a well-paying hobby, not a job. This is typical for indie Mac utilities -- even iStat Menus, the gold standard, is a small-team lifestyle business after 15+ years.

> **Key insight:** Revenue modeling confirms what the market analysis suggests: HUD is a lifestyle business, not a venture-scale opportunity. The most realistic path is Scenario B (open core, $25 one-time) for simplicity, or Scenario D (hybrid) if you are willing to invest in cloud infrastructure. Either way, year 1 revenue will be $10-15K. Plan your time investment accordingly.

---

## 9. The Apple Risk — Dynamic Island for Mac

This is the biggest risk to HUD and every other notch app.

### What We Know

According to [Bloomberg's Mark Gurman](https://www.bloomberg.com/news/articles/2026-02-24/apple-s-touch-screen-macbook-pro-to-have-dynamic-island-new-interface) and research firm [Omdia](https://www.macrumors.com/2024/12/09/macbook-pro-without-notch-roadmap/):

- **Late 2026:** OLED MacBook Pro with hole-punch camera replaces the notch
- **Dynamic Island for macOS:** Interactive, context-aware status area around the camera cutout
- **Touchscreen macOS:** New touch-friendly interface controls
- **MacBook Air:** Keeps the notch through 2028

### Impact Analysis

| Scenario | Probability | Impact on HUD |
|----------|------------|---------------|
| **Apple ships Dynamic Island for Mac in late 2026** | High (~70%) | Severe. Apple's native implementation will be more polished, integrated with system APIs, and free. Media controls, timers, and Now Playing — the bread and butter of NotchNook/Boring Notch — become native features. |
| **MacBook Pro loses the notch, Air keeps it** | High (~80%) | Moderate. HUD must adapt to work with both notch and hole-punch designs. The addressable market for "notch-specific" features shrinks but doesn't disappear (Air users). |
| **Apple's Dynamic Island is limited** | Medium (~40%) | Mild. If Apple only does media controls and timers (like iPhone), HUD's programmable features remain differentiated. |
| **Notch disappears entirely by 2028** | Medium (~50%) | HUD must pivot to a floating panel or menu bar presence. The "notch" identity becomes irrelevant. |

### Survival Strategies

**1. Position HUD as "Dynamic Island for power users" not "Dynamic Island clone"**

If Apple ships a basic Dynamic Island (media, timers, phone calls), HUD's value is everything Apple does NOT ship: HTTP API, plugin system, notification OS, LCD aesthetics, RSVP, escalation. Apple will never ship a policy engine. Apple will never ship localhost:7070.

**2. Decouple from the notch**

HUD should work anywhere: notch, hole-punch, floating panel, menu bar. The layout engine design doc already anticipates this:

> On machines without a notch, the HUD renders as a floating panel anchored to the menu bar center.

This is critical. HUD's identity should be "programmable status display" not "notch app." The notch is an implementation detail.

**3. Embrace the Dynamic Island API**

If Apple ships a Dynamic Island API for macOS (like ActivityKit on iOS), HUD should be the first app to integrate. Use Apple's native rendering for system-level features (media, timers) and HUD's custom rendering for everything else (LCD, scanner, RSVP, notifications).

**4. Accelerate the timeline**

If Apple's Dynamic Island ships in late 2026, HUD has ~6-9 months to establish itself. Every month of delay is market opportunity lost. Ship early, ship often.

> **Key insight:** The Apple risk is not theoretical — it is confirmed. Dynamic Island for Mac is coming in 2026. This does not kill HUD, but it fundamentally changes the positioning. HUD must be "the programmable layer Apple will never build" rather than "Dynamic Island for Mac."

---

## 10. Risk Analysis

### Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Apple ships Dynamic Island for Mac** | High (70%) | High | Differentiate on programmability, API, notifications |
| **Notch disappears from MacBooks** | Medium (50% by 2028) | High | Decouple from notch — floating panel, menu bar modes |
| **Open source competitor (Boring Notch) adds API** | Low (20%) | Medium | First-mover advantage, deeper notification OS |
| **Small market — insufficient users** | High (60%) | Medium | Position as developer tool, not consumer app |
| **Battery drain complaints** | Medium (40%) | Medium | Aggressive optimization, idle detection, configurable polling |
| **macOS API breakage** (NotchNook suffered this) | High (70%) | Low | Pin to stable APIs, avoid private APIs, rapid patching |
| **Payment processor issues** (NotchNook's Stripe incident) | Low (15%) | High | Use Paddle (MoR), not direct Stripe |
| **No community forms** — single-developer project forever | Medium (50%) | Medium | Invest in DX: docs, tutorials, Discord, plugin examples |

### The Existential Question

The biggest risk is not technical. It is existential: **is the programmable notch display a category people want?**

NotchNook proved that people will pay $25 for a polished Dynamic Island clone. But that is a known quantity — iPhone users already understand Dynamic Island. A "programmable display surface with an HTTP API and a notification OS" is an unknown quantity.

The market for "programmable" anything is always smaller than the market for "just works." Developers love APIs. Normal users love widgets. HUD appeals to developers. NotchNook appeals to normal users. The developer market is smaller but more willing to pay for tools.

---

## 11. Recommendation — What HUD Should Be

### Identity: Developer-First Notification Dashboard

HUD should be positioned as:

> **The programmable notification dashboard that lives in your Mac's status area.** An HTTP API, plugin system, and notification OS for developers, AI agents, and DevOps teams. Free and open source core. Pro tier for power features.

Not: "Dynamic Island for Mac" (Apple is doing that).
Not: "notch decoration app" (Notchmeister did that).
Not: "another menu bar utility" (too crowded).

### Business Model: Open Core + One-Time Purchase

1. **Core (MIT, free):** Display engines, HTTP API, plugin system, CLI, built-in plugins, basic themes.
2. **Pro ($25 one-time):** Notification OS, escalation, focus modes, RSVP, premium themes, multi-machine.
3. **Revenue target:** $50-100K in year one from direct sales.
4. **Distribution:** GitHub + Homebrew (free), own website + Paddle (paid).
5. **Launch:** Product Hunt + Hacker News "Show HN" + Reddit r/macapps.

### Why Open Core + One-Time

- **Open core** maximizes developer adoption (the API and plugin system attract contributors).
- **One-time purchase** matches Mac user expectations (no subscription fatigue).
- **$25** matches NotchNook's price and is in the proven comfort zone.
- **MIT core** means the community can build on the API even if you stop maintaining it.

### What to Build Next (Priority Order)

| Priority | Feature | Why |
|----------|---------|-----|
| 1 | **Decouple from notch** — floating panel mode for non-notch Macs | Addresses the Apple risk, expands TAM |
| 2 | **Plugin DX** — `hud install <plugin>`, documentation, examples | Without plugin developers, there is no platform |
| 3 | **Pro licensing** — integrate Paddle, gate Pro features | Revenue enables continued development |
| 4 | **Launch** — Product Hunt, HN, r/macapps, dev Twitter | Nothing matters without users |
| 5 | **Three showcase plugins** — PagerDuty integration, GitHub Actions, Claude Code status | Proves the platform value to developers |
| 6 | **Dynamic Island compatibility** — if/when Apple ships APIs | Stay relevant post-notch |

---

## 12. Anti-Patterns

| Anti-Pattern | What Happens | Do This Instead |
|-------------|-------------|-----------------|
| **Building enterprise features before you have 1,000 users** | You spend months on team dashboards nobody uses. | Ship the core product. Let organic adoption reveal enterprise demand. |
| **Subscription pricing for a utility app** | Mac users revolt. Bartender proved this. | One-time purchase ($20-30). Subscriptions only if tied to ongoing service (cloud, AI). |
| **Competing with NotchNook on consumer features** | You lose. They have a head start, more polish, and brand recognition. | Compete on programmability — the axis where NotchNook cannot follow. |
| **Building a plugin marketplace before you have plugins** | You build infrastructure nobody uses. Classic chicken-and-egg. | Write 20 great plugins yourself first. Marketplace comes at 50+ community plugins. |
| **Staying "notch-only" when the notch is disappearing** | Your app becomes obsolete in 2027-2028. | Position as "programmable status display." The notch is one rendering target. |
| **Ignoring battery drain** | One blog post about "HUD drains my battery" kills adoption. NotchNook suffered this. | Benchmark aggressively. Idle detection. Configurable polling intervals. Test on M1 (worst case). |
| **Keeping the API undocumented** | Developers cannot build on what they cannot understand. | Write API docs before you write new features. |
| **MIT license with no revenue plan** | You burn out maintaining a popular free project. | Open core: MIT base + proprietary Pro. Or choose GPL to prevent proprietary forks. |
| **Trying to be everything** | "It's a notch app AND an AI dashboard AND a notification OS AND a speed reader AND..." | Pick one identity for marketing. Be the "programmable notification dashboard." Other features are differentiators, not the pitch. |
| **Shipping on Mac App Store** | Sandboxing breaks the HTTP API, plugin system, and file-based architecture. | Ship direct. Homebrew for developers. Paddle for payments. |

---

## 13. Execution Plan

### Phase 1: Foundation (Weeks 1-4)

- [ ] Decouple from notch — implement floating panel mode
- [ ] Write comprehensive API documentation
- [ ] Create "Build Your First Plugin" tutorial
- [ ] Set up GitHub Discussions
- [ ] Benchmark battery usage on M1/M2/M3/M4

### Phase 2: Pro Tier (Weeks 5-8)

- [ ] Integrate Paddle for licensing
- [ ] Gate Pro features (notification OS, escalation, RSVP, premium themes)
- [ ] Build a simple landing page (one page, features + pricing + download)
- [ ] Create Homebrew cask for free tier
- [ ] Record demo videos (30s each: LCD, scanner, RSVP, escalation, plugin creation)

### Phase 3: Launch (Weeks 9-12)

- [ ] Product Hunt launch (prepare 1 week in advance: hunter, first comment, visuals)
- [ ] Hacker News "Show HN" post (same day as PH or day after)
- [ ] Reddit r/macapps, r/macOS, r/programming posts
- [ ] Dev Twitter/Bluesky threads showing the API in action
- [ ] Reach out to Mac app review sites (MacStories, 9to5Mac, HowToGeek)

### Phase 4: Community (Weeks 13-20)

- [ ] Build 3 showcase integrations (PagerDuty, GitHub Actions, Claude Code)
- [ ] Create plugin template repository
- [ ] Launch Discord for community support
- [ ] Write 5 blog posts showing HUD usage patterns
- [ ] Engage with Boring Notch / NotchNook communities

### Phase 5: Adapt (Weeks 21+)

- [ ] Monitor Apple Dynamic Island announcements from WWDC 2026
- [ ] Implement Dynamic Island compatibility if APIs are released
- [ ] Evaluate SaaS tier (remote push) based on user demand
- [ ] Consider Setapp submission if the platform remains viable

---

## 14. References

### Direct Competitors

- [NotchNook by lo.cafe](https://lo.cafe/notchnook) — Market-leading notch app. $25 one-time or $3/mo. ~$100K revenue confirmed.
- [Boring Notch (TheBoredTeam)](https://github.com/TheBoredTeam/boring.notch) — Open source notch app. 7.6K GitHub stars. Music-focused.
- [Notchmeister on Mac App Store](https://apps.apple.com/us/app/notchmeister/id1599169747?mt=12) — Free cosmetic notch decorations by The Iconfactory.
- [Alcove — Dynamic Island for Mac](https://tryalcove.com/) — Polished Dynamic Island clone with media and calendar.
- [MediaMate](https://wouter01.github.io/MediaMate/) — Notch-style volume/brightness indicators.
- [Atoll (GitHub)](https://github.com/Ebullioscopic/Atoll) — Open source Dynamic Island with live activities.
- [DynamicNotchKit (GitHub)](https://github.com/MrKai77/DynamicNotchKit) — SwiftUI framework for building notch-aware views.
- [NotchPrompt on Product Hunt](https://hunted.space/product/notchprompt) — Teleprompter around the notch. 147 upvotes.

### Notch App Reviews and Comparisons

- [Best Notch Apps for MacBook 2026 — Raphael Journey](https://raphaeljourney.com/blogs/best-notch-apps-macbook) — Comprehensive comparison of all major notch apps.
- [Best Notch Apps for Mac — Apps.Deals](https://blog.apps.deals/best-notch-apps-mac) — Alcove vs NotchNook vs Boring Notch vs Notchmeister vs TopNotch.
- [NotchNook Review — MacSources](https://macsources.com/notchnook-mac-app-review/) — Detailed review with feature breakdown.
- [NotchNook and MediaMate — MacStories](https://www.macstories.net/reviews/notchnook-and-mediamate-two-apps-to-add-a-dynamic-island-to-the-mac/) — Side-by-side Dynamic Island app review.
- [Boring Notch — BrightCoding](https://www.blog.brightcoding.dev/2026/03/24/boring-notch-your-macbooks-notch-just-got-powerful) — Feature overview and community growth.
- [Stripe Withholds $100K from NotchNook Developer — AppleInsider](https://appleinsider.com/articles/24/08/07/stripe-withholding-100k-from-popular-mac-utility-developer) — Payment processor risk for indie Mac developers.

### Menu Bar Utilities

- [iStat Menus 7 by Bjango](https://bjango.com/mac/istatmenus/) — Gold standard menu bar monitoring. $12 one-time.
- [Bartender 6](https://www.macbartender.com/) — Menu bar management. $15. Controversial subscription pivot.
- [Ice (GitHub)](https://github.com/jordanbaird/Ice) — Free open source Bartender alternative.
- [Alfred Powerpack](https://www.alfredapp.com/powerpack/) — Paid upgrade (~$40) for workflows and automation.

### Developer Tools

- [Raycast Pricing](https://www.raycast.com/pricing) — Freemium: free base, $8/mo Pro, $12/user/mo Teams.
- [Raycast Company Statistics — TechLila](https://www.techlila.com/raycast-company-growth-funding-and-market-share-statistics/) — Revenue growth, user numbers, funding details.
- [Raycast raises $30M — TechCrunch](https://techcrunch.com/2024/09/25/raycast-raises-30m-to-bring-its-mac-productivity-app-to-windows-and-ios/) — Series B for Windows and iOS expansion.
- [MacGPT on Gumroad](https://goodsnooze.gumroad.com/l/menugpt) — One-time purchase AI menu bar app.

### Apple Dynamic Island for Mac

- [Touchscreen OLED MacBook Pro with Dynamic Island — MacRumors](https://www.macrumors.com/2026/02/24/touchscreen-macbook-pro-dynamic-island/) — Bloomberg-sourced report on late 2026 launch.
- [Apple's Dynamic Island May Surface on MacBooks — WebProNews](https://www.webpronews.com/apples-dynamic-island-may-soon-surface-on-macbooks-and-it-could-reshape-how-we-interact-with-our-laptops/) — Impact analysis.
- [MacBook Pro Without Notch Roadmap — MacRumors](https://www.macrumors.com/2024/12/09/macbook-pro-without-notch-roadmap/) — Omdia research: OLED MacBook Pro ditches notch for hole-punch.
- [Notch is Dead — Tom's Guide](https://www.tomsguide.com/computing/macbooks/macbook-pro-oled-with-no-notch-looks-like-apple-may-hate-the-notch-just-as-much-as-i-do) — MacBook Pro OLED without notch.
- [Apple Touch-Screen Laptop — Bloomberg](https://www.bloomberg.com/news/articles/2026-02-24/apple-s-touch-screen-macbook-pro-to-have-dynamic-island-new-interface) — Primary source on Dynamic Island + touch macOS.

### Open Source Monetization

- [5 Proven Strategies for Monetizing Open Source — Wingback](https://www.wingback.com/blog/5-proven-strategies-for-monetizing-open-source-software) — Open core, services, support, training, sponsorship.
- [Open Core Business Model — OCV Handbook](https://handbook.opencoreventures.com/open-core-business-model/) — Comprehensive open core strategy guide.
- [Monetize Open Source on GitHub — MarkAICode](https://markaicode.com/monetize-open-source-github-income/) — GitHub Sponsors, dual licensing, marketplace.
- [I Hit $100K/yr on GitHub Sponsors — Caleb Porzio](https://calebporzio.com/i-just-hit-dollar-100000yr-on-github-sponsors-heres-how-i-did-it) — Sponsorware success story from Livewire creator.
- [Open Core vs Open Source for Startups — Startupik](https://startupik.com/open-core-vs-open-source-which-model-works-better-for-software-startups/) — Comparison of models with trade-offs.

### Distribution and Payments

- [Paddle vs Gumroad — Paddle](https://www.paddle.com/compare/gumroad) — MoR comparison. Paddle: 5% + $0.50. Gumroad: 10%.
- [Payment Processing for Indie Hackers — CalmOps](https://calmops.com/programming/web/payment-processing-guide/) — Stripe vs Paddle vs alternatives.
- [Homebrew Cask — How to Create a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap) — Official Homebrew documentation.
- [Adding Software to Homebrew](https://docs.brew.sh/Adding-Software-to-Homebrew) — Requirements for Homebrew cask listing.

### Market Data

- [Apple Mac Sales 2024 — Apple World Today](https://appleworld.today/2025/01/apple-sold-22-9-million-macs-in-2024-for-annual-worldwide-growth-of-4-5/) — 22.9M Macs shipped in 2024.
- [Mac Sales 2024-2025 — Apple World Today](https://appleworld.today/2026/01/mac-sales-grew-5-9-annually-from-2024-to-2025/) — 5.9% annual growth.
- [App Store Ecosystem $1.3T in 2024 — MacRumors](https://www.macrumors.com/2025/06/05/app-store-global-ecosystem-study-2024/) — Overall App Store ecosystem data.
- [Setapp Revenue Distribution — Setapp Developer Docs](https://docs.setapp.com/docs/distributing-revenue) — 70% developer share, 10% Setapp commission.
- [Setapp Mobile Shutdown — TechCrunch](https://techcrunch.com/2026/01/20/one-of-the-first-alternative-app-stores-in-the-eu-is-shutting-down/) — iOS marketplace closed. Mac service continues.
- [NotchNook Reviews on Setapp](https://setapp.com/apps/notchnook/customer-reviews) — User reviews and ratings.

### Product Hunt and Launch Strategy

- [Product Hunt Launch Strategy 2025 — Awesome Directories](https://awesome-directories.com/blog/product-hunt-launch-guide-2025-algorithm-changes/) — Algorithm changes and tips.
- [How to Launch on Product Hunt for macOS Apps — Screen Charm](https://screencharm.com/blog/how-to-launch-on-product-hunt) — macOS-specific launch guide.

---

## Appendix: HUD Architecture Summary

For context on what HUD actually is — the system we are analyzing.

### Display Engines

| Engine | Modes | Description |
|--------|-------|-------------|
| **Scanner** | KITT sweep, histogram, progress bar, heartbeat, VU meter, sparkline | Animated status indicators in the notch |
| **LCD** | 5x7 dot-matrix with 4 color themes and 30+ sprites | Retro dot-matrix text and graphics |
| **Text** | Plain monospace, RSVP speed reading | Direct text rendering and speed reading |

### Plugin System

Plugins are directories in `~/.atlas/plugins/` containing a `manifest.json`:

```json
{
  "id": "weather",
  "name": "Weather",
  "description": "Current temperature and conditions",
  "version": "1.0",
  "display": {
    "renderer": "lcd",
    "presentation": "static",
    "size": "large",
    "priority": "passive"
  },
  "schedule": {
    "type": "interval",
    "interval": 1800
  },
  "command": "bash ~/.atlas/plugins/weather/run.sh"
}
```

Schedule types: `continuous`, `interval`, `event`, `manual`.
Display renderers: `text`, `lcd`.
Presentations: `static`, `scroll`, `rsvp`.

### Notification OS

```
Notification arrives (POST /notify)
  │
  ├── Policy Engine: rate limit check, channel config, interruption level
  │
  ├── Message Queue: priority-sorted, FIFO within priority
  │
  ├── Focus Mode: work/sleep/personal filter
  │
  ├── Escalation Engine: yellow (5min) → red (15min) → SOS (1min) → Telegram
  │
  └── Display Router: LCD/scanner/text based on severity + config
```

### Themes

JSON-based theme files controlling colors, typography, animations, and banner styles:

```json
{
  "name": "lcars",
  "colors": {
    "info": "#9999FF",
    "warning": "#FF9900",
    "error": "#CC0000"
  },
  "typography": {
    "font": "monospaced",
    "size": 12,
    "weight": "heavy"
  },
  "animations": {
    "expand": "ease",
    "bannerSpeed": 40
  },
  "bannerStyle": "typewriter"
}
```

### Layout Engine (In Development)

The layout engine design document describes a future where the HUD acts as a window manager for the notch area:

- **Clients declare content, not geometry** — "show this status at high priority"
- **The layout engine decides placement** — based on available space, severity, rules
- **Severity drives layout** — green = collapsed, yellow = medium expansion, red = full dashboard
- **Layered config** — system defaults, theme overrides, user overrides

This design explicitly supports non-notch rendering modes, which is critical for post-notch survival.

---

*This analysis was written in March 2026. The macOS notch app market is small, evolving, and facing an existential inflection point with Apple's confirmed Dynamic Island for Mac in late 2026. HUD's best path is to establish itself as the programmable notification dashboard for developers before Apple ships, using an open core model with a $25 one-time Pro tier.*
