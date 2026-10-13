---
name: Sanctuary Elegance
colors:
  surface: '#fbf9f4'
  surface-dim: '#dbdad5'
  surface-bright: '#fbf9f4'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f3ee'
  surface-container: '#f0eee9'
  surface-container-high: '#eae8e3'
  surface-container-highest: '#e4e2dd'
  on-surface: '#1b1c19'
  on-surface-variant: '#404944'
  inverse-surface: '#30312e'
  inverse-on-surface: '#f2f1ec'
  outline: '#707974'
  outline-variant: '#c0c9c2'
  surface-tint: '#316853'
  primary: '#003626'
  on-primary: '#ffffff'
  primary-container: '#134e3a'
  on-primary-container: '#85bea4'
  inverse-primary: '#99d3b8'
  secondary: '#7b581d'
  on-secondary: '#ffffff'
  secondary-container: '#ffd089'
  on-secondary-container: '#79571c'
  tertiary: '#0b3529'
  on-tertiary: '#ffffff'
  tertiary-container: '#254c3f'
  on-tertiary-container: '#92bbab'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#b5efd3'
  primary-fixed-dim: '#99d3b8'
  on-primary-fixed: '#002115'
  on-primary-fixed-variant: '#16503c'
  secondary-fixed: '#ffddaf'
  secondary-fixed-dim: '#edbf7a'
  on-secondary-fixed: '#281800'
  on-secondary-fixed-variant: '#604105'
  tertiary-fixed: '#c1ecda'
  tertiary-fixed-dim: '#a6d0be'
  on-tertiary-fixed: '#002117'
  on-tertiary-fixed-variant: '#274e41'
  background: '#fbf9f4'
  on-background: '#1b1c19'
  surface-variant: '#e4e2dd'
typography:
  headline-lg:
    fontFamily: Noto Serif
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 48px
  headline-lg-mobile:
    fontFamily: Noto Serif
    fontSize: 26px
    fontWeight: '600'
    lineHeight: 38px
  headline-md:
    fontFamily: Noto Serif
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 34px
  headline-sm:
    fontFamily: Noto Serif
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: IBM Plex Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 30px
  body-md:
    fontFamily: IBM Plex Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: IBM Plex Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: IBM Plex Sans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: IBM Plex Sans
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: IBM Plex Sans
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.25rem
---

## Brand & Style

The design system establishes a quiet, contemplative sanctuary for spiritual lifestyle and devotion. Tailored specifically for modern Android experiences with full native Right-to-Left (RTL) precedence, it reflects refined Islamic aesthetics through restrained modernism rather than ornamental clutter. 

The emotional signature is grounded in tranquility, reverence, and effortless legibility. Interface surfaces mimic parchment and hand-milled paper under natural light, balanced with deep mineral stones and brushed brass accents. Geometric heritage is honored via minimal structural framing—utilizing subtle octagonal star (Khatam) silhouettes, clean 8-point geometric corners, and disciplined borders rather than overwhelming arabesques.

Every interaction prioritizes mindfulness: fluid touch gestures, ergonomic bottom-weighted controls for single-handed use during dhikr or reading, and an uncluttered screen architecture that respects moments of devotion.

## Colors

The palette balances organic mineral depth with soothing natural warmth, crafted to prevent visual fatigue during extended recitations and nocturnal prayer routines.

- **Primary (`#134E3A` / Deep Emerald):** Acts as the commanding brand anchor. Used for primary interactive triggers, active navigation markers, and prayer milestone highlights. Its companion shade (`#0F382C`) offers grounding contrast for elevated structural headers.
- **Secondary (`#C99E5C` / Muted Artisan Gold):** Used sparingly for ceremonial accents, active verse indicators, visual dividers, and badges of completion. Never deployed for large text blocks to preserve absolute legibility.
- **Surface & Canvas (`#FBF9F4` to `#F5F1E8`):** Warm ivory foundation avoiding the harsh glare of stark white. In dark mode, surfaces invert to deep sanctuary obsidian and nocturnal spruce (`#0B1914` canvas, `#12241E` surface container) with glowing emerald highlights.
- **Text & Contrast:** High-density charcoal (`#1A2420`) in light mode ensures crisp, high-clarity typography exceeding WCAG AAA contrast against ivory backdrops, while muted bronze-gray (`#637069`) serves secondary labels.

## Typography

Typography is architected specifically around the fluid mechanics of the Arabic script, resolving traditional vertical clipping and tight line-height issues common in multi-script engines.

- **Spiritual & Classical Passages:** Rendered using classical calligraphic proportioning, prioritizing open baselines, distinct diacritics (tashkeel), and expansive leading to allow breathing room for complex ligatures.
- **UI & Structural Functional Text:** Rendered via structured Arabic grotesque typography. Engineered with robust horizontal metrics, open counters, and distinctive letter stems that maintain razor-sharp clarity across dense lists, prayer timetables, and micro-labels.
- **RTL Baseline Alignment:** All letter spacing is maintained at natural script connections; negative tracking is strictly avoided to prevent ligature fractures. Heading line-heights are intentionally relaxed (1.45–1.55x) to accommodate tall ascenders and deep descenders.

