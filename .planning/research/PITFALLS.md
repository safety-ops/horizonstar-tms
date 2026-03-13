# Domain Pitfalls: Incremental Dashboard Restyle to Stripe/Linear Aesthetic

**Domain:** Restyling a large existing dashboard app (48K-line single-file SPA)
**Researched:** 2026-03-12
**Context:** Two prior restyle attempts failed (v1.2 too ambitious, v1.3 too conservative). Current approach: page-by-page incremental restyle with CSS + JS changes.

---

## Critical Pitfalls

Mistakes that cause rewrites, reverts, or abandonment (as already happened twice).

### Pitfall 1: The Frankenapp Problem (Mixed Visual States)

**What goes wrong:** When you restyle page-by-page, the app spends weeks or months in a "half-old, half-new" state. Restyled pages look clean and flat, unrested pages look dated. Shared components (modals, toasts, sidebar, topbar) must serve both aesthetics simultaneously. Users navigate between pages and experience jarring visual whiplash.

**Why it happens:** Each `renderXxx()` function produces self-contained HTML with inline styles. There is no shared component layer -- each page re-implements its own cards, filters, headers, and badges inline. Changing the sidebar or modal to match the new aesthetic before all pages are updated makes unrested pages look broken.

**Consequences:**
- Shared chrome (sidebar, topbar, modals) can only be restyled once ALL pages are done, or else unrested pages look wrong
- Users perceive the app as "broken" or "unfinished" rather than "being improved"
- Motivation to finish drops because the mixed state feels worse than the original

**Prevention:**
1. Restyle shared chrome (sidebar, topbar) LAST, not first
2. Keep a strict "old page / new page" boundary -- do not half-restyle a page
3. Within each page, restyle the ENTIRE render function at once (not just the header, then cards later)
4. Add a CSS class (e.g., `.restyled`) to the container of each completed page so shared styles can target both states
5. Prioritize the pages users see most (Dashboard, Orders, Trips) to minimize time in mixed state

**Detection:** Navigate between a restyled page and an unrested page. If the transition feels jarring, the Frankenapp problem is active.

**Which phase should address it:** Phase 1 planning -- define page order and shared-component strategy before touching code.

---

### Pitfall 2: Inline Style Whack-a-Mole (4,344 Inline Styles)

**What goes wrong:** The codebase has 4,344 inline `style=` attributes embedded in JavaScript template literal strings. Changing the aesthetic requires touching most of these. But inline styles are scattered across concatenated strings, ternary expressions, and computed values -- they cannot be overridden by CSS classes because inline styles have the highest specificity (short of `!important`).

**Why it happens:** The app was built without a build step, so inline styles in `innerHTML` template literals were the fastest way to style dynamic content. This is now the single biggest obstacle to restyling.

**Consequences:**
- CSS-only changes (variables.css, base.css) cannot override inline styles -- v1.3's CSS-only approach failed because of this
- Each render function must be manually edited to replace inline styles with classes or CSS variables
- Risk of breaking layout when removing an inline style that also set structural properties (display, flex, gap, position)
- Regex find-and-replace is dangerous because inline styles are embedded in JS string concatenation with conditional logic

**Prevention:**
1. For each render function, categorize inline styles as STRUCTURAL (display, flex, grid, position, width) vs COSMETIC (color, background, border-radius, box-shadow, font-weight)
2. Replace cosmetic inline styles with CSS classes or CSS variable references
3. Leave structural inline styles alone unless they conflict with the new aesthetic
4. Never do blind find-and-replace -- each inline style must be understood in context
5. When a style appears in a ternary (e.g., `background: isActive ? 'green' : 'transparent'`), convert to class toggling (e.g., `class="${isActive ? 'active' : ''}"`)

**Detection:** After restyling a page, search for remaining `style=` attributes in that render function. If cosmetic properties remain inline, the job is incomplete.

**Which phase should address it:** Every page-restyle phase. Establish the pattern in Phase 1 (first page) and follow it consistently.

---

### Pitfall 3: The Boil-the-Ocean Trap (Scope Creep per Page)

**What goes wrong:** When restyling a page, the developer sees "while I'm here" opportunities -- refactoring the render function, adding new features, fixing data bugs, restructuring the HTML. The restyle of one page balloons from a 1-hour task to a 6-hour task. After two pages, momentum stalls. This is exactly what killed v1.2.

