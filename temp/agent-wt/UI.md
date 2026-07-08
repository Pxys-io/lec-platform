# beIN Med — THE DEFINITIVE FLUTTER MIGRATION BIBLE

This document is the exhaustive, all-encompassing specification for migrating beIN Med from React Native (Expo) to Flutter. It consolidates every detail from the PRD, the reference codebase, and the functional specifications.

---

## 1. CORE IDENTITY & DESIGN LANGUAGE

### 1.1 Visual Palette (High-Fidelity)
| Token | Hex Code | Light Mode Usage | Dark Mode Usage | Semantic Role |
|---|---|---|---|---|
| `Primary` | `#1B4F72` | Header, Status Bar, Active Tab | Accent highlights, Icons | Brand Identity |
| `Secondary` | `#2E86C1` | Action Buttons, Active Filters | Primary Buttons, Links | Action/Interaction |
| `Accent` | `#148F77` | Progress Bars, Success Check | Achievements, Radar Charts | Growth/Success |
| `Background` | `#F7F9FC` | Entire App Canvas | N/A (Standardized) | Neutral Foundation |
| `Surface` | `#FFFFFF` | Cards, Modals, Bottom Sheets | `#1C2833` (Onyx Blue-Grey) | Component Shell |
| `Text Primary` | `#1A1A2E` | Headlines, Body Text | `#F7F9FC` (Off-white) | High Contrast Info |
| `Text Secondary`| `#566573` | Captions, Metadata, Disabled | `#9BA1A6` (Muted Grey) | Supporting Info |
| `Success` | `#1E8449` | Correct Answers, Paid Status | Verified Badges, Completed | Positive Feedback |
| `Warning` | `#D4A017` | Expiry Banners, Locked Badges | Alert Icons, Pending | Caution/Attention |
| `Error` | `#C0392B` | Incorrect Answers, Delete UI | Critical Alerts, Failed | Negative Feedback |

### 1.2 Typography System (Inter Family)
- **H1 (Screen Title):** 24px, Bold (w700), Letter Spacing: -0.5
- **H2 (Section Header):** 18px, Semi-Bold (w600)
- **H3 (Card Title):** 15px, Semi-Bold (w600)
- **Body Large:** 16px, Regular (w400)
- **Body Medium:** 14px, Regular (w400), Line Height: 1.5
- **Caption:** 12px, Regular (w400), `Text Secondary`
- **Mono:** `Roboto Mono` or `Courier`, 12px (Used for Student IDs and Access Codes)

### 1.3 Geometry & Layout
- **Base Unit:** 8px grid (Scale: 4, 8, 16, 24, 32, 48)
- **Page Padding:** 16px horizontal, 24px vertical
- **Card Corner Radius:** 16px (Main), 12px (Small/Nested)
- **Button Radius:** 30px (Pill-shaped)
- **Elevation:** Low shadow (Blur 4, Offset [0, 2], Opacity 0.08)

---

## 2. NAVIGATION & SCREEN FLOWS

### 2.1 The 5-Tab Architecture
1.  **Home (`/home`):** Personalized student dashboard.
2.  **Discover (`/discover`):** Searchable, categorizable course library.
3.  **QBank (`/qbank`):** Clinical clinical practice environment.
4.  **Progress (`/progress`):** Visual performance analytics.
5.  **Profile (`/profile`):** Identity, certificates, and settings.

### 2.2 Linear User Journeys
- **Onboarding Flow:** Splash (2s) -> Onboarding Slides (Pager) -> Auth Gateway (Login/Register).
- **Authentication Flow:** Register -> multi-step Form -> 2FA (OTP) -> Token Refresh (Background).
- **Learning Flow:** Home -> Continue Learning -> Hero Animation -> Secure Player.
- **Evaluation Flow:** QBank Config -> Active Session (Tutor/Timed) -> Result Breakdown -> Review Mode.

---

## 3. EXHAUSTIVE SCREEN SPECIFICATIONS

### 3.1 Authentication Group
- **Splash Screen:** Animated logo on branded background.
- **Onboarding:** 3 Slides (Lectures, QBank, Security). Skip button (Top-Right), Dots (Bottom-Center), Next/Get Started (Bottom-Right).
- **Registration:** Fields for Name, Email, Password, Institution, Specialty. "I am an Instructor" toggle. Real-time strength/format validation.
- **Two-Factor Auth:** 6-digit numeric OTP. Auto-focus field. 60s resend timer.
- **Login:** Email/Password + "Remember Me" + Forgot Password (OTP Reset) + Social (Google/Apple).

### 3.2 Dashboard & Home
- **Personalized Header:** Circular Avatar + "Welcome back, [Name]" + Study Streak (Flame icon + Day count).
- **Continue Learning:** Horizontal scroll card showing the very last lesson watched (thumbnail, title, progress bar, "Resume" CTA).
- **My Courses:** 2-column Grid of `CourseVerticalCard` showing completion %.
- **Upcoming Live Sessions:** Banner with countdown to next Dr. live stream.
- **Announcements:** Expandable list of instructor updates.

