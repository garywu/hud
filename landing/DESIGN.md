# Jane Landing Page — Design System

## Overview

The Jane landing page uses a cohesive design language inspired by the Jane brand: dark, technical, minimalist. Cyan accents evoke the notch UI. Responsive mobile-first approach ensures fast load times and great UX across all devices.

---

## COLOR PALETTE

### Primary Colors

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| **Background Dark** | `#0f172a` | 15, 23, 42 | Page background |
| **Background Darker** | `#051929` | 5, 25, 41 | Sections, footer |
| **Accent Cyan** | `#06b6d4` | 6, 182, 212 | Links, buttons, accents |
| **Accent Light** | `#22d3ee` | 34, 211, 238 | Hover states, gradients |
| **Accent Dark** | `#0891b2` | 8, 145, 178 | Dark hover, depth |

### Text Colors

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| **Text Primary** | `#f1f5f9` | 241, 245, 249 | Main text |
| **Text Secondary** | `#cbd5e1` | 203, 213, 225 | Secondary text, descriptions |
| **Text Muted** | `#94a3b8` | 148, 163, 184 | Captions, notes, placeholder |

### Border Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Border** | `#1e293b` | Section dividers, card borders |
| **Border Light** | `#334155` | Interactive element borders |

### Semantic Colors

| Usage | Color |
|-------|-------|
| Success | `#22c55e` (green) |
| Error | `#ef4444` (red) |
| Warning | `#f59e0b` (amber) |

---

## TYPOGRAPHY

### Font Family

**Primary:** Inter (Google Fonts)
**Fallback Stack:** `-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`

### Font Sizes

| Size | px | rem | Usage |
|------|----|----|-------|
| xs | 12 | 0.75 | Small labels, captions |
| sm | 14 | 0.875 | Secondary text, notes |
| base | 16 | 1 | Body text, default |
| lg | 18 | 1.125 | Feature descriptions |
| xl | 24 | 1.5 | Card titles |
| 2xl | 32 | 2 | Section headings |
| 3xl | 40 | 2.5 | Subheadings |
| 4xl | 48 | 3 | Hero title (desktop) |

### Font Weights

| Weight | Usage |
|--------|-------|
| 400 | Body text |
| 500 | Emphasized text |
| 600 | Buttons, CTAs |
| 700 | Headings |

### Line Heights

| Element | Height | Ratio |
|---------|--------|-------|
| Headings | Auto | 1.2 |
| Body | 1.6 | 1.6x font size |
| Tight | 1.3 | For dense copy |

---

## SPACING SYSTEM

All spacing follows a consistent scale based on 0.5rem (8px):

| Size | Value | Usage |
|------|-------|-------|
| xs | 0.25rem (4px) | Micro spacing |
| sm | 0.5rem (8px) | Tight spacing |
| md | 1rem (16px) | Default spacing |
| lg | 1.5rem (24px) | Section gaps |
| xl | 2rem (32px) | Component spacing |
| 2xl | 3rem (48px) | Large gaps |
| 3xl | 4rem (64px) | Section padding |

---

## LAYOUT & BREAKPOINTS

### Mobile-First Breakpoints

| Breakpoint | Width | Device | Grid Cols |
|------------|-------|--------|-----------|
| Mobile | 375px | iPhone 12 | 1 |
| Small | 480px | Larger phone | 1 |
| Tablet | 768px | iPad | 2 |
| Desktop | 1024px | MacBook | 3 |
| Large | 1440px | 4K | 3+ |

### Container Widths

| Breakpoint | Max Width | Padding |
|------------|-----------|---------|
| Mobile | 100% | 24px |
| Tablet | 90% | 32px |
| Desktop | 1200px | 32px |
| Large | 1400px | 32px |

### Section Padding

- Mobile: `64px vertical, 24px horizontal`
- Tablet: `96px vertical, 32px horizontal`
- Desktop: `96px vertical, 32px horizontal`

---

## COMPONENT LIBRARY

### Button

**Base Styles:**
- Font Weight: 600
- Border Radius: 0.5rem (8px)
- Transition: all 150ms ease-in-out
- Padding: 1rem (md) / 1.5rem (lg) vertical, 1.5rem (md) / 2rem (lg) horizontal
- Display: inline-flex (aligns icon + text)

**Button Variants:**