**Why it happens:** The render functions are dense (100-400 lines of HTML-in-JS). Once you start editing, every imperfection becomes visible. The temptation to "fix everything" is overwhelming, especially when inline styles are interleaved with logic.

**Consequences:**
- Individual page restyles take 3-5x longer than estimated
- More code changed per commit = higher regression risk
- Fatigue sets in after 2-3 pages, leaving the app in the Frankenapp state
- Reverts become necessary (as happened with v1.2)

**Prevention:**
1. Define a strict restyle checklist per page: colors, typography, spacing, shadows, border-radius -- NOTHING ELSE
2. Do NOT refactor render function structure during restyle
3. Do NOT add new features or fix non-visual bugs during restyle
4. Do NOT restructure HTML nesting during restyle
5. Set a time-box per page (e.g., 45 minutes). If it takes longer, the scope is too big -- split the page into sections
6. Commit after each completed page, not after a batch

**Detection:** If a restyle diff touches JS logic (conditionals, data access, event handlers), scope has crept.

**Which phase should address it:** Enforced from Phase 1 onward. The checklist should be written before any code changes begin.

---

### Pitfall 4: Dark Mode Afterthought

**What goes wrong:** The restyle is built for light mode. When dark mode is addressed later, half the new styles use hardcoded colors instead of CSS variables. Dark mode looks broken -- wrong contrast, invisible text, borders that disappear, backgrounds that blend together.

**Why it happens:** PROJECT.md says "light mode priority, dark mode follows." This is correct strategically but dangerous tactically. When replacing inline styles like `background:#f5f5f5` with `background:var(--bg-tertiary)`, developers must verify the dark-mode value of that variable works too. When adding NEW styles not covered by existing variables, developers hardcode light-mode values.

**Consequences:**
- Dark mode requires a second pass over every restyled page
- New hardcoded colors in the restyle defeat the purpose of the CSS variable system
- Users who prefer dark mode see a worse experience than before the restyle

**Prevention:**
1. NEVER introduce a hardcoded color value. Every color must reference a CSS variable.
2. After restyling each page in light mode, toggle dark mode and verify. This takes 30 seconds.
3. If a needed color does not exist as a variable, add it to variables.css with BOTH light and dark values before using it
4. The `.dark-theme` class and variable overrides in `<style>` block (line 35 of index.html) must be checked for completeness

**Detection:** Toggle dark mode after each page restyle. If anything looks wrong, hardcoded colors snuck in.

**Which phase should address it:** Every phase. Dark mode verification is part of the "done" checklist for each page.

---

## Moderate Pitfalls

Mistakes that cause delays, rework, or technical debt.

### Pitfall 5: Specificity Wars with Existing CSS

**What goes wrong:** The existing `base.css` (1000+ lines) and `variables.css` define component styles (`.card`, `.stat-card`, `.data-table`, `.status-badge`, etc.). New restyle CSS is added, but existing selectors fight with new ones. Developers add `!important` to force the new styles, creating a specificity escalation that makes future changes even harder.

**Why it happens:** The app has three layers of styling: (1) CSS files, (2) `<style>` blocks in index.html, (3) inline `style=` attributes. Inline styles beat everything. CSS file styles may conflict with `<style>` block styles. Adding a fourth layer ("restyle CSS") without cleaning up the others creates chaos.

**Prevention:**
1. Do NOT add a fourth CSS file. Modify base.css and variables.css in place.
2. When restyling a page, remove inline styles and let the CSS file classes take over
3. Never use `!important` -- if a style is not applying, find the higher-specificity source and remove it
4. The `<style>` blocks in index.html (lines 35, 34801, 37040, 47007) must be audited -- move any general styles to base.css

**Which phase should address it:** Phase 1 should audit the `<style>` blocks and establish the specificity strategy.

---

### Pitfall 6: Typography and Spacing Inconsistency Across Pages

**What goes wrong:** Stripe/Linear aesthetics rely heavily on consistent typography scale, letter-spacing, and whitespace rhythm. When each page is restyled independently, subtle differences creep in -- one page uses 13px body text, another uses 14px. One page has 24px section gaps, another has 20px. The result looks "off" without anyone being able to pinpoint why.

**Why it happens:** With 48K+ render functions each setting their own font-size, padding, gap, and margin inline, there is no enforced consistency. Each render function is its own island.

**Prevention:**
1. Define the typography scale ONCE before starting: heading sizes, body text, labels, captions, monospace
2. Define the spacing scale ONCE: section gaps, card padding, element spacing (already partially done with `--space-*` tokens)
3. Create a one-page "restyle reference" showing the exact values for each element type
4. When restyling each page, reference the scale -- do not eyeball values