## Layout & Spacing

The layout is built around an ergonomic mobile-first 4-column grid (scaling to 8 columns on foldables and tablets), with native RTL margin priority.

- **One-Handed Ergonomics (Thumb Zone):** Critical touch targets, primary prayer toggles, and the digital tasbih (counter) anchor within the lower 40% of the viewport. High-frequency actions rest within easy reach of the lower thumb sweep.
- **RTL Flow Dynamics:** Information flows naturally from right to left. Navigational progress tracks right-to-left, trailing icons become leading icons, and numerical sequence markers anchor comfortably on the right margin.
- **Vertical Rhythm:** A strict 8dp base unit underpins all layout spacing. Card padding defaults to `space-md` (16px), while spacious devotional passages expand with `space-lg` and `space-xl` breathing room to foster focus and minimize cognitive clutter.

## Elevation & Depth

Depth is conveyed through delicate physical layering inspired by bound manuscript leaves and carved architectural stone, avoiding harsh artificial drop shadows.

- **Surface Tiers:** Content layers ascend from the foundational warm canvas (`#FBF9F4`) to elevated reading cards (`#FFFFFF` in light mode, `#162C24` in dark mode). Higher-elevation elements (such as persistent bottom sheets or player controls) introduce subtle tinted backdrops.
- **Ambient Chromatic Shadows:** Shadows are soft, wide-dispersion halos tinted with deep emerald and warm charcoal rather than pure black (e.g., `rgba(15, 56, 44, 0.06)` with a 16px blur radius and 4px vertical offset). This creates a warm, natural lift resembling diffuse morning ambient light.
- **Geometric Filigree Borders:** Elevated cards utilize a hairline inner border (`1px solid rgba(201, 158, 92, 0.2)`) that catches light with a whisper of brushed gold, anchoring the tactile luxury feel without creating visual noise.

## Shapes

The design system deploys a structured, balanced radius language (`roundedness: 2`, base 8px/0.5rem radius) that softens modern geometry while maintaining structural order.

- **Cards and Containers:** Feature an 8px (`rounded-md`) to 16px (`rounded-lg`) corner radius, echoing the subtle rounded angles of carved marble and traditional architectural masonry.
- **Octagonal Motifs:** Badges, verse markers, and chapter badges utilize chamfered octagonal framing or 8-pointed star silhouettes, providing authentic visual geometry directly derived from historic Islamic patterns.
- **Tactile Pills:** Floating action controls, counter chips, and the bottom prayer indicator bar adopt full pill profiles (`rounded-full`) for finger-friendly comfort and effortless touch responsiveness.

## Components

### Buttons & Interactive Controls
- **Primary Action Button:** Solid deep emerald background (`#134E3A`) with ivory text, styled with an 8px radius and a discreet hairline gold top edge. Height is fixed at 52px for generous touch targets.
- **Secondary Devotional Action:** Outlined button featuring a 1.5px warm gold border (`#C99E5C`) with deep emerald typography, providing high contrast without competing with the primary call to action.
- **Haptic Tasbih Counter:** A specialized massive tactile surface (80x80px minimum) rendered with concentric dual-ring borders and center-burst ripple animations on tap, engineered specifically for thumb tap counting without looking at the screen.

### Navigation & App Bars
- **RTL Navigation Bar:** Back arrows, chapter transitions, and drawer triggers mirror automatically for RTL. Titles sit flush right next to contextual glyphs.
- **Sanctuary Bottom Navigation:** Floating docked dock with 24px corner radius, finished in frosted warm ivory (`rgba(251, 249, 244, 0.92)`) or nocturnal emerald (`rgba(18, 36, 30, 0.92)`) with backdrop blur. Active states illuminate with a muted gold dot indicator beneath the icon.

### Cards & Reading Surfaces
- **Prayer Time Horizon Card:** Elevated card featuring the next upcoming prayer with an active progress arc, framed with a hairline gold accent and an understated geometric Khatam watermarked subtly into the corner.
- **Ayah & Dhikr Container:** Generous padding (`space-lg`), high-contrast classical script, complete with a gilded octagonal verse counter positioned on the far right.

### Input Fields, Chips & Toggles
- **Inputs:** Soft ivory fill with a recessed 1px charcoal/gold border, activating into a distinct emerald outline when focused. Trailing action glyphs (e.g., audio playback or search clearance) anchor on the far left to respect RTL input flow.
- **Category Chips:** Horizontal scrolling pill tags (`space-sm` vertical, `space-md` horizontal padding). Inactive chips sit transparent with soft green borders; active chips fill with deep emerald and crisp ivory text.