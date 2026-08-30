import * as Lexxy from "lexxy"

const HTML_ICON = `<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M8.5 6.5 3 12l5.5 5.5 1.4-1.4L5.8 12l4.1-4.1-1.4-1.4zm7 0-1.4 1.4 4.1 4.1-4.1 4.1 1.4 1.4L21 12l-5.5-5.5z"/></svg>`

class HtmlSourceExtension extends Lexxy.Extension {
  initializeToolbar(toolbar) {
    this.toolbar = toolbar
    this.htmlMode = false
    this.onToggle = this.toggle.bind(this)
    this.onSubmit = this.syncToEditor.bind(this)

    this.button = document.createElement("button")
    this.button.type = "button"
    this.button.name = "html-source"
    this.button.className = "lexxy-editor__toolbar-button"
    this.button.title = "Edit HTML"
    this.button.setAttribute("aria-pressed", "false")
    this.button.innerHTML = HTML_ICON
    this.button.addEventListener("click", this.onToggle)

    const undo = toolbar.querySelector("button[name=undo]")
    if (undo) {
      toolbar.insertBefore(this.button, undo)
    } else {
      toolbar.append(this.button)
    }

    const content = this.editorElement.editorContentElement
    if (!content) return

    this.textarea = document.createElement("textarea")
    this.textarea.className = "lexxy-html-source"
    this.textarea.hidden = true
    this.textarea.spellcheck = false
    this.textarea.setAttribute("aria-label", "HTML source")
    this.editorElement.editorContentElement.insertAdjacentElement("afterend", this.textarea)

    this.form = this.editorElement.closest("form")
    this.form?.addEventListener("submit", this.onSubmit)
  }

  dispose() {
    this.button?.removeEventListener("click", this.onToggle)
    this.form?.removeEventListener("submit", this.onSubmit)
    this.button?.remove()
    this.textarea?.remove()
  }

  toggle(event) {
    event.preventDefault()
    if (this.htmlMode) {
      this.showEditor()
    } else {
      this.showHtml()
    }
  }

  showHtml() {
    if (!this.textarea) return
    this.textarea.value = prettyPrintHtml(this.editorElement.value ?? "")
    this.textarea.hidden = false
    this.htmlMode = true
    this.editorElement.classList.add("lexxy-editor--html-source")
    this.button.setAttribute("aria-pressed", "true")
    this.textarea.focus()
  }

  showEditor() {
    this.syncToEditor()
    this.textarea.hidden = true
    this.htmlMode = false
    this.editorElement.classList.remove("lexxy-editor--html-source")
    this.button.setAttribute("aria-pressed", "false")
    this.editorElement.editorContentElement?.focus()
  }

  syncToEditor() {
    if (!this.htmlMode) return
    this.editorElement.value = minifyHtml(this.textarea.value)
  }
}

const VOID_TAGS = new Set([
  "area", "base", "br", "col", "embed", "hr", "img", "input",
  "link", "meta", "param", "source", "track", "wbr"
])

const INLINE_TAGS = new Set([
  "a", "abbr", "b", "bdi", "bdo", "br", "cite", "code", "data", "dfn",
  "em", "i", "kbd", "mark", "q", "s", "samp", "small", "span", "strong",
  "sub", "sup", "time", "u", "var", "wbr"
])

function prettyPrintHtml(html) {
  const template = document.createElement("template")
  template.innerHTML = html.trim()
  return formatNodes([ ...template.content.childNodes ], 0).trim()
}

function minifyHtml(html) {
  return html.replace(/>\s+</g, "><").trim()
}

function formatNodes(nodes, depth) {
  return nodes.map((node) => formatNode(node, depth)).filter(Boolean).join("\n")
}

function formatNode(node, depth) {
  if (node.nodeType === Node.COMMENT_NODE) {
    return indent(depth) + `<!--${node.data}-->`
  }

  if (node.nodeType === Node.TEXT_NODE) {
    const text = collapseWhitespace(node.textContent)
    if (!text) return ""
    return indent(depth) + escapeText(text)
  }

  if (node.nodeType !== Node.ELEMENT_NODE) return ""

  return formatElement(node, depth)
}

function formatElement(el, depth) {
  const name = el.tagName.toLowerCase()
  const open = openTag(el)

  if (VOID_TAGS.has(name)) return indent(depth) + open

  if (el.childNodes.length === 0) return indent(depth) + open + `</${name}>`

  if (name === "pre") return indent(depth) + open + el.innerHTML + `</${name}>`

  if (isCompact(el)) return indent(depth) + open + compactChildren(el) + `</${name}>`

  const inner = formatNodes([ ...el.childNodes ], depth + 1)
  return `${indent(depth)}${open}\n${inner}\n${indent(depth)}</${name}>`
}

function isCompact(el) {
  return [ ...el.childNodes ].every((node) => {
    if (node.nodeType === Node.TEXT_NODE || node.nodeType === Node.COMMENT_NODE) return true
    if (node.nodeType !== Node.ELEMENT_NODE) return false
    return INLINE_TAGS.has(node.tagName.toLowerCase()) && isCompact(node)
  })
}

function compactChildren(el) {
  return [ ...el.childNodes ].map((node) => {
    if (node.nodeType === Node.TEXT_NODE) return escapeText(node.textContent.replace(/\s+/g, " "))
    if (node.nodeType !== Node.ELEMENT_NODE) return ""

    const name = node.tagName.toLowerCase()
    if (VOID_TAGS.has(name)) return openTag(node)
    return openTag(node) + compactChildren(node) + `</${name}>`
  }).join("").replace(/^ /, "").replace(/ $/, "")
}

function openTag(el) {
  const name = el.tagName.toLowerCase()
  const attrs = [ ...el.attributes ].map((attr) => `${attr.name}="${escapeAttr(attr.value)}"`).join(" ")
  return attrs ? `<${name} ${attrs}>` : `<${name}>`
}

function indent(depth) {
  return "  ".repeat(depth)
}

function collapseWhitespace(text) {
  return text.replace(/\s+/g, " ").trim()
}

function escapeText(value) {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

function escapeAttr(value) {
  return value.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;")
}

Lexxy.configure({
  global: {
    extensions: [ HtmlSourceExtension ]
  }
})
