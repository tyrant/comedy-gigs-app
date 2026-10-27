// Entry point for the build script in your package.json
import React from 'react'
import ReactDOM from 'react-dom/client'
import { setWorkerUrl } from 'maplibre-gl'
import App from './components/App'

// The map's style (a URL, or a style document as JSON) and worker script come
// from the page, so the test environment can swap the basemap out.
const mapStyle = (value) => value.trim().startsWith('{') ? JSON.parse(value) : value

document.addEventListener('DOMContentLoaded', () => {
  const element = document.getElementById('root')
  if (element) {
    setWorkerUrl(element.dataset.mapWorker)
    const root = ReactDOM.createRoot(element)
    root.render(React.createElement(App, { mapStyle: mapStyle(element.dataset.mapStyle) }))
  }
})
