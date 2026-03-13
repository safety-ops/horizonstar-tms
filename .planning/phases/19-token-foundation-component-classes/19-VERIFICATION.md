---
phase: 19-token-foundation-component-classes
verified: 2026-03-12T22:00:00Z
status: gaps_found
score: 4/6 must-haves verified
gaps:
  - truth: "Font weights capped at 600 (no 700 or 800)"
    status: failed
    reason: "variables.css and base.css correctly cap weights at 600, but index.html inline style block (lines 35-9600) still contains 422 instances of font-weight:700 and 85 instances of font-weight:800"
    artifacts:
      - path: "index.html"
        issue: "422x font-weight:700 and 85x font-weight:800 remain in the inline style block (lines 35-9600)"
    missing:
      - "Replace all font-weight:700 with 600 in inline CSS style block (lines 35-9600)"
      - "Replace all font-weight:800 with 600 in inline CSS style block (lines 35-9600)"
  - truth: "Decorative hover transforms fully removed"
    status: partial
    reason: "Most decorative keyframes removed but 3 decorative hover scale transforms remain in the inline style block"
    artifacts:
      - path: "index.html"
        issue: "Decorative hover scales at lines 6685 (.live-map-panel-fab:hover scale 1.05), 7517 (.stat-card:hover .stat-icon scale 1.08), 8134 (.nav-item:hover .icon scale 1.15)"
    missing:
      - "Remove transform:scale from .live-map-panel-fab:hover (line 6685)"
      - "Remove transform:scale from .stat-card:hover .stat-icon (line 7517)"
      - "Remove transform:scale from .nav-item:hover .icon (line 8134)"
---

# Phase 19: Token Foundation & Component Classes Verification Report

