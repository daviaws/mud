import { EditorState } from "@codemirror/state"
import { EditorView, keymap, highlightActiveLine, lineNumbers } from "@codemirror/view"
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands"
import { markdown, markdownLanguage } from "@codemirror/lang-markdown"
import { syntaxHighlighting, defaultHighlightStyle } from "@codemirror/language"

const parchmentTheme = EditorView.theme({
  "&": {
    background: "#fdf6e3",
    color: "#2c1810",
    fontFamily: "'IM Fell English', Georgia, serif",
    fontSize: "1rem",
    border: "1px solid #c4a35a",
    borderRadius: "2px",
  },
  ".cm-content": { padding: "0.75rem" },
  ".cm-line": { lineHeight: "1.7" },
  ".cm-activeLine": { background: "rgba(196, 163, 90, 0.12)" },
  ".cm-gutters": {
    background: "#f4e9c9",
    border: "none",
    borderRight: "1px solid #c4a35a",
    color: "#5c3d2e",
  },
  ".cm-cursor": { borderLeftColor: "#8b1a1a" },
}, { dark: false })

function createEditor(container, initialValue, onChange) {
  const state = EditorState.create({
    doc: initialValue,
    extensions: [
      history(),
      keymap.of([...defaultKeymap, ...historyKeymap]),
      lineNumbers(),
      highlightActiveLine(),
      markdown({ base: markdownLanguage }),
      syntaxHighlighting(defaultHighlightStyle),
      parchmentTheme,
      EditorView.updateListener.of(update => {
        if (update.docChanged) onChange(update.state.doc.toString())
      }),
    ]
  })

  return new EditorView({ state, parent: container })
}

// Toolbar helpers
function wrapSelection(view, before, after) {
  const { from, to } = view.state.selection.main
  const selected = view.state.sliceDoc(from, to)
  view.dispatch({
    changes: { from, to, insert: `${before}${selected}${after}` },
    selection: { anchor: from + before.length, head: to + before.length }
  })
  view.focus()
}

function insertAtCursor(view, text) {
  const { from } = view.state.selection.main
  view.dispatch({ changes: { from, insert: text } })
  view.focus()
}

// Hook LiveView
export const MarkdownEditor = {
  mounted() {
    const field = this.el.dataset.field
    const pushEvent = this.pushEvent.bind(this)

    // container do editor
    const container = this.el.querySelector(".cm-container")
    const initialValue = this.el.querySelector(`textarea[name='${field}']`)?.value || ""

    const view = createEditor(container, initialValue, (value) => {
      pushEvent("update_field", { field, value })
      // atualiza preview
      window.dispatchEvent(new CustomEvent("md-update"))
    })

    // toolbar
    this.el.querySelectorAll("[data-action]").forEach(btn => {
      btn.addEventListener("click", e => {
        e.preventDefault()
        const action = btn.dataset.action
        switch (action) {
          case "bold":        wrapSelection(view, "**", "**"); break
          case "italic":      wrapSelection(view, "_", "_"); break
          case "heading2":    insertAtCursor(view, "\n## "); break
          case "heading3":    insertAtCursor(view, "\n### "); break
          case "link":        wrapSelection(view, "[", "](url)"); break
          case "code":        wrapSelection(view, "`", "`"); break
          case "codeblock":   wrapSelection(view, "\n```\n", "\n```\n"); break
          case "ul":          insertAtCursor(view, "\n- "); break
          case "fullscreen":  this.el.classList.toggle("fullscreen"); view.focus(); break
        }
      })
    })

    this._view = view
  },

  updated() {
    // não sobrescreve o editor no re-render do LiveView
  },

  destroyed() {
    this._view?.destroy()
  }
}