### 3.3 Course Discovery
- **Global Search:** Top search bar with 16px radius and filter icon.
- **Category Chips:** Horizontal scrolling list (All, Cardiology, Pathology, etc.).
- **Course Detail:**
  - **Hero:** Backdrop image + Instructor Avatar overlay + Rating row.
  - **Tabs:** Overview (Long text), Curriculum (Accordion sections), Reviews (Student feedback).
  - **Logic:** "Request Access" button triggers the Request form if the course is locked.

### 3.4 Secure Video Player (Priority Logic)
- **Screen Protection:** `FLAG_SECURE` enabled. Watermark MUST persist on pause.
- **Dynamic Watermark:** Moves every 10s to randomized $(x, y)$ coordinates. Text: "Email — Student ID". Opacity: 22%.
- **Player Controls:** Custom UI. Play/Pause, 10s Skip, Volume, Full-screen toggle.
- **Modals:** Playback Speed (0.5x-2.0x), Video Quality (360p-1080p).
- **Notes Feature:** In-player text input synced to `/stats/watch` or `/lessons/{id}/comments`.
- **Bookmarks:** Timestamp markers visible on the seek bar.

### 3.5 QBank (UWorld-Style)
- **Configuration:** Select Subjects (Multi-select) -> Select Mode (Tutor/Timed) -> Count (10/20/40).
- **Active Session:** Pager view. Top progress bar. Flag button (for review). Pause button.
- **Tutor Mode:** Select answer -> Immediate Green/Red Highlight -> Auto-slide up Explanation Panel.
- **Timed Mode:** Countdown timer. No feedback until "End Session" is pressed.
- **Explanation Panel:** Contains "Correct Answer Rationale", "Educational Objective", and "Subject Tags".

### 3.6 Progress & Analytics
- **Cards:** Total study hours, Streak, Avg Quiz Score, Questions Answered.
- **Visuals:** 
  - `Weekly Study Time`: Bar Chart.
  - `Subject Mastery`: Radar/Spider Chart (Accuracy across specialties).
  - `Accuracy Over Time`: Line Chart.
- **Achievements:** List of badges (Play, Flame, Trophy icons). Locked = Greyed out.

---

## 4. FUNCTIONAL & TECHNICAL REQUIREMENTS

### 4.1 Backend Integration (`agent` SDK)
- **Repository Pattern:** Wrap `Backend` in Feature cubits.
- **Auth:** `AuthRepository` for login/token/2FA.
- **Stats:** Background periodic POST to `/stats/watch` every 60s during video playback.
- **HLS Proxy:** Video URLs MUST be routed via `main-server` proxy for manifest/segments.

### 4.2 Local Persistence
- **Hydrated BLoC:** Store Theme Mode, "Continue Watching" cache, and Notification preferences.
- **PDF Viewer:** `flutter_pdfview` for in-app reading. NO download/share buttons allowed.

### 4.3 Interactive Logic Summary
- **Hero Animations:** Thumbnail (Dashboard) -> Thumbnail (Detail) -> Player.
- **Haptics:** Light vibration on button press; Success/Error vibration on Quiz answers.
- **Skeleton Loaders:** Shimmer effect for all data-driven lists.

---

## 5. COMPLETE MOCK DATA STRUCTURES

### 5.1 User Profile
- `Ahmed Hassan`, `STU-00421`, `Internal Medicine`, `Cairo University`, `Streak: 14 Days`.

### 5.2 Sample Course (C01)
- `Cardiology Masterclass`, `Dr. Sara Khalil`, `12 Lectures`, `Rating 4.8`.
- **Lecture 1:** `Introduction to Anatomy`, `isFree: true`, `HLS URL`.
- **Lecture 4:** `Valvular Diseases`, `isFree: false` (Locked).

### 5.3 Assessment
- `Cardiology Basics Quiz`, `3 Questions`, `Time Limit: 15m`.
- **Sample Question:** "Which artery supplies the anterior wall?" -> `LAD`.

---

## 6. MIGRATION COMPONENT MAPPING

| React Native (Reference) | Flutter (Migration Target) |
|---|---|
| `<View>` | `Container` / `Column` / `Row` / `SizedBox` |
| `<Text>` | `Text` (Theme-ready) |
| `<FlatList>` / `<ScrollView>` | `ListView.builder` / `SliverList` / `SingleChildScrollView` |
| `expo-router` | `go_router` |
| `lucide-react-native` | `lucide_icons` (Pub) |
| `Animated.timing` | `TweenAnimationBuilder` / `AnimationController` |
| `Victory Native` / `Chart Kit` | `fl_chart` |
| `Zustand` | `flutter_bloc` / `cubit` |
| `expo-video` | `chewie` / `video_player` |
