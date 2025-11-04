# vel_tutor - Viral Frontend Features PRD

**Author:** Reuben
**Date:** 2025-11-03
**Version:** 1.0
**Type:** Feature Addition (Frontend)
**Project Level:** 3 (Complex - Novel viral mechanics + multi-persona UX)

---

## Executive Summary

This PRD defines the **missing frontend features** needed to transform vel_tutor from a backend AI orchestration platform into a viral, gamified learning platform for Varsity Tutors.

**Current State:** Backend API with LiveView admin dashboards only - no student/parent/tutor-facing UI
**Target State:** Full-featured Phoenix LiveView frontend with viral loops, social features, and gamification that achieves K ≥ 1.20

**Tech Stack:** Phoenix LiveView (90%) + Alpine.js (10%) + HTMX + Vanilla JS - leveraging existing Phoenix infrastructure for faster development

**Gap Analysis:**
- ❌ No student-facing UI for practice, diagnostics, or tutoring sessions
- ❌ No viral mechanics or sharing capabilities
- ❌ No presence system, leaderboards, or social features
- ❌ No reward/incentive system UI
- ❌ No session transcription or agentic action interfaces
- ❌ No async results pages with share cards

---

## Success Criteria

### Primary Metrics
1. **Viral Coefficient:** K ≥ 1.20 for at least one loop (14-day cohort)
2. **Activation Lift:** +20% to first-value moment (first practice or AI-Tutor minute)
3. **Referral Mix:** Referrals ≥ 30% of new weekly signups
4. **D7 Retention:** +10% for referred cohorts vs organic

### Secondary Metrics
- **Tutor Utilization:** +5% session bookings via referral conversion
- **CSAT:** ≥ 4.7/5 on viral prompts and rewards
- **Fraud Rate:** <0.5% fraudulent joins
- **Opt-out Rate:** <1% from growth communications

---

## Epic 1: Student Learning Interface & Results Pages

**Goal:** Build core student UX for practice, diagnostics, and async learning tools with viral-ready results pages.

### Story 1.1: Practice Session UI with Progress Tracking

As a **student**,
I want to complete practice problems with real-time feedback and progress tracking,
So that I can improve my skills and see my advancement.

**Acceptance Criteria:**
1. LiveView component for multi-step practice sessions (math, reading, science)
2. Real-time answer validation with immediate feedback (server-side)
3. Progress bar showing completion % and skill level (LiveView assigns)
4. Session timer and question counter (server-managed, sync via WebSocket)
5. "Pause and resume" capability with state persistence (Ecto schemas)
6. Mobile-responsive design (iOS/Android web) with Tailwind CSS
7. Direct integration with PracticeContext (no REST API needed)

---

### Story 1.2: Diagnostic Assessment Flow

As a **student or parent**,
I want to complete a diagnostic assessment to identify skill gaps,
So that I can get personalized learning recommendations.

**Acceptance Criteria:**
1. Multi-stage diagnostic flow LiveView (20-30 questions, adaptive difficulty server-side)
2. Subject selection with Alpine.js dropdown
3. Grade-level selection (K-12, college prep)
4. Timed sections with countdown warnings (JavaScript timer + server validation)
5. Progress persistence (LiveView temporary assigns + Ecto for long-term)
6. Submit assessment → `live_redirect` to results LiveView
7. Loading state with spinner while AI analyzes results (assign `analyzing: true`)

---

### Story 1.3: Viral Results Page - Diagnostics

As a **student**,
I want to see my diagnostic results with shareable achievements,
So that I can celebrate progress and challenge friends.

**Acceptance Criteria:**
1. Skills heatmap visualization (SVG or Chart.js via Phoenix hook)
2. Score breakdown with percentile ranking (computed server-side)
3. AI-generated study recommendations (GPT-4o via MCP agent)
4. **Share card generator** (privacy-safe, no PII)
   - "I scored 85% in Algebra! Can you beat me?" template
   - Dynamic OG image generated server-side (Elixir Image library or Puppeteer)
   - Short link with attribution tracking (generated in LiveView mount)
5. **"Challenge a Friend" CTA** → `phx-click="trigger_buddy_challenge"` event
6. **"Study Together" CTA** → `phx-click="trigger_study_buddy"` event
7. Deep link route with `live_session` handling for invitees (FVM flow)

---

### Story 1.4: Viral Results Page - Practice Tests

As a **student**,
I want to see my practice test results with leaderboard position,
So that I can compare with peers and create competitive challenges.

**Acceptance Criteria:**
1. Test score with question-by-question breakdown (LiveView component)
2. Time spent and accuracy metrics (computed in assigns)
3. **Mini-leaderboard** (anonymized peers via Phoenix Presence or DB query)
   - Real-time updates via PubSub
   - LiveView stream for efficient rendering
4. **"Beat My Score" share button** → `phx-click="share_buddy_challenge"`
5. **"Results Rally" trigger** → cohort leaderboard LiveView with invite link
6. Share card variations by persona (server-side template selection)
7. Deep link lands invitees in micro-task LiveView (no auth required initially)

---

### Story 1.5: Flashcard Study Session

As a **student**,
I want to study using AI-generated flashcards with spaced repetition,
So that I can efficiently memorize concepts.

**Acceptance Criteria:**
1. Swipeable flashcard UI with Alpine.js or vanilla JS touch events
   - LiveView tracks state server-side (current card, mastery status)
2. Deck selection by subject and skill (LiveView form)
3. AI-generated flashcards based on diagnostic gaps (MCP Personalization Agent)
4. Progress tracking (cards mastered vs remaining in socket assigns)
5. Spaced repetition algorithm (server-side logic in FlashcardContext)
6. **Achievement Spotlight** trigger on completion (`handle_event("deck_complete")`)
7. Share card generated server-side: "Just mastered 50 Algebra flashcards! 🎯"

---

