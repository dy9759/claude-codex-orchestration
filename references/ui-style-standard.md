# UI Style Standard (Frontend Default)

Applies to all frontend work. Since CC owns frontend by default (see Default Work Distribution), CC is the primary consumer of this file. If frontend is delegated to Codex, the Codex task spec must explicitly reference this standard.

---

## Hard Default: shadcn/ui + radix-nova

**Every new frontend project starts with this `components.json`:**

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "radix-nova",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "",
    "css": "src/global.css",
    "baseColor": "neutral",
    "cssVariables": true,
    "prefix": ""
  },
  "iconLibrary": "lucide",
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  },
  "registries": {
    "@react-bits": "https://reactbits.dev/r/{name}.json"
  }
}
```

**Key choices (do not drift without explicit user permission):**
- `style: radix-nova` — primary theme
- `baseColor: neutral` — grayscale base
- `iconLibrary: lucide` — consistent iconography
- `cssVariables: true` — theming via CSS vars, not Tailwind class substitution
- `tsx: true, rsc: false` — TypeScript default, no React Server Components unless explicitly requested
- Component alias: `@/components` / `@/components/ui` / `@/hooks` / `@/lib`

Install reference: [ui.shadcn.com/docs/installation](https://ui.shadcn.com/docs/installation)

**When to override:**
- User explicitly requests a different style (e.g. `new-york`, `default`)
- Project already has a divergent `components.json` — **respect what exists**, don't migrate unsolicited (Chesterton's Fence)
- RSC/SSR project — then `rsc: true` is correct

---

## Secondary Style Library (Inspiration, Not Default)

Reference these when user wants something beyond shadcn baseline, or asks for a specific vibe (editorial, brutalist, magazine, etc.).

| Source | Kind | When to consult |
|--------|------|-----------------|
| [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md) | Awesome-list — design system markdown references | User asks "make it feel like X brand" and needs a reference library |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | Opinionated design principles document | Need "good taste" defaults for spacing, hierarchy, color |
| [bergside/typeui](https://github.com/bergside/typeui) | Typography-focused UI system | Type-heavy interfaces (docs, reading apps, editorial) |
| [bergside/awesome-design-skills](https://github.com/bergside/awesome-design-skills) | Design skill references | Learning / teaching context, design justification |
| [dy9759/brandmd0419](https://github.com/dy9759/brandmd0419) | User's personal brand MD | User-specific design language — authoritative when present |
| [dy9759/dembrandt0419](https://github.com/dy9759/dembrandt0419) | User's personal design theme | Same as above |

**Rule:** these are **inspiration sources**, not hard defaults. shadcn + radix-nova remains the default unless user explicitly asks otherwise or an existing project already uses another system.

---

## Webpage Style Extraction Capability

When the user says **"make it look like [URL]"** or **"extract the style from this page"**, run the following workflow (inspired by [bergside/design-md-chrome](https://github.com/bergside/design-md-chrome)).

### Extraction Workflow

```
1. Fetch the page — use WebFetch
2. Extract design tokens — parse for:
   - Color palette (primary, accent, neutral, semantic colors)
   - Typography (font families, scale, weights, line-height)
   - Spacing rhythm (padding, margin, gap patterns)
   - Border radius scale
   - Shadow elevation system
   - Motion / interaction patterns (if observable)
3. Emit a design spec in markdown:
   - Color: name + hex + usage intent
   - Type scale: size + weight + usage
   - Spacing tokens: sm / md / lg with px values
   - Component patterns: button, card, input, modal examples
4. Map to shadcn/ui override:
   - Generate CSS variables in `src/global.css`
   - Update `tailwind.config.js` color extensions
   - Suggest `components.json` style override if appropriate
5. Ask user to confirm before applying
```

### Extraction Output Template

```markdown
## Extracted Design Style — [source URL]

### Color Palette
- Primary: `#XXXXXX` (used for CTA buttons, links)
- Accent: `#XXXXXX` (hover states, highlights)
- Neutral scale: [50, 100, 200, 400, 600, 800, 900]
- Background: `#XXXXXX`
- Foreground: `#XXXXXX`

### Typography
- Heading: [font-family], [weight]
- Body: [font-family], [weight]
- Scale: [type-scale ratio, e.g. 1.25 major third]

### Spacing Rhythm
- Base unit: [px]
- Scale: [sm/md/lg/xl values]

### Border & Elevation
- Radius: [sm/md/lg values]
- Shadow: [sm/md/lg with offset + blur]

### Proposed shadcn Override
- CSS variables to add to `src/global.css`: [list]
- Tailwind config extensions: [list]
- components.json style change: [keep radix-nova / propose alternative]

### Files to create / modify
- [explicit file list]

Proceed?
```

---

## Integration with Orchestration

**Before frontend dispatch to CC** (or Codex with explicit exception):
- Check project's `components.json` exists — if not, initialize with the hard default
- If user provided a reference URL → run extraction workflow first, apply overrides
- Any new component goes into `@/components/ui` (shadcn primitives) or `@/components` (composed)
- Use `lucide-react` for icons — do NOT introduce other icon libraries without justification

**At integration review** (Five-Axis Review, "Readability" axis extended):
- Verify: no inline styles where Tailwind classes would do
- Verify: colors reference CSS variables, not hardcoded hex (avoid magic values per `maintainability-harness.md` §11)
- Verify: spacing uses Tailwind scale, not arbitrary `p-[13px]`
- Verify: component structure matches shadcn conventions (use `forwardRef`, `cn()` helper, variant props via `class-variance-authority` if needed)

**Hard Red Lines (add to `maintainability-harness.md` §18 for frontend):**
- Introducing a second icon library alongside lucide
- Hardcoding hex colors in components when CSS variables exist
- Bypassing `@/components/ui` to inline primitive styles
- Overriding `radix-nova` theme variables without user confirmation
- Introducing a second UI library (MUI, Chakra, AntD) alongside shadcn
