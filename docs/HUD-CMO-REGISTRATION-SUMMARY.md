# HUD CMO Registration — Quick Reference

**Date:** 2026-03-28
**Status:** Design complete, ready for implementation
**Owner:** Hermes (CMO) + Hephaestus (CTO)

---

## THE ASK

Register HUD (garywu/hud) as a **production business unit under CMO** (Hermes) in the Atlas conglomerate.

HUD is:
- A macOS platform product (notch display engine)
- Used internally (Jane daemon, Atlas board)
- Shipped publicly (Homebrew, 643 GitHub stars)
- Needs brand positioning (currently unbranded)
- Needs marketing/community management (CMO responsibility)

---

## DELIVERABLES (COMPLETED)

### 1. identity.yaml Template
**Location:** `hud/hq/identity.yaml`
**Size:** ~150 lines
**Contains:**
- Business unit metadata (name, slug, type=platform)
- 4 services HUD provides (notch rendering, HTTP API, notification OS, plugin system)
- 2 services HUD consumes (atlas observations, api-mom)
- Secret references to 1Password (GITHUB_RELEASE_TOKEN, HOMEBREW_TOKEN, etc.)
- KPIs (monthly installs, GitHub stars, plugin ecosystem size)
- 6 SOPs (secret-management, macos-deployment, homebrew-pipeline, plugin-governance)
- Goals (v1 release complete, Jane integration in-progress, plugin ecosystem pending)

**Status:** ✅ Designed, ready to create file

### 2. CMO Integration (Brand & Content)
**Components:**
- **Brand.yaml:** Positioning ("dashboard for always-listening AI"), ICP (developers/power users), tone (technical, delightful)
- **Content calendar:** Release announcements, plugin spotlights (1/week), Jane integration messaging
- **Social media:** @notchsh Twitter account, GitHub Discussions, Developer relations
- **Metrics:** Homebrew analytics, GitHub API (stars, releases), plugin registry health
- **Dispatch flow:** CMO perceives → makes decisions → dispatches to social-good → tweets posted

**Status:** ✅ Designed, ready to implement

### 3. Vault Setup (Secrets)
**Vault:** `bu-hud` under Atlas org in 1Password
**Items:**
- GITHUB_RELEASE_TOKEN (publish to releases)
- HOMEBREW_GITHUB_TOKEN (publish Homebrew formula)
- SENTRY_DSN (error tracking)
- API_MOM_API_KEY (bundled plugins data)
- JANE_WEBHOOK_SECRET (secure Jane notifications)

**Status:** ✅ Designed, CTO implements

### 4. Business Unit Relationships
**Dependencies:**
```
HUD ← provides display engine to → jane-daemon, atlas-serve
HUD ← consumes observations from → atlas
HUD ← consumes data from → api-mom
HUD ← metrics displayed in → OpenDash
HUD ← metrics collected by → Scram Jet
HUD ← brand positioning managed by → CMO (Hermes)
HUD ← release coordination with → CTO (Hephaestus)
```

**Status:** ✅ Documented

### 5. Launch Checklist
**CMO tasks:**
- [ ] Create brand.yaml (2h)
- [ ] Create content calendar (2h)
- [ ] Set up @notchsh Twitter (1h)
- [ ] Write 3 release announcements (4h)

**CTO tasks:**
- [ ] Create identity.yaml (2h)
- [ ] Set up 1Password vault (1h)
- [ ] Configure GitHub Actions CI/CD (3h)
- [ ] Implement Scram Jet pipeline (4h)
- [ ] Build OpenDash /hud panel (2h)

**Total effort:** ~22 hours over 3 sprints (8–11 days parallel)

**Status:** ✅ Designed

---

## WHAT'S IN THE DESIGN DOCUMENT

| Section | Content | Status |
|---------|---------|--------|
| Part 1 | Complete identity.yaml template | Ready |
| Part 2 | CMO integration (brand, content, metrics, social) | Ready |
| Part 3 | 1Password vault structure & secret management | Ready |
| Part 4 | Business unit relationships & dependency graph | Ready |
| Part 5 | Launch checklist & effort timeline | Ready |
| Part 6 | CTO vault setup instructions | Ready |
| Part 7 | CMO agent integration (pseudo-code) | Ready |
| Part 8 | HUD directory structure & roadmap | Ready |
| Part 9 | Timeline & effort estimate | Ready |
| Part 10 | Decision rationale & alternatives | Ready |
| Appendix A | Sample CMO dispatch for HUD release | Ready |
| Appendix B | identity.yaml validation | Ready |
| Appendix C | Monitoring & escalation procedures | Ready |

---

## KEY DECISIONS

**Decision 1: HUD is a platform product, not a content brand**
- Unlike llc-tax or svg-generators (content brands), HUD has an API and plugin ecosystem
- But it STILL needs CMO brand positioning and social presence
- **Implication:** CMO manages brand/positioning, CTO manages infrastructure

**Decision 2: CMO perceives HUD as a brand**
- CMO agent sees HUD in its daily brand registry
- CMO makes content decisions about HUD ("feature this plugin this week")
- CMO dispatches to social-good for Twitter posting
- **Implication:** Hermes queries `atlas-cmo` D1 table for HUD metrics and state

**Decision 3: Metrics flow Layer 1 → Layer 3 (no direct agent API calls)**
- Scram Jet (Layer 1) collects Homebrew, GitHub, plugin registry data → D1
- OpenDash (Layer 3) displays HUD metrics
- CMO reasons over D1 data, doesn't call external APIs
- **Implication:** New Scram Jet pipeline for `hud-metrics.yaml`

