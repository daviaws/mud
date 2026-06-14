import { Socket } from "phoenix"

const SAY_PATTERN = /^(.+) diz[^:]*:\s*(.+)$/
const ROOM_HEADER = /^==\s*(.+?)\s*==$/

export const MudClient = {
  mounted() {
    this.history = []
    this.historyIndex = null
    this.playerName = null
    this.inRoomDesc = false
    this.roomLines = []
    this.currentRoomName = null
    this.lastSayRoom = null

    this.setupInput()
    this.connect()
  },

  connect() {
    const socket = new Socket("/socket")
    socket.connect()

    this.channel = socket.channel("mud:session", {})

    this.channel.on("output", ({ text }) => this.handleOutput(text))

    this.channel.on("closed", () => {
      this.appendLog("--- conexão encerrada ---", "mud-system")
      this.resetState()
      setTimeout(() => this.connect(), 500)
    })

    this.channel.on("error", ({ reason }) => this.appendLog(`erro: ${reason}`, "mud-error"))

    this.channel.join()
      .receive("ok", () => {
        this.appendLog("Conectado.", "mud-system")
        if (this.playerName) {
          setTimeout(() => {
            this.sendCommand(this.playerName)
            this.updateCharacterPanel(this.playerName)
          }, 100)
        }
      })
      .receive("error", () => this.appendLog("Falha ao conectar.", "mud-error"))
  },

  setupInput() {
    const input = document.getElementById("mud-cmd")
    const historyEl = document.getElementById("mud-history")

    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        const text = input.value.trim()
        if (!text) return

        if (!this.playerName) {
          this.playerName = text
          this.updateCharacterPanel(text)
        }

        this.sendCommand(text)
        this.history.unshift(text)
        if (this.history.length > 50) this.history.pop()
        this.historyIndex = null
        input.value = ""
        historyEl.style.display = "none"
        return
      }

      if (e.key === "ArrowUp") {
        e.preventDefault()
        if (this.history.length === 0) return
        this.historyIndex = this.historyIndex === null
          ? 0
          : Math.min(this.historyIndex + 1, this.history.length - 1)
        input.value = this.history[this.historyIndex]
        return
      }

      if (e.key === "ArrowDown") {
        e.preventDefault()
        if (this.historyIndex === null) return
        this.historyIndex -= 1
        if (this.historyIndex < 0) {
          this.historyIndex = null
          input.value = ""
        } else {
          input.value = this.history[this.historyIndex]
        }
        return
      }

      if (e.key === "Escape") {
        historyEl.style.display = "none"
        return
      }
    })

    input.addEventListener("click", () => {
      if (this.history.length === 0) return
      this.renderHistory()
      historyEl.style.display = historyEl.style.display === "none" ? "block" : "none"
    })

    document.addEventListener("click", (e) => {
      if (!e.target.closest(".mud-input")) {
        historyEl.style.display = "none"
      }
    })

    input.focus()
  },

  sendCommand(text) {
    this.channel.push("input", { text })
    this.appendLog(`> ${text}`, "mud-cmd-echo")
  },

  handleOutput(text) {
    const lines = text.split(/\r?\n/)

    lines.forEach(line => {
      const trimmed = line.trim().replace(/^>\s*/, "")

      if (!trimmed || trimmed === ">") return

      if (trimmed.includes("Até a próxima")) {
        this.appendLog(trimmed)
        this.resetState()
        return
      }

      const roomMatch = trimmed.match(ROOM_HEADER)
      if (roomMatch) {
        this.inRoomDesc = true
        this.roomLines = []
        this.currentRoomName = roomMatch[1]
        this.appendLog(trimmed)
        return
      }

      if (this.inRoomDesc) {
        if (trimmed.startsWith("Saídas:")) {
          this.roomLines.push(trimmed)
          this.inRoomDesc = false
          this.updateRoomPanel(this.currentRoomName, this.roomLines)
        } else if (trimmed.startsWith("Flora:")) {
          this.inRoomDesc = false
          this.updateRoomPanel(this.currentRoomName, this.roomLines)
        } else {
          this.roomLines.push(trimmed)
        }
        this.appendLog(trimmed)
        return
      }

      const sayMatch = trimmed.match(SAY_PATTERN)
      if (sayMatch) {
        this.appendSay(sayMatch[1], sayMatch[2])
      }

      this.appendLog(trimmed)
    })

    this.scrollLog()
  },

  resetState() {
    this.playerName = null
    this.inRoomDesc = false
    this.roomLines = []
    this.currentRoomName = null
    this.lastSayRoom = null
    this.updateCharacterPanel(null)
    const roomEl = document.getElementById("room-desc")
    if (roomEl) roomEl.innerHTML = `<p class="muted">—</p>`
    const saysEl = document.getElementById("room-says")
    if (saysEl) saysEl.innerHTML = ""
  },

  updateCharacterPanel(name) {
    const el = document.getElementById("character-info")
    if (!el) return
    el.innerHTML = name
      ? `<p><strong>${name}</strong></p>`
      : `<p class="muted">Conectando...</p>`
  },

  updateRoomPanel(name, descLines) {
    const roomEl = document.getElementById("room-desc")
    if (!roomEl) return
    roomEl.innerHTML = `<strong>${name}</strong><br><span>${descLines.join("<br>")}</span>`
  },

  appendLog(text, cls = "") {
    const el = document.getElementById("mud-log-content")
    if (!el) return
    const line = document.createElement("div")
    line.className = `mud-line ${cls}`.trim()
    line.textContent = text
    el.appendChild(line)
    this.scrollLog()
  },

  appendSay(who, what) {
    const el = document.getElementById("room-says")
    if (!el) return

    if (this.currentRoomName !== this.lastSayRoom) {
      this.lastSayRoom = this.currentRoomName
      const header = document.createElement("div")
      header.className = "mud-say-room"
      header.textContent = this.currentRoomName
      el.appendChild(header)
    }

    const line = document.createElement("div")
    line.className = "mud-say"
    line.innerHTML = `<span class="say-who">${who}</span>: ${what}`
    el.appendChild(line)
    el.scrollTop = el.scrollHeight
  },

  scrollLog() {
    const log = document.getElementById("mud-log")
    if (log) log.scrollTop = log.scrollHeight
  },

  renderHistory() {
    const el = document.getElementById("mud-history")
    el.innerHTML = ""
    this.history.slice(0, 10).forEach(cmd => {
      const item = document.createElement("div")
      item.className = "mud-history-item"
      item.textContent = cmd
      item.addEventListener("click", () => {
        document.getElementById("mud-cmd").value = cmd
        el.style.display = "none"
        document.getElementById("mud-cmd").focus()
      })
      el.appendChild(item)
    })
  },

  destroyed() {
    if (this.channel) this.channel.leave()
  }
}