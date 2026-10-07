// Screenshots of the running lab systems, taken by the pipeline.
//
//   node screenshot.mjs <outDir> <name>=<url>[|selector] ...
//
// Environment:
//   SHOT_COOKIE  "name=value" cookie set for localhost (Argo CD's login token)
//   SHOT_AUTH    "user:password" sent as HTTP basic auth (Grafana)
// Pages that poll forever (Prometheus, Grafana, Argo CD) never go network-idle,
// so idle is waited for best-effort and a fixed settle time follows.
import { chromium } from 'playwright'
import { mkdirSync } from 'node:fs'
import { join } from 'node:path'

const [outDir, ...specs] = process.argv.slice(2)
mkdirSync(outDir, { recursive: true })

const browser = await chromium.launch()
const context = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  ignoreHTTPSErrors: true,
  extraHTTPHeaders: process.env.SHOT_AUTH
    ? { Authorization: 'Basic ' + Buffer.from(process.env.SHOT_AUTH).toString('base64') }
    : {},
})
if (process.env.SHOT_COOKIE) {
  const [name, ...rest] = process.env.SHOT_COOKIE.split('=')
  await context.addCookies([{ name, value: rest.join('='), domain: 'localhost', path: '/' }])
}

let failed = 0
for (const spec of specs) {
  const eq = spec.indexOf('=')
  const name = spec.slice(0, eq)
  const [url, selector] = spec.slice(eq + 1).split('|')
  const page = await context.newPage()
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60_000 })
    if (selector) await page.waitForSelector(selector, { timeout: 60_000 })
    await page.waitForLoadState('networkidle', { timeout: 15_000 }).catch(() => {})
    await page.waitForTimeout(6_000)
    await page.screenshot({ path: join(outDir, `${name}.png`) })
    console.log(`captured ${name} <- ${url}`)
  } catch (err) {
    failed++
    console.error(`FAILED ${name}: ${err.message.split('\n')[0]}`)
    await page.screenshot({ path: join(outDir, `FAILED-${name}.png`) }).catch(() => {})
  } finally {
    await page.close()
  }
}
await browser.close()
process.exit(failed ? 1 : 0)
