# Jane HUD — Product Hunt Launch Plan
## Go-to-Market Strategy for Persistent AI Companion with Face, Voice, Memory

**Launch Date Target:** April 15, 2026 (Tuesday)
**MVP Status:** v1.0.0 shipped, ready for public launch
**Business Model:** MIT open-core + $25/mo Pro tier
**Success Target:** Top 5 in category day 1, 500+ upvotes, 50+ presales

---

## 1. LAUNCH NARRATIVE: THE JANE STORY

### Core Message
> Jane is not a chatbot you visit. She's an always-present AI companion living in your MacBook notch — with a face, a voice, persistent memory, and local superpowers. She remembers what you said last week. She listens without you asking. She controls your apps, accesses your files, and runs deep research in the background.

### The Problem We're Solving
Current AI assistants suffer from **fragmentation and forgetfulness**:

- **ChatGPT/Claude:** Powerful but ephemeral — you type, they respond, they forget
- **Siri/Alexa:** Always-listening but dumb — they handle timers but not reasoning
- **Claude Code:** Deep local access but task-scoped — exists only during coding
- **AI companion apps:** Emotional presence but no capability — can't touch your files

**The gap:** No product combines persistent memory + voice interaction + local machine access + ambient visual presence + deep AI reasoning.

### Jane Fills the Gap
Jane is a **persistent daemon with personality**:

- **Face:** Expressive avatar in the notch, reacting to what she hears and says
- **Voice:** Natural speech input (Whisper/WhisperKit) and output (ElevenLabs quality)
- **Memory:** 3-tier persistent memory spanning weeks/months (core + context + archive)
- **Local Superpowers:** File access, AppleScript/JXA automation, 1Password integration, system monitoring
- **Always There:** Listens for wake word, surfaces proactive alerts, remembers context
- **Open Core:** MIT-licensed platform + cloud-optional premium features

### The Jane Origin
*Optional narrative hook (for Product Hunt tagline):*
"Named after Jane from Ender's Game — an AI always in Ender's ear, outside the system, bridging human and everything. Gary's AI companion, now open to the world."

### Value Propositions
1. **For Developers:** Open-source notch platform, plugin ecosystem, API-driven, self-hosted capable
2. **For Knowledge Workers:** AI secretary that remembers conversations, finds files, and thinks alongside you
3. **For Mac Power Users:** System monitoring, automation, and ambient intelligence in one place
4. **For Privacy-Conscious Users:** Local-first architecture, self-hosted option, no chat logs sent to cloud by default

---

## 2. LANDING PAGE OUTLINE

### Page Structure & Messaging

#### Hero Section (Above Fold)
```
Headline: "Meet Jane — Your AI Companion Lives in the Notch"

Subheadline: "A persistent voice, a face you'll recognize, a memory that remembers.
Now open source."

Hero Image:
- Animated notch avatar with expression changing
- Sparkline graphs in background (system monitoring)
- Voice waveform pulsing
- Call to action: "Get Started Free" + "View on GitHub"

Stats Row:
- v1.0.0 shipped | MIT Licensed | 3,000+ GitHub stars* | Works offline
```

#### Problem/Solution Section (2-3 Scrolls Down)
```
Title: "AI Assistants Don't Work Like This"

Visual: Before/After grid
BEFORE:
- Open ChatGPT tab
- Type question
- Close tab
- Forget context
- Manual calendar check

AFTER:
- "Jane, what did Sarah recommend?"
- Instant voice response
- Jane remembers context from last week
- Proactive meeting alerts
- Files found automatically

Supporting Text:
"Existing AI lives in browser tabs or phone apps. Jane lives on your Mac,
watches your screen, listens when you speak, and thinks alongside you—
without requiring activation. She's not a chatbot. She's a daemon."
```

#### Features Section (Scannable Features + Graphics)
```
Layout: 3 columns × 2 rows, each with icon + headline + description

1. PERSISTENT MEMORY
   "Remembers conversations spanning weeks and months. Uses a 3-tier
   architecture: core memory (recent context), context (recent chat),
   archival (searchable recall). Privacy-first — memories stay on your Mac."

2. VOICE & FACE
   "Hears you through wake word detection. Speaks with natural voice via
   ElevenLabs TTS. Expressive avatar in the notch reacts to what she's
   hearing and saying. Lip-sync and idle animations included."

3. LOCAL SUPERPOWERS
   "Accesses your file system, controls apps via AppleScript/JXA, checks
   1Password, monitors system state. Runs deep research in the background.
   Offline-capable for core features."

4. AMBIENT INTELLIGENCE
   "Always in the corner of your eye. Proactive alerts for meetings,
   system issues, research results. Never intrusive. Respects focus modes.
   Extensible via HTTP API."

5. OPEN SOURCE PLATFORM
   "MIT-licensed notch display platform with 12+ plugins. Build your own
   LLM pipeline. Router between local Ollama and cloud APIs. Full control
   over costs and models."

6. PLUGIN ECOSYSTEM
   "Extend with custom plugins (manifest.json + run.sh). Recipes included:
   SRS flashcards, system monitors, deep research, weather, calendar sync.
   Community-driven."
```

