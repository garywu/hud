# HUD Business Unit Onboarding

**Last Updated:** 2026-03-28
**Status:** Phase 1 Complete
**Next Step:** Phase 2 (Twitter setup, GitHub Actions)

---

## Overview

HUD is now registered as an Atlas business unit under **Hermes (CMO)**. This document explains:

1. **For CTOs:** How to use `identity.yaml` for infrastructure and configuration
2. **For CMOs:** How to use `brand.yaml` for marketing and positioning
3. **For both:** Secret management, release coordination, and escalation paths

---

## Part 1: For CTOs (Infrastructure & Configuration)

### What is identity.yaml?

`identity.yaml` is HUD's **infrastructure and operational card**. It tells Atlas:

- What services HUD provides (rendering engine, HTTP API, notification OS, plugins, distribution)
- What services HUD consumes (Jane observations from Atlas, data from API Mom)
- How to reach HUD (localhost:7070)
- What secrets HUD needs (5 items in 1Password vault `bu-hud`)
- What KPIs to track (installs, GitHub stars, plugins)
- What SLAs to meet (24h release cycle, 48h plugin review)

### How to use identity.yaml

**For CI/CD configuration:**
- Reference `secrets.refs` to load secrets in GitHub Actions
- Example: `${{ secrets.GITHUB_RELEASE_TOKEN }}` maps to `vault_item: "github-hud-releases"` in 1Password

**For service discovery:**
- Atlas agents (Jane daemon, atlas-serve) use `endpoint: "localhost:7070"` to connect to HUD
- CMO agent uses `brand:` section to understand HUD's positioning

**For metrics collection:**
- Scram Jet pipelines read `metrics.primary` and `metrics.secondary` to know what to collect
- Example: homebrew-analytics pulls `monthly-active-installs` every hour

**For SLA tracking:**
- OpenDash alerts fire when SLAs are breached
- Example: If `community-response-sla` exceeds 24h, CMO gets a notification

### Required Secrets Setup (Phase 2)

Before launch, Hephaestus (CTO) must create these 5 items in 1Password vault `bu-hud`:

```yaml
1. github-hud-releases
   Type: Login
   Username: github-actions[bot]
   Password: [GITHUB_RELEASE_TOKEN]

2. homebrew-publish
   Type: Login
   Username: homebrew-bot
   Password: [HOMEBREW_GITHUB_TOKEN]

3. sentry-hud
   Type: Login
   Username: sentry-dsn
   Password: [SENTRY_DSN for error tracking]

4. api-mom-credential
   Type: Login
   Username: api-mom-key
   Password: [API_MOM_API_KEY for bundled plugins]

5. jane-daemon-webhook
   Type: Login
   Username: jane-webhook
   Password: [JANE_WEBHOOK_SECRET for secure notifications]
```

**How to create these:**
```bash
# Example (requires 1Password CLI access)
op vault create --name "bu-hud"
op item create --vault "bu-hud" --category "Login" \
  --title "github-hud-releases" \
  username="github-actions[bot]" \
  password="ghp_xxxxx"
```

### GitHub Actions Integration

Reference secrets in `.github/workflows/`:

```yaml
env:
  GITHUB_RELEASE_TOKEN: ${{ secrets.GITHUB_RELEASE_TOKEN }}
  HOMEBREW_GITHUB_TOKEN: ${{ secrets.HOMEBREW_GITHUB_TOKEN }}
  SENTRY_DSN: ${{ secrets.SENTRY_DSN }}
  API_MOM_API_KEY: ${{ secrets.API_MOM_API_KEY }}
```

### Validation

Run this command (from atlas repo) to validate HUD's identity.yaml:

```bash
pnpm run validate:business-units hud
```

Expected output:
```
✓ identity.yaml schema valid
✓ All service endpoints documented
✓ Secrets referenced in 1Password exist
✓ SOP files exist in hq/sops/
✓ Owner (hermes) has agent definition
```

---

## Part 2: For CMOs (Brand & Content)

### What is brand.yaml?

`brand.yaml` is HUD's **marketing and positioning card**. It tells the CMO:

- **Positioning:** "The dashboard for always-listening AI"
- **ICP (Ideal Customer Profile):** Developers + power users (not enterprise, not non-technical)
- **Tone:** Technical, delightful, minimalist (no buzzwords, no hype)
- **Channels:** Twitter, GitHub, Product Hunt (future)
- **Content calendar:** 4-week sample + Q2 2026 themes
- **Forbidden words:** synergy, leverage, disrupt, "AI for everyone", cute, fun, gimmick, always-listening
- **Crisis playbook:** How to respond to security issues, bugs, plugin misuse, community backlash

### How to use brand.yaml