## Epic 2: Viral Loop Mechanics & MCP Orchestration

**Goal:** Implement ≥4 viral loops with MCP agent orchestration to achieve K ≥ 1.20.

### Story 2.1: Loop Orchestrator MCP Agent (Frontend Integration)

As a **platform**,
I want the Loop Orchestrator to decide which viral prompt to show after key events,
So that users receive timely, personalized sharing opportunities.

**Acceptance Criteria:**
1. LiveView event handlers for viral triggers:
   - `handle_info(:diagnostic_completed, socket)`
   - `handle_info(:practice_test_completed, socket)`
   - `handle_info(:flashcard_deck_completed, socket)`
   - `handle_info(:badge_earned, socket)`
   - `handle_info(:streak_at_risk, socket)`
   - `handle_info(:session_ended, socket)`
2. PubSub subscription to Loop Orchestrator topic in mount
3. Decision payload via `send(self(), {:viral_prompt, data})` includes: `loop_type`, `prompt_copy`, `cta_button`, `deep_link`
4. Throttling logic server-side (check last_prompt_shown in user session)
5. Dismissible prompts with `phx-click="dismiss_prompt"` and user preference storage
6. A/B test variant support via `on_mount` hook (Experimentation Agent assigns variant)
7. Fallback to default prompt in `handle_info` catch-all clause

---

### Story 2.2: Buddy Challenge Loop (Student → Student)

As a **student**,
I want to challenge a friend to beat my practice score,
So that we can compete and both get streak rewards.

**Acceptance Criteria:**
1. **Trigger:** `handle_info({:loop_orchestrator, :buddy_challenge}, socket)` in results LiveView
2. **Prompt Copy:** "You scored 85%! Think your friend can beat it? 🎯" (dynamic from assigns)
3. **CTA:** "Challenge [Friend Name]" or "Share Link" button with `phx-click="show_share_modal"`
4. **Share Options:** Alpine.js modal with Web Share API fallback
   - SMS/WhatsApp (native intents on mobile)
   - Email (mailto: link)
   - Copy Link (clipboard API with toast notification)
5. **Deep Link:** Phoenix route `/challenge/:token` opens micro-practice LiveView
6. **Reward:** Both users get streak shields (GenServer manages reward distribution)
   - FVM tracked in LiveView (`handle_event("answer_submitted", ...)` counts)
7. **Attribution:** Signed smart link generated in `ChallengeContext.create_link/2`
   - Token includes: `sender_id`, `loop_type`, `timestamp`, HMAC signature
8. **UI States:** (all in socket assigns)
   - Challenge sent (pending) → show "Waiting for friend..."
   - Friend joined (in-progress) → Phoenix Presence update → "Friend is playing!"
   - Challenge completed → both LiveViews receive PubSub message → reward animation

---

### Story 2.3: Results Rally Loop (Async → Social)

As a **student**,
I want to see where I rank vs peers and invite others to the leaderboard,
So that I can compete in a cohort and climb the rankings.

**Acceptance Criteria:**
1. **Trigger:** Results LiveView mount calls `LeaderboardContext.get_cohort_ranking/2`
2. **Mini-Leaderboard:** LiveView stream of top 10 in cohort (grade + subject)
   - Anonymized usernames (Student A, B, C... assigned deterministically)
   - User's rank highlighted with CSS class
   - Real-time updates via PubSub (`Phoenix.PubSub.subscribe("leaderboard:algebra")`)
   - `handle_info({:leaderboard_update, rankings}, socket)` updates stream
3. **Prompt:** "You're #7 of 143! Invite friends to climb the board 📈" (dynamic from assigns)
4. **CTA:** "Invite to Rally" → `phx-click="generate_rally_link"`
   - Server generates cohort join token
   - Alpine.js modal with share options
5. **Deep Link:** `/rally/:cohort_token` route → placement quiz LiveView
6. **Reward:** +50 XP for referrer when invitee completes FVM
   - Tracked via `AttributionContext.track_fvm/2`
   - XP update sent via PubSub to referrer's active LiveView
7. **Cohort Room UI:** Presence indicators via `Phoenix.Presence.list/1`
   - "28 students practicing now" (count of active presences)
   - Updates automatically via presence diffs

---

### Story 2.4: Proud Parent Loop (Parent → Parent)

As a **parent**,
I want to share my child's progress with other parents and invite them to try the platform,
So that my friends can help their children succeed too.

**Acceptance Criteria:**
1. **Trigger:** Weekly progress email (Oban scheduled job) or parent dashboard LiveView
2. **Progress Card:** (server-side HTML or image generation)
   - Child's name (first name only, from `child.first_name`)
   - Skills improved (SVG heatmap with up arrows)
   - Time spent learning this week (computed from session logs)
   - Streak count (from `child.current_streak`)
3. **Privacy:** COPPA-compliant, no child photo or last name, redacted in templates
4. **Share Options:** Alpine.js modal with Web Share API
   - Email (mailto: with pre-filled body)
   - Facebook (sharer.php URL with OG tags)
   - Text (SMS intent on mobile)
5. **Copy:** "Emma improved in 5 skills this week! See how vel_tutor can help your child too."
6. **CTA:** "Invite a Parent" → `phx-click="generate_parent_referral"`
   - Server generates signed referral token
7. **Reward:** Referrer gets 1 free class pass (IncentivesContext.award_class_pass/1)
   - Triggered when `AttributionContext.track_fvm/2` fires for invitee
8. **Deep Link:** `/signup/parent/:token` route → diagnostic sign-up LiveView (not generic homepage)

---

### Story 2.5: Streak Rescue Loop (Student → Student)

As a **student**,
I want to save my streak by inviting a friend to co-practice,
So that we both keep our streaks alive and earn shields.

**Acceptance Criteria:**
1. **Trigger:** Oban scheduled job checks for at-risk streaks every hour
   - Sends PubSub message to active LiveViews: `{:streak_at_risk, time_remaining}`
   - Push notification if user offline
