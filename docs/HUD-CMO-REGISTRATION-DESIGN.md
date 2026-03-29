# HUD CMO Registration — Business Unit Onboarding Design

**Date:** 2026-03-28
**Status:** Design document (not yet implemented)
**Scope:** Position HUD as a production business unit under Hermes (CMO) in the Atlas conglomerate

---

## EXECUTIVE SUMMARY

HUD (garywu/hud) is being registered as a **developer tools / infrastructure** business unit under CMO (Hermes). Unlike content-focused brands managed by CMO (llc-tax, svg-generators, etc.), HUD is a **platform product** that:
- Serves internal use (Jane daemon, Atlas board) + external users (developers wanting notch UIs)
- Has its own lifecycle, versioning, and distribution channel
- Requires coordination with Hermes for brand/positioning, and Hephaestus (CTO) for infrastructure

This design outlines:
1. **identity.yaml template** — HUD's business unit card
2. **CMO integration points** — brand presence, content calendar, positioning
3. **Vault structure** — secrets, credentials, configuration
4. **Business unit relationships** — dependencies on Sisyphus, OpenDash, Scram Jet
5. **CTO/CMO coordination** — launch checklist and effort timeline

---

## PART 1: IDENTITY.YAML TEMPLATE

Location: `hud/hq/identity.yaml`

```yaml
# HUD — Repo Identity Card
name: "HUD"
slug: "hud"
type: "platform"
description: "Programmable notch display platform for macOS — unified 50×60pt rendering engine for ambient interfaces, system status, and notifications"
status: "production"
owner: "hermes"
reports_to: "hermes"

domain: "hud.notch.sh"

# Services HUD provides to the org and external customers
provides:
  - service: "notch-rendering-engine"
    description: "Unified display engine (LCD, scanner, text modes) with 5 font sizes and 3 themes"
    endpoint: "localhost:7070"
    consumers: [atlas, jane-daemon]

  - service: "http-api"
    description: "REST + SSE API for remote display control, plugin management, status updates"
    endpoint: "GET/POST localhost:7070/*"
    consumers: [jane-daemon, atlas-serve]

  - service: "notification-os"
    description: "Policy engine, rate limiting, focus modes, escalation ladder, priority queue"
    endpoint: "POST localhost:7070/status"
    consumers: [jane-daemon, atlas-serve]

  - service: "plugin-system"
    description: "Extensible plugin architecture with 12 bundled plugins (weather, git, docker, ai-status, etc.)"
    endpoint: "localhost:7070/plugins"
    consumers: []

  - service: "distribution"
    description: "Homebrew formula + direct download for macOS 14+ (Universal 2 binary)"
    endpoint: "https://github.com/garywu/hud/releases"
    consumers: []

# Services HUD consumes from other business units
consumes:
  - provider: "atlas"
    service: "jane-observations"
    purpose: "Real-time Jane activity stream, status, alerts for HUD display"

  - provider: "api-mom"
    service: "apimom-router"
    purpose: "Weather, news, stock data aggregation for bundled plugins"

# Cloudflare infrastructure (if any — v1.0 is macOS-only, no Workers)
infrastructure:
  workers: []
  d1: []
  r2: []
  kv: []
  durable_objects: []

# macOS resources
macos:
  notch_display: "50×60pt"
  background_app_refresh: required
  microphone: optional
  file_access: optional
  accessibility_api: optional

# Secrets and credentials
secrets:
  vault: "bu-hud"
  service_account: "sa-hud"
  refs:
    - key: "GITHUB_RELEASE_TOKEN"
      vault_item: "github-hud-releases"
    - key: "HOMEBREW_GITHUB_TOKEN"
      vault_item: "homebrew-publish"
    - key: "SENTRY_DSN"
      vault_item: "sentry-hud"
    - key: "API_MOM_API_KEY"
      vault_item: "api-mom-credential"

# Standard operating procedures
sops:
  - sop-secret-management
  - sop-repo-tooling
  - sop-hq-structure
  - sop-macos-notch-deployment
  - sop-homebrew-release-pipeline
  - sop-plugin-ecosystem-governance

# Brand and positioning
brand:
  positioning: "The dashboard for always-listening AI — bring ambient intelligence to your Mac's notch"
  icp: "Developer + power users running local AI companions, system status dashboards, creative tools"
  tone: "technical, delightful, minimalist"
  channels:
    - name: "Twitter (@notchsh)"
      category: "developer-relations"
    - name: "GitHub Discussions"
      category: "community"
    - name: "Product Hunt (eventual)"
      category: "launch"

# Metrics and KPIs (owned by OpenDash/Scram Jet)
metrics:
  primary:
    - name: "monthly-active-installs"
      source: "homebrew-analytics"
      target: 500
    - name: "github-stars"
      source: "github-api"
      target: 1000
    - name: "plugin-ecosystem-extensions"
      source: "hud-manifest-registry"
      target: 25
  secondary:
    - name: "release-cycle-days"
      source: "github-releases"
      target: 14
    - name: "plugin-quality-score"
      source: "manifest-validation"
      target: 95

# Architecture references (link to brain/Research or articles)
references:
  articles:
    - ambient-ai-notch-ui-design-patterns
    - macos-notch-hid-rendering-apis
    - plugin-ecosystem-patterns
    - homebrew-distribution-pipeline
  research:
    - notch-platform-competitive-analysis-20260328
    - macos-accessibility-api-capabilities-20260328

# Goals and roadmap
goals:
  - slug: "hud-v1-release"
    description: "Ship HUD v1.0.0 to public (Homebrew + direct download)"
    status: "complete"
    verification: "GitHub release exists, Homebrew formula published"

  - slug: "hud-jane-integration"
    description: "Jane daemon uses HUD for all display + notifications"
    status: "in-progress"
    verification: "jane-daemon WebSocket → HUD API, Jane status visible in notch"

  - slug: "plugin-ecosystem-launch"
    description: "First 3rd-party plugin published to registry"
    status: "pending"
    verification: "External plugin in manifest, functional in notch"

  - slug: "hud-analytics-dashboard"
    description: "OpenDash panel showing install, engagement, plugin usage"
    status: "pending"
    verification: "OpenDash /hud route displays real-time HUD metrics"

# Operational schedule
schedule: 604800000  # 7 days = new releases, plugin governance reviews
```