**Detection:** After 3+ pages are restyled, screenshot them side by side. Look at heading sizes, label styles, card padding. If they are not pixel-identical, the scale is drifting.

**Which phase should address it:** Phase 1 must define the scale. Phase 2+ must enforce it.

---

### Pitfall 7: Losing Functional Styles During Cosmetic Changes

**What goes wrong:** An inline style like `style="padding:5px 9px;font-size:12px;background:var(--dim-blue);color:var(--info)"` contains both cosmetic properties (font-size, color) and functional ones (padding that ensures click targets are large enough). When replacing with a CSS class, the functional padding is lost, and buttons become too small to click on mobile.

**Why it happens:** In the current codebase, structural and cosmetic styles are mixed together in single `style` attributes. There is no separation. The developer removing inline styles may not realize that a `padding` or `min-width` or `gap` was serving a functional purpose.

**Prevention:**
1. When removing an inline style, test the element's interactivity (clickable? scrollable? visible?)
2. Preserve all `min-width`, `min-height`, `padding` on interactive elements (buttons, inputs, checkboxes)
3. The 44px minimum touch target rule for mobile must be verified after restyling
4. Keep structural layout properties (`display:flex`, `gap`, `grid-template-columns`) inline if they are page-specific and not generalizable

**Detection:** After restyling, test on mobile viewport (375px). If buttons are hard to tap or layouts break, functional styles were lost.

**Which phase should address it:** Every phase. Mobile check is part of the "done" checklist.

---

### Pitfall 8: The "Just CSS Variables" Illusion

**What goes wrong:** Developer assumes swapping CSS variable values in `variables.css` will achieve the restyle. Changes `--shadow-sm` to be subtler, `--radius` to be smaller, `--bg-primary` to be more neutral. But most styling is INLINE (4,344 instances), so CSS variable changes only affect the ~300 lines of base.css. 90% of the app looks unchanged.

**Why it happens:** This is approximately what v1.3 tried. The variable system is well-designed but vastly underused -- the majority of styling bypasses it via inline styles.

**Consequences:**
- Days of work on variables.css with minimal visible impact
- Frustration and abandonment (exactly what happened with v1.3)
- False sense of progress because the CSS file looks "done"

**Prevention:**
1. Accept upfront: variables.css changes are necessary but NOT sufficient
2. The real work is converting inline styles in each `renderXxx()` function to use CSS classes/variables
3. Track progress as "pages fully restyled" not "variables updated"

**Detection:** After changing variables.css, if less than 20% of the visual change is visible, inline styles are dominating.

**Which phase should address it:** Phase 1 planning should set realistic expectations.

---

### Pitfall 9: Gradient/Glow Removal Creates "Flat = Boring" Perception

**What goes wrong:** The current UI has 99 gradients, 118 box-shadows, glass effects, and glow animations. Removing these for a flat Stripe/Linear look makes the app feel lifeless and cheap if not replaced with proper visual hierarchy using spacing, typography weight, and subtle borders.

**Why it happens:** Gradients and shadows provide visual hierarchy. Remove them without adding alternative hierarchy (e.g., font-weight contrast, border-bottom separators, background tints for sections) and the page becomes a wall of same-looking white boxes.

**Prevention:**
1. Study how Stripe/Linear create hierarchy WITHOUT shadows/gradients: typographic weight, subtle borders, background color shifts, strategic whitespace
2. When removing a gradient from a card, ADD something: a top border-color accent, or a background tint, or bolder heading text
3. The status badge colors (green/amber/red) are the app's primary visual language -- preserve them and make them more prominent in the flat design
4. Use the `.hero-card` left-border pattern already in base.css as a model

**Detection:** After removing gradients, if a page looks like an unstyled HTML document, visual hierarchy cues are missing.

**Which phase should address it:** Phase 1 should define the hierarchy toolkit (what replaces gradients/shadows). Apply from Phase 2 onward.

---

## Minor Pitfalls

Mistakes that cause annoyance but are fixable.

### Pitfall 10: Forgetting Print Styles

**What goes wrong:** The app has a 491-line `print.css` for payroll PDFs and reports. Restyle changes may break print layouts if print.css relies on the same class names or structural elements that get modified.

**Prevention:** After restyling Payroll and Billing pages, do a print preview test.

**Which phase should address it:** The phase that restyles Payroll/Billing pages.