2. **Prompt:** "🔥 Your 7-day streak is at risk! Phone-a-friend to save it?" (LiveView assign)
3. **CTA:** "Invite Study Buddy" → `phx-click="send_rescue_invite"`
   - Generates rescue token with 2-hour expiry
   - Alpine.js share modal
4. **Co-Practice Session:** (shared LiveView)
   - Both users join same practice deck (10 questions)
   - Real-time presence via `Phoenix.Presence.track/4`
     - `handle_info({:presence_diff, diff}, socket)` shows "Friend joined!"
   - Synchronized timer (JavaScript timer + server validation)
   - Both must complete → both LiveViews check via `handle_info(:practice_complete, socket)`
5. **Reward:** Streak shields (1-day freeze) awarded via IncentivesContext
   - PubSub broadcasts reward to both users' LiveViews
   - Confetti animation (Alpine.js transition)
6. **Urgency UI:** Countdown timer (JavaScript timer in Alpine component)
   - Server sends `push_event("update_timer", %{seconds_left: 7200})`
7. **Deep Link:** `/rescue/:token` → instant practice LiveView (auth optional, guest mode for invitee)

---

## Epic 3: Social Presence & Gamification Layer

**Goal:** Make the platform feel "alive" with presence signals, activity feeds, and cohort rooms.

### Story 3.1: Live Presence System

As a **student**,
I want to see who else is learning right now,
So that I feel motivated and part of a learning community.

**Acceptance Criteria:**
1. **Global Presence Widget:** (LiveView component)
   - "342 students practicing now 🟢" via `Phoenix.Presence.list("global")`
   - Subject breakdown computed from presence metadata
   - Auto-updates via `handle_info({:presence_diff, diff}, socket)` (no polling needed)
2. **Subject-Specific Presence:**
   - "5 peers in Calculus now" via `Presence.list("subject:calculus")`
   - Avatars (anonymized via Boring Avatars library or user-uploaded)
3. **Friend Presence:**
   - "Emma is practicing Algebra" (filter presence list by `user.friends`)
   - "Join Emma" CTA → `phx-click="join_copractice"` → redirects to shared practice LiveView
4. **Cohort Room:**
   - Named rooms (e.g., "Algebra Aces", "Bio Squad") stored in `cohorts` table
   - Member count: total, active now (from Presence)
   - "Join Room" → `phx-click="join_cohort"` → updates user.cohort_id + tracks presence
5. **Privacy:** Opt-out setting in user preferences
   - If `user.presence_visible == false`, don't call `Presence.track/4`

---

### Story 3.2: Activity Feed (Social Feed)

As a **student**,
I want to see recent achievements and activity from peers,
So that I stay engaged and discover new challenges.

**Acceptance Criteria:**
1. **Feed Items:** (LiveView stream)
   - Badge earned: "Alex just earned the 'Algebra Master' badge 🏆"
   - Streak milestone: "Jamie reached a 30-day streak! 🔥"
   - Challenge issued: "Taylor challenged Chris to a Geometry duel ⚔️"
   - New high score: "Morgan scored 98% in SAT Math Practice!"
   - Each item inserted via PubSub → `stream_insert(socket, :feed_items, item)`
2. **Feed Actions:**
   - Like/react → `phx-click="react"` updates server-side counter
   - "Challenge me too" button → `phx-click="join_challenge"`
   - "Try this deck" button → `live_redirect` to practice LiveView
3. **Personalization:** Query prioritizes `user.friends` and same-subject peers
4. **Privacy:** User controls in settings table (`user.feed_visibility`)
   - Filter feed generation based on privacy settings
5. **Pagination:** Infinite scroll with HTMX
   - `hx-get="/feed?offset=20"` loads next 20 items
   - Or LiveView `handle_event("load_more")` with stream append

---

### Story 3.3: Leaderboards (Subject & Cohort)

As a **student**,
I want to compete on leaderboards to rank against peers,
So that I stay motivated to improve.

**Acceptance Criteria:**
1. **Leaderboard Types:** (separate LiveView routes)
   - Global: `/leaderboard/global` (top 100 all-time)
   - Subject: `/leaderboard/subject/:name` (top 50 per subject)
   - Cohort: `/leaderboard/cohort/:id` (class or study group)
   - Weekly: `/leaderboard/weekly` (Oban resets every Monday)
2. **Ranking Criteria:** (computed in LeaderboardContext)
   - XP earned (primary sort)
   - Practice accuracy (tiebreaker)
   - Streak length (tiebreaker)
   - Challenges won (tiebreaker)
3. **Fairness Logic:** (DB query filters)
   - Separate boards for `user.tenure < 7 days` vs veterans
   - Age band separation via `user.age_band` (elementary, middle, high, college)
4. **UI Elements:**
   - User's rank badge (CSS highlight in LiveView stream)
   - Position movement arrows (↑↓) stored in `user.rank_change` (computed daily)
   - "Overtake next player" progress bar (XP difference calculation in assigns)
5. **Viral Hook:** "Invite a friend" CTA → `phx-click="show_invite_modal"`

---

### Story 3.4: Badges & Achievements System

As a **student**,
I want to earn badges for milestones and share them,
So that I can celebrate progress and show off accomplishments.

**Acceptance Criteria:**
1. **Badge Categories:** (defined in `badges` table)
   - Skill mastery (e.g., "Algebra Expert", "Grammar Guru")
   - Streaks (7-day, 30-day, 100-day)
   - Social (e.g., "Team Player" for 5 co-practice sessions)
   - Challenges (e.g., "Duel Champion" for 10 wins)
2. **Badge Unlock Animation:**
   - Confetti effect (Alpine.js + canvas-confetti library)
   - Badge modal (`x-show` toggle) with description from assigns
   - "Share Achievement" CTA → `phx-click="share_badge"`