---

## PART 2: CMO INTEGRATION POINTS

### 2.1 Brand & Positioning

**HUD's market position** (Hermes/CMO manages):
- **Elevator pitch:** "The dashboard for always-listening AI — bring ambient intelligence to your Mac's notch"
- **ICP:** Developer + power users (not enterprise, not non-technical)
- **Channels:** Twitter, GitHub, Developer communities, Product Hunt (eventual)
- **Tone:** Technical, delightful, minimalist (no buzzwords, no hype)
- **Anti-patterns:** "SaaS for everyone," marketing fluff, feature-list positioning

**CMO responsibilities:**
1. Maintain `hud/hq/brand.yaml` — positioning, messaging, keywords
2. Social media presence (@notchsh on Twitter) — CMO dispatches to social-good for tweets
3. GitHub community management — CMO monitors discussions, escalates bugs
4. Launch timing — coordinate with Hephaestus for release dates

### 2.2 Content Calendar & Publishing Workflow

HUD content flows through **CMO's daily loop**, same as other brands:

**Content types:**
- **Release announcements** — new versions, breaking changes
- **Plugin spotlights** — highlight community plugins weekly
- **Technical deep-dives** — architecture posts, design decisions
- **Integration updates** — "HUD now integrates with [service]"

**Publishing workflow:**
```
CMO perceives (HUD GitHub releases, plugin registry)
  ↓
CMO makes content decisions (e.g., "feature the new weather plugin")
  ↓
CMO dispatches to social-good
  ↓
social-good generates tweet drafts
  ↓
human approves
  ↓
Posted to @notchsh
```

**Calendar location:** `hud/hq/campaigns/`
- `2026-q2-launch-campaign.md` — public launch push
- `2026-plugin-spotlight-schedule.md` — weekly plugin features
- `2026-jane-integration-messaging.md` — how HUD enables Jane