#### Pricing Section
```
Title: "Open Core + Premium"

Pricing Cards:

FREE (MIT Open Source)
- Jane daemon (voice, face, memory)
- 3-tier persistent memory
- Local file/app access
- Wake word detection
- API for plugins
- Self-hosted option
- $0/month
[GitHub button] [Local Setup]

PRO ($25/month)
- Everything in Free +
- Cloud sync (encrypted)
- Multiple-device sync
- Priority model access (Opus, o3)
- Deep research integration (Perplexity)
- Voice cloning (custom voice for Jane)
- Email-based proactive alerts
- 1Password vault integration (encrypted)
- 50 GB memory archive storage
- [No vendor lock-in. Cancel anytime.]
- $25/month [Start 7-day free trial]

Feature comparison table:
- Persistence: Free = Local only | Pro = Cloud + local
- Voice models: Free = Basic TTS | Pro = Premium TTS + voice clone
- API limits: Free = 100 req/day | Pro = Unlimited
- Research: Free = Manual | Pro = Async deep research
- Device sync: Free = Single Mac | Pro = Up to 5 Macs
```

#### Social Proof Section
```
"Built with" logos:
- Anthropic Claude API
- Cloudflare Workers (backend)
- Whisper/WhisperKit (speech)
- ElevenLabs TTS
- Open source community stars (if available pre-launch)

Testimonial Callout (Gary's perspective):
"I built Jane because I was tired of asking ChatGPT the same questions
twice. I needed an AI that remembers, listens, and thinks while I work.
That's a local daemon with a face, not a chat window."
—Gary Wu, Creator
```

#### CTA Section (Bottom)
```
Primary CTAs:
- [Get Started Free] → Setup guide + GitHub
- [View Architecture] → Full tech deep-dive

Secondary:
- [Try Demo] (if video available)
- [Join Discord] → Community + support
- [Read the Code] → GitHub repo
```

#### Footer
```
Links:
- GitHub: github.com/garywu/hud
- Docs: jane.ai (or domain TBD)
- Discord: (community invite)
- Privacy: Self-hosted, no telemetry by default
- License: MIT

Badges:
- "macOS only (Apple Silicon + Intel)"
- "v1.0.0 — Production ready"
- "Open source + optional paid cloud features"
```

---

## 3. DEMO VIDEO SCRIPT (90 seconds)

### Structure: Problem → Solution → Future

**[0:00-0:10] COLD OPEN — Problem**
```
VISUAL: Screen showing typical workflow
- User opens ChatGPT, types question, waits, closes tab
- User opens Calendar app, manually checks schedule
- User searches emails for attachment

VOICEOVER (female voice, warm):
"You ask your AI the same question twice.
It forgets. Every time.

You check your calendar manually.
Your AI doesn't know what's coming.

You dig through emails for that one file.
Your AI can't help."

SFX: Subtle frustration tone, clock ticking
```

**[0:10-0:25] MEET JANE**
```
VISUAL: MacBook screen, notch visible
- Jane's avatar animates in the notch (smiling, alert)
- Waveform pulsing around her face

VOICEOVER:
"Meet Jane.

She's not a chatbot.
She's a daemon with a face."

SFX: Subtle uplifting tone, ambient synth
```

**[0:25-0:45] WHAT SHE CAN DO**
```
VISUAL: Quick montage, each scene 4-5 seconds

Scene 1: USER SPEAKS → JANE LISTENS
- User says: "Jane, what did Sarah recommend for dinner?"
- Jane's avatar tilts, listens (ear animation)
- Text appears: "Processing..."
- Jane responds: "The Thai place in Hayes Valley. You sent her a text about it Tuesday."
- Visual: Jane's face lights up with confidence

Scene 2: JANE REMEMBERS
- Screen shows memory interface (optional detail view)
- Text: "Tuesday 3:47 PM - Sarah recommended Thai, Hayes Valley"
- Jane remembered across a week, without being asked to save anything

Scene 3: JANE PROACTIVE
- Meeting appears in calendar
- Jane's avatar pulses gently in notch: "Your standup starts in 5 minutes"
- Text: "Jane knows your prep preferences and surfaces meetings proactively"

Scene 4: JANE ACCESSES YOUR FILES
- User: "Find the PDF Dave sent about Q3 budget"
- Jane: "Found it. Opening now."
- PDF appears on screen (file system access shown)

VOICEOVER (continuous, energetic):
"She remembers what you said last week.
She listens when you speak.
She accesses your files.
She thinks alongside you.
She never forgets."

SFX: Building energy, subtle uplifting soundtrack
```

**[0:45-0:65] OPEN SOURCE & ARCHITECTURE**
```
VISUAL: Brief technical showcase (subtle, not overwhelming)
- Terminal with `hud start`
- HTTP API response (JSON snippet)
- Plugin architecture diagram (simple)
- Memory tier visualization (core → context → archive)

VOICEOVER:
"Jane is open source. MIT licensed.
Self-hosted. Your data, your control.

Cloud-optional. Run locally. Connect your own models.
Router between Ollama and cloud APIs.
Full transparency. Full extensibility."

SFX: Confident, technical undertone
```