3. **Share Card Generation:** (server-side)
   - Badge SVG/PNG with user first name
   - "Just earned [Badge Name] 🏆" template
   - Deep link `/badge/:badge_id/try` to challenge for invitees
4. **Badge Collection Page:** (LiveView at `/badges`)
   - Grid of earned badges (colored, from `user_badges` join)
   - Locked badges (grayscale CSS filter) with unlock criteria
   - Progress bars for multi-level badges (e.g., "50% to Gold Streak")

---

### Story 3.5: XP & Rewards System UI

As a **student**,
I want to earn XP and rewards for learning activities,
So that I stay motivated and can unlock premium features.

**Acceptance Criteria:**
1. **XP Sources:** (all server-side calculations)
   - Complete practice session: +10 XP (via PracticeContext.complete_session/1)
   - Perfect score: +20 XP (bonus in same function)
   - Daily streak: +5 XP/day (Oban daily job)
   - Invite a friend (FVM reached): +50 XP (via AttributionContext)
   - Badge earned: +100 XP (via BadgeContext.award_badge/2)
2. **XP Display:** (LiveView component in app layout)
   - Persistent XP counter in header (from `socket.assigns.current_user.xp`)
   - Level indicator "Level 7" (computed from XP thresholds)
   - Progress bar to next level (SVG or Tailwind)
   - XP gain animation via `push_event("xp_gained", %{amount: 10})`
     - Alpine.js listens for event, shows toast with animation
3. **Rewards Shop:** (LiveView at `/shop`)
   - 15 min AI Tutor credits (500 XP) → `phx-click="redeem" phx-value-item="ai_tutor"`
   - Class sampler pass (1,000 XP)
   - Streak shield (300 XP)
   - Profile themes (200 XP)
4. **Incentive Economy Agent Integration:**
   - Backend validation via IncentivesContext.redeem_reward/2
   - Abuse detection (rate limits in plug, duplicate checks in context)
   - Reward balance tracking in `user_rewards` table

---

## Epic 4: Session Intelligence & Tutor Features

**Goal:** Transcribe live/instant tutoring sessions and trigger agentic actions that create viral opportunities.

### Story 4.1: Session Transcription Pipeline

As a **platform**,
I want to transcribe and summarize all live and instant tutoring sessions,
So that AI agents can generate personalized follow-up actions.

**Acceptance Criteria:**
1. **Audio Capture:** (vanilla JS in LiveView hook)
   - WebRTC `getUserMedia` captures audio stream from tutor-student sessions
   - LiveView hook sends audio chunks to backend via `phx-hook="AudioCapture"`
   - Real-time transcription (Deepgram or Whisper API) via GenServer
   - Transcript saved to `session_transcripts` table with timestamps
2. **AI Summarization:** (Oban worker after session ends)
   - GPT-4o via MCP Orchestrator generates summary:
     - Topics covered
     - Student strengths identified
     - Skill gaps detected
     - Recommended next steps
   - Stored in `session_summaries` table
3. **Trigger Events:**
   - `Phoenix.PubSub.broadcast("sessions", {:summary_ready, data})`
   - Payload: `%{student_id, tutor_id, summary, skills_covered}`
   - MCP agents subscribe to this topic
4. **Privacy:** COPPA/FERPA compliance
   - Parental consent checkbox in signup (minors)
   - Transcripts encrypted at rest
5. **Opt-out:** User preference `user.transcription_enabled` (default true)
   - If false, skip transcription hook

---

### Story 4.2: Student Agentic Action - Auto Beat-My-Skill Challenge

As a **student**,
I want to automatically receive a challenge based on my tutoring session gaps,
So that I can practice and invite a friend to compete.

**Acceptance Criteria:**
1. **Trigger:** `handle_info({:summary_ready, %{skill_gaps: gaps}}, socket)` in student LiveView
2. **AI Action:** Personalization Agent (MCP call) generates 5-question micro-deck
   - Stored in `practice_decks` table with `generated_from: "session_summary"`
3. **Prompt:** "Your tutor noticed you're close to mastering quadratics! Take this 5-min challenge and see if a friend can beat your score."
   - Displayed in LiveView modal (Alpine.js)
4. **CTA:** Two buttons:
   - "Start Challenge" (solo) → `phx-click="start_solo"`
   - "Challenge a Friend" (viral) → `phx-click="share_challenge"`
5. **Reward:** Both users get streak shields if friend reaches FVM (3+ questions)
   - Tracked via `ChallengeContext.track_completion/2`
   - Awarded via IncentivesContext
6. **Share Options:** Alpine.js modal with Web Share API
   - SMS, WhatsApp, email with deep link
7. **Deep Link:** `/deck/:token` opens micro-deck LiveView (guest mode initially)

---

### Story 4.3: Student Agentic Action - Study Buddy Nudge

As a **student**,
I want to be nudged to invite a study buddy for upcoming exams detected in my session,
So that we can prepare together and both stay accountable.

**Acceptance Criteria:**
1. **Trigger:** Session summary NLP detects "exam" or "test" keywords
   - `handle_info({:summary_ready, %{exam_detected: true}}, socket)`
2. **AI Action:** Social Presence Agent (MCP) creates co-practice invite
   - Generates topic-specific practice deck
3. **Prompt:** "You mentioned a Calculus exam next week! Invite a study buddy to practice together."
   - LiveView modal (Alpine.js)
4. **CTA:** "Invite Study Buddy" → `phx-click="invite_study_buddy"`
   - Generates co-practice token, opens share modal
