# Case: 10x K Factor — Viral, Gamified, Supercharged Varsity Tutors (Finalized Bootcamp Brief)

## The Challenge

Varsity Tutors has rich products (1:1 scheduled tutoring, instant on-demand tutoring, AI tutoring, live classes, diagnostics, practice, flashcards, etc.). Design and implement a production-ready growth system that makes learning feel fun, social, and “alive,” and that 10×’s viral growth by turning every touchpoint into a shareable, referable moment—across students, parents, and tutors.

## Core Objectives

- Ship ≥ 4 closed-loop viral mechanics that measurably increase K-factor (K = invites per user × invite conversion rate).
  - We’ll tease example loops below, but you choose which 4+ to build (and you’re encouraged to propose others).
- Make the platform feel alive: presence signals, activity feed, mini-leaderboards, and cohort rooms that show “others are learning with you.”
- Convert async results pages (diagnostics, practice tests, flashcards, etc.) into powerful viral surfaces with share cards, deep links, and cohort challenges.
- Prove lift with a controlled experiment and a clear analytics plan.

## Required Agents (minimum)

- **[required] Loop Orchestrator Agent** – Chooses which loop to trigger (after session, badge earned, streak preserved, results page view, etc.); coordinates eligibility & throttling.
- **[required] Personalization Agent** – Tailors invites, rewards, and copy by persona (student/parent/tutor), subject, and intent.
- **Incentives & Economy Agent** – Manages credits/rewards (AI Tutor minutes, class passes, gem/XP boosts), prevents abuse, ensures unit economics.
- **Social Presence Agent** – Publishes presence (“28 peers practicing Algebra now”), recommends cohorts/clubs, nudges “invite a friend to join this practice.”
- **Tutor Advocacy Agent** – Generates share-packs for tutors (smart links, auto thumbnails, one-tap WhatsApp/SMS) and tracks referrals/attribution.
- **Trust & Safety Agent** – Fraud detection, COPPA/FERPA-aware redaction, duplicate device/email checks, rate-limits, report/undo.
- **[required] Experimentation Agent** – Allocates traffic, logs exposures, computes K, uplift, and guardrail metrics in real time.

Agents communicate via Model Context Protocol (MCP) servers. Each decision must include a short rationale for auditability.

## Session Intelligence (Transcription → Agentic Actions → Viral)

All live and instant sessions are transcribed and summarized. These summaries power agentic actions for students and tutors that also seed viral behaviors.

### Minimum agentic actions (ship ≥ 4 total)

- **For Students (ship ≥ 2)** possible examples:
  1. **Auto “Beat-My-Skill” Challenge**: From the summary’s skill gaps, generate a 5-question micro-deck with a share link to challenge a friend; both get streak shields if friend reaches FVM within 48h.
  2. **Study Buddy Nudge**: If summary shows upcoming exam or stuck concept, create a co-practice invite tied to the exact deck; presence shows “friend joined.”
- **For Tutors (ship ≥ 2)** possible examples:
  1. **Parent Progress Reel + Invite**: Auto-compose a privacy-safe 20–30s reel (key moments & wins) with a referral link for the parent to invite another parent for a class pass.
  2. **Next-Session Prep Pack Share**: Tutor receives an AI-generated prep pack and a class sampler link to share with peers/parents; joins credit the tutor’s referral XP.

(All actions must be COPPA/FERPA safe, with parental gating for minors and clear consent UX.)

## Core Requirements

- **Async Results as Viral Surfaces** – Diagnostics, practice tests, and other async tools produce results pages (scores, skills heatmaps, recommendations) that must:
  - Render privacy-safe share cards for student/parent/tutor variants.
  - Offer “Challenge a friend / Invite a study buddy” CTAs tied to the exact skill deck/class/AI practice set.
  - Provide deep links landing new users directly in a bite-size first-value moment (e.g., 5-question skill check).
  - Include cohort/classroom variants for teachers/tutors to invite groups.
- **“Alive” Layer** – Presence pings, study map, mini-leaderboards per subject, “friends online now,” cohort rooms.
- **Instant-Value Rewards** – Credits/gems/time passes that are immediately usable (e.g., 15 minutes of AI Tutor, class samplers, practice power-ups).
- **Cross-Surface Hooks** – Web, mobile, email, push, SMS; deep links prefill context.
- **Analytics** – Event schema for invites, opens, joins, first-value moment (FVM), retention (D1/D7/D28), and LTV deltas.

## Viral Loop Menu (pick any 4+; you may propose others)

Important: We are not prescribing which to build. Choose any 4+ that best fit your squad’s thesis, and feel free to add original ideas.

