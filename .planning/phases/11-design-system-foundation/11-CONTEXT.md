# Phase 11: Design System Foundation + Global Components - Context

**Gathered:** 2026-02-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Migrate the approved v1.1 mockup design system (shared.css tokens + component styles) into production CSS and restyle all global UI components to match mockup designs. This is purely visual — same DOM structure, same JS logic, same behavior, same sidebar nav order. Phases 12-15 handle per-page styling.

</domain>

<decisions>
## Implementation Decisions

### Migration Strategy
- Keep old CSS files (variables.css, base.css) loaded in HTML head as fallback layer — don't delete or comment out the `<link>` tags
- design-system.css is the primary source of truth; old files stay loaded for safety in case any values are missed
- Fresh sweep of all hex colors — systematically scan and replace ALL hex values in index.html with var() references, even those already converted (ensures consistency)
- Mockup component styles brought in at Claude's discretion for file structure (single file vs separate components.css)

### Theme Toggle Behavior
- Keep existing `.dark-theme` class toggle mechanism — do NOT switch to `[data-theme="dark"]` attribute
- Dark theme: keep current production dark theme feel but apply the new token structure (bridge old dark values to new variable names, don't copy mockup dark palette exactly)
- Default theme: light (keep current behavior)
- Toggle UX: keep current icon button in header with localStorage persistence — just restyle the button to match mockup design

### Global Component Styling
- Sidebar: apply mockup visual styling (dark sidebar, green active indicator, icons, hover states) while preserving production's exact nav items and order
- Modals: match mockup exactly — backdrop blur, rounded corners, header bar, close button style, animations
- Tables: define global table style in Phase 11 (striped rows, sticky headers, hover highlights) so all tables get the new look immediately
- Buttons, badges, form inputs, toasts, cards, pagination: ALL match their mockup counterparts — no exceptions

### Rollout Approach
- Component by component within Phase 11 — tokens first, then sidebar, then modals, then tables, etc. Each step verified before the next
- If a global style change causes visual breakage on any page, fix it immediately in Phase 11 (don't defer to phases 12-15)
- Old CSS files remain loaded throughout as safety net

### Verification
- After Phase 11 completes, do a manual visual walkthrough of key pages together before moving to Phase 12

### Claude's Discretion
- Whether to put component styles in design-system.css or a separate components.css file
- Whether inline hex colors in index.html render functions should be replaced in Phase 11 or deferred to per-page phases 12-15 (whichever makes theme toggle work correctly)
- Exact rollout order of components (tokens → sidebar → modals → tables → etc.)

</decisions>

<specifics>
## Specific Ideas

- Bridge aliases already exist in design-system.css mapping old production var names to new tokens — preserve and extend this pattern
- design-system.css already has 1,513 lines of tokens, bridge aliases, gradients, shadows, and spacing — build on this foundation rather than starting over
- Mockup shared.css (1,308 lines) is the design spec — component styles should visually match what's rendered in the mockup HTML files
- Production sidebar nav order is the authority — mockup sidebar has different ordering that should NOT be applied

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-design-system-foundation*
*Context gathered: 2026-02-10*