**For positioning decisions:**
- Reference `messaging_pillars` when writing release announcements
- Example: "Ambient Intelligence" pillar → "HUD brings AI from chat windows into your always-visible notch"

**For content calendar:**
- Use `content_calendar.sample_4_week` as template for weekly planning
- Each week has a theme (launch, community building, onboarding, ecosystem health)
- Schedule posts with social-good using the `tone_examples` guide

**For Twitter dispatch:**
- CMO gives social-good `brand.yaml` section `social_media.twitter`
- Example: "Post plugin spotlight (format: single tweet, max 3 hashtags, tone: delightful)"
- social-good generates draft → CMO approves → posted to @notchsh

**For community management:**
- GitHub Discussions: Use `response_templates` (bug reports, feature requests, plugin help)
- Response SLA: 24h acknowledgment (from `slas.community-issue-response`)
- Escalate technical questions to CTO within 24h

**For crisis response:**
- Reference `crisis:` section when something breaks
- Example: "Major bug in release" → notify CTO + @notchsh + GitHub issue within 2h

### Sample Content Dispatch

When HUD v1.1 releases, CMO's workflow:

1. **Perceive:** GitHub release notification arrives
2. **Decide:** "Feature plugin ecosystem. This is big."
3. **Dispatch:** Send to social-good:
   ```json
   {
     "brand": "hud",
     "content_type": "release-announcement",
     "tone": "technical-delighted",
     "pillars": ["Extensibility", "Developer Platform"],
     "include_links": ["plugin-submission-guide", "github-release"]
   }
   ```
4. **Review:** social-good generates draft
5. **Approve:** CMO reviews against `tone_examples`
6. **Publish:** Post to @notchsh

### Audience Segmentation

Target three segments with tailored messaging:

1. **AI Companion Builders** (2-5K developers)
   - Need: low-latency display + plugins
   - Channels: GitHub, Twitter, ML communities
   - Message: "Display engine for your local AI"

2. **System Status Enthusiasts** (5-10K power users)
   - Need: real-time metrics, customization
   - Channels: Twitter, Reddit, indie communities
   - Message: "Beautiful system dashboard in your notch"

3. **Creative Tool Builders** (1-2K makers)
   - Need: expressive canvas + animation
   - Channels: Twitter, GitHub, Indie Hackers
   - Message: "50×60pt creative platform"

### Anti-patterns to Avoid

From `forbidden_words`:
- ❌ "HUD is the most **disruptive** notch platform" (buzzword)
- ❌ "AI for everyone" (we target developers, not everyone)
- ❌ "This **cute** little dashboard" (too informal)
- ❌ "The **ultimate** productivity tool" (vaporware language)

**Instead, say:**
- ✅ "HUD gives AI developers a unified rendering engine for notch displays"
- ✅ "Built for developers + power users running local AI"
- ✅ "Ship working features to your Mac's notch"

---

## Part 3: Shared Responsibilities

### Release Coordination (CMO + CTO)

**Timeline for a release:**

```
Day 1: Code merge to main
  ├─ Hephaestus (CTO) triggers release workflow
  └─ Creates GitHub release + updates Homebrew formula (24h SLA)

Day 1-2: CMO perceives release
  ├─ CMO reads CHANGELOG from GitHub release
  ├─ Decides on content angle (plugin ecosystem? Jane integration?)
  └─ Dispatches to social-good with messaging pillars

Day 2-3: Content loop
  ├─ social-good generates draft tweet(s)
  ├─ CMO reviews against brand.yaml tone_examples
  └─ Approves → posted to @notchsh

Day 3+: Community engagement
  ├─ CMO monitors GitHub Discussions for questions
  ├─ Responds within 24h SLA
  └─ Escalates technical issues to CTO
```

### Emergency Contact & Escalation

**Who to contact:**

| Situation | Contact | Channel |
|-----------|---------|---------|
| Security issue | Hephaestus (CTO) | Telegram #atlas-hud-oncall |
| Plugin ecosystem problem | Hermes (CMO) + Hephaestus | Telegram #atlas-hud-oncall |
| Community backlash | Hermes (CMO) | GitHub Discussions + Telegram |
| Install metrics declining | Hermes (CMO) → Hephaestus | Telegram #atlas-cmo + GitHub issue |

**Escalation thresholds:**
- Security vulnerability → page immediately (4h triage)
- Complete service outage → page immediately
- Install drop > 50% week-over-week → page CTO within 1h
- Community SLA breach → acknowledge within 24h

---

## Part 4: Secret Management Workflow

### Where Secrets Live

All HUD secrets are in **1Password vault: `bu-hud`**

- CTO has full access (creates, rotates)
- CMO has read access (for automation dispatch)
- GitHub Actions reads via `op://` references (requires auth)

