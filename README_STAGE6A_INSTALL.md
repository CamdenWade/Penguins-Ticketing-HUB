# Stage 6A package — publication additions for an existing working RStudio project

This ZIP is **not** a replacement project, and it does not include the source files/datasets you previously generated in Stages 2–5B. Merge only its additions into the **existing, working** `Penguins-Ticketing-HUB` folder on your Mac.

## Add / replace

```text
Penguins-Ticketing-HUB/
├── README.md                                  REPLACE old Stage 2 README
├── .gitignore                                 REPLACE old minimal ignore rules
├── scripts/
│   └── 15_check_git_publication.R             ADD
└── docs/
    ├── data_sources_and_ethics.md             ADD
    ├── reproducibility.md                    ADD
    ├── stage6a_publication_playbook.md        ADD
    └── screenshots/                          ADD 5 PNG screenshots
        ├── attendance-dashboard.png
        ├── revenue-dashboard.png
        ├── customer-dashboard.png
        ├── backtest-dashboard.png
        └── opportunity-dashboard.png
```

## Retain unchanged

- `app.R` (working Stage 5B)
- All `R/` helper/module scripts
- `scripts/00` through `scripts/14`
- `www/styles.css`, `www/stage4b.css`, `www/stage5b.css`
- All validated `.rds` data and saved fitted models (for local use and later deployment)
- All existing docs, stage quality reports and exploratory plots

## First command in RStudio

```r
source("scripts/15_check_git_publication.R")
```

Then follow `docs/stage6a_publication_playbook.md` **in order** for Git initialization, inspection, repository creation in your GitHub browser, and first push.

The newly created public repository must be **empty** before your first local push; do not initialize it with a GitHub README or license. The README inside this package contains links to screenshot assets that should be committed together.

The check script saves its output to `outputs/tables/stage6a_publication_audit.csv`, which is intentionally ignored by Git.

No files from this ZIP create or modify Git metadata, install credentials, or deploy the application.
