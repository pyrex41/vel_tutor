# V0-Inspired UI Style Guide for Vel Tutor

## Overview
This guide defines the v0-inspired design system for modernizing Vel Tutor's Live components. Focus on minimalism, clean lines, neutral palettes, and intuitive interactions.

## Design Philosophy
- **Minimalism**: Clean layouts with ample whitespace, no clutter.
- **Neutral Palette**: Whites, grays, subtle accents (blues/greens for highlights).
- **Typography**: Geist font family (sans-serif for UI, mono for code).
- **Interactions**: Smooth CSS transitions, no heavy animations.
- **Accessibility**: WCAG AA compliance, keyboard navigation, ARIA labels.

## Color Palette (oklch)
From globals.css:
- Background: oklch(1 0 0) / oklch(0.145 0 0) (light/dark)
- Foreground: oklch(0.145 0 0) / oklch(0.985 0 0)
- Primary: oklch(0.205 0 0) / oklch(0.985 0 0)
- Secondary: oklch(0.97 0 0) / oklch(0.269 0 0)
- Muted: oklch(0.97 0 0) / oklch(0.269 0 0)
- Accent: oklch(0.97 0 0) / oklch(0.269 0 0)
- Destructive: oklch(0.577 0.245 27.325) / oklch(0.396 0.141 25.723)
- Border: oklch(0.922 0 0) / oklch(0.269 0 0)
- Input: oklch(0.922 0 0) / oklch(0.269 0 0)
- Ring: oklch(0.708 0 0) / oklch(0.439 0 0)

## Typography
- Sans: 'Geist', 'Geist Fallback' (headings, body)
- Mono: 'Geist Mono', 'Geist Mono Fallback' (code, timers)
- Sizes: Use Tailwind scale (text-sm, text-base, text-lg, etc.)
- Weights: 400 (normal), 500 (medium), 600 (semibold)

## Spacing
- Scale: 4px increments (space-1 = 4px, space-2 = 8px, etc.)
- Container: max-w-4xl mx-auto for main content
- Padding: p-4, p-6, p-8 for cards/sections

## Components (Phoenix HEEx Adaptation)
Use Tailwind classes to mimic shadcn/ui:

- **Card**: `<div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">`
- **Button**: `<button class="bg-primary text-primary-foreground hover:bg-primary/90 px-4 py-2 rounded-md">`
- **Progress**: `<div class="w-full bg-secondary rounded-full h-2"><div class="bg-primary h-2 rounded-full" style="width: 50%"></div></div>`
- **Input**: `<input class="bg-background border border-input px-3 py-2 rounded-md">`
- **Badge**: `<span class="bg-secondary text-secondary-foreground px-2 py-1 rounded-full text-xs">`

## Animations
- Use `tailwindcss-animate` for subtle effects.
- Transitions: `transition-all duration-200`
- Hover: `hover:scale-105` (light only)

## Responsive Design
- Mobile-first: sm:, md:, lg: breakpoints.
- Grid: `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3`
- Flex: `flex flex-col md:flex-row`

## Accessibility
- ARIA: `aria-label`, `role`, `aria-live`
- Focus: `focus:ring-2 focus:ring-ring`
- Contrast: Ensure 4.5:1 ratio

## Implementation Notes
- For Phoenix LiveView: Use HEEx with Tailwind classes.
- Charts: Adapt Recharts from v0_files (if needed, port to Phoenix).
- Real-time: Use LiveView assigns for updates.
- Consistency: All components share this guide.