**[0:65-0:90] CALL TO ACTION & VISION**
```
VISUAL:
- Return to Jane in notch
- Expand to show potential: home office, user working, Jane ambient presence
- Fade to clean notch with Jane avatar
- Text overlay: "Open Source | Always-On | Your AI Companion"

VOICEOVER:
"Jane is an ambient intelligence that lives with you.
Not a chatbot you visit.
Not a voice assistant that forgets.

A persistent companion. With a face. With memory.
With superpowers.

Open source. Ready now.

Join us."

CLOSING VISUAL:
- Jane winks or smiles
- Text: "jane.ai" or "Get Started Free on GitHub"
- Buttons: [Get Started] [Learn More]

SFX: Final uplifting chord, fade to silence
```

### Visual Style Guidance
- **Color:** Minimal, notch-friendly palette (accent colors from themes)
- **Motion:** Smooth, purposeful animations (no jitter)
- **Pace:** Brisk but readable (1.5x normal speech speed)
- **Voice:** Warm, confident, slightly conversational (not robotic)
- **Text Overlays:** Clean, sans-serif, minimal (let demo speak)
- **B-roll:** Real MacBook notch, real use cases, authentic workflows

### Voice Casting
- Female voice recommended (aligned with Jane identity)
- Natural accent, conversational tone
- Professional but personable (not corporate)
- Consider: ElevenLabs custom voice for authenticity

---

## 4. LAUNCH DAY TIMELINE

### Phase 1: Pre-Launch (Week of April 7)

#### Tuesday, April 7 (T-8 days)
- [ ] **Soft launch on GitHub Discussions** — Announce Product Hunt launch date
- [ ] **Discord announcement** — Community rally (link server)
- [ ] **Twitter/X teaser thread** — "In 8 days, Jane launches on Product Hunt"
- [ ] **Email to past contributors/users** (if applicable) — Early access link, ask for launch day support

#### Wednesday, April 8 (T-7 days)
- [ ] **Product Hunt pre-launch setup:**
  - [ ] Create Product Hunt account (if needed)
  - [ ] Fill in all fields (tagline, gallery, description, demo video)
  - [ ] Add pricing ($0 free, $25/mo Pro)
  - [ ] Prepare discussion starter question
  - [ ] Test all links (GitHub, landing page, Discord)
- [ ] **Media outreach begins** — Pitch to tech journalists, product blogs
  - Target: MacRumors, 9to5Mac, Product Hunt newsletter editors
  - Angle: "Open-source AI companion, not a chatbot, lives in notch"
- [ ] **Cross-promotion prep:**
  - [ ] Design Twitter card (Jane face, notch visual)
  - [ ] Prepare Discord announcements (timing, copy)
  - [ ] Ready GitHub topics, tags for discoverability

#### Thursday, April 9 (T-6 days)
- [ ] **Hunter recruitment** — Identify 2-3 Product Hunt influencers to support launch
  - Target: Hunters with 5K+ followers, prior open-source wins
  - Pitch: Early demo access + discount codes for Pro tier
- [ ] **Landing page final review** — Ensure video, pricing, CTAs are locked
- [ ] **Demo video finalization** — Audio mix, color grade, final export
- [ ] **Prepare launch day content:**
  - [ ] Twitter threads (3-5 planned)
  - [ ] Hacker News post ready
  - [ ] Reddit /r/MacApps post ready
  - [ ] Dev.to cross-post ready

#### Friday, April 10 (T-5 days)
- [ ] **Media check-in** — Follow up with journalists who showed interest
- [ ] **Community mobilization:**
  - [ ] Post in relevant Discord communities (AI, Mac, open-source)
  - [ ] Tag relevant accounts on Twitter (Anthropic, Cloudflare, open-source communities)
- [ ] **Product Hunt page goes live** — Set to 12:01 AM PT Monday, April 13

