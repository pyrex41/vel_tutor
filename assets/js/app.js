import "../css/app.css"

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"

// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {},
})

// Clipboard copy functionality using Phoenix.LiveView.JS
document.addEventListener('click', (e) => {
  const target = e.target.closest('[data-clipboard-text]')
  if (target) {
    const text = target.getAttribute('data-clipboard-text')
    // Use Phoenix.LiveView.JS for clipboard operations
    if (typeof JS !== 'undefined' && JS.copy) {
      // Create a temporary element with the text to copy from
      const tempEl = document.createElement('div')
      tempEl.textContent = text
      tempEl.style.position = 'absolute'
      tempEl.style.left = '-9999px'
      document.body.appendChild(tempEl)

      // Use LiveView JS to copy from the temporary element
      JS.copy().to(tempEl)

      // Clean up
      document.body.removeChild(tempEl)
    } else {
      // Fallback to plain JS if LiveView.JS not available
      navigator.clipboard.writeText(text).catch(err => {
        console.error('Failed to copy:', err)
      })
    }
  }
})

// Show progress bar on live navigation and form submits using Phoenix.LiveView.JS
topbar.configure({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => {
  if (typeof JS !== 'undefined') {
    // Use LiveView.JS dispatch for consistency, but still call topbar.show()
    JS.dispatch("phx:topbar:show", {detail: {duration: 300}})
  }
  topbar.show(300)
})
window.addEventListener("phx:page-loading-stop", _info => {
  if (typeof JS !== 'undefined') {
    // Use LiveView.JS dispatch for consistency, but still call topbar.hide()
    JS.dispatch("phx:topbar:hide")
  }
  topbar.hide()
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    if (typeof JS !== 'undefined') {
      JS.dispatch("phx:live_reload:logs_enabled")
    }
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => {
      keyDown = e.key
      if (typeof JS !== 'undefined') {
        JS.dispatch("phx:live_reload:keydown", {detail: {key: e.key}})
      }
    })
    window.addEventListener("keyup", e => {
      keyDown = null
      if (typeof JS !== 'undefined') {
        JS.dispatch("phx:live_reload:keyup", {detail: {key: e.key}})
      }
    })
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        if (typeof JS !== 'undefined') {
          JS.dispatch("phx:live_reload:open_caller", {detail: {target: e.target}})
        }
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        if (typeof JS !== 'undefined') {
          JS.dispatch("phx:live_reload:open_def", {detail: {target: e.target}})
        }
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}