### 2.3 Metrics & OpenDash Integration

HUD metrics are **collected by Scram Jet** (Layer 1), displayed in **OpenDash** (Layer 3).

**Metrics sources:**
- Homebrew analytics (install counts, version breakdowns)
- GitHub API (stars, releases, issue velocity)
- Plugin registry (manifest validation, ecosystem health)
- Sentry (crash rates, error trends)

**OpenDash dashboard:**
- **Panel:** `/hud` route shows real-time KPIs
- **Datasource:** Scram Jet pipeline at `atlas/hq/pipelines/hud-metrics.yaml`
- **Alerts:** CMO sees if installs drop > 10% week-over-week (triggers investigation)

**Pipeline example** (`scram-jet`):
```yaml
# atlas/hq/pipelines/hud-metrics.yaml
name: "HUD Metrics Collection"
schedule: "0 * * * *"  # hourly
sources:
  - name: "homebrew"
    type: "http"
    url: "https://formulae.brew.sh/analytics/hud.json"
  - name: "github-releases"
    type: "github-api"
    repo: "garywu/hud"
  - name: "plugin-registry"
    type: "http"
    url: "https://hud.notch.sh/api/plugins/stats"
destination: "atlas-opendash-db"
table: "hud_metrics"
```

### 2.4 Social Media & Community

**Twitter account:** @notchsh
- Owned by social-good (platform)
- CMO dispatches content decisions
- Monthly: feature releases, plugin spotlights, developer stories

**GitHub presence:**
- Issues: user feedback, bug reports
- Discussions: community Q&A, feature requests
- Releases: automated via GitHub Actions (Mulan publishes)

**Developer relations:**
- HUD plugin documentation (in `docs/` folder)
- Plugin submission guide (in `CONTRIBUTING.md`)
- Monthly plugin office hours (TBD)

---

## PART 3: VAULT STRUCTURE & SECRETS MANAGEMENT

### 3.1 1Password Vault Layout

HUD gets its own vault under Atlas org:

```
Atlas Organization Vault (org-level shared secrets)
├── Org-level secrets
│   ├── GITHUB_AUTOMATION_TOKEN
│   ├── CF_ACCOUNT_TOKEN (if HUD adds Workers in future)
│   └── ...
│
└── Business Unit Vaults
    ├── bu-hud/  ← HUD's vault
    │   ├── GitHub Release Bot
    │   │   ├── GITHUB_RELEASE_TOKEN (publish to releases)
    │   │   └── GITHUB_ACTIONS_KEY
    │   ├── Homebrew
    │   │   ├── HOMEBREW_GITHUB_TOKEN
    │   │   └── homebrew-publish-key
    │   ├── Monitoring & Observability
    │   │   ├── SENTRY_DSN
    │   │   └── AMPLITUDE_API_KEY (analytics)
    │   ├── External APIs
    │   │   ├── API_MOM_API_KEY (for bundled plugins)
    │   │   ├── OPENWEATHER_API_KEY
    │   │   └── GITHUB_REST_API_TOKEN
    │   └── Service Account (sa-hud)
    │       └── SSH key for CI/CD
    │
    └── Credentials for Integrated Services
        ├── jane-daemon-webhook-secret
        └── atlas-serve-api-key
```

### 3.2 Secret References in identity.yaml

```yaml
secrets:
  vault: "bu-hud"
  service_account: "sa-hud"
  refs:
    - key: "GITHUB_RELEASE_TOKEN"
      vault_item: "github-hud-releases"
      scope: "repo:garywu/hud"
      usage: "GitHub Actions publish releases"

    - key: "HOMEBREW_GITHUB_TOKEN"
      vault_item: "homebrew-publish"
      usage: "Homebrew tap updates"

    - key: "SENTRY_DSN"
      vault_item: "sentry-hud"
      usage: "Error tracking and crash reporting"

    - key: "API_MOM_API_KEY"
      vault_item: "api-mom-credential"
      usage: "Plugin data aggregation (weather, news, stocks)"

    - key: "JANE_WEBHOOK_SECRET"
      vault_item: "jane-daemon-webhook"
      usage: "Secure Jane observer notifications to HUD"
```

