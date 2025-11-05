Of course. Here is a detailed Product Requirements Document (PRD) for the "10x K-Factor" initiative for Varsity Tutors, based on the provided project brief and current codebase status.

---

## Product Requirements Document: Vel Tutors "Project K-Factor"

**Author:** Gemini
**Version:** 1.0
**Date:** November 4, 2025
**Status:** In Development

### 1. Introduction & Vision

#### 1.1. The Challenge
Varsity Tutors offers a diverse suite of learning products. The current user experience, while functional, is largely individualistic and lacks the network effects that drive exponential growth. Results and achievements are personal milestones that evaporate without creating a ripple effect. The platform feels static, missing the energy of a live, collaborative learning environment.

#### 1.2. Product Vision
To transform Varsity Tutors into a dynamic, interconnected learning ecosystem. We will build a production-ready growth engine that makes learning social, fun, and "alive." Every student achievement, parent update, and tutor success will become a shareable, referable moment that fuels a powerful viral loop. Our goal is to **10x viral growth (K-factor)** by deeply integrating gamification, social presence, and intelligent, agent-driven interactions into the core product experience.

#### 1.3. Goals & Objectives
*   **Viral Growth:** Ship a minimum of four closed-loop viral mechanics that measurably increase the K-factor.
*   **Platform Vitality:** Create a palpable sense of activity and community through presence signals, activity feeds, and real-time leaderboards.
*   **Surface Conversion:** Convert static results pages into dynamic, shareable surfaces for viral acquisition.
*   **Prove Lift:** Validate the success of these initiatives through controlled A/B testing and a comprehensive analytics plan.

### 2. User Personas

*   **The Student (Alex, 15)**
    *   **Needs:** Wants to improve grades in Algebra. Feels isolated while studying. Is motivated by peer competition and social validation. Spends time on social platforms like TikTok and Instagram.
    *   **Goals:** Achieve better test scores, feel more connected to peers, and have fun while learning.

*   **The Parent (Sarah, 45)**
    *   **Needs:** Wants to stay informed about her son Alex's progress without being intrusive. Is proud of his achievements and willing to share successes with other parents in her network.
    *   **Goals:** See a clear return on her investment in tutoring, easily share positive updates, and find trusted educational resources for friends' children.

*   **The Tutor (David, 28)**
    *   **Needs:** Wants to build his reputation and client base. Looks for ways to provide extra value to his students and their parents.
    *   **Goals:** Increase student engagement and retention, generate more referrals, and be recognized for his teaching effectiveness.

### 3. Feature Requirements

This section details the core features required to achieve the project's vision.

#### 3.1. FR-01: "Alive" Layer & Social Presence
*   **User Story:** As a student, I want to see that other students are online and learning at the same time as me, so I feel like part of a larger community and stay more motivated.
*   **Functional Requirements:**
    1.  **Global Presence:** A real-time indicator showing the total number of users currently active on the platform.
    2.  **Subject-Specific Presence:** Display the number of users currently active in a specific subject area (e.g., "28 peers practicing Algebra now").
    3.  **Activity Feed:** A real-time feed of anonymized user achievements (e.g., "A student just completed a 15-day streak!," "Someone just scored 95% on a practice test.").
    4.  **Mini-Leaderboards:** Small, contextual leaderboards on subject pages showing top performers for the day or week.
    5.  **Study Buddy Nudge:** When a user is in a practice session, periodically prompt them to "invite a friend to join this practice."
*   **Acceptance Criteria:**
    *   Global and subject presence counts update in real-time via Phoenix Channels.
    *   Activity feed updates automatically with new events from Phoenix PubSub.
    *   Users can opt-out of presence tracking in their settings, which immediately removes them from all public presence indicators.
    *   All personally identifiable information (PII) is anonymized in the public activity feed.

#### 3.2. FR-02: Viral Loop Mechanics (Select 4+)
The platform will implement a minimum of four of the following closed-loop viral mechanics.

*   **FR-02.1: Buddy Challenge (Student → Student)**
    *   **User Story:** As a student, after completing a practice test, I want to challenge a friend to beat my score so we can compete and both get rewards.
    *   **Functional Requirements:**
        1.  After a practice session or on a results page, a "Challenge a Friend" CTA will appear.
        2.  Generates a unique, shareable deep link to a "micro-deck" of 5 questions based on the completed session.
        3.  The friend clicks the link and completes the challenge without needing to sign up immediately (First Value Moment).
        4.  If the friend signs up and completes the challenge within 48 hours, both users receive a "Streak Shield" reward.
        5.  The system tracks the invite, conversion, and reward issuance.

*   **FR-02.2: Results Rally (Async → Social)**
    *   **User Story:** As a student, after a diagnostic test, I want to see how my score ranks against my peers and create a leaderboard challenge for my friends.
    *   **Functional Requirements:**
        1.  Diagnostic and practice test results pages will display the user's percentile rank.
        2.  A "Create a Rally" CTA generates a unique deep link to a cohort leaderboard.
        3.  Friends who join the rally via the link take the same assessment.
        4.  The leaderboard page updates in real-time as new participants complete the assessment.

