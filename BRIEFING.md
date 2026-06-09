# Cadence — App Briefing

## What is Cadence?

Cadence is a minimal, tactile interval timer for iPhone. It helps people structure time — whether that's a breathing exercise, a meditation session, a workout, or a deep work block — by guiding them through a sequence of timed phases with sound, haptic, and visual cues.

Where most timer apps are either too simple (a single countdown) or too complex (cluttered with features), Cadence sits in the middle: it is expressive enough to handle any interval-based practice, and minimal enough to stay out of the way while you do it.

---

## The Core Idea

Almost every structured practice — breathwork, HIIT, Pomodoro, meditation — follows the same underlying pattern: **a sequence of phases, repeated a number of times**. Cadence is built around that pattern.

You define the phases (e.g. Inhale → Hold → Exhale), set their durations, choose how many rounds to repeat, and Cadence handles the rest: counting down, signalling transitions, and keeping you in the flow without requiring you to look at your phone.

---

## What Makes It Special

**Fully multi-sensory cues**
Every interval transition can trigger any combination of a sound cue, a haptic pattern, and a full-screen colour flash. You can feel a transition through your pocket, hear it through your headphones, or see it from across the room.

**A library of curated presets**
Cadence ships with 16 expertly configured presets across three categories — Mind, Body, and Productivity. Each preset has been tuned with appropriate sounds, colours, and timing. Users can start immediately without any setup.

**A powerful but simple custom timer wizard**
Users can build their own timers in a two-step wizard: first define the interval sequence, then configure the start and end experience. Every setting has a sensible default so you can create a working timer in under a minute, or fine-tune every detail.

**Voice announcements**
A male or female voice announces the start and end of every session. Users can choose a voice, a sound cue, or turn the announcement off entirely for each end of the session.

**Apple Health integration**
Completed sessions are saved to Apple Health automatically. Breathing and meditation sessions save as Mindful Sessions; Body sessions save as HIIT Workouts.

**Cues without commentary**
Most guided apps talk at you. Cadence signals you. A soft bell, a gentle vibration, or a colour flash marks each transition — no voice counting your breaths, no coach telling you to relax. The practice stays quiet and in your own head. Voice announcements are available at the start and end of a session for those who want them, but they are optional and off by default on custom timers.

**Designed for eyes-closed use**
The timer screen is built to be used without looking. Large corner indicators (elapsed, remaining, round, current phase) provide glanceable context. Sound and haptic cues carry the experience so the phone can sit face-down or go in a pocket.

**Dark, tactile aesthetic**
Cadence has a single dark theme with a warm neutral palette. The UI feels physical — transitions are smooth, controls are large, and colour is used meaningfully (each interval block has its own colour identity).

---

## Feature Overview

### Library
- 16 built-in presets across Mind, Body, and Productivity
- Filter presets by category
- Full-text search with semantic understanding (searching "focus" surfaces Deep Work and Pomodoro; "run" surfaces Sprint Intervals; "meditation" surfaces all breathing presets)
- Personal library for saved custom timers
- Multi-select bulk delete
- Duplicate any preset to create a personalised version
- Tab preference persists between sessions

### Timer Builder (Wizard)
**Step 1 — Sequence**
- Add unlimited interval blocks
- Per-block: label, duration (minutes + seconds), colour (7 options), sound cue (13 options), haptic pattern (4 options), visual flash
- Multi-select bulk delete for blocks
- Reorder blocks
- Duplicate blocks with inherited settings

**Step 2 — Start & End**
- Category selection (Mind / Body / Productivity)
- Configurable opening countdown (0–60 seconds, sound on/off)
- Opening and closing announcement: Female voice, Male voice, any sound cue, or off
- Preview button for every sound option

### Active Timer Screen
- Three concentric rings: block progress, round progress, session progress
- Block countdown in large monospaced type
- Four corner indicators: round, phase name, elapsed, remaining
- Pause / Resume / Stop / Skip round controls
- Full-screen colour flash on transitions
- Voice announcement at session start and end
- Status bar hidden for full immersion

### Session Summary
- Total time, rounds completed
- Save to Apple Health (one tap)
- Start again or return to library

### Settings
- Cue volume slider with live bell preview
- "Louder than music" toggle (audio ducking)
- FAQ
- Contact support
- Subscription management (via App Store)
- Privacy Policy and Terms of Service
- Free trial indicator showing days remaining

---

## Preset Library

### Mind
| Preset | Structure | Total |
|---|---|---|
| Box Breathing | 4s × 4 phases | 4 min 48s per set |
| 4-7-8 Breathing | 4s / 7s / 8s | ~6 min |
| Coherent Breathing | 5s inhale / 5s exhale × 20 | ~3 min |
| Pre-Sleep Breathing | 4s / 6s / 2s × 20 | ~8 min |
| 10-Minute Meditation | Bell every 2 min × 5 | 10 min |
| 15-Minute Meditation | Bell every 3 min × 5 | 15 min |
| 20-Minute Meditation | Bell every 5 min × 4 | 20 min |
| 30-Minute Meditation | Bell every 5 min × 6 | 30 min |

### Body
| Preset | Structure | Total |
|---|---|---|
| Tabata | 20s work / 10s rest × 8 | 4 min |
| HIIT | 40s work / 20s rest × 10 | 10 min |
| Sprint Intervals | 20s sprint / 100s walk × 8 | ~16 min |
| Mobility Drill | 4s move / 6s hold / 4s return × 8 | ~3 min |
| Strength Movement Pattern | 3s contract / 3s hold / 5s release × 10 | ~2 min |

### Productivity
| Preset | Structure | Total |
|---|---|---|
| Pomodoro | 25 min focus / 5 min break × 4 | 2 hrs |
| Deep Work | 4 × 30 min phases | 2 hrs |
| Ultradian Focus | 75 min focus / 20 min recover × 2 | ~3 hrs |

---

## Technical Foundation

- **Platform:** iOS 17+, iPhone
- **Language:** Swift 6 / SwiftUI
- **Persistence:** SwiftData (local, no cloud)
- **Audio:** AVFoundation — 13 original sound cues (WAV/MP3), male and female voice recordings
- **Haptics:** Core Haptics — 3 patterns (soft pulse, double tap, long buzz)
- **Health:** HealthKit — Mindful Sessions and HIIT Workouts
- **Privacy:** No analytics, no tracking, no data leaves the device

---

## Monetisation

Cadence offers a **7-day free trial** with access to all features. After the trial period, a premium subscription unlocks continued use. Subscriptions are managed entirely through Apple's App Store.

---

## Target Audience

- People with a regular breathwork or meditation practice who want a purpose-built tool, not a general wellness app
- Fitness enthusiasts who want a clean, distraction-free interval timer for HIIT, Tabata, or custom protocols
- Knowledge workers who use structured focus methods (Pomodoro, deep work blocks) and want a phone-based timer that stays out of the way
- **People who find voice guidance more annoying than helpful** — Cadence defaults to subtle sound and haptic cues rather than spoken instructions, so the practice stays uninterrupted and in your own head. Voice announcements exist but are entirely optional
- Anyone who finds general timer apps too barebones and dedicated wellness apps too cluttered