1. **Buddy Challenge (Student → Student)** – After practice or on results pages, share a “Beat-my-score” micro-deck; both get streak shields if friend reaches FVM.
2. **Results Rally (Async → Social)** – Diagnostics/practice results generate a rank vs. peers and a challenge link; cohort leaderboard refreshes in real time.
3. **Proud Parent (Parent → Parent)** – Weekly recap card + shareable progress reel; “Invite a parent” for a class pass.
4. **Tutor Spotlight (Tutor → Family/Peers)** – After 5★ session, generate a tutor card + invite link; tutor accrues XP/leaderboard perks when joins convert.
5. **Class Watch-Party (Student Host → Friends)** – Co-watch recorded class with synced notes; host invites 1–3 friends; guests get class sampler + AI notes.
6. **Streak Rescue (Student → Student)** – When a streak is at risk, prompt “Phone-a-friend” to co-practice now; both receive streak shields upon completion.
7. **Subject Clubs (Multi-user)** – Join a live subject club; each member gets a unique friend pass; presence shows “friends joined.”
8. **Achievement Spotlight (Any persona)** – Auto-generated milestone badges convert to social cards (safe by default); clickthrough gives newcomers a try-now micro-task.

## Technical Specifications

- MCP between agents; JSON-schema contracts; <150ms decision SLA for in-app triggers.
- Concurrency: 5k concurrent learners; peak 50 events/sec orchestrated.
- Attribution: Signed smart links (short codes) with UTM + cross-device continuity.
- Data: Event bus → stream processing → warehouse/model store; PII minimized; child data segregated.
- Explainability: Each agent logs decision, rationale, features_used.
- Failure Mode: Graceful degradation to default copy/reward if agents are down.

## Infrastructure Constraints

- **Privacy/Compliance**: COPPA/FERPA safe defaults; clear consent flows.

## Ambiguous Elements (you must decide)

- Optimal reward mix (AI minutes vs. gem boosts vs. class passes) by persona and CAC/LTV math.
- Fairness in leaderboards (new users vs. veterans; age bands).
- Spam thresholds: caps on invites/day; cool-downs; school email handling.
- K-factor definition for multi-touch joins (view → sign-up → FVM).
- Tutor incentives and disclosures.

## Success Metrics

- **Primary**: Achieve K ≥ 1.20 for at least one loop over a 14-day cohort.
- **Activation**: +20% lift to first-value moment (first correct practice or first AI-Tutor minute).
- **Referral Mix**: Referrals ≥ 30% of new weekly signups (from baseline [__]%).
- **Retention**: +10% D7 retention for referred cohorts.
- **Tutor Utilization**: +5% via referral conversion to sessions.
- **Satisfaction**: ≥ 4.7/5 CSAT on loop prompts & rewards.
- **Abuse**: <0.5% fraudulent joins; <1% opt-out from growth comms.

## Deliverables (Bootcamp)

1. Thin-slice prototype (web/mobile) with ≥ 4 working loops and live presence UI.
2. MCP agent code (or stubs) for Orchestrator, Personalization, Incentives, Experimentation.
3. Session transcription + summary hooks that trigger ≥ 4 agentic actions (≥2 tutor, ≥2 student) feeding viral loops.
4. Signed smart links + attribution service.
5. Event spec & dashboards: K, invites/user, conversion, FVM, retention, guardrails.
6. Copy kit: dynamic templates by persona, localized [en + __].
7. Risk & compliance memo (1-pager): data flows, consent, gating.
8. Results-page share packs for diagnostics/practice/async tools (cards, reels, deep links).
9. Run-of-show demo: 3-minute journey from trigger → invite → join → FVM.

## Analytics & Experiment Design

- **K-factor tracking**: invites_sent, invite_opened, account_created, FVM_reached.
- **Attribution**: last-touch for join; multi-touch stored for analysis.
- **Guardrails**: complaint rate, opt-outs, latency to FVM, support tickets.
- **Dashboards**: cohort curves (referred vs. baseline), loop funnel drop-offs, LTV deltas.
- **Results-page funnels**: impressions → share clicks → join → FVM per tool (diagnostics, practice tests, flashcards).
- **Transcription-action funnels**: session → summary → agentic action → invite → join → FVM.

## Acceptance Criteria

- ≥ 4 viral loops functioning end-to-end with MCP agents.
- ≥ 4 agentic actions (≥2 tutor, ≥2 student) triggered from session transcription, each feeding a viral loop.
- Measured K for a seeded cohort and a clear readout (pass/fail vs K ≥ 1.20).
- Demonstrated presence UI and at least one leaderboard or cohort room.
- Compliance memo approved and results-page sharing active for diagnostics/practice/async tools.
