// Entry point for the build script in your package.json
import React from 'react'
import ReactDOM from 'react-dom/client'
import { setWorkerUrl } from 'maplibre-gl'
import App from './components/App'

// The map's light and dark styles (URLs, or style documents as JSON) and its
// worker script come from the page, so the test environment can swap the basemap out.
const mapStyle = (value) => value.trim().startsWith('{') ? JSON.parse(value) : value

document.addEventListener('DOMContentLoaded', () => {
  const element = document.getElementById('root')
  if (element) {
    setWorkerUrl(element.dataset.mapWorker)
    const root = ReactDOM.createRoot(element)
    const mapStyles = { light: mapStyle(element.dataset.mapStyleLight), dark: mapStyle(element.dataset.mapStyleDark) }
    root.render(React.createElement(App, { mapStyles }))
  }
})
