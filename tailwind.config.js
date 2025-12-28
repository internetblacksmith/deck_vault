/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {
      colors: {
        mtg: {
          primary: '#1a1f36',
          secondary: '#5b21b6',
          accent: '#8b5cf6',
        }
      },
      animation: {
        shimmer: 'shimmer 2s infinite',
        pulse: 'pulse 2s infinite',
      }
    }
  },
  plugins: []
}