### Rotation Schedule

| Secret | Rotation | Owner | Reason |
|--------|----------|-------|--------|
| GITHUB_RELEASE_TOKEN | Quarterly | CTO | GitHub best practice |
| HOMEBREW_GITHUB_TOKEN | Quarterly | CTO | Homebrew best practice |
| SENTRY_DSN | Per security review | CTO | Observability security |
| API_MOM_API_KEY | Per API Mom policy | CTO | External dependency |
| JANE_WEBHOOK_SECRET | Quarterly | CTO | Internal security |

### Local Development

Developers working on HUD:

1. **Do NOT commit secrets** to `.env` files
2. **Use `.env.local`** (gitignored) for local testing
3. **In CI/CD**, GitHub Actions loads from 1Password automatically

```bash
# Local development
cp .env.example .env.local
# Edit .env.local with test tokens
# Never commit .env.local
```

### Incident Response

**If a secret is exposed:**

1. Rotate immediately via 1Password (take it offline)
2. Update GitHub Actions secrets
3. Audit recent logs (Sentry, GitHub Actions)
4. Post-mortem in GitHub issue (CTO + CMO)

---

## Part 5: Phase 2 Checklist

Phase 1 (complete) created identity.yaml + brand.yaml.

**Phase 2 (next sprint) will:**

- [ ] Create 1Password vault `bu-hud` with 5 secrets
- [ ] Configure GitHub Actions `.github/workflows/release.yml`
- [ ] Set up @notchsh Twitter account
- [ ] Create social-good dispatch flows
- [ ] Write first 3 content pieces
- [ ] Test CMO → social-good → Twitter pipeline
- [ ] Implement Scram Jet metrics pipeline
- [ ] Create OpenDash /hud panel

---

## Part 6: File Locations & Structure

```
hud/
├── hq/
│   ├── identity.yaml          ← CTO uses this (infrastructure)
│   ├── brand.yaml             ← CMO uses this (marketing)
│   ├── ONBOARDING.md          ← You are here
│   ├── status.json            ← Current operational state (update weekly)
│   │
│   ├── campaigns/
│   │   ├── 2026-q2-launch.md
│   │   ├── 2026-plugin-spotlights.md
│   │   └── 2026-jane-integration.md
│   │
│   └── sops/
│       ├── secret-management.md
│       ├── macos-notch-deployment.md
│       ├── homebrew-release-pipeline.md
│       └── plugin-ecosystem-governance.md
│
├── docs/
│   ├── API.md                 ← HTTP API reference
│   ├── PLUGIN-GUIDE.md        ← How to build plugins
│   ├── ARCHITECTURE.md        ← System design
│   └── FAQ.md
│
├── plugins/                    ← Bundled plugins (12)
├── README.md                  ← Product marketing (homepage)
└── LICENSE
```

---

## Part 7: Key Contacts

| Role | Name | Email | Slack | Purpose |
|------|------|-------|-------|---------|
| **CMO (HUD Brand)** | Hermes | hermes@atlas.internal | #atlas-cmo | Brand positioning, content, community |
| **CTO (HUD Infra)** | Hephaestus | hephaestus@atlas.internal | #atlas-cto | Releases, secrets, infrastructure |
| **Social Media** | social-good (agent) | n/a | #atlas-cmo | Twitter dispatch, content generation |
| **Emergency** | Both | — | #atlas-hud-oncall | Security, outages, critical issues |

---

## Part 8: Success Metrics (First 30 Days)

**Technical:**
- [ ] HUD discoverable via `brew install hud`
- [ ] Jane daemon successfully connects to HUD API
- [ ] GitHub release automation working (24h SLA met)
- [ ] Homebrew formula updates automatically (1h SLA met)

**Marketing:**
- [ ] 100+ GitHub stars in week 1
- [ ] 50+ monthly active installs in month 1
- [ ] 1 community-submitted plugin in month 1
- [ ] @notchsh reaches 500 followers in month 1
- [ ] All community questions answered within 24h

**Operational:**
- [ ] CMO perceives HUD as a brand in agent reasoning
- [ ] Release cycle sustainable (2-week cadence)
- [ ] Community response SLA met (0 breaches)
- [ ] 1Password vault created + secrets rotated quarterly

---

## Questions?

For questions about:
- **Infrastructure (CTO):** Read `identity.yaml` sections: `services`, `infrastructure`, `secrets`, `slas`
- **Marketing (CMO):** Read `brand.yaml` sections: `audience`, `messaging_pillars`, `content_calendar`, `crisis`
- **Both:** See "Key Contacts" above

---

**Last Updated:** 2026-03-28
**Next Review:** 2026-04-04 (Phase 2 start)
