# Stage 6A — Publish the RStudio source project to GitHub

**Target repository:** `CamdenWade/Penguins-Ticketing-HUB`  
**Visibility:** Public  
**Current published status:** New repository must be created on GitHub; no repo has been confirmed published yet.  
**Deployment:** Not part of Stage 6A; leave shinyapps.io for Stage 6B.

## Part A: Prepare your existing Mac project

1. Make a backup copy of your **working** `Penguins-Ticketing-HUB` project folder in Finder before changing any files.
2. Unzip **Stage 6A Additions** somewhere outside the project.
3. In your existing project folder, **replace** `README.md` with the new one. **Replace** `.gitignore` with the Stage 6A version; on macOS, press `Command + Shift + .` in Finder to reveal dotfiles if needed.
4. Add `scripts/15_check_git_publication.R`, new `docs/*.md`, and `docs/screenshots/` with the five screenshots. Do not overwrite `app.R`, existing `R/` helpers, other scripts, `www/`, `data/`, `models/`, or `outputs/`.
5. From RStudio, run:

   ```r
   source("scripts/15_check_git_publication.R")
   ```

   Check `outputs/tables/stage6a_publication_audit.csv`. A pending Git initialization message is expected until `git init` is run. Any `FAIL` must be resolved before publishing.

## Part B: Initialize Git locally (for the first time)

In **RStudio → Tools → Terminal → New Terminal**, make sure you are in the project root:

```bash
pwd
git --version
```

If `pwd` is not the project folder, use `cd` followed by the actual path on your Mac. Do **not** run `git init` in your `Documents` directory or home directory by mistake.

If you previously ran `git init`, don't initialize again. Otherwise:

```bash
git init -b main
```

If the command fails on an older Git installation, use:

```bash
git init
git branch -M main
```

Check your Git author configuration:

```bash
git config user.name
git config user.email
```

If either is empty, configure it using your chosen GitHub-visible identity and email (never paste login tokens into these settings):

```bash
git config --global user.name "YOUR GIT AUTHOR NAME"
git config --global user.email "YOUR GIT AUTHOR EMAIL"
```

A GitHub-provided `noreply` email is a reasonable option if you prefer not to publish your personal address.

## Part C: Confirm source-only Git tracking

Confirm generated and secret paths are ignored:

```bash
git check-ignore -v data/processed/games_real.rds
git check-ignore -v data/synthetic/ticket_orders.rds
git check-ignore -v models/attendance_model_bundle.rds
git check-ignore -v .Renviron
```

All four should show the `.gitignore` rule responsible for excluding them. `.gitignore` does **not** remove these files from your Mac or prevent later Shiny deployment.

Rerun the R audit after Git initialization:

```r
source("scripts/15_check_git_publication.R")
```

Then stage the source files and review what would be published:

```bash
git add -A
git status --short
git diff --cached --stat
git diff --cached --name-only
```

Your staged list **should** include `app.R`, the `R/` and `scripts/` source files, the three `www/*.css` files, the documentation and screenshots, `.gitignore`, `README.md`, and your `.Rproj` file. It **should not** contain local datasets, JSON/HTML caches, RDS model artifacts, deployment credentials, `.Renviron`, or the entire `outputs/` directory.

If a generated/sensitive file was accidentally staged, stop and unstage it (this keeps the local file):

```bash
git restore --staged path/to/file
```

Fix `.gitignore` if necessary and repeat the audit; do not push credentials or customer-like datasets accidentally. If the file was already tracked in an earlier commit, ignoring it alone won't remove it from Git history—investigate and address that separately before publishing.

Commit your reviewed source:

```bash
git commit -m "Publish Penguins ticketing analytics Shiny app and reproducible research pipeline"
```

## Part D: Create the empty public GitHub repository

1. Open https://github.com/new in your browser and sign in as **CamdenWade**.
2. **Repository name:** `Penguins-Ticketing-HUB`.
3. **Description:** `R Shiny sports business analytics: real NHL attendance, synthetic ticketing and CRM, historical model backtest, and revenue scenarios.`
4. Choose **Public** (portfolio visibility).
5. **Do not check** Add a README, Add .gitignore, or Choose a license. These files are already managed locally (license selection can be made separately).
6. Click **Create repository**. A Quick Setup page should appear for the empty repository.

The repository-creation step is manual because the connected GitHub actions available here cannot create brand-new repositories; they can interact with existing ones.

## Part E: Link local Git to the new remote and push

Back in RStudio's Terminal, from the project folder:

```bash
git remote add origin https://github.com/CamdenWade/Penguins-Ticketing-HUB.git
git remote -v
git push -u origin main
```

**Do not run** `git remote add origin` a second time if one already exists. If it says `remote origin already exists`, inspect `git remote -v` and update deliberately only if the URL is incorrect:

```bash
git remote set-url origin https://github.com/CamdenWade/Penguins-Ticketing-HUB.git
```

GitHub no longer accepts account passwords for Git over HTTPS. Complete the browser / credential-manager authentication or use GitHub CLI as your setup supports. **Never paste a token into a chat or the repository.**

## Part F: Verify publication in the browser

Open your newly created repository at `https://github.com/CamdenWade/Penguins-Ticketing-HUB` after the push. Confirm:

- README renders at the top, including **five dashboard screenshots**.
- `app.R`, `R/`, `scripts/`, `www/`, and `docs/` exist.
- GitHub does **not** show `data/synthetic/`, RDS model files, raw NHL HTML caches or secret files.
- Historical model metrics are accurate and the **REAL vs SYNTHETIC** boundary is prominent.
- Repository description matches the project; suggested GitHub topics: `r`, `r-shiny`, `sports-analytics`, `business-intelligence`, `hockey`, `data-visualization`, `predictive-modeling`.
- The local app still starts: `shiny::runApp()`.

After the repository is live, run:

```bash
git status
git log -1 --oneline
git remote -v
```

Expected: working tree clean; most recent commit visible; remote points to your GitHub repository.

## Notes on licenses and publication

The package **does not automatically assign a reuse license**, because that is your choice. Public repositories can be viewed, but source code without a license is generally not freely reusable by others. If you want to allow others to reuse your code, select an appropriate code license (for example MIT) with a separate decision. Do not imply a code license grants rights to third-party NHL source content or team trademarks.

## What Stage 6B will do

- Build a reproducible **deployment-only bundle** with the required precomputed RDS data and fitted models, separate from the public GitHub source commit.
- Assess Shiny startup memory and minimize per-session data loading.
- Set up `rsconnect` / shinyapps.io credentials **locally** and deploy the app.
- Test the published URL and update README with the **verified** live link.
- Finish employer-facing walkthroughs and repository polish; website integration remains a separate conversation.
