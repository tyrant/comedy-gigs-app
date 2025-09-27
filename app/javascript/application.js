// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './components/App'

// Mount React app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  const element = document.getElementById('root')
  if (element) {
    const root = ReactDOM.createRoot(element)
    root.render(React.createElement(App))
  }
})
