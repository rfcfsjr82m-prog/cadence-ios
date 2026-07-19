# Cadence — Design Guidelines

These guidelines define the visual language for Cadence across all touchpoints including the website, marketing materials, and App Store presence. They are derived directly from the app's design system.

---

## Brand Personality

**Calm. Precise. Tactile.**

Cadence should feel like a tool made by someone who actually uses it. Not clinical, not playful — somewhere between the two. The aesthetic is understated: dark backgrounds, careful spacing, subtle contrast. Colour is used sparingly but with purpose. Nothing shouts.

Key traits to communicate:
- Quiet confidence — it does one thing and does it well
- Depth without complexity — powerful under the surface, simple on top
- Physicality — it connects to the body, to breath, to rhythm
- Focus — distraction-free, nothing unnecessary

---

## Logo & Name

**Wordmark:** Cadence
- Set in a geometric sans-serif (SF Pro Display or equivalent)
- Weight: Medium or Semibold
- Letter-spacing: slightly tracked out (+0.5–1%)
- Always on dark background; avoid light backgrounds

**App Icon:**
- Concentric arc rings on near-black (`#080809`)
- The rings graduate from near-white (bright) through mid-grey to dark grey — representing progress, rhythm, and cycles
- Do not place the icon on white or light backgrounds
- Minimum display size: 44×44px; preferred: 60px and above

---

## Colour

### Background Hierarchy
Four levels of dark surface, used to create depth without adding borders.

| Role | Hex | Usage |
|---|---|---|
| Background | `#0F0F11` | Page background, main canvas |
| Surface | `#18181C` | Cards, input fields, list items |
| Surface 2 | `#1F1F25` | Elevated cards, modals |
| Surface 3 | `#27272F` | Nested elements, hover states |
| Timer (deepest) | `#080809` | Full-bleed immersive contexts |

### Text
| Role | Hex | Usage |
|---|---|---|
| Primary | `#F0F0F2` | Headlines, body copy, labels |
| Secondary | `#8A8A96` | Subtitles, supporting text, metadata |
| Tertiary | `#56565E` | Placeholders, disabled states, captions |

### Accent
| Role | Hex | Usage |
|---|---|---|
| Accent | `#7C6FFF` | CTAs, active states, links, highlights |
| Accent dim | `#7C6FFF` at 15% opacity | Backgrounds behind accent elements |

The accent is a soft violet — not electric, not pastel. It should feel like it belongs in the dark environment, not like it's been dropped in from a different palette.

### Interval Block Colours
These colours represent individual interval phases in the timer. On the website they can be used as accent swatches, illustration elements, or to add warmth to an otherwise monochromatic layout. Never use more than 2–3 together in one composition.

| Name | Hex | Character |
|---|---|---|
| Teal | `#3DD9A4` | Calm, restorative |
| Lavender | `#A78BFA` | Focused, meditative |
| Coral | `#FF7B6B` | Active, energetic |
| Amber | `#F5A623` | Warm, holding |
| Sky | `#60B8FF` | Open, breathable |
| Pink | `#F472B6` | Light, expressive |
| Sage | `#86EFAC` | Steady, grounded |

### Borders
- Default border: `rgba(255, 255, 255, 0.08)` — use on cards and containers
- Elevated border: `rgba(255, 255, 255, 0.14)` — use on modals or focus states
- Never use solid-colour borders on dark backgrounds; always use white at low opacity

---

## Typography

Cadence uses the system font stack. On the web, use **Inter** as the primary typeface — it matches the proportions and feel of SF Pro used in the app.

### Type Scale

| Role | Size | Weight | Tracking | Usage |
|---|---|---|---|---|
| Display | 56–72px | Light (300) | -1% | Hero headlines |
| Headline 1 | 40px | Semibold (600) | -0.5% | Section titles |
| Headline 2 | 28px | Semibold (600) | -0.5% | Card headings |
| Body Large | 18px | Regular (400) | 0 | Lead paragraphs |
| Body | 16px | Regular (400) | 0 | Standard body copy |
| Body Small | 14px | Regular (400) | 0 | Secondary descriptions |
| Label | 12px | Medium (500) | +3–5% | Section labels, tags (uppercase) |
| Mono | 14–52px | Light (300) | 0 | Timer digits, data values |

### Rules
- Headlines and display text: always `#F0F0F2`
- Body copy: `#8A8A96` on dark backgrounds for comfortable long-form reading; use `#F0F0F2` for short punchy copy
- Section labels: uppercase, tracked out, `#56565E`
- Monospaced figures for any numeric data (countdown, stats, duration)
- Line height: 1.5× for body, 1.2× for headlines

---

## Spacing & Layout

Cadence uses an **8px base grid**. All spacing values are multiples of 8.

| Token | Value | Usage |
|---|---|---|
| xs | 4px | Icon gaps, tight inline spacing |
| sm | 8px | Within components |
| md | 16px | Component padding, list gaps |
| lg | 24px | Section spacing |
| xl | 40px | Large section gaps |
| 2xl | 64px | Page section breaks |
| 3xl | 96–120px | Hero padding |

