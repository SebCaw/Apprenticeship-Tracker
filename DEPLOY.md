# Deploying the Apprenticeship Tracker to GitHub

This puts the site online (GitHub Pages) and switches on the automatic GOV.UK
checks + Telegram alerts (GitHub Actions). Everything here is **free**.

The repository is the `public/` folder — it already contains everything:
the pages, the data files, the scraper (`scrape.ps1`) and the schedule
(`.github/workflows/scrape.yml`).

---

## Easiest route — GitHub Desktop (no command line)

### 1. Install + sign in
- Download **GitHub Desktop** from https://desktop.github.com and install it.
- Open it and **sign in** with your GitHub account (create one free at github.com if needed).

### 2. Add this project
- **File → Add local repository…**
- Browse to: `C:\Users\sebca\.claude\Let-iq\apprenticeships\public`
- Click **Add repository**.

### 3. Commit the changes
- Bottom-left you'll see all the files listed.
- In the **Summary** box type something like:
  `Split into sales/finance/consulting trackers + 3x daily scrape`
- Click **Commit to main**.

### 4. Publish to GitHub
- Click **Publish repository** (top of the window).
- Name it `apprenticeship-tracker`.
- **Untick** "Keep this code private" (public repos get free Pages + unlimited Actions).
- Click **Publish repository**. Your code is now on GitHub.

### 5. Turn on the website (GitHub Pages)
- Go to github.com → your `apprenticeship-tracker` repo → **Settings → Pages**.
- Under **Build and deployment**:
  - Source: **Deploy from a branch**
  - Branch: **main**, folder **/ (root)** → **Save**.
- Wait ~1 minute. Your site is live at:
  `https://<your-username>.github.io/apprenticeship-tracker/`

  Each sector lives in its own folder, so the URLs are tidy:
  - Sales: About-me `…/sales/` · tracker `…/sales/tracker.html`
  - Finance: About-me `…/finance/` · tracker `…/finance/tracker.html`
  - Consulting: About-me `…/consulting/` · tracker `…/consulting/tracker.html`
  - Combined showcase (all sectors): `…/tracker.html`

  When you apply to a finance role, share `…/finance/` (or just `…/finance/tracker.html`) —
  nothing on those pages reveals the other sectors.

### 6. Switch on Telegram alerts (add the secrets)
- Repo → **Settings → Secrets and variables → Actions → New repository secret**.
- Add these two (use the values from your BotFather chat — do **not** put them in any file):
  - Name `TELEGRAM_BOT_TOKEN`  → value: your full `botid:secret` token
  - Name `TELEGRAM_CHAT_ID`    → value: your numeric chat id

### 7. Enable + test the robot
- Open the **Actions** tab. If prompted, click **"I understand my workflows, enable them"**.
- Click **Scrape GOV.UK apprenticeships** → **Run workflow → Run workflow**.
- It should go green. A manual run ignores the time gate, so it's the quickest way to test.
  (Scheduled runs only fire at 09:00 / 13:00 / 16:00 UK time.)

Done. From now on it checks GOV.UK three times a day and messages you on Telegram
whenever a genuinely new Level 6 role appears.

---

## Alternative — command line (if you prefer)

```sh
cd "C:\Users\sebca\.claude\Let-iq\apprenticeships\public"
git add -A
git commit -m "Split into sales/finance/consulting trackers + 3x daily scrape"

# Create the GitHub repo and push (needs the GitHub CLI `gh`, logged in):
gh repo create apprenticeship-tracker --public --source=. --remote=origin --push
```

If you made the repo on the website instead, connect and push manually:

```sh
git remote add origin https://github.com/<your-username>/apprenticeship-tracker.git
git branch -M main
git push -u origin main
```

Then do steps 5–7 above (Pages, secrets, enable Actions).

---

## Changing text later

Two easy ways:

1. **On github.com (no tools):** open the file — the finance tracker is
   `finance/tracker.html`, the finance About-me is `finance/index.html` — click the
   ✏️ pencil, edit the words, scroll down and click **Commit changes**. The live
   site updates in about a minute.
2. **Locally:** edit the file, then in GitHub Desktop **Commit to main** → **Push origin**.

Edit wording in the **HTML** files (headings, intro text, the "About this project"
box). Don't hand-edit the company listings in the `data-*.json` files — the scraper
overwrites those on every run.