#### Monday, April 13 (T-2 days)
- [ ] **Final 48-hour push begins:**
  - [ ] Send reminder email to launch support network
  - [ ] Prepare Product Hunt discussion response templates
  - [ ] Test all demo links, redirects, download flows one final time
  - [ ] Confirm hunter support (they'll post on launch day)
- [ ] **Set up monitoring:**
  - [ ] Create dashboard for PH upvotes, comments, traffic
  - [ ] Monitor GitHub stars spike
  - [ ] Track landing page analytics
  - [ ] Set up Discord moderation for incoming users

#### Tuesday, April 15 (T-0, LAUNCH DAY)

##### 11:45 PM PT, Monday (45 min before)
- [ ] **Pre-flight checks:**
  - [ ] Product Hunt page loaded (refreshed, no errors)
  - [ ] GitHub repo pinned to top of account
  - [ ] Discord server ready (welcome message, links to docs)
  - [ ] Twitter scheduled posts queued (first post at 12:01)
  - [ ] Landing page live and responsive
  - [ ] Email template ready for inbound inquiries

##### 12:01 AM PT Tuesday (LAUNCH)
- [ ] **Go live on Product Hunt** — Page auto-posts (if scheduled correctly)
- [ ] **Twitter launch thread** — First post with link, demo video, key point
  - Tag: @ProductHunt @AnthropicAI @garywu
  - Include: Jane story, "Ship of the Day" angle, GitHub link
- [ ] **Post on Hacker News** — "Show HN: Jane — Persistent AI Companion for macOS Notch"
  - Include: Problem statement, architecture overview, GitHub
- [ ] **Discord announcement** — "We're live on Product Hunt!" + link
- [ ] **Reddit /r/MacApps** — "Jane: Open-Source AI Companion in Your Notch"
- [ ] **Dev.to cross-post** — Full architecture article with PH link

##### 6:00 AM-8:00 AM PT (Morning rush)
- [ ] **Active engagement begins:**
  - [ ] Reply to every Product Hunt comment within 15 min
  - [ ] Answer technical questions thoroughly
  - [ ] Acknowledge and engage with Hacker News thread
  - [ ] Monitor Twitter mentions, retweet support
  - [ ] Encourage early users to post feedback
- [ ] **Secondary wave promotions:**
  - [ ] Post on Product Hunt Forums (new feature)
  - [ ] Post in relevant Slack communities (with permission)
  - [ ] Encourage hunters to share with their networks

##### 12:00 PM PT (Midday)
- [ ] **Check-in on metrics:**
  - [ ] Review upvote count, rank in category
  - [ ] Identify top comments/concerns
  - [ ] Prepare responses to common questions
  - [ ] Check GitHub star growth (target: 200-300 new stars by now)
- [ ] **Tertiary content drops:**
  - [ ] Share a behind-the-scenes tweet (development journey)
  - [ ] Post technical deep-dive thread (memory architecture, voice stack)
  - [ ] Discord: Share user testimonials if any early adopters

##### 5:00 PM PT (Afternoon peak)
- [ ] **Press monitoring:**
  - [ ] Check if any media outlets picked it up (9to5Mac, Product Hunt newsletter)
  - [ ] Share press mentions to social
  - [ ] Engage with journalists if they covered launch
- [ ] **Continue engagement:**
  - [ ] Maintain <15 min response time on comments
  - [ ] Offer early access to Pro tier ($25/mo discount codes)
  - [ ] Collect feature requests, add to GitHub Issues
- [ ] **Community moderation:**
  - [ ] Keep Discord welcoming, on-topic
  - [ ] Pin FAQs and setup links
  - [ ] Identify power users, invite to feedback group

##### 10:00 PM PT (Evening)
- [ ] **EOD standup:**
  - [ ] Final upvote count for the day
  - [ ] Top comment threads to monitor overnight
  - [ ] Early user feedback summary
  - [ ] Identify any blockers (bugs, documentation issues)
- [ ] **Plan overnight actions:**
  - [ ] Set up auto-responses for Product Hunt comments
  - [ ] Schedule follow-up tweets for next morning
  - [ ] Prepare early morning response team (timezone coverage)

### Phase 2: Launch Week (April 15-21)

#### Tuesday, April 15 continued
- [ ] End-of-day metrics (upvotes, position in category)
- [ ] Prepare for 24-hour push through Wednesday

#### Wednesday, April 16
- [ ] **Day 2 momentum:**
  - [ ] Check if "Ship of the Day" featured (if applicable)
  - [ ] Second round of media outreach (follow-ups)
  - [ ] Engage with emerging community discussions
  - [ ] Address common setup/bug issues
- [ ] **Engagement goals:**
  - [ ] Target: 300+ upvotes by end of day
  - [ ] Monitor ranking in "AI Agents" or "AI Software" category

#### Thursday, April 17
- [ ] **Sustained engagement:**
  - [ ] Post first user testimonial (if available)
  - [ ] Share GitHub milestone (500 stars, 1K stars)
  - [ ] Begin onboarding support for new users
  - [ ] Prepare feature roadmap post (transparently show future plans)

#### Friday, April 18-Sunday, April 20
- [ ] **Post-launch consolidation:**
  - [ ] Compile feedback into GitHub Issues (prioritized)
  - [ ] Plan Week 1 bug fixes/improvements
  - [ ] Prepare "Thank You" post on Product Hunt (Sunday)
  - [ ] Invite top supporters to advisory group

#### Monday, April 21
- [ ] **Week 1 wrap-up:**
  - [ ] Publish "Product Hunt Launch Retrospective" (GitHub Discussions)
  - [ ] Share metrics (upvotes, stars, email signups, Discord members)
  - [ ] Announce first week improvements (if any quick wins)
  - [ ] Plan Week 2: feature requests, bug fixes, documentation

---

## 5. PRICING PAGE MOCKUP

### Visual Layout

```
┌─────────────────────────────────────────────────────────────┐
│ JANE PRICING                                                 │
│ Open Core + Optional Cloud                                  │
│                                                              │
│ Choose your path:                                           │
│ Free forever with local Jane.                               │
│ $25/mo for cloud sync and premium models.                   │
│ Cancel anytime. No lock-in.                                 │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────────┬──────────────────────────────────┐
│ FREE                     │ PRO                              │
│ Open Source              │ Cloud-Enabled                    │
│                          │                                  │
│ $0/month                 │ $25/month                        │
│ [Get Started]            │ [Start Free Trial]               │
│                          │                                  │
│ CORE FEATURES            │ EVERYTHING IN FREE +             │
│ ✓ Jane daemon            │ ✓ Cloud memory sync              │
│ ✓ Voice (Whisper)        │   (encrypted end-to-end)         │
│ ✓ Face & avatar          │ ✓ Multi-device sync              │
│ ✓ 3-tier memory          │   (up to 5 Macs)                 │
│   (local only)           │                                  │
│ ✓ Local file access      │ ADVANCED AI                      │
│ ✓ App control (JXA/AS)   │ ✓ Priority access to             │
│ ✓ Wake word detection    │   Claude Opus, o3                │
│ ✓ Plugin system          │ ✓ Perplexity deep research       │
│ ✓ 12+ plugins included   │   integration                    │
│ ✓ System monitoring      │ ✓ Voice cloning                  │
│ ✓ HTTP API               │   (custom voice for Jane)        │
│ ✓ Self-hosted            │                                  │
│ ✓ MIT licensed           │ PRODUCTIVITY                     │
│                          │ ✓ Email-based proactive         │
│ LIMITS                   │   alerts                         │
│ • 100 API requests/day   │ ✓ 1Password vault integration    │
│ • Single device          │   (encrypted sync)               │
│ • Manual research only   │ ✓ Calendar + contacts sync       │
│ • Local models only      │                                  │
│                          │ STORAGE & SYNC                   │
│ PERFECT FOR              │ ✓ 50 GB memory archive           │
│ • Developers             │   (3-month retention)            │
│ • Self-hosters           │ ✓ Cross-device backup            │
│ • Privacy-first users    │ ✓ Export your memory             │
│ • Learning & evaluation  │                                  │
│                          │ LIMITS                           │
│                          │ • Unlimited API requests         │
│                          │ • Up to 5 Macs/devices           │
│                          │ • Async deep research            │
│                          │ • Cloud model access             │
│                          │                                  │
│                          │ PERFECT FOR                      │
│                          │ • Knowledge workers              │
│                          │ • Teams & professionals          │
│                          │ • Multi-device setup             │
│                          │ • Deep research workflows        │
│                          │ • Those valuing convenience      │
│                          │                                  │
└──────────────────────────┴──────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ FEATURE COMPARISON TABLE                                     │
├───────────────────────────┬──────────────┬─────────────────┤
│ Feature                   │ Free         │ Pro             │
├───────────────────────────┼──────────────┼─────────────────┤
│ Jane daemon               │ ✓            │ ✓               │
│ Voice input (Whisper)     │ ✓            │ ✓               │
│ Voice output (TTS)        │ Basic EL     │ Premium EL + *  │
│ Avatar & animation        │ ✓            │ ✓               │
│ Memory (local)            │ 30 days      │ 3 months        │
│ Memory (cloud sync)       │ —            │ ✓               │
│ Multi-device sync         │ —            │ ✓               │
│ Voice cloning             │ —            │ ✓               │
│ Model priority            │ Haiku/mini   │ Opus/o3         │
│ Deep research integration │ Manual       │ Async/proactive │
│ 1Password integration     │ —            │ ✓               │
│ Calendar sync             │ —            │ ✓               │
│ File access               │ ✓            │ ✓               │
│ App control               │ ✓            │ ✓               │
│ Plugin system             │ ✓            │ ✓               │
│ HTTP API                  │ 100 req/day  │ Unlimited       │
│ Self-hosted option        │ ✓            │ ✓               │
│ Export data               │ ✓ (JSON)     │ ✓               │
│ Custom models (Ollama)    │ ✓            │ ✓               │
│ Price                     │ $0           │ $25/month       │
└───────────────────────────┴──────────────┴─────────────────┘

* Pro tier includes access to voice cloning, allowing a custom voice
  for Jane (choose from 29+ premium voices or clone your own).

┌─────────────────────────────────────────────────────────────┐
│ WHY THE PRICING MODEL?                                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ OPEN SOURCE AT CORE                                          │
│ Jane daemon, plugins, memory architecture = MIT licensed.    │
│ Zero cost to run locally. No limits on local-only features.  │
│                                                              │
│ CLOUD IS OPTIONAL, NOT REQUIRED                              │
│ Don't want cloud? Free tier runs fully locally. Your data,   │
│ your machine, your control.                                  │
│                                                              │
│ PRO COVERS REAL COSTS                                        │
│ Cloud sync (database + encryption): ~$8/user/month          │
│ Premium model access (Opus, o3): ~$10/user/month            │
│ Voice cloning + ElevenLabs premium: ~$5/user/month          │
│ Perplexity integration: ~$2/user/month                       │
│ Total: ~$25/month (plus profit for team, operations)         │
│                                                              │
│ NO LOCK-IN                                                   │
│ Cancel anytime. Export all your data in JSON. Self-host if   │
│ you want. Open source means you're never stranded.           │
│                                                              │
│ WHO USES FREE vs PRO?                                        │
│ Free: Solo developers, privacy-first users, evaluating Jane, │
│       self-hosters, students, open-source enthusiasts       │
│ Pro: Teams, knowledge workers, multi-device users, those     │
│      wanting cloud convenience & premium AI models          │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ GETTING STARTED                                              │
├─────────────────────────────────────────────────────────────┤
│ Free:  [Get Started] → GitHub → `hud start` → Docs         │
│ Pro:   [Try 7 Days Free] → Create account → Install Pro    │
│        Includes API key + cloud sync setup                  │
│                                                              │
│ Questions? Discord community or support@jane.ai (Pro tier)  │
└─────────────────────────────────────────────────────────────┘
```

### Additional Pricing Context

**Payment Processing:**
- Stripe for subscriptions (card, Apple Pay, Google Pay)
- Annual option available (2 months free): $250/year → $240/year
- Free trial: 7 days, no credit card required
- Refund policy: 30-day money-back guarantee

**Billing & Cancellation:**
- Monthly billing on the 15th
- Cancel anytime via account dashboard
- Downgrade to free (data remains, cloud features disabled)
- Export option: Download all memory data in JSON format

**Pro Tier Justification:**
- Each Pro user on cloud requires ~$8-10/month infrastructure (hosting, DB, encryption)
- Model costs (Opus, o3 access): ~$5-10/month per heavy user
- Voice cloning + premium TTS: ~$3-5/month
- Perplexity integration (async research): ~$1-2/month
- $25/month covers costs + team operations + improvements

---

## 6. SUCCESS METRICS & TARGETS

### Launch Day (April 15)

| Metric | Target | Rationale |
|--------|--------|-----------|
| **Product Hunt Upvotes** | 300+ | Top 5 in "AI Agents" category |
| **Ranking** | Top 5 daily | Comparable to other dev tools launches |
| **Comments Engagement** | <15 min avg response time | Build trust, address concerns quickly |
| **GitHub Stars (new)** | 200-300 | Spike from PH traffic |
| **Landing Page Views** | 5K-10K | From PH, Twitter, HN |
| **Discord Joins** | 200-300 | Community formation |
| **Pro Signups** | 20-30 | Early believers in cloud features |
| **Media Mentions** | 2-3 | 9to5Mac, MacRumors, or similar |

### Week 1 (April 15-21)

| Metric | Target | Rationale |
|--------|--------|-----------|
| **Total Upvotes** | 500+ | Sustained engagement after launch day |
| **"Ship of the Day"** | 1-2 times | Recognition from PH curation |
| **GitHub Stars (cumulative)** | 800-1K | Growth through word-of-mouth |
| **Email Signups** | 500-800 | Newsletter + early access list |
| **Pro Tier Signups** | 50-80 | Paid conversion targets |
| **Discord Members** | 400-600 | Engaged community |
| **Press Coverage** | 3-5 articles | Expansion to tech blogs, podcasts |
| **Hacker News Ranking** | Top 10 | Relevant to dev community |

### Month 1 (April 15 - May 15)

| Metric | Target | Rationale |
|--------|--------|-----------|
| **GitHub Stars** | 3K-5K | Sustained growth, word-of-mouth |
| **Pro Annual Recurring Revenue (ARR)** | $3K-5K | 100-200 paying customers |
| **Discord Members** | 1K+ | Active community |
| **Landing Page Conversions** | 5-8% | Free + Pro tier combined |
| **Press Mentions** | 10+ | Broader tech media, podcasts |
| **Featured/Discussed In** | 3-5 | Product Hunt Forums, Twitter spaces, podcasts |

### Success Definition
Launch is **successful** if we achieve:
1. **Top 5 ranking** on Product Hunt for "AI Agents" or top 20 overall
2. **1K+ GitHub stars** within first month
3. **500+ paying Pro subscribers** within Q2 2026
4. **Sustainable feedback loop** (active GitHub issues, Discord discussions)
5. **Press validation** (3+ major tech outlets covering Jane)
6. **Community contributions** (first 5+ community plugins submitted)

---

## 7. COMMUNITY STRATEGY

### Discord
**Purpose:** Real-time support, feedback loop, plugin showcase

**Channels:**
- `#introductions` — New members introduce themselves
- `#announcements` — Major updates, feature releases
- `#general` — Chat and off-topic
- `#support` — Technical help, setup questions
- `#plugins` — Share and discuss custom plugins
- `#roadmap` — Feature voting, roadmap discussions
- `#showcase` — User stories, automation showcases
- `#dev` — Development discussions, architecture

**Moderation:**
- Response SLA: <1 hour during US business hours
- Pin FAQ in #support (setup, common issues, model routing)
- Weekly digest of top questions → FAQ updates
- Highlight community plugins in announcements

### GitHub Discussions
**Purpose:** Asynchronous feedback, feature requests, knowledge base

**Categories:**
- `Announcements` — Releases, updates, milestones
- `Feature Requests` — Vote on new capabilities
- `Troubleshooting` — Technical help with issue tracking
- `Show & Tell` — Community projects, plugins, use cases
- `Ideas` — Brainstorm and discuss future directions

**Engagement:**
- Triage all discussions into GitHub Issues (prioritized)
- Label: `community-request`, `high-priority`, `roadmap`
- Monthly digest of approved features (transparency)

### Twitter/X
**Purpose:** Product news, user stories, technical deep-dives, thought leadership

**Content Mix:**
- **50%** Product updates, feature releases, milestones
- **30%** User stories, showcases, community contributions
- **15%** Technical insights, architecture decisions, open-source philosophy
- **5%** Industry commentary, AI/open-source trends

**Key Accounts to Engage:**
- @AnthropicAI (Claude partnerships)
- @cloudflare (Workers/infrastructure mentions)
- Mac dev community (@mjtsai, @siracusa, etc.)
- Open-source advocates
- Product Hunt community leaders

**Tweet Cadence:**
- Launch week: 2-3 tweets/day
- Sustain week: 1 tweet/day
- Weekly threads (Sundays): "This Week in Jane"

### Hacker News
**Purpose:** Developer validation, technical credibility

**Strategy:**
- Launch post: "Show HN: Jane — Persistent AI Companion for macOS"
- Follow-up monthly: Architectural posts, lessons learned, open-source deep-dives
- Respond to every significant comment (within 2 hours)
- Link to GitHub for curious developers

### Reddit
**Purpose:** Niche community building, use case discovery

**Subreddits:**
- r/MacApps — "Jane: Open-Source AI Companion in Your Notch"
- r/OpenSource — "Jane: MIT-Licensed Notch AI Platform (Persistent Memory, Voice, Local Access)"
- r/MacOS — For feature announcements
- r/Developers — Technical architecture posts
- r/ChatGPT or r/LocalLLMs — Comparative discussions

**Engagement:**
- Post 1-2x per month max (avoid spam perception)
- Answer every comment, engage with skeptics respectfully

### Blog & Longer-Form Content
**Target:** Dev.to, Medium, Substack, personal blogs

**Content Ideas:**
1. **"How to Build an Always-On AI Companion"** — Full architecture walkthrough
2. **"Local AI is the Future of Productivity"** — Vision post
3. **"Open-Source AI: the Case for MIT over Proprietary"** — Philosophy
4. **"Persistent Memory for AI Agents"** — Technical deep-dive (3-tier architecture)
5. **"MacBook Notch: The Last Unclaimed UI Real Estate"** — Opportunity thesis
6. **"Voice, Face, Memory: Beyond Chatbots"** — Product vision
7. **"Building Jane: Lessons from Open-Source on Day 1"** — Post-launch reflection

**Channels:**
- Dev.to (cross-post GitHub repo README)
- Medium (longer essays)
- Personal blog (owned content)
- Substack (weekly newsletter for deeper subscribers)

---

## 8. CROSS-PROMOTION CHANNELS

### Pre-Existing Audiences
- **Anthropic community** — Claude community Slack, forums
- **Cloudflare community** — Workers community, Discord
- **Open-source communities** — GitHub Trending, Product Hunt Collections
- **Mac developer community** — @siracusa, @mjtsai, MacRumors forums

### Hunter Strategy
**Target:** 2-3 Product Hunt top hunters with:
- 5K+ followers
- Prior open-source/dev tool wins
- Aligned interest in AI, Mac, or open-source

**Offer:**
- Early access (48 hours before public launch)
- Lifetime Pro discount code (50% off)
- Mention in "Special Thanks" section
- Opportunity to be first to cover Jane

**Timeline:**
- Identify hunters by April 8
- Send pitch April 9
- Confirm support by April 12
- Brief them on launch narrative by April 14

---

## 9. ESTIMATED EFFORT TO EXECUTE

### Timeline & Workload Estimate

| Phase | Duration | Effort | Owner(s) |
|-------|----------|--------|----------|
| **Planning & Messaging** | 1 week | 20 hours | 1 person (product/marketing) |
| **Landing Page Design** | 1 week | 30 hours | 1 designer + 1 copywriter |
| **Demo Video Production** | 2 weeks | 40 hours | 1 videographer + 1 editor + voiceover |
| **Product Hunt Setup** | 3 days | 10 hours | 1 person |
| **Media Outreach** | 2 weeks | 15 hours | 1 PR/marketing |
| **Hunter Recruitment** | 1 week | 5 hours | 1 person |
| **Social Content Prep** | 1 week | 15 hours | 1 content creator |
| **Community Setup** | 1 week | 10 hours | 1 community manager |
| **Launch Day Operations** | 1 day | 12 hours | 2 people (rotating) |
| **Week 1 Follow-up** | 1 week | 20 hours | 2 people |

**Total Estimated Effort:** 177 hours (~4.5 weeks, 1 FTE equivalent)

### Team Composition (Recommended)
- **1 Product/Marketing Lead** — Vision, messaging, overall strategy (40 hours)
- **1 Designer** — Landing page, social assets, video graphics (30 hours)
- **1 Copywriter** — Landing page, scripts, social posts (25 hours)
- **1 Videographer/Editor** — Demo video production (40 hours)
- **1 Community Manager** — Discord setup, moderation, engagement (20 hours)
- **1 Launch Day Lead** — Real-time management, response coordination (12 hours)
- **Gary (Founder)** — Strategic decisions, community relationships, demo recording (20 hours)

### Budget Estimate (Optional Paid Additions)
- **Professional demo video:** $1-3K (if outsourced)
- **Voice talent/ElevenLabs voice clone:** $500-1K
- **Paid media/Twitter ads:** $1-2K (optional, lower priority)
- **Design tools/assets:** $0 (Figma, Cursor free tier)

**Total Optional Budget:** $3-7K (not required for successful launch)

---

## 10. LAUNCH CONTENT CHECKLIST

### Landing Page
- [ ] Hero section with video loop or animated GIF
- [ ] Problem/solution section with before/after visuals
- [ ] 6 feature cards (Memory, Voice, Face, Local Superpowers, Open Source, Plugins)
- [ ] Pricing comparison (Free vs Pro)
- [ ] Social proof / testimonials section
- [ ] Architecture diagram (optional, technical deep-dive)
- [ ] FAQ section (common setup questions)
- [ ] Footer with links (GitHub, Discord, Docs, Privacy)
- [ ] Mobile-responsive design

### Demo Video
- [ ] 90-second master cut
- [ ] Social cuts (15s, 30s, 60s variants)
- [ ] Subtitles/captions (SRT file)
- [ ] Poster frame (thumbnail)
- [ ] YouTube, Twitter, Product Hunt optimized versions

### Social Assets
- [ ] Twitter card (1200x630px) — Jane face + notch visual
- [ ] Discord server banner
- [ ] Product Hunt gallery images (5-7)
- [ ] GitHub social preview
- [ ] LinkedIn cover image (if applicable)

### Copy Templates
- [ ] Product Hunt product description (100 words)
- [ ] Product Hunt discussion starter question
- [ ] Twitter thread (5-7 tweets, launch narrative)
- [ ] Discord welcome message
- [ ] Email to supporters (launch notification)
- [ ] FAQ responses (common questions pre-written)

### GitHub
- [ ] README.md updated (launch-ready)
- [ ] GitHub topics: `ai`, `macos`, `open-source`, `notch`, `companion`, `voice`
- [ ] GitHub Discussions category setup
- [ ] First release tagged (v1.0.0)
- [ ] Contributing guide updated
- [ ] Security policy in place

---

## 11. RISK MITIGATION

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| **Low initial adoption** | Medium | Medium | Pre-launch community building, hunter support |
| **Technical issues on day 1** | Low | High | QA pass, setup docs tested, support team ready |
| **Negative feedback on memory privacy** | Medium | High | Proactive privacy messaging, local-first docs |
| **Product Hunt algorithm downrank** | Low | Medium | Sustained engagement, hunter support, day 2 momentum |
| **Server/API issues (if Pro launches same day)** | Low | High | No Pro billing on day 1 (delay to week 2 if needed) |
| **Feature creep requests** | High | Low | Clear roadmap, expectations, community voting |
| **Bad media coverage** | Low | Medium | Prepare fact-check docs, respond professionally |
| **Competitor launches same day** | Low | Medium | Focus on unique positioning (persistent, open, local) |

---

## 12. POST-LAUNCH (Week 2+)

### Immediate Actions (Day 3-7)
- [ ] Publish Product Hunt retrospective (metrics, learnings)
- [ ] Thank key supporters publicly
- [ ] Begin triaging GitHub Issues into roadmap
- [ ] Plan first bug-fix release (v1.0.1)
- [ ] Promote top community plugins

### Week 2-4
- [ ] Release v1.0.1 (bug fixes, quality-of-life improvements)
- [ ] Publish first "Jane Roadmap" post (3-6 month vision)
- [ ] Highlight 5+ community contributions
- [ ] Publish technical blog posts (2-3 deep-dives)
- [ ] Begin gathering case studies (early power users)

### Month 2 (May)
- [ ] v1.1.0 release (first major feature additions)
- [ ] 1st annual Product Hunt metrics post
- [ ] Host community event (Twitter Spaces, Discord AMA)
- [ ] Evaluate paid conversion rate (% of free users → Pro)
- [ ] Plan Q2 goals based on feedback

---

## APPENDIX: QUICK REFERENCE

### Launch URL Checklist
- Product Hunt: producthunt.com/posts/jane-...
- GitHub: github.com/garywu/hud (or dedicated jane repo)
- Landing: jane.ai (or domain TBD)
- Discord: discord.gg/jane-community (or custom vanity)
- Docs: docs.jane.ai or README-based
- Twitter: @janecompanion or @garywu

### Key Messaging Pillars
1. **Persistent** — Remembers you, your preferences, past conversations
2. **Local-First** — Privacy-respecting, self-hosted option available
3. **Open Source** — MIT licensed, no vendor lock-in
4. **Ambient** — Always there, never intrusive, watches your back
5. **Capable** — Voice, face, file access, app control, deep reasoning

### Three-Word Elevator Pitch
"AI companion. In your notch. Remembers everything."

### One-Sentence Pitch
"Jane is an always-on AI companion living in your MacBook notch with persistent memory, voice interaction, and local machine access — fully open source."

---

## DELIVERABLES SUMMARY

This plan provides:

1. ✅ **Launch Narrative** — Jane origin story, problem/solution, value props
2. ✅ **Landing Page Outline** — Full section structure, messaging, CTAs
3. ✅ **Demo Video Script** — 90-second narrative with visual beats
4. ✅ **Launch Day Timeline** — Hour-by-hour from T-8 days through week 1
5. ✅ **Pricing Page Mockup** — Free vs Pro comparison, justification, limits
6. ✅ **Success Metrics** — Launch day, week 1, and month 1 targets
7. ✅ **Community Strategy** — Discord, GitHub, Twitter, Reddit, press
8. ✅ **Execution Roadmap** — Team composition, effort estimates, budget
9. ✅ **Risk Mitigation** — Key risks and contingencies

**Ready to Execute:** All sections are actionable. No decisions needed to proceed with implementation.

