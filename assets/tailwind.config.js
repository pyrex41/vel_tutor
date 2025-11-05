/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    '../lib/*_web/**/*.ex',
    '../lib/*_web/**/*.html.{heex,eex,leex}',
    '../lib/*_web/**/*.heex',
    './js/**/*.js'
  ],
  theme: {
    extend: {
      colors: {
        // v0-inspired neutral color palette
        background: 'oklch(98% 0 0)',
        foreground: 'oklch(21% 0.006 285.885)',
        card: 'oklch(99% 0.001 0)',
        'card-foreground': 'oklch(22.4% 0.006 285.885)',
        popover: 'oklch(0% 0 0)',
        'popover-foreground': 'oklch(100% 0 0)',
        primary: 'oklch(70% 0.213 47.604)',
        'primary-foreground': 'oklch(100% 0 0)',
        secondary: 'oklch(55% 0.027 264.364)',
        'secondary-foreground': 'oklch(100% 0 0)',
        muted: 'oklch(100% 0.001 0)',
        'muted-foreground': 'oklch(55% 0.006 285.885)',
        accent: 'oklch(100% 0 0)',
        'accent-foreground': 'oklch(21% 0.006 285.885)',
        destructive: 'oklch(0% 0.253 17.585)',
        'destructive-foreground': 'oklch(100% 0 0)',
        border: 'oklch(100% 0.001 0)',
        input: 'oklch(100% 0.001 0)',
        ring: 'oklch(70% 0.213 47.604)',
        // Additional v0 colors
        'background-secondary': 'oklch(96% 0.001 286.375)',
        'background-tertiary': 'oklch(92% 0.004 286.32)',
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui'],
        mono: ['JetBrains Mono', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      borderRadius: {
        lg: '0.5rem',
        md: '0.375rem',
        sm: '0.25rem',
      },
      animation: {
        'fade-in': 'fadeIn 0.2s ease-out',
        'slide-in': 'slideIn 0.2s ease-out',
        'slide-up': 'slideUp 0.2s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideIn: {
          '0%': { transform: 'translateX(-8px)', opacity: '0' },
          '100%': { transform: 'translateX(0)', opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(8px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],
  darkMode: 'class',
}