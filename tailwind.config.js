/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/javascript/**/*.{js,jsx,ts,tsx}",
    "./app/views/**/*.{erb,html}",
    "./app/helpers/**/*.rb",
    "./app/assets/stylesheets/**/*.css"
  ],
  theme: {
    extend: {
      screens: {
        'xs': '475px',
      }
    },
  },
  plugins: [],
}