5. **Co-Practice Feature:** (shared LiveView at `/copractice/:token`)
   - Both users work on same deck (state synced via PubSub)
   - Presence indicator via Phoenix.Presence: "Emma is online 🟢"
   - Synchronized progress bar (both see each other's progress)
   - Chat or emoji reactions (optional, via PubSub messages)
6. **Reward:** +100 XP each when both complete
   - Tracked via `CoPracticeContext.check_completion/1`
7. **Reminder:** Oban scheduled job 48h before exam
   - Sends push notification if `copractice_session.started == false`

---

### Story 4.4: Tutor Agentic Action - Parent Progress Reel + Invite

As a **tutor**,
I want to auto-generate a privacy-safe progress reel for parents to share,
So that I can grow my student base through referrals.

**Acceptance Criteria:**
1. **Trigger:** 5★ session rating from student or parent (Ecto after_update callback)
2. **AI Action:** Tutor Advocacy Agent generates 20-30s video reel:
   - Key moments (anonymized or with consent) - FFmpeg via Elixir System.cmd
   - Wins and breakthroughs (text overlays) - generated server-side
   - Tutor intro card (name, subjects, rating) - Phoenix template
3. **Privacy:** COPPA/FERPA-safe, no student faces/names without consent (enforced in context)
4. **Parent Share Link:**
   - "Watch [Child]'s progress with Tutor Sarah!" (Phoenix controller with OG tags)
   - Deep link to tutor profile + referral code (Phoenix route `/tutors/:id?ref=:code`)
5. **Reward:** Parent gets 1 free class pass for sharing + invitee signup (Incentives Agent via PubSub)
6. **Tutor Incentive:** +50 XP per referred family, leaderboard rank boost (Ecto update)
7. **Attribution:** Track referral source (email, social, SMS) - Phoenix Plug parses utm_source

---

### Story 4.5: Tutor Agentic Action - Next-Session Prep Pack Share

As a **tutor**,
I want to receive an AI-generated prep pack after each session,
So that I can share it with the student and their network.

**Acceptance Criteria:**
1. **Trigger:** `handle_info({:session_ended, session_id}, socket)` → Oban worker
2. **AI Action:** Tutor Advocacy Agent creates prep pack:
   - Recap of today's session (from summary)
   - Practice problems (generated by Personalization Agent)
   - Video/article resources (curated via Perplexity MCP agent)
   - "Invite a friend to [Subject] class" CTA with referral link
   - Stored as PDF or HTML page
3. **Tutor Distribution:**
   - Email to student/parent (Phoenix.Mailer)
   - Shareable link displayed in tutor's dashboard LiveView
   - Tutor can copy link for social/WhatsApp (Alpine.js clipboard)
4. **Class Sampler Embedded:** Deep link `/class/sample/:subject?ref=:token`
   - 10-min trial class (free, FVM for attribution)
5. **Reward:** Tutor earns referral XP when invitee books session
   - Tracked via `BookingContext.track_attribution/2`
6. **Tracking:** Dashboard LiveView shows:
   - Prep pack opens (tracked via pixel in email/page view)
   - Shares (link generation count)
   - Conversions (bookings with attribution)

---

## Epic 5: Analytics, Attribution & Experimentation

**Goal:** Measure K-factor, track attribution across devices, and run A/B tests on viral loops.

### Story 5.1: Smart Link Attribution System

As a **platform**,
I want to track invite conversions across devices and channels,
So that I can accurately measure K-factor and reward referrers.

**Acceptance Criteria:**
1. **Signed Smart Links:** (generated in `AttributionContext`)
   - Short codes via URL shortener (e.g., `vt.link/abc123`)
   - Signed with HMAC (`:crypto.mac/4`) to prevent tampering
   - Token embeds: `referrer_id`, `loop_type`, `campaign_id`, `timestamp`
   - Verified in LiveView mount via `AttributionContext.verify_token/1`
2. **Cross-Device Tracking:**
   - Fingerprinting fallback (IP + user agent stored in session)
   - Cookie-based tracking (`_vel_tutor_attribution` cookie)
   - Deep link app parameters (parsed in LiveView mount)
3. **UTM Parameters:** (Phoenix router extracts in plug)
   - `utm_source` (sms, email, whatsapp, social)
   - `utm_medium` (buddy_challenge, results_rally, etc.)
   - `utm_campaign` (weekly_cohort_2025_w45)
   - Stored in `conn.assigns.utm_params`
4. **Attribution Events:** (tracked in `attribution_events` table)
   - `link_generated` (on token creation)
   - `link_clicked` (on LiveView mount with token)
   - `account_created` (on signup completion)
   - `fvm_reached` (on first-value moment trigger)
5. **Dashboard Integration:** LiveView at `/dashboard/attribution`
   - Real-time stream via PubSub (no SSE needed with LiveView)

---

### Story 5.2: K-Factor Tracking Dashboard

As a **product manager**,
I want to measure K-factor for each viral loop,
So that I can identify high-performing loops and optimize spend.

**Acceptance Criteria:**
1. **K-Factor Formula:** (computed in `MetricsContext`)
   - K = (invites sent / active user) × (signups / invites sent)
   - Calculated per loop type and cohort
2. **Dashboard Metrics:** (LiveView at `/dashboard/k-factor`)
   - K-factor per loop (Buddy Challenge, Results Rally, etc.) in table
   - Cohort curves (referred vs organic) via Chart.js Phoenix hook
   - Invite funnel: sent → opened → signup → FVM (funnel visualization)
   - Time-to-FVM distribution (histogram)
3. **Filters:** (LiveView form with `phx-change="filter"`)
   - Date range dropdown (7d, 14d, 30d, custom date picker)
   - Loop type multi-select
   - User persona multi-select (student, parent, tutor)
   - Cohort dropdown (weekly, monthly)
4. **Alerts:** (Oban periodic job checks thresholds)
   - K ≥ 1.20 achieved → PubSub broadcast to dashboard + push notification
   - K < 0.8 for 3+ days → warning in dashboard + email to team
5. **Export:** `phx-click="export_csv"` button
   - Generates CSV server-side, returns download link

---

### Story 5.3: Experimentation Agent Integration

As a **platform**,
I want to run A/B tests on viral loop prompts and rewards,
So that I can maximize conversion and K-factor.

**Acceptance Criteria:**
1. **Experiment Configuration:** (LiveView admin panel at `/admin/experiments`)
   - Define variants (A: control, B: test copy, C: different reward)
   - Set traffic allocation (50/50, 33/33/33, etc.)
   - Choose success metric dropdown (K-factor, FVM rate, D7 retention)
   - Stored in `experiments` table
2. **Traffic Allocation:** (via `on_mount` hook in LiveView)
   - Sticky assignment (hash of `user_id` + `experiment_id` determines variant)
   - Stored in `user_experiments` table
   - Experimentation Agent MCP call returns variant on LiveView mount
   - Assigned to `socket.assigns.experiment_variants`
3. **Exposure Logging:** (automatic on variant render)
   - `handle_info(:log_exposure, socket)` logs to `experiment_exposures` table
   - Track: `experiment_id`, `variant_id`, `user_id`, `timestamp`
4. **Real-Time Metrics:** (LiveView at `/admin/experiments/:id`)
   - Conversion rate per variant (computed in assigns)
   - Statistical significance (p-value via ExStats library)
   - Confidence interval (95% CI)
5. **Winner Declaration:** (Oban daily job)
   - Auto-promote winning variant at 95% confidence
   - PubSub broadcast to team + email notification

---

### Story 5.4: Guardrail Metrics Dashboard

As a **compliance officer**,
I want to monitor abuse, fraud, and opt-out rates,
So that I can ensure platform health and regulatory compliance.

**Acceptance Criteria:**
1. **Fraud Detection Metrics:** (LiveView at `/admin/guardrails`)
   - Duplicate device/email signups (computed from `fraud_signals` table)
   - Referral loops detection (graph traversal query: A invites B, B invites A)
   - Abnormal invite volume (>20 invites/day per user)
   - Signups from disposable email domains (checked via EmailChecker library)
2. **Opt-Out Tracking:**
   - Users who disable viral prompts (`user.viral_enabled == false`)
   - Users who unsubscribe from emails (`user.email_subscribed == false`)
   - Trend chart over time (should be <1%)
3. **Complaint Rate:**
   - Support tickets with "spam" or "annoying" keywords (parsed from support system)
   - CSAT scores on viral prompts (from `feedback` table)
4. **COPPA/FERPA Compliance:**
   - % of child accounts with parental consent (`user.parental_consent == true`)
   - Audit log LiveView stream (`audit_logs` table filtered by minor accounts)
5. **Alerts:** (Oban hourly job checks thresholds)
   - Fraud rate >0.5% → PubSub broadcast + email escalation
   - Opt-out rate >1% → warning in dashboard + review meeting notification
   - COPPA violation detected → auto-disable account + legal team email

---

### Story 5.5: Viral Loop Performance Report (Weekly Automated)

As a **growth team**,
I want an automated weekly report on all viral loops,
So that I can review performance and plan optimizations.

**Acceptance Criteria:**
1. **Report Sections:** (generated by Oban scheduled job)
   - Executive Summary (K-factor, top loop, week-over-week % change)
   - Loop-by-Loop Breakdown table (invites sent, conversion %, K-factor)
   - Persona Analysis (student vs parent vs tutor performance comparison)
   - Channel Performance (SMS, email, WhatsApp, social breakdown)
   - Guardrail Check (fraud rate, opt-outs, complaints summary)
2. **Delivery:** (Oban worker runs every Monday 9am)
   - Email via Phoenix.Mailer
   - PDF attachment (generated via ExPDF or headless browser)
   - Link to live dashboard (`/dashboard/weekly-report/:date`)
3. **Insights:** (AI-generated section)
   - GPT-4o via MCP Orchestrator analyzes trends from metrics
   - Recommendations for next week's experiments (bulleted list)
4. **Distribution List:** (configured in `report_recipients` table)
   - Product team emails
   - Growth team emails
   - Executive stakeholders

---

## Technical Architecture (Frontend-Specific)

### Frontend Stack (Phoenix-Native)

**Primary Framework: Phoenix LiveView (90% of UI)**
- **Why LiveView:** Real-time by default, server-rendered, no API serialization, Phoenix Channels built-in
- **State Management:** LiveView assigns (server-side state)
- **Routing:** Phoenix Router with live routes
- **Styling:** Tailwind CSS + DaisyUI or custom components
- **Real-Time:** Phoenix Channels + Phoenix Presence (built-in)
- **Forms:** Phoenix.HTML.Form + Ecto changesets
- **Charts:** Chart.js or ApexCharts (via Phoenix hooks)
- **Mobile:** Responsive web (iOS/Android Safari), PWA-ready

**Alpine.js (10% - Client-Side Interactivity)**
- Modal dialogs and dropdowns
- Toast notifications
- Share button interactions
- Clipboard copy with animations
- Client-side form validation
- **Size:** 15KB minified

**HTMX (Specific Use Cases)**
- Infinite scroll (activity feed)
- Lazy-loaded components
- Partial page updates
- **Size:** 14KB minified

**Vanilla JS (Specialized Features)**
- WebRTC for session audio capture
- Canvas for share card generation
- Service Worker for PWA
- Web Share API integration

**Total JS Bundle:** ~50KB (vs 140KB+ for React stack)

### LiveView Architecture Patterns

**1. Student Practice Session (LiveView)**
```elixir
# lib/viral_engine_web/live/practice_live.ex
defmodule ViralEngineWeb.PracticeLive do
  use ViralEngineWeb, :live_view

  # Real-time state updates
  def mount(_params, _session, socket) do
    if connected?(socket), do: PubSub.subscribe("practice:updates")
    {:ok, assign(socket, questions: [], current: 0, score: 0)}
  end

  # Handle answer submission
  def handle_event("submit_answer", %{"answer" => answer}, socket) do
    # Validate, update score, trigger viral loop if session complete
    {:noreply, socket}
  end

  # Real-time presence
  def handle_info({:presence_update, peers}, socket) do
    {:noreply, assign(socket, peers_online: peers)}
  end
end
```

**2. Live Presence System (Phoenix Presence)**
```elixir
# lib/viral_engine/presence.ex
defmodule ViralEngine.Presence do
  use Phoenix.Presence,
    otp_app: :viral_engine,
    pubsub_server: ViralEngine.PubSub
end

# Track users in subjects
Presence.track(self(), "subject:algebra", user.id, %{
  username: user.username,
  practicing: true,
  joined_at: System.system_time(:second)
})
```

**3. Viral Loop Prompts (LiveView + Alpine)**
```heex
<!-- Viral prompt modal triggered by Loop Orchestrator -->
<div x-data="{ show: false }"
     x-show="show"
     phx-hook="ViralPrompt"
     id="viral-prompt">
  <div class="modal">
    <h2><%= @prompt_copy %></h2>
    <button phx-click="share_challenge" class="btn-primary">
      <%= @cta_button %>
    </button>
  </div>
</div>
```

**4. Real-Time Leaderboard (LiveView Stream)**
```elixir
# Efficient real-time updates with streams
def mount(_params, _session, socket) do
  if connected?(socket) do
    PubSub.subscribe("leaderboard:algebra")
  end

  {:ok, stream(socket, :rankings, get_rankings())}
end

def handle_info({:ranking_update, user}, socket) do
  {:noreply, stream_insert(socket, :rankings, user)}
end
```

### Key LiveView Components

**1. ViralLoopComponent** (`lib/viral_engine_web/live/components/viral_loop.ex`)
- Listens to Loop Orchestrator via PubSub
- Renders viral prompts with throttling (stored in assigns)
- Tracks user interactions (server-side)
- No client-side state management needed

**2. PresenceComponent** (`lib/viral_engine_web/live/components/presence.ex`)
- Uses Phoenix.Presence for real-time counters
- Displays "28 students practicing now" via `list/1`
- Auto-updates via presence diffs (no polling)

**3. AttributionHook** (Phoenix LiveView Hook)
- Parses smart link parameters in `mounted()` callback
- Sends attribution to backend via `pushEvent`
- Stores in session (server-side)

**4. RewardsComponent** (`lib/viral_engine_web/live/components/rewards.ex`)
- Displays XP balance from socket assigns
- XP gain animations via Alpine.js transitions
- Validates redemptions server-side (Incentives Agent)

**5. ShareCardComponent** (`lib/viral_engine_web/live/components/share_card.ex`)
- Generates OG images server-side (Elixir libraries)
- Provides share URLs with meta tags
- Alpine.js handles Web Share API or clipboard copy

### MCP Agent Interactions (LiveView → Backend)

**All interactions happen server-side in LiveView processes - no client API calls needed**

| Agent | LiveView Trigger | Expected Response | Timeout | Implementation |
|-------|------------------|-------------------|---------|----------------|
| Loop Orchestrator | `handle_info(:diagnostic_completed)` | `{ loop_type, prompt_copy, cta, deep_link }` | 150ms | PubSub message |
| Personalization | Mount with `socket.assigns.current_user` | Tailored copy and reward | 200ms | GenServer call |
| Incentives & Economy | `handle_event("redeem_reward")` | `{ success, new_balance, reward }` | 100ms | Context function |
| Social Presence | Presence.track on mount | `{ members[], active_now }` | 50ms | Presence.list |
| Experimentation | `on_mount` hook | `{ experiment_id, variant_id }` | 100ms | Plug |
| Trust & Safety | `handle_event("signup")` | `{ valid, fraud_risk_score }` | 200ms | Context function |

**Benefits of Server-Side Architecture:**
- No CORS issues
- No API authentication complexity
- No network serialization overhead
- Easier to debug (all logic in one place)
- Better security (sensitive logic never in client)

---

## Compliance & Risk

### COPPA/FERPA Requirements

1. **Age Gate:** Ask birthdate on signup, flag users <13 as minors
2. **Parental Consent:**
   - Email verification sent to parent email
   - Parent must approve account creation + data collection
   - Minor accounts locked until consent received
3. **Data Minimization:**
   - No sharing of child's last name, photo, or school in viral content
   - Share cards for minors use only first name + anonymized metrics
4. **Opt-Out Controls:**
   - Parents can disable viral features for child's account
   - Parents can request data deletion (GDPR-style)

### Fraud Prevention

1. **Rate Limits:**
   - Max 10 invites/day per user
   - Max 3 signups from same device in 7 days
   - Max 5 FVM attempts from same IP in 1 hour
2. **Duplicate Detection:**
   - Device fingerprinting (FingerprintJS)
   - Email domain blacklist (disposable emails)
   - Referral loop detection (A → B → A)
3. **Manual Review Queue:**
   - Flagged accounts reviewed by Trust & Safety Agent
   - High-risk signals: VPN usage, abnormal invite volume, complaint history

---

## Deliverables Checklist

### Must-Have (Bootcamp)

- [ ] Student practice session UI with results pages
- [ ] Diagnostic assessment flow
- [ ] ≥4 viral loops implemented and working end-to-end:
  - [ ] Buddy Challenge
  - [ ] Results Rally
  - [ ] Proud Parent
  - [ ] Streak Rescue
- [ ] ≥4 agentic actions triggered from session transcription:
  - [ ] Auto Beat-My-Skill Challenge (student)
  - [ ] Study Buddy Nudge (student)
  - [ ] Parent Progress Reel + Invite (tutor)
  - [ ] Next-Session Prep Pack Share (tutor)
- [ ] Live presence system (global + cohort)
- [ ] Activity feed with social interactions
- [ ] XP/rewards system UI
- [ ] Smart link attribution service
- [ ] K-factor tracking dashboard
- [ ] Experimentation framework (A/B tests)
- [ ] COPPA/FERPA compliance (age gate, parental consent)
- [ ] Fraud detection (rate limits, duplicate checks)
- [ ] 3-minute demo: trigger → invite → join → FVM

### Nice-to-Have (Post-Bootcamp)

- [ ] Leaderboard (global + subject-specific)
- [ ] Badge collection page
- [ ] Co-practice real-time sync
- [ ] Class Watch-Party
- [ ] Subject Clubs
- [ ] Achievement Spotlight
- [ ] Tutor Spotlight loop
- [ ] Guardrail metrics dashboard
- [ ] Weekly viral loop performance report

---

## Open Questions & Decisions Needed

1. **Reward Mix:** What's the optimal balance of AI Tutor minutes vs class passes vs XP boosts for each persona? (Need CAC/LTV analysis)

2. **Leaderboard Fairness:** How do we balance new users vs veterans? Age bands? Separate boards?

3. **Spam Thresholds:** What's the right cap on invites/day? Should it vary by user tenure or engagement level?

4. **K-Factor Definition:** For multi-touch journeys (view → signup → FVM), do we count K at signup or at FVM?

5. **Tutor Incentives:** Do tutors get financial rewards for referrals, or just XP/leaderboard perks? What disclosure is needed?

6. **Mobile App vs PWA:** Should we build native iOS/Android apps, or is responsive web + PWA sufficient for v1?

7. **Session Recording Consent:** Do we need explicit audio recording consent beyond COPPA age gate? What about 1-party vs 2-party consent states?

8. **Share Card Moderation:** Do we need human review of user-generated share cards, or can we rely on AI moderation?

---

## Success Validation Plan

### Experiment Design

**Hypothesis:** Implementing ≥4 viral loops will increase weekly signups from referrals by 20%+ and achieve K ≥ 1.20 for at least one loop.

**Test Cohort:**
- Seed with 500 active users (mix of students, parents, tutors)
- 50% control group (no viral features)
- 50% treatment group (all viral loops enabled)

**Duration:** 14 days

**Primary Metric:** K-factor (invites sent × conversion rate)

**Secondary Metrics:**
- Referral % of new signups
- Time to FVM for referred users
- D7 retention (referred vs organic)
- CSAT on viral prompts

**Success Criteria:**
- K ≥ 1.20 for at least one loop in treatment group
- Referral mix ≥ 30% of new signups
- +10% D7 retention vs control
- CSAT ≥ 4.5/5

**Go/No-Go Decision:** If all success criteria met → roll out to 100% of users. If K < 1.0 → iterate on loop prompts and rewards, retest.

---

## Timeline Estimate

| Epic | Stories | Est. Effort | Dependencies |
|------|---------|-------------|--------------|
| Epic 1: Student Learning Interface | 5 | 3 weeks | Backend API for practice/diagnostics |
| Epic 2: Viral Loop Mechanics | 5 | 4 weeks | MCP Loop Orchestrator + Personalization Agent |
| Epic 3: Social Presence & Gamification | 5 | 3 weeks | WebSocket/Presence backend |
| Epic 4: Session Intelligence & Tutor Features | 5 | 4 weeks | Transcription pipeline + Tutor Advocacy Agent |
| Epic 5: Analytics & Experimentation | 5 | 2 weeks | Event pipeline + attribution backend |

**Total:** 16 weeks (4 months) for full implementation

**Bootcamp Thin-Slice:** 4 weeks (Epic 1 + Epic 2 minimal viable loops)

---

## Appendix: Example User Flows

### Flow 1: Buddy Challenge (Student → Student)

1. Student completes practice test, scores 85%
2. Results page loads with share card preview
3. Loop Orchestrator decides to show Buddy Challenge prompt
4. Student clicks "Challenge a Friend"
5. SMS/WhatsApp opens with pre-filled message: "I scored 85% in Algebra! Can you beat me? [smart link]"
6. Friend receives message, clicks link
7. Deep link opens micro-practice (5 questions, no signup required yet)
8. Friend answers 3+ questions (FVM reached)
9. Prompt: "You're doing great! Sign up to see your score and challenge [Student Name] back!"
10. Friend signs up (attribution tracked)
11. Both users receive streak shields (reward delivered via Incentives Agent)
12. Activity feed shows: "[Friend] accepted your challenge! 🏆"

### Flow 2: Proud Parent (Parent → Parent)

1. Parent receives weekly progress email (Monday 9am)
2. Email includes child's progress card (skills improved, time spent, streak)
3. CTA: "Invite a parent friend to help their child succeed too"
4. Parent clicks, opens web page with shareable card
5. Parent shares via email to another parent
6. Invitee clicks smart link, lands on diagnostic sign-up page
7. Invitee signs up for child's account (parental consent flow)
8. Child completes diagnostic (FVM reached)
9. Referrer parent receives notification: "Your friend [Name] signed up! You've earned 1 free class pass 🎓"
10. Incentives Agent credits the reward
11. Tutor Utilization increases as referrer parent books a class with the pass

### Flow 3: Streak Rescue (Student → Student)

1. Student's 7-day streak is at risk (22 hours since last activity)
2. Push notification: "🔥 Your streak is at risk! Phone-a-friend to save it?"
3. Student opens app, sees Streak Rescue prompt
4. Student clicks "Invite Study Buddy"
5. SMS sent to friend with deep link
6. Friend clicks link, joins co-practice session instantly
7. Both users see live presence: "Emma is online 🟢"
8. Synchronized practice deck (10 questions)
9. Both complete the deck within 2-hour window
10. Both users receive streak shields (1-day freeze)
11. Activity feed: "You and Emma saved your streaks together! 🔥🛡️"
12. Loop Orchestrator logs successful Streak Rescue, increases future trigger probability for both users

---

**End of PRD**
