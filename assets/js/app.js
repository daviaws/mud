import "../css/app.css"

import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { marked } from "marked"
import { MarkdownEditor } from "./editor"
import { MudClient } from "./mud_client"

window.marked = marked

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: { MarkdownEditor, MudClient }
})
liveSocket.connect()

function renderMarkdown() {
  document.querySelectorAll("[data-md]").forEach(el => {
    el.innerHTML = marked.parse(el.dataset.md)
  })
}

window.addEventListener("phx:update", renderMarkdown)
document.addEventListener("DOMContentLoaded", renderMarkdown)