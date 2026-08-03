// Does the WEB build actually boot in a browser?
//
//   cd export/web && python -m http.server 8099 &
//   node tools/webtest.mjs [http://localhost:8099/index.html]
//
// Everything else in this repo can be checked headless with Godot itself. The
// web build cannot: it is the only target whose failure mode is "the page loads
// and then nothing happens", and that only shows up in a real browser running
// real WASM. Chrome's --screenshot flag is no help — it fires on the load event,
// long before Godot has compiled anything — so this drives the browser over CDP
// and waits for the engine to say it is running.
//
// Uses Chromium from the Playwright cache and Node's built-in WebSocket, so
// there is nothing to npm install.

import { spawn } from 'node:child_process'
import { mkdtempSync, existsSync, writeFileSync, readdirSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const URL_ = process.argv[2] ?? 'http://localhost:8099/index.html'
const PORT = 9333
const BOOT_TIMEOUT_MS = 180_000

function findChrome() {
  const root = join(process.env.LOCALAPPDATA ?? '', 'ms-playwright')
  if (!existsSync(root)) return null
  for (const dir of readdirSync(root).filter((d) => d.startsWith('chromium-')).sort().reverse()) {
    const exe = join(root, dir, 'chrome-win64', 'chrome.exe')
    if (existsSync(exe)) return exe
  }
  return null
}

const chrome = findChrome()
if (!chrome) {
  console.error('FAIL no chromium found (expected a Playwright browser cache)')
  process.exit(2)
}

const profile = mkdtempSync(join(tmpdir(), 'karakuri-web-'))
const proc = spawn(chrome, [
  '--headless=new',
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profile}`,
  '--no-sandbox',
  '--no-first-run',
  '--disable-gpu',
  // SwiftShader: no GPU in this environment, and a WebGL context that never
  // gets created looks exactly like a game that failed to start.
  '--use-gl=angle',
  '--use-angle=swiftshader',
  '--enable-unsafe-swiftshader',
  '--window-size=1280,720',
  'about:blank',
], { stdio: 'ignore' })

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

async function endpoint() {
  for (let i = 0; i < 60; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json()
      const page = list.find((t) => t.type === 'page')
      if (page?.webSocketDebuggerUrl) return page.webSocketDebuggerUrl
    } catch {}
    await sleep(250)
  }
  throw new Error('devtools never came up')
}

let nextId = 1
const pending = new Map()
const consoleErrors = []

function send(ws, method, params = {}) {
  const id = nextId++
  ws.send(JSON.stringify({ id, method, params }))
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }))
}

const ws = new WebSocket(await endpoint())
await new Promise((r) => (ws.onopen = r))

ws.onmessage = (ev) => {
  const msg = JSON.parse(ev.data)
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id)
    pending.delete(msg.id)
    msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result)
    return
  }
  // Anything the page shouts about is worth keeping: a Godot crash in the
  // browser surfaces as an exception, not as a failed request.
  if (msg.method === 'Runtime.exceptionThrown') {
    consoleErrors.push(msg.params?.exceptionDetails?.exception?.description ?? 'exception')
  } else if (msg.method === 'Runtime.consoleAPICalled' && msg.params.type === 'error') {
    consoleErrors.push(msg.params.args.map((a) => a.value ?? a.description ?? '').join(' '))
  }
}

await send(ws, 'Runtime.enable')
await send(ws, 'Page.enable')
const started = Date.now()
await send(ws, 'Page.navigate', { url: URL_ })

// The Godot shell hides #status once the engine is running; that is the moment
// the player would see the menu.
const probe = `(() => {
  const s = document.getElementById('status')
  const c = document.getElementById('canvas')
  return JSON.stringify({
    status: s ? s.style.display : 'gone',
    notice: document.getElementById('status-notice')?.textContent?.trim() ?? '',
    w: c?.width ?? 0, h: c?.height ?? 0,
  })
})()`

let booted = false
let last = ''
while (Date.now() - started < BOOT_TIMEOUT_MS) {
  const r = await send(ws, 'Runtime.evaluate', { expression: probe, returnByValue: true })
  last = r.result?.value ?? ''
  const st = JSON.parse(last || '{}')
  if (st.notice) {
    console.error(`FAIL the page reported: ${st.notice}`)
    break
  }
  // 'none' when the shell hides the splash, 'gone' when it removes the element
  // outright — which is what this Godot version does, and reading only 'none'
  // made a perfectly booted build report failure for three minutes.
  if ((st.status === 'none' || st.status === 'gone') && st.w > 0) {
    booted = true
    break
  }
  await sleep(1000)
}

const secs = ((Date.now() - started) / 1000).toFixed(1)
if (booted) {
  const shot = await send(ws, 'Page.captureScreenshot', { format: 'png' })
  writeFileSync(process.env.WEBTEST_SHOT ?? 'web_boot.png', Buffer.from(shot.data, 'base64'))
  console.log(`BOOT OK in ${secs}s  (screenshot written)`)
} else {
  console.log(`BOOT FAILED after ${secs}s  last state: ${last}`)
}
for (const e of consoleErrors.slice(0, 10)) console.log(`  console error: ${e}`)

ws.close()
proc.kill()
process.exit(booted && consoleErrors.length === 0 ? 0 : 1)
