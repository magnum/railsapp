import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "list", "name", "status"]
  static values = { optionsUrl: String, signInUrl: String, error: String }

  async add(event) {
    event.preventDefault()
    const name = this.nameTarget.value.trim()
    if (!name) {
      this.nameTarget.focus()
      return
    }

    try {
      const options = await this.post(this.optionsUrlValue)
      const credential = await navigator.credentials.create({ publicKey: this.publicKey(options, true) })
      this.append(name, credential)
      this.nameTarget.value = ""
      this.element.requestSubmit()
    } catch (_error) {
      this.showError()
    }
  }

  async authenticate(event) {
    event.preventDefault()

    try {
      const options = await this.post(this.optionsUrlValue)
      const credential = await navigator.credentials.get({ publicKey: this.publicKey(options, false) })
      this.submitCredential(credential)
    } catch (_error) {
      this.showError()
    }
  }

  append(name, credential) {
    const html = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", Date.now().toString())
    const wrapper = document.createElement("div")
    wrapper.innerHTML = html
    wrapper.querySelector("[data-passkey-name]").value = name
    wrapper.querySelector("[data-passkey-credential]").value = JSON.stringify(this.serialize(credential))
    this.listTarget.append(...wrapper.children)
  }

  submitCredential(credential) {
    const token = document.querySelector("meta[name='csrf-token']").content
    const form = document.createElement("form")
    form.method = "post"
    form.action = this.signInUrlValue
    form.dataset.turbo = "false"

    const csrf = document.createElement("input")
    csrf.type = "hidden"
    csrf.name = "authenticity_token"
    csrf.value = token

    const field = document.createElement("input")
    field.type = "hidden"
    field.name = "credential"
    field.value = JSON.stringify(this.serialize(credential))

    form.append(csrf, field)
    document.body.append(form)
    form.submit()
  }

  async post(url) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      }
    })
    if (!response.ok) throw new Error("request failed")
    return response.json()
  }

  publicKey(options, registration) {
    const publicKey = {
      challenge: this.buffer(options.challenge),
      timeout: options.timeout,
      rpId: options.rpId
    }

    if (registration) {
      publicKey.rp = options.rp
      publicKey.user = { ...options.user, id: this.buffer(options.user.id) }
      publicKey.pubKeyCredParams = options.pubKeyCredParams
      publicKey.authenticatorSelection = options.authenticatorSelection
      publicKey.excludeCredentials = (options.excludeCredentials || []).map((item) => ({
        ...item,
        id: this.buffer(item.id)
      }))
    } else {
      publicKey.userVerification = options.userVerification
      publicKey.allowCredentials = (options.allowCredentials || []).map((item) => ({
        ...item,
        id: this.buffer(item.id)
      }))
    }

    return publicKey
  }

  serialize(credential) {
    const response = credential.response
    const result = {
      type: credential.type,
      id: credential.id,
      rawId: this.encode(credential.rawId),
      response: {
        clientDataJSON: this.encode(response.clientDataJSON)
      }
    }

    if (response.attestationObject) {
      result.response.attestationObject = this.encode(response.attestationObject)
    } else {
      result.response.authenticatorData = this.encode(response.authenticatorData)
      result.response.signature = this.encode(response.signature)
      if (response.userHandle) result.response.userHandle = this.encode(response.userHandle)
    }

    return result
  }

  buffer(value) {
    const base64 = value.replace(/-/g, "+").replace(/_/g, "/")
    const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), "=")
    const binary = atob(padded)
    const bytes = new Uint8Array(binary.length)
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index)
    return bytes
  }

  encode(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ""
    bytes.forEach((byte) => {
      binary += String.fromCharCode(byte)
    })
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
  }

  showError() {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = this.errorValue
  }
}