---

### Pitfall 11: Inconsistent Icon Treatment

**What goes wrong:** The app has 136 dual-tone SVG icons (recently replaced). The Stripe/Linear aesthetic typically uses single-weight, monochrome icons. The existing dual-tone icons may clash with the flat aesthetic.

**Prevention:** Evaluate icon style compatibility early. If icons need to change, that is a separate task -- do not block the restyle on it.

**Which phase should address it:** Assess in Phase 1, execute as a standalone task if needed.

---

### Pitfall 12: Stale CSS Accumulation

**What goes wrong:** As inline styles are converted to classes, old CSS rules in base.css become orphaned. New utility classes are added. Over time, the CSS file grows with dead code, conflicting rules, and duplicate patterns.

**Prevention:** After each page restyle, scan base.css for rules that are no longer referenced. Do not add duplicate utility classes -- check if an existing one works first.

**Which phase should address it:** CSS cleanup after the final page is restyled.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Defining the aesthetic (before code) | Vague target ("make it look like Stripe") without concrete specs | Create a concrete reference: exact hex colors, font sizes, spacing values, border-radius, shadow values. One page of tokens. |
| Dashboard restyle | Scope creep -- Dashboard is the most complex page (500+ lines of render, charts, KPIs, analytics) | Split into sections: KPI strip, main grid, sidebar, analytics. Restyle each section as a sub-task. |
| Orders restyle | Inline styles deeply embedded in conditional ternaries (lines 22401-22482) | Map every inline style before editing. Replace ternary styles with class toggles. |
| Trips restyle | Dual view modes (table + cards) both need restyling | Restyle table and card views as separate sub-tasks. |
| Modals (shared component) | Modals are used by ALL pages -- restyling modals before all pages are done creates inconsistency | Restyle modals LAST, after all page content is done. |
| Sidebar/Topbar (shared chrome) | Changing nav aesthetics affects every page simultaneously | Restyle LAST. Or restyle early with intentionally neutral styling that does not clash with either old or new pages. |
| Billing/Payroll | Print layouts depend on current styling | Test print preview after restyling. |
| Dark mode pass | Assumed to be "just toggle variables" but hardcoded colors will have crept in | Full dark-mode audit after all pages are restyled in light mode. |

---

## Lessons from v1.2 and v1.3 Failures

### v1.2: Death by Ambition
- **What happened:** Tried to match v1.1 mockups exactly in production code. Too many changes at once. Reverted entirely.
- **Lesson:** Do NOT target a mockup. Target a simple, repeatable aesthetic pattern (flat, neutral, consistent spacing) that can be applied incrementally.
- **Applied to v1.4:** No mockups to match. Define an aesthetic token set (colors, spacing, typography, shadows) and apply it page by page.

### v1.3: Death by Timidity
- **What happened:** Scoped to CSS-only polish. Never started because the team realized CSS-only cannot override 4,344 inline styles.
- **Lesson:** CSS-only is insufficient. JS render function edits are required. Accept this upfront.
- **Applied to v1.4:** CSS + JS changes are explicitly in scope. Each page restyle includes editing the render function.

### The Goldilocks Zone for v1.4
- **Not too ambitious:** One page at a time, committed individually, each page fully complete before moving to the next
- **Not too timid:** JS render functions are fair game for style changes (but NOT logic changes)
- **Just right:** Define tokens, restyle page, commit, move on. No batching, no "while I'm here" detours.

---

## Sources

- [Case Study: Large Scale CSS Refactoring in a Legacy Application](https://dev.to/kathryngrayson/case-study-large-scale-css-refactoring-in-a-legacy-application-52lc)
- [Refactoring CSS: Strategy, Regression Testing And Maintenance](https://www.smashingmagazine.com/2021/08/refactoring-css-strategy-regression-testing-maintenance-part2/)
- [How to Redesign a Legacy UI Without Losing Users](https://xbsoftware.com/blog/legacy-app-ui-redesign-mistakes/)
- [Incremental vs Big Bang Redesigns](https://expdyn.medium.com/incremental-vs-big-bang-redesigns-evaluating-design-changes-for-users-2cb15dea05a4)
- [CSS Architectures: Refactor Your CSS](https://www.sitepoint.com/css-architectures-refactor-your-css/)
- Direct codebase analysis: 4,344 inline style attributes, 99 gradients, 118 box-shadows, 1,076 border-radius, 133 render functions across 48,636 lines