### 3.3 SOP: HUD Secret Management

Create `hud/hq/sops/secret-management.md`:

```markdown
# SOP: HUD Secret Management

## Rotation Schedule
- GITHUB_RELEASE_TOKEN: quarterly
- HOMEBREW_GITHUB_TOKEN: quarterly
- API_MOM_API_KEY: per API Mom policy
- SENTRY_DSN: on security review

## Incident Response
- Lost token → rotate immediately via 1Password
- Exposed in logs → rotate + audit GitHub Actions
- Homebrew tap compromised → coordinate with Homebrew team

## Local Development
- Use `.env.local` (gitignored)
- Never commit secrets
- Use `op://` references in CI/CD only
```

---

## PART 4: BUSINESS UNIT RELATIONSHIPS & DEPENDENCIES

### 4.1 Dependency Graph

```
HUD (platform)
├── consumes: atlas (Jane observations)
├── consumes: api-mom (external data for plugins)
├── provides: display engine → jane-daemon
└── provides: display engine → atlas-serve (board alerts)

Atlas (org OS)
├── owns: Jane DO (in packages/jane/)
├── owns: Telegram bridge
└── coordinates: CMO (Hermes) for HUD positioning

OpenDash (SaaS dashboard)
├── displays: HUD metrics via Scram Jet
├── shows: HUD install trends, plugin ecosystem health
└── alerts: CMO if HUD KPIs decline

Scram Jet (data collection)
├── collects: Homebrew analytics, GitHub stats
├── collects: Plugin registry health
└── publishes: to Atlas D1 for OpenDash

Jane Daemon (local companion)
├── reads: HUD API (display engine)
├── writes: observations to HUD
└── needs: HUD running to show status/alerts
```

### 4.2 Service Contracts

**HUD ↔ Jane Daemon (WebSocket)**

Jane daemon connects to HUD API:
```
Jane → POST localhost:7070/status
Payload: { "icon": "jane-listening", "text": "Listening...", "color": "cyan" }

Jane → POST localhost:7070/notification
Payload: { "msg": "Alert: low memory", "severity": "warning", "ttl": 5000 }
```

**HUD ↔ Atlas Board (HTTP)**

Atlas sends HUD notifications for org-wide alerts:
```
Atlas → POST localhost:7070/notification
Payload: {
  "msg": "Board meeting in 5 min",
  "severity": "info",
  "source": "atlas-board"
}
```

**CMO ↔ HUD (indirect via social-good)**

CMO dispatches content decisions → social-good publishes to @notchsh

### 4.3 Integration Timeline

**Phase 1: Registration (This Sprint)**
- [ ] Create `hud/hq/identity.yaml`
- [ ] Create `hud/hq/brand.yaml`
- [ ] Set up 1Password vault (bu-hud)
- [ ] Add HUD to CMO's brand registry (atlas-cmo D1)
- [ ] Hermes (CMO agent) perceives HUD as a brand

**Phase 2: Content Loop (Next Sprint)**
- [ ] Create `hud/hq/campaigns/` folder
- [ ] Write first 2 release announcements
- [ ] Create plugin spotlight calendar
- [ ] Test CMO → social-good dispatch flow

**Phase 3: Metrics & Monitoring (Following Sprint)**
- [ ] Implement Scram Jet pipeline (homebrew analytics)
- [ ] Add HUD metrics to OpenDash dashboard
- [ ] Set up Sentry error tracking
- [ ] Create alerts for KPI thresholds

---

## PART 5: LAUNCH CHECKLIST & EFFORT TIMELINE

### 5.1 CMO/CTO Coordination Matrix

| Task | Owner | Effort | Duration | Blocks |
|------|-------|--------|----------|--------|
| identity.yaml + brand.yaml | CMO | 2h | 1 day | everything else |
| 1Password vault setup | CTO (Hephaestus) | 1h | 2 hours | secret rotation |
| GitHub Actions CI/CD | CTO | 3h | 1 day | releases |
| Homebrew formula publish | CTO | 1h | 2 hours | public launch |
| Scram Jet pipeline | CTO | 4h | 2 days | OpenDash display |
| OpenDash /hud panel | CTO | 2h | 1 day | metrics display |
| Social media account setup | CMO | 1h | 2 hours | content dispatch |
| First 3 content pieces | CMO | 4h | 1-2 days | social launch |
| Plugin submission guide | CTO + CMO | 3h | 1 day | community launch |
| Community office hours (optional) | CMO | 2h setup | 1 day | engagement |

**Total Critical Path:** 4 days (parallel work possible)

### 5.2 Detailed Launch Checklist

#### Pre-Launch (CMO)

- [ ] **Brand positioning locked**
  - Elevator pitch: "The dashboard for always-listening AI"
  - ICP: Developer + power users
  - Anti-patterns: No enterprise positioning, no "AI for everyone"

- [ ] **Content calendar created**
  - Release announcement template
  - Plugin spotlight schedule (1/week for 8 weeks)
  - Jane integration messaging
  - Social media style guide

- [ ] **Community channels ready**
  - Twitter @notchsh account created
  - GitHub Discussions enabled
  - Community handbook written

#### Launch Day (CMO + CTO)

- [ ] **Vault provisioned** (CTO + CMO)
  - 1Password bu-hud vault created
  - All secrets rotated and stored
  - access granted to CI/CD runners

- [ ] **GitHub Actions configured** (CTO)
  - Release automation workflow
  - Homebrew formula push
  - Sentry error tracking enabled

- [ ] **Metrics collection live** (CTO)
  - Scram Jet pipeline deployed
  - OpenDash /hud route returns data
  - Alerts configured in Hermes (CMO agent)

- [ ] **Social media go-live** (CMO)
  - @notchsh first tweet (release announcement)
  - GitHub Discussions pinned threads
  - Newsletter announcement (if applicable)

#### Post-Launch (CMO)

- [ ] **Monitor metrics** (daily for week 1)
  - Install counts trending correctly
  - Community engagement (Discussions, issues)
  - Error rates in Sentry

- [ ] **Plugin ecosystem nurture**
  - Respond to submission inquiries within 24h
  - Feature first plugin on @notchsh
  - Update docs based on feedback

### 5.3 Success Criteria

**Technical:**
- [ ] HUD discoverable via Homebrew (`brew install hud`)
- [ ] Jane daemon successfully connects to HUD API
- [ ] OpenDash shows real-time HUD metrics
- [ ] Scram Jet pipeline runs hourly without errors

**Marketing:**
- [ ] 100+ GitHub stars in week 1
- [ ] 50+ monthly active installs in month 1
- [ ] 1 community-submitted plugin in month 1
- [ ] @notchsh reaches 500 followers in month 1

**Operational:**
- [ ] CMO perceives HUD as a brand in agent reasoning
- [ ] Release cycle sustainable (2-week cadence)
- [ ] Community triage SLA met (24h response)

---

## PART 6: HUD VAULT SETUP CHECKLIST (CTO)

### Create 1Password Items

```bash
# 1. GitHub Release Bot
op item create \
  --category "Login" \
  --title "github-hud-releases" \
  --vault "bu-hud" \
  username="github-actions[bot]" \
  password="${GITHUB_RELEASE_TOKEN}"

# 2. Homebrew
op item create \
  --category "Login" \
  --title "homebrew-publish" \
  --vault "bu-hud" \
  username="homebrew-bot" \
  password="${HOMEBREW_GITHUB_TOKEN}"

# 3. Sentry
op item create \
  --category "Login" \
  --title "sentry-hud" \
  --vault "bu-hud" \
  username="sentry-dsn" \
  password="${SENTRY_DSN}"

# 4. API Mom
op item create \
  --category "Login" \
  --title "api-mom-credential" \
  --vault "bu-hud" \
  username="api-mom-key" \
  password="${API_MOM_API_KEY}"

# 5. Service Account
op user create \
  --email "sa-hud@atlas.internal" \
  --vault "bu-hud" \
  sa-hud
```

### GitHub Actions Secrets

Configure in `hud/.github/workflows/release.yml`:

```yaml
env:
  GITHUB_RELEASE_TOKEN: ${{ secrets.GITHUB_RELEASE_TOKEN }}
  HOMEBREW_GITHUB_TOKEN: ${{ secrets.HOMEBREW_GITHUB_TOKEN }}
  SENTRY_DSN: ${{ secrets.SENTRY_DSN }}
  API_MOM_API_KEY: ${{ secrets.API_MOM_API_KEY }}
```

---

## PART 7: CMO AGENT INTEGRATION (Pseudo-code)

When Hermes (CMO agent) launches, HUD is registered as a brand:

```typescript
// atlas/packages/board/src/cmo/seed.ts

export const seedBrands = [
  // Existing brands
  { slug: "llc-tax", name: "LLC Tax Tips", ... },
  { slug: "svg-generators", name: "SVG Generators", ... },

  // NEW: HUD as a brand
  {
    slug: "hud",
    name: "HUD",
    positioning: "The dashboard for always-listening AI",
    domain: "hud.notch.sh",
    channels: [
      { name: "Twitter", handle: "@notchsh", platform: "twitter" },
      { name: "GitHub", handle: "garywu/hud", platform: "github" },
    ],
    maturity: "production",
    monetization: "freemium",
    kpis: {
      monthlyInstalls: 500,
      githubStars: 1000,
      pluginEcosystemSize: 25,
    },
  },
];
```

CMO perceives HUD daily:
```typescript
// In CmoAgent.perceive()

const brandMetrics = {
  hud: {
    installs: 342,  // from Scram Jet
    stars: 643,     // from Scram Jet
    recentIssues: 12,
    pendingPlugins: 3,
  },
};

