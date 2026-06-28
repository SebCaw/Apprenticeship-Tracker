# 🎓 Degree Apprenticeship Tracker

A live dashboard that automatically tracks **Level 6 degree apprenticeships** in **sales, finance and consulting** at 12 major employers — and surfaces other large-employer opportunities worth a look.

**🔗 Live site:** https://SebCaw.github.io/apprenticeship-tracker/

> Built by Sebastian Cawthorne, 2026.

---

## What it does

- Monitors the UK Government's official **[Find an Apprenticeship](https://www.findapprenticeship.service.gov.uk/)** register — the legally-required listing service every employer must post to.
- Tracks 12 target employers: **Microsoft, IBM, Salesforce, Amazon, Oracle, SAP, HSBC, Barclays, Goldman Sachs, JPMorgan, PwC, Deloitte.**
- Filters to **non-technical, client-facing roles** (sales, business development, finance, banking, audit, consulting) and deliberately excludes software/engineering roles.
- A **"Might spark your interest"** section discovers degree apprenticeships at other large, well-known employers.
- Shows status at a glance — 🟢 Open · 🟡 Closing soon · ⚪ Not yet open · 🔴 Closed — plus closing-date countdowns and a typical-application-window timeline.
- Lets you **track your own progress** per role (Watching / Applied / Interview / Offer …), saved privately in your browser.

## How it works

```
GitHub Actions (cron, 2×/day)  ──►  scrape.ps1  ──►  GOV.UK  ──►  data.json  ──►  GitHub Pages (index.html)
```

- **`scrape.ps1`** — a PowerShell scraper that queries GOV.UK, parses the listings, applies the role filters, and rewrites `data.json`.
- **GitHub Actions** (`.github/workflows/scrape.yml`) runs the scraper on a schedule **in the cloud** — so the data stays fresh even when my computer is off — and commits any changes.
- **`index.html`** — a self-contained dashboard (vanilla HTML/CSS/JS, no framework) that loads `data.json` and renders everything, with progress tracking persisted in `localStorage`.
- **GitHub Pages** serves the static site for free.

## Tech

`HTML` · `CSS` (custom properties, animations) · `JavaScript` (no framework) · `PowerShell` · `GitHub Actions` · `GitHub Pages`

## Run the scraper manually

From the **Actions** tab → *Scrape GOV.UK apprenticeships* → **Run workflow**. Or locally:

```powershell
pwsh ./scrape.ps1
```

## Notes

- Salary/location figures shown before a role goes live are indicative estimates; live listings are populated directly from GOV.UK.
- Most employers open their degree apprenticeship cycle around **September–November**, so listings are sparse outside that window — that's the register being empty, not the tracker.