#### Primary Button
- Background: Linear gradient (Cyan → Light Cyan)
- Color: Dark background
- Border: Transparent
- Hover: Scale up 2px, shadow 0 12px 24px rgba(6, 182, 212, 0.3)

#### Secondary Button
- Background: Transparent
- Color: Cyan
- Border: 2px Cyan
- Hover: Background rgba(6, 182, 212, 0.1), border Light Cyan

#### Outline Button
- Background: Transparent
- Color: Text Primary
- Border: 2px Border Light
- Hover: Background rgba(255, 255, 255, 0.05), border Cyan, color Cyan

#### Large Button
- Padding: 1.5rem vertical, 2rem horizontal
- Font Size: lg (1.125rem)

---

### Card

**Base Styles:**
- Background: rgba(255, 255, 255, 0.02)
- Border: 1px Border color
- Border Radius: 0.5rem (8px)
- Padding: 2rem (32px)
- Transition: all 300ms ease-in-out

**Card Hover State:**
- Border Color: Cyan
- Background: rgba(6, 182, 212, 0.1)
- Transform: translateY(-4px)

**Card Variants:**
- Feature Card: Icon (emoji), title, description
- Pricing Card: Price display, feature list, CTA button
- Proof Card: Quote or stat + label + description

---

### Form Input

**Base Styles:**
- Padding: 1rem vertical, 1rem horizontal
- Border: 1px Border
- Border Radius: 0.5rem (8px)
- Background: rgba(255, 255, 255, 0.05)
- Color: Text Primary
- Font Size: base (16px)
- Font Family: Primary
- Transition: all 150ms ease-in-out

**Focus State:**
- Outline: None
- Border Color: Cyan
- Background: rgba(255, 255, 255, 0.08)
- Box Shadow: 0 0 20px rgba(6, 182, 212, 0.2)

**Placeholder:**
- Color: Text Muted

---

### Navigation Bar

**Base Styles:**
- Position: sticky, top 0, z-index 1000
- Background: rgba(15, 23, 42, 0.95) with backdrop blur (10px)
- Border Bottom: 1px Border
- Padding: 1rem vertical

**Logo:**
- Font Size: xl (1.5rem)
- Font Weight: 700
- Color: Cyan
- Hover: scale(1.05)

**Nav Links (Desktop):**
- Display: flex, gap 1.5rem
- Font Size: sm (0.875rem)
- Color: Text Secondary
- Hover: Cyan
- CTA Link: Gradient background, dark text

**Mobile Menu:**
- Display: none on desktop
- Position: absolute, top 100%
- Flex direction: column
- Max height: animated (0 → 400px)
- Background: rgba(15, 23, 42, 0.98) with blur

---

### Notch Mockup

**Container:**
- Width: 120px
- Height: 180px
- Background: Background Darker
- Border: 2px Border Light
- Border Radius: 0 0 20px 20px
- Box Shadow: 0 20px 40px rgba(0, 0, 0, 0.5)

**Inner (Avatar):**
- Background: Linear gradient (Cyan → Dark Cyan)
- Animation: Pulse (3s ease-in-out, glow effect)
- Contains: Eyes (blink animation), Mouth (talk animation)

---

### Section Headers

**Heading (h2):**
- Font Size: 2xl (32px) mobile, 3xl (40px) tablet, 4xl (48px) desktop
- Text Align: Center
- Margin Bottom: lg (24px)

**Subheading (p):**
- Font Size: lg (1.125rem)
- Color: Text Secondary
- Max Width: 600px
- Margin: 0 auto

---

## ANIMATIONS & TRANSITIONS

### Global Transitions

| Speed | Duration | Easing | Usage |
|-------|----------|--------|-------|
| Fast | 150ms | ease-in-out | Hover effects, quick feedback |
| Normal | 300ms | ease-in-out | Section transitions, card interaction |
| Slow | 500ms | ease-in-out | Page load, major section changes |

### Animations

#### Eye Blink (Avatar)
- Duration: 3s
- Easing: ease-in-out
- Effect: scaleY(1) → scaleY(0.1) → scaleY(1)

#### Mouth Talk (Avatar)
- Duration: 2s
- Easing: ease-in-out
- Effect: scaleY(1) → scaleY(1.2) → scaleY(1)