// CMO makes decisions
// e.g., "Plugin submissions trending up, feature a plugin this week"
```

---

## PART 8: HUD STRUCTURE & ROADMAP

### Directory Structure (hud/hq/)

```
hud/
├── hq/
│   ├── identity.yaml          ← Business unit card
│   ├── brand.yaml             ← Positioning, tone, ICP
│   ├── status.json            ← Current operational state
│   ├── handbook.md            ← Team handbook (minimalist)
│   │
│   ├── campaigns/
│   │   ├── 2026-q2-launch.md
│   │   ├── 2026-plugin-spotlights.md
│   │   └── 2026-jane-integration.md
│   │
│   ├── sops/
│   │   ├── secret-management.md
│   │   ├── macos-notch-deployment.md
│   │   ├── homebrew-release-pipeline.md
│   │   └── plugin-ecosystem-governance.md
│   │
│   ├── decisions/
│   │   ├── 001-separate-hud-from-jane.md
│   │   ├── 002-plugin-manifest-schema.md
│   │   └── 003-cmo-brand-positioning.md
│   │
│   ├── rfcs/
│   │   ├── RFC-HUD-001-v2-architecture.md
│   │   └── RFC-HUD-002-plugin-ecosystem.md
│   │
│   └── accounting/
│       └── budget.yaml        ← (if HUD has direct costs)
│
├── docs/
│   ├── API.md                 ← HTTP API reference
│   ├── PLUGIN-GUIDE.md        ← How to build plugins
│   ├── ARCHITECTURE.md        ← System design
│   └── examples/              ← Plugin examples
│
├── plugins/                    ← Bundled plugins (12)
│   ├── weather/
│   ├── git-status/
│   ├── docker-containers/
│   ├── system-stats/
│   ├── ai-status/
│   └── ...
│
└── README.md                  ← Product marketing
```

### V1.1+ Roadmap (informing CMO content calendar)

- **v1.0.1** (Week 1) — Bug fixes, Homebrew stability
- **v1.1** (Week 3) — Plugin ecosystem launch (submission guide, first 3rd-party plugin)
- **v1.2** (Week 6) — Jane daemon integration complete
- **v2.0** (Q3) — Voice input, local LLM routing, advanced avatar animations

---

## PART 9: TIMELINE & EFFORT ESTIMATE

### Sprint 1 (This Week): Registration & Setup
**Effort:** 2–3 days of focused work

- [ ] CMO creates brand.yaml + positioning (2h)
- [ ] CTO sets up 1Password vault (1h)
- [ ] Create identity.yaml (2h)
- [ ] Add HUD to CMO's seed data (1h)
- [ ] Test CMO perceives HUD (1h)
- **Total:** ~7 hours

### Sprint 2 (Following Week): Content Loop & Social
**Effort:** 3–4 days

- [ ] Create content calendar (2h)
- [ ] Write 3 release announcements (4h)
- [ ] Set up @notchsh Twitter account (1h)
- [ ] Configure social-good dispatch flow (2h)
- [ ] Test CMO → social-good → Twitter pipeline (2h)
- **Total:** ~11 hours

### Sprint 3 (Week after): Metrics & OpenDash
**Effort:** 3–4 days

- [ ] Implement Scram Jet pipeline (3h)
- [ ] Build OpenDash /hud panel (3h)
- [ ] Configure Sentry + monitoring (2h)
- [ ] Test full metrics loop (2h)
- **Total:** ~10 hours

### Grand Total: 8–11 days of coordinated work (CMO + CTO)

---

## PART 10: DECISION RECORD

**Decision:** Register HUD as a CMO-owned business unit
**Rationale:**
- HUD is a branded product with external users → needs marketing/positioning
- HUD has release cycles, community, ecosystem → needs brand continuity
- CMO must coordinate social presence (@notchsh)
- OpenDash must display HUD metrics for org visibility

**Alternatives Considered:**
1. **Keep HUD internal-only** → rejected (external users exist, public GitHub)
2. **Register under CTO only** → rejected (CMO needs brand/positioning control)
3. **Create separate "Tools" business unit** → rejected (too many entities; CMO/CTO coordination cleaner)

**Implications:**
- CMO's brand registry grows to 5+ brands
- Scram Jet pipeline count increases by ~3 (homebrew, github, plugin-registry)
- OpenDash dashboard adds new /hud panel
- Release coordination between CMO (messaging) and CTO (technical)

---

## APPENDIX A: SAMPLE CMO DISPATCH FOR HUD RELEASE

When HUD v1.1 releases, CMO perceives it and makes decisions:

```json
{
  "perception": {
    "hud": {
      "new_release": "v1.1.0",
      "release_notes": "Plugin ecosystem launch, 3 new bundled plugins",
      "github_stars": 643,
      "community_interest": "high"
    }
  },
  "decision": {
    "action": "dispatch-content",
    "channel": "twitter",
    "brand": "hud",
    "content_type": "release-announcement",
    "tone": "technical-delighted"
  },
  "dispatch_message": {
    "provider": "social-good",
    "service": "draft-generation",
    "context": {
      "brand": "hud",
      "feature": "v1.1 plugin ecosystem launch",
      "draft_style": "technical but celebratory",
      "include": ["github link", "plugin submission guide link"]
    }
  }
}
```

Result: social-good generates draft tweet → human approves → posted to @notchsh

---

## APPENDIX B: IDENTITY.YAML VALIDATION

Validate HUD's identity.yaml with:
```bash
# In atlas repo
pnpm run validate:business-units hud

# Should pass:
✓ identity.yaml schema valid
✓ All service endpoints documented
✓ Secrets referenced in 1Password exist
✓ SOP files exist in hq/sops/
✓ Owner (hermes) has agent definition
```

---

## APPENDIX C: MONITORING & ESCALATION

**CMO monitors HUD health via OpenDash:**
```
If installs drop > 10% week-over-week
  → CMO escalates to Hephaestus (CTO)
  → Creates GitHub issue (atlas#xxx: "HUD install decline investigation")
  → CTO investigates homebrew, Sentry errors, GitHub issues

If community sentiment negative (issues, Discussions)
  → CMO acknowledges within 24h
  → Escalates to Hephaestus if technical issue
  → Responds to feature requests publicly

If social engagement low
  → CMO revises content strategy
  → May launch "PluginSpotlight" weekly series
```

---

**STATUS:** Ready for implementation
**NEXT STEP:** Create `hud/hq/identity.yaml` + `hud/hq/brand.yaml` (CMO/Hermes)