**Decision 4: Release coordination is CMO ↔ CTO**
- CTO: technical release (GitHub Actions, Homebrew formula publish)
- CMO: messaging release (content calendar, @notchsh tweets)
- No single source of truth — async coordination via GitHub issues
- **Implication:** SOP documents the process clearly

---

## IMPLEMENTATION ORDER (3 Sprints)

### Sprint 1: Registration (CTO + CMO, 2–3 days)
1. [ ] CMO: Create `hud/hq/brand.yaml`
2. [ ] CTO: Create `hud/hq/identity.yaml`
3. [ ] CTO: Set up `bu-hud` vault in 1Password
4. [ ] CTO: Add HUD to CMO's seed data (`atlas-cmo` D1)
5. [ ] Test: CMO agent perceives HUD

**Blockers:** None
**Risk:** Low

### Sprint 2: Content Loop (CMO, 3–4 days)
1. [ ] CMO: Create `hud/hq/campaigns/` folder
2. [ ] CMO: Write content calendar (release announcements, plugin spotlights)
3. [ ] CMO: Set up @notchsh Twitter account (or coordinate with social-good)
4. [ ] CTO: Test social-good dispatch flow (CMO → social-good → Twitter)
5. [ ] Test: End-to-end release announcement

**Blockers:** Sprint 1 complete
**Risk:** Medium (social-good API contract may need tweaking)

### Sprint 3: Metrics & Monitoring (CTO, 3–4 days)
1. [ ] CTO: Implement `atlas/hq/pipelines/hud-metrics.yaml` (Scram Jet)
2. [ ] CTO: Build `/hud` panel in OpenDash
3. [ ] CTO: Configure Sentry for HUD error tracking
4. [ ] CTO: Set up KPI alerts (install drop, error spike)
5. [ ] Test: CMO sees real-time HUD metrics in OpenDash

**Blockers:** Sprint 1 complete
**Risk:** Medium (Scram Jet pipeline syntax)

---

## SUCCESS CRITERIA

**Technical:**
- [ ] HUD discoverable via Homebrew
- [ ] Jane daemon connects to HUD API without errors
- [ ] OpenDash /hud panel shows real-time install, star, ecosystem metrics
- [ ] Scram Jet pipeline runs hourly without errors
- [ ] CMO agent reasons about HUD in daily cycle

**Marketing:**
- [ ] HUD positioned clearly: "dashboard for always-listening AI"
- [ ] @notchsh Twitter account active (posts 2–3x/week)
- [ ] GitHub Discussions answered within 24h
- [ ] 100+ new GitHub stars in month 1
- [ ] 50+ monthly active installs by month 1

**Operational:**
- [ ] Release coordination (CMO ↔ CTO) defined and tested
- [ ] 2-week release cadence sustainable
- [ ] Community triage SOP documented and followed
- [ ] Secrets rotated on schedule (quarterly)

---

## RISKS & MITIGATION

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| CMO dispatch to social-good fails | Medium | HUD releases go unannounced | Test dispatch flow in Sprint 2 before going live |
| Homebrew formula becomes stale | Low | Install counts drop | Automate via GitHub Actions in v1.1 |
| Plugin submission spam | Low | Community quality suffers | Implement manifest validation + admin review gate |
| CMO perceive cycle misses HUD | Medium | HUD metrics not visible to agents | Add HUD to CMO seed data + add test |
| Scram Jet pipeline errors | Medium | OpenDash metrics stale | Monitor pipeline logs daily in Sprint 3 |

---

## NEXT STEPS

### Immediate (Today)
1. [ ] Share design document with Hermes (CMO) and Hephaestus (CTO)
2. [ ] Confirm brand positioning with Hermes
3. [ ] Confirm 1Password vault setup with Hephaestus
4. [ ] Create GitHub issue (atlas#XXX: "HUD Business Unit Registration") to track progress

### This Week (Sprint 1)
1. [ ] Create `hud/hq/identity.yaml`
2. [ ] Create `hud/hq/brand.yaml`
3. [ ] Set up 1Password `bu-hud` vault
4. [ ] Add HUD to CMO seed data
5. [ ] Test CMO perceives HUD

### Next Week (Sprint 2)
1. [ ] Create content calendar
2. [ ] Set up @notchsh Twitter
3. [ ] Test CMO → social-good dispatch
4. [ ] Write 3 release announcements

### Following Week (Sprint 3)
1. [ ] Implement Scram Jet pipeline
2. [ ] Build OpenDash /hud panel
3. [ ] Configure monitoring & alerts
4. [ ] Public launch of @notchsh

---

## FILES CREATED

**Today:**
- `/Users/admin/Work/HUD-CMO-REGISTRATION-DESIGN.md` — Full design (this document + Appendices)
- `/Users/admin/Work/HUD-CMO-REGISTRATION-SUMMARY.md` — This quick reference

**To be created:**
- `hud/hq/identity.yaml` — Business unit card
- `hud/hq/brand.yaml` — Brand positioning
- `hud/hq/status.json` — Operational state
- `hud/hq/campaigns/2026-q2-launch.md` — Release announcements
- `hud/hq/sops/macos-notch-deployment.md` — SOP
- `atlas/packages/board/src/cmo/seed.ts` — Add HUD to CMO's brands (updated)
- `atlas/hq/pipelines/hud-metrics.yaml` — Scram Jet pipeline

---

## KEY CONTACTS

**CMO (Hermes):** @hermes (agent)
**CTO (Hephaestus):** @hephaestus (agent)
**HUD Owner:** gary (human, external)
**Social-Good Owner:** (check identity.yaml)
**OpenDash Owner:** (check identity.yaml)

---

**Document status:** ✅ Design complete, ready for implementation
**Last updated:** 2026-03-28
**Next review:** After Sprint 1 completion