**Max content width:** 1120px, centred
**Column gutter:** 24px
**Page horizontal padding:** 24px (mobile), 48px (tablet), 80px (desktop)

---

## Components

### Cards
- Background: `#18181C`
- Border: 0.5px, `rgba(255,255,255,0.08)`
- Border radius: 14px (standard), 12px (compact)
- Padding: 16–20px
- No drop shadows — depth is created through surface layers, not shadows
- On hover (web): border brightens to `rgba(255,255,255,0.14)`; subtle scale `1.01`

### Buttons

**Primary (CTA)**
- Background: `#7C6FFF`
- Text: `#F0F0F2`, Medium weight
- Border radius: 12px
- Padding: 14px 24px
- Hover: brightness +8%, scale `1.01`
- No heavy box shadows

**Secondary / Ghost**
- Background: `rgba(255,255,255,0.06)`
- Border: `rgba(255,255,255,0.10)`
- Text: `#F0F0F2`
- Hover: background `rgba(255,255,255,0.10)`

**Text button / Link**
- Color: `#7C6FFF`
- No underline by default; underline on hover

### Pills / Tags
- Background: accent or block colour at 12–18% opacity
- Text: matching full-opacity colour
- Font: 11px, Bold, uppercase, tracked +3%
- Border radius: full (capsule)
- Padding: 3px 8px

### Dividers
- `rgba(255,255,255,0.08)`, 0.5–1px
- Never use solid grey dividers

---

## Iconography

- Use **SF Symbols** style icons or equivalents (Lucide, Phosphor in Regular weight)
- Stroke weight: 1.5px at 24px size
- Color: `#8A8A96` (secondary) for decorative; `#F0F0F2` (primary) for interactive
- Never fill icons in flat UI contexts — use stroked outline style throughout
- Accent color (`#7C6FFF`) for active/selected icon states

---

## Motion & Animation

Cadence is not a flashy app. Animation serves purpose — it communicates state, not personality.

### Principles
- **Ease in/out** for navigational transitions (0.28–0.35s)
- **Linear** for progress indicators and countdown rings
- **Spring** for appearing elements (response: 0.45, damping: 0.82)
- No bounce on exit animations
- Reduced motion: all transitions fall back to simple fades

### Specific patterns
- Page/section enters: fade up 12px, 0.3s ease-out
- Cards on scroll: stagger 40ms between items, fade + 8px upward
- CTA button press: scale 0.97, 0.12s ease-in, return 0.18s ease-out
- Number changes (stats): quick crossfade, 0.15s

---

## Photography & Imagery

Cadence does not use lifestyle photography of people exercising or meditating — that territory is saturated and generic.

**Preferred visual directions:**
- **Abstract macro** — close-up textures, breath on glass, water ripples, fabric folds
- **Minimal still life** — a phone on a quiet surface, objects with intentional negative space
- **Dark, low-key lighting** — images should sit comfortably on `#0F0F11` without jarring
- **Monochromatic with one accent colour** — compositions that echo the app palette

**Avoid:**
- Stock photo aesthetics (generic athlete, woman eyes closed in sunlight)
- Bright white or heavily saturated backgrounds
- Busy, cluttered compositions
- Any imagery that implies the app is exclusively for fitness or exclusively for meditation

---

## App Screenshots & Mockups

- Always show the app on a device with a dark background
- Device frame: iPhone 15 Pro in Black Titanium or frameless (screenshot only)
- Background: `#0F0F11` or a very subtle radial gradient (centre `#1A1A20`, edge `#0F0F11`)
- Optional: place 1–2 block colours as soft glowing orbs behind the device for depth
- Caption text: SF Pro / Inter, 13–14px, `#8A8A96`

---

## Voice & Tone

**In headlines:** Short, confident, present tense. No hype.
> "Structure your practice." not "Take your wellness to the next level!"

**In body copy:** Calm and direct. Speak to someone who already knows what they want — you're not convincing them, you're showing them it exists.
> "Set your phases, pick your cues, go." not "Our revolutionary AI-powered timer helps you achieve your goals."

**In UI labels and microcopy:** Minimal. Only what's needed.
> "Start & End" not "Configure Opening and Closing Options"

**Avoid:**
- Wellness clichés ("journey", "transformation", "mindful living")
- Hyperbole ("best", "perfect", "ultimate")
- Second-guessing the user ("Are you sure?", "Don't forget to...")

---

## Don'ts

- Don't use light/white backgrounds anywhere in Cadence-branded contexts
- Don't mix more than 3 block colours in one composition
- Don't add drop shadows to cards — use surface layering instead
- Don't use rounded-rectangle app icon on a white or coloured background
- Don't use a different typeface for the wordmark without explicit approval
- Don't use the accent violet (`#7C6FFF`) for large background fills — it's an accent, not a base