*   **FR-02.3: Proud Parent (Parent → Parent)**
    *   **User Story:** As a parent, I want to receive a weekly summary of my child's progress that is easy to share with another parent, giving them a free class pass.
    *   **Functional Requirements:**
        1.  The system automatically generates a weekly, privacy-safe "Progress Reel" (visual summary) for students.
        2.  Parents receive an email with a link to this reel.
        3.  The reel page includes an "Invite a Parent" CTA with a referral link for a free class pass.
        4.  The system tracks the referral and attributes the new sign-up to the sharing parent.

*   **FR-02.4: Streak Rescue (Student → Student)**
    *   **User Story:** As a student whose practice streak is about to expire, I want to be prompted to invite a friend to a quick co-practice session to save our streaks together.
    *   **Functional Requirements:**
        1.  When a user's streak is within 6 hours of expiring, a "Streak Rescue" prompt appears.
        2.  The prompt encourages a "Phone-a-Friend" co-practice session with a shareable link.
        3.  If both users complete a short practice session together, both receive a "Streak Shield" reward.

#### 3.3. FR-03: Session Intelligence & Agentic Actions
*   **User Story:** As a student, after a tutoring session, I want to receive intelligent, actionable recommendations that can also involve my friends, making my follow-up study more effective and social.
*   **Functional Requirements:**
    1.  **Transcription and Summarization:** All live and instant tutoring sessions will be transcribed. The system will generate a summary identifying key moments, wins, and skill gaps.
    2.  **Agentic Action Triggering:** The `Loop Orchestrator Agent` will analyze the session summary to trigger at least four different agentic actions (2 for students, 2 for tutors).
    3.  **Student Action 1: Auto "Beat-My-Skill" Challenge:** If a skill gap is identified, the system will auto-generate a 5-question micro-deck on that topic and present it to the student with a shareable challenge link.
    4.  **Student Action 2: Study Buddy Nudge:** If the summary mentions an upcoming exam, the system will create a co-practice invite for the relevant subject and prompt the student to invite a friend.
    5.  **Tutor Action 1: Parent Progress Reel + Invite:** After a session with a high rating, the system will auto-compose a privacy-safe progress reel and send it to the tutor, who can then one-click share it with the parent. The share link will include a referral code.
    6.  **Tutor Action 2: Next-Session Prep Pack Share:** The system will generate an AI-powered "prep pack" for the next session and provide the tutor with a shareable link.

*   **Acceptance Criteria:**
    *   All agentic actions must be fully automated based on triggers from the session summary.
    *   All shared content must be COPPA/FERPA safe by default, with clear consent flows.
    *   Each action must feed into one of the viral loops (e.g., Beat-My-Skill feeds into Buddy Challenge).

#### 3.4. FR-04: Analytics and Experimentation
*   **User Story:** As a product manager, I want to measure the K-factor of each viral loop in real-time and run A/B tests to optimize their performance.
*   **Functional Requirements:**
    1.  **Event Tracking:** The system will implement a comprehensive event schema to track `invites_sent`, `invite_opened`, `account_created`, and `FVM_reached`.
    2.  **Attribution:** All shareable links will be signed, trackable smart links that support cross-device continuity.
    3.  **Experimentation Agent:** An agent will be responsible for allocating users into different variants of a viral loop (e.g., different invite copy, different rewards).
    4.  **Guardrail Metrics:** The system will monitor opt-out rates, fraud flags, and support ticket volume related to the growth features.
    5.  **Dashboards:** A performance dashboard will display cohort curves, loop funnel drop-offs, and LTV deltas for referred vs. baseline users.

### 4. Non-Functional Requirements

*   **Performance:**
    *   **Decision SLA:** In-app triggers from the MCP agents must have a P95 latency of less than 150ms.
    *   **Concurrency:** The system must support 5,000 concurrent learners with a peak of 50 orchestrated events per second.
*   **Scalability:** The architecture must support horizontal scaling to handle potential exponential growth in users and events.
*   **Security & Compliance:**
    *   **COPPA/FERPA:** All features must be safe by default, with PII redacted from shared content and clear parental gating for minors.
    *   **Data Privacy:** All user data must be handled in a GDPR-compliant manner, with child data segregated.
*   **Reliability:** The system must include graceful degradation. If an AI agent is down, the system will fall back to default, non-personalized copy and rewards.
*   **Explainability:** Every decision made by an AI agent must be logged with a clear rationale and the features used to make that decision.

### 5. Success Metrics

The success of Project K-Factor will be measured against the following primary and secondary metrics:

| Metric | Category | Target | Measurement |
| :--- | :--- | :--- | :--- |
| **K-Factor** | Primary | **K ≥ 1.20** | For at least one loop over a 14-day cohort. |
| **Activation Lift** | Secondary | **+20%** | Lift in users reaching their First Value Moment. |
| **Referral Mix** | Secondary | **≥ 30%** | Percentage of new weekly signups from referrals. |
| **D7 Retention** | Secondary | **+10%** | For referred cohorts compared to baseline. |
| **Tutor Utilization** | Secondary | **+5%** | Increase in tutor sessions from referral conversions. |
| **User Satisfaction** | Guardrail | **≥ 4.7/5** | CSAT on viral loop prompts and rewards. |
| **Abuse Rate** | Guardrail | **< 0.5%** | Fraudulent joins from referral links. |
| **Opt-Out Rate** | Guardrail | **< 1%** | Opt-outs from growth-related communications. |

---