#### Notch Pulse (Glow)
- Duration: 3s
- Easing: ease-in-out
- Effect: inset shadow intensity varies

#### Scroll Fade-In (Feature Cards)
- Duration: 600ms
- Easing: ease-out
- Effect: opacity 0 → 1, transform translateY(20px) → 0
- Trigger: Intersection Observer (when element enters viewport)

#### Slide Down (Form Message)
- Duration: 300ms
- Easing: ease-out
- Effect: translateY(-10px) → 0, opacity 0 → 1

### Disabled Animations
Users with `prefers-reduced-motion: reduce` receive no animations.

---

## RESPONSIVE DESIGN

### Mobile-First Approach

All styles start mobile (375px), then breakpoints add complexity:

```
Mobile (375px)
  ↓ [tablet @ 768px]
Tablet (768px)
  ↓ [desktop @ 1024px]
Desktop (1024px)
  ↓ [large @ 1440px]
Large (1440px)
```

### Key Changes by Breakpoint

**Tablet (768px):**
- Hero: 2-column grid (text + notch)
- Features: 2-column grid
- Pricing: 2-column grid
- Social Proof: 3-column grid
- Buttons: Horizontal layout

**Desktop (1024px):**
- Features: 3-column grid
- Sticky navbar visible (not hamburger)
- Full spacing and padding

**Large (1440px):**
- Max container width: 1400px
- Increased padding and spacing
- All elements fully visible

---

## PERFORMANCE TARGETS

### Page Load Times

| Metric | Target | Status |
|--------|--------|--------|
| First Contentful Paint (FCP) | <1.5s | Aim for <1s |
| Largest Contentful Paint (LCP) | <2.5s | Aim for <2s |
| Cumulative Layout Shift (CLS) | <0.1 | Aim for <0.05 |
| Time to Interactive (TTI) | <3.5s | Aim for <3s |

### Lighthouse Scores

| Category | Target | Must-Have |
|----------|--------|-----------|
| Performance | 95+ | >90 |
| Accessibility | 95+ | >90 |
| Best Practices | 95+ | >90 |
| SEO | 100 | 100 |

### File Size Budget

- HTML: <50KB
- CSS: <30KB
- JavaScript: <30KB
- Total: <100KB gzipped

---

## ACCESSIBILITY

### WCAG 2.1 Level AA Compliance

- Color contrast: 4.5:1 for text, 3:1 for graphics
- Focus indicators: Visible outline for all interactive elements
- Keyboard navigation: Full support for all features
- Screen readers: Semantic HTML, ARIA labels where needed
- Mobile: Touch targets minimum 44x44px

### Focus Indicators

- Outline: 2px solid Cyan
- Outline Offset: 2px
- Border Radius: 0.25rem

---

## THEMING

### Dark Theme (Primary)

Follows macOS dark appearance. All colors defined in CSS variables for easy toggling.

### Light Theme (Fallback)

Optional fallback (prefers-color-scheme: light) for users who prefer light mode:
- Background: White
- Text Primary: Near black
- Accent: Cyan (unchanged)

---

## DESIGN CHECKLIST

- [ ] All colors from palette
- [ ] Typography within defined sizes/weights
- [ ] Spacing multiples of 8px
- [ ] Cards have consistent styling
- [ ] Buttons have hover/focus states
- [ ] Forms have proper validation states
- [ ] Animations use defined timings
- [ ] Mobile breakpoints tested
- [ ] Lighthouse >90 across all categories
- [ ] Accessible color contrast
- [ ] No layout shift (CLS <0.1)
- [ ] Page load <2s on 3G

---

## DEVELOPER NOTES

All design values are in `/landing/styles.css` as CSS variables:

```css
:root {
  --color-accent: #06b6d4;
  --font-size-lg: 1.125rem;
  --spacing-md: 1rem;
  --transition-fast: 150ms ease-in-out;
  /* ... */
}
```

To modify design:
1. Update variable in `:root`
2. Changes cascade throughout the page
3. Test on mobile (375px) and desktop (1440px)
4. Run Lighthouse audit

---

## PHASE 2 DESIGN UPDATES

- Dynamic GitHub star count display
- Product Hunt badge with launch date
- User testimonial photos/avatars
- Blog post teasers
- Animated gradient backgrounds (subtle)
- Real demo video embed

