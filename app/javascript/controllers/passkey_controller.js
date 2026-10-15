import { Controller } from "@hotwired/stimulus"
import { useState } from "reactionview"
import { Turbo } from "@hotwired/turbo-rails"

// Runs a WebAuthn ceremony: sign in with a passkey ("get") or add one
// ("create"). The template owns the `passkey_status` herb:state and shows the
// matching message; this controller does the browser and network work.
//
//   data-passkey-mode-value="get" | "create"
//   data-passkey-challenge-url-value  POST → creation/request options (JSON)
//   data-passkey-submit-url-value     POST ← { credential } → { location } or { error }
export default class extends Controller {
  static values = { mode: String, challengeUrl: String, submitUrl: String }
  static targets = ["error"]

  connect() {
    useState(this)
    if (!window.PublicKeyCredential) this.state.set({ passkey_status: "unsupported" })
  }

  async start() {
    this.showError("")
    this.state.set({ passkey_status: "waiting" })

    try {
      const options = await this.post(this.challengeUrlValue)
      const credential = this.modeValue === "create"
        ? await navigator.credentials.create({ publicKey: decodeCreationOptions(options) })
        : await navigator.credentials.get({ publicKey: decodeRequestOptions(options) })

      this.state.set({ passkey_status: "verifying" })
      const result = await this.post(this.submitUrlValue, { credential: encodeCredential(credential) })
      Turbo.visit(result.location)
    } catch (error) {
      this.state.set({ passkey_status: "idle" })
      // NotAllowedError = the person dismissed the prompt or it timed out.
      if (error.name !== "NotAllowedError" && error.name !== "AbortError") this.showError(error.message)
    }
  }

  async post(url, body = {}) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      },
      body: JSON.stringify(body),
      credentials: "same-origin"
    })
    const json = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(json.error || "Something went wrong. Try again.")
    return json
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.hidden = !message
  }
}

// --- base64url <-> ArrayBuffer -------------------------------------------

function toBuffer(base64url) {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/")
  const padded = base64 + "===".slice((base64.length + 3) % 4)
  return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0)).buffer
}

function toBase64url(buffer) {
  const bytes = new Uint8Array(buffer)
  let binary = ""
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

function decodeCreationOptions(options) {
  return {
    ...options,
    challenge: toBuffer(options.challenge),
    user: { ...options.user, id: toBuffer(options.user.id) },
    excludeCredentials: (options.excludeCredentials || []).map((c) => ({ ...c, id: toBuffer(c.id) }))
  }
}

function decodeRequestOptions(options) {
  return {
    ...options,
    challenge: toBuffer(options.challenge),
    allowCredentials: (options.allowCredentials || []).map((c) => ({ ...c, id: toBuffer(c.id) }))
  }
}

function encodeCredential(credential) {
  const { response } = credential
  const encoded = {
    id: credential.id,
    rawId: toBase64url(credential.rawId),
    type: credential.type,
    authenticatorAttachment: credential.authenticatorAttachment,
    clientExtensionResults: credential.getClientExtensionResults(),
    response: { clientDataJSON: toBase64url(response.clientDataJSON) }
  }

  if (response.attestationObject) {
    encoded.response.attestationObject = toBase64url(response.attestationObject)
    encoded.response.transports = response.getTransports?.() || []
  } else {
    encoded.response.authenticatorData = toBase64url(response.authenticatorData)
    encoded.response.signature = toBase64url(response.signature)
    if (response.userHandle) encoded.response.userHandle = toBase64url(response.userHandle)
  }

  return encoded
}