**Phase Goal:** The CSS token layer and component class library produce the Stripe/Linear aesthetic globally -- neutral surfaces, restrained shadows, tighter radius, medium-weight typography, dark slate buttons, and flat component patterns ready for page sweeps.
**Verified:** 2026-03-12T22:00:00Z
**Status:** gaps_found
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Neutral slate-gray surface hierarchy (Tailwind Slate palette) | VERIFIED | variables.css: --bg-primary: #f8fafc, --text-primary: #0f172a, --border: #e2e8f0, --bg-tertiary: #f1f5f9 |
| 2 | Shadows barely visible -- 3 depth levels (xs/sm/md), no glow | VERIFIED | variables.css lines 60-72: --shadow-xs (0.04 opacity), --shadow-sm (0.06/0.03), --shadow-md (0.08/0.04). Glow tokens set to none. |
| 3 | All primary buttons dark slate (#0f172a) | VERIFIED | variables.css line 152: --btn-primary-bg: #0f172a. base.css line 917: .btn-primary uses var(--btn-primary-bg) |
| 4 | Decorative animations gone | PARTIAL | All 32 decorative keyframes (cardEnter, driveTruck, numberPop, etc.) removed. But 3 decorative hover scale transforms remain (lines 6685, 7517, 8134) |
| 5 | Reusable component classes exist | VERIFIED | base.css: .btn-primary (L916), .btn-secondary (L942), .btn-ghost (L968), .btn-danger (L994), .badge-success (L1051), .stat-flat (L1058), .data-table (L439), .status-badge (L417) |
| 6 | Font weights capped at 600 | FAILED | variables.css correct (--weight-bold: 600, --weight-heavy: 600). base.css correct (only .font-bold at 700 for backward compat). But index.html inline styles: 422x font-weight:700, 85x font-weight:800 in style block lines 35-9600 |

**Score:** 4/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `assets/css/variables.css` | Complete Stripe/Linear token layer | VERIFIED | 162 lines, slate palette, 3-level shadows, tighter radius (6/8/12px), dark slate button tokens, weights capped at 600, glow tokens = none |
| `assets/css/base.css` | Component class library | VERIFIED | 1704 lines. .btn-primary/.btn-secondary/.btn-ghost/.btn-danger, .badge-success/warning/danger/info/neutral, .stat-flat, .data-table, .input/.select/.textarea, .status-badge |
| `index.html` inline styles | Neutralized competing declarations | PARTIAL | Competing :root overrides removed (rem sizes, indigo spectrum, gradients). But 507 instances of font-weight 700/800 remain in the inline style block |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| variables.css tokens | base.css components | var() references | WIRED | .btn-primary uses var(--btn-primary-bg), shadows use var(--shadow-xs), radius uses var(--radius-sm) |
| variables.css | index.html inline :root | Cascade order (no conflicts) | WIRED | Competing :root overrides for fonts, colors, gradients removed in Plan 01 |
| base.css component classes | render functions | CSS class usage | READY | Classes available; page sweeps will adopt them |

### Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| TOK-01: Slate palette | SATISFIED | -- |
| TOK-02: 3-level shadows | SATISFIED | -- |
| TOK-03: Weights capped at 600 | BLOCKED | 507 instances of 700/800 in index.html inline style block |
| TOK-04: Radius tightened | SATISFIED | 6px/8px/12px/12px |
| TOK-05: Dark slate buttons | SATISFIED | --btn-primary-bg: #0f172a |
| CMP-01: Flat cards | SATISFIED | .card uses 1px border, var(--shadow-xs) |
| CMP-02: Flat buttons | SATISFIED | .btn-primary/secondary/ghost/danger classes defined |
| CMP-03: Clean tables | SATISFIED | .data-table with sticky headers, subtle hover |
| CMP-04: Desaturated badges | SATISFIED | .badge-success etc. use 8% dim tint backgrounds |
| CMP-05: Decorative animations removed | PARTIAL | 32 keyframes removed; 3 decorative hover scales remain |
| CMP-06: Subtle hover states | PARTIAL | Most hovers are background-color only; 3 scale transforms remain |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| index.html | 277-8813 | font-weight: 700 (422 instances) | WARNING | Typography not capped at 600 in inline styles; renders heavier than intended |
| index.html | 4557-8149 | font-weight: 800 (85 instances) | WARNING | Extra-heavy weights break Stripe/Linear aesthetic |
| index.html | 6685 | .live-map-panel-fab:hover scale(1.05) | INFO | Decorative hover transform not removed |
| index.html | 7517 | .stat-card:hover .stat-icon scale(1.08) | INFO | Decorative hover transform not removed |
| index.html | 8134 | .nav-item:hover .icon scale(1.15) | INFO | Decorative hover transform not removed |
| base.css | 157 | .font-bold { font-weight: 700 } | INFO | Intentional backward compat -- page sweeps will stop using it |

### Human Verification Required

### 1. Slate Surface Hierarchy Visual Check
**Test:** Open the app in a browser. Verify the background has a cool slate-gray tone, not warm zinc/gray.
**Expected:** Page background should be #f8fafc (very light cool gray), cards white, borders #e2e8f0.
**Why human:** Programmatic check confirms token values but actual rendering depends on browser and any overrides deeper in JS.

### 2. Shadow Subtlety Check
**Test:** Look at any card on dashboard, orders, or trips page.
**Expected:** Shadows should be barely visible -- no glow effects, no prominent elevation.
**Why human:** Shadow perception is visual; the token values are correct but need visual confirmation.

### 3. Button Appearance
**Test:** Find a primary action button (e.g., Add Order, Save).
**Expected:** Dark slate (#0f172a) background with white text. No gradient, no glow.
**Why human:** Inline styles in render functions may override the token-based button styling.

### Gaps Summary

Two gaps prevent full goal achievement:

1. **Font weights not capped at 600 in inline styles (TOK-03):** The token layer (variables.css) correctly defines --weight-bold and --weight-heavy as 600, and base.css component classes use max 600. However, the inline style block in index.html (lines 35-9600) still contains 422 instances of font-weight:700 and 85 instances of font-weight:800. These inline CSS rules apply to sidebar items, topbar elements, page headers, form labels, modal elements, and many other UI components that have not been updated. This is the primary gap.

2. **Three residual decorative hover transforms (CMP-05/CMP-06):** While all 32 decorative keyframes were successfully removed, three hover scale transforms remain in the inline style block: .live-map-panel-fab:hover, .stat-card:hover .stat-icon, and .nav-item:hover .icon. These are minor but technically violate the "no decorative hover transforms" requirement.

Note: The phase goal says "ready for page sweeps" which suggests the font-weight issue in JS template literals (lines 9600+) is expected to be addressed in later phases. However, the inline CSS style block (lines 35-9600) is within scope of this phase and should have been cleaned.

---

_Verified: 2026-03-12T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
