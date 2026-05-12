# Reproduction recipe / 复现指南

Complete step-by-step guide to regenerate every data table, figure, and
DOCX manuscript in this repository from the master spreadsheet.

从主表完整复现本仓库所有数据表、图件与稿件的逐步指南。

---

## 1. Prerequisites / 必要条件

### 1.1 Software / 软件

| Tool | Minimum | Notes |
|---|---|---|
| **R** | ≥ 4.5 | 4.5.x verified on macOS arm64 + RHEL 10 x86_64 |
| **Python** | ≥ 3.9 | for the DOCX assembly step |
| **Git** | any recent | only for cloning |
| **GDAL** (via `sf`) | ≥ 3.5 | shapefile + GPKG I/O |
| **SQLite** | ≥ 3.40 | direct GPKG inspection (optional) |

### 1.2 R packages / R 包

```r
install.packages(c(
  "readxl", "readr", "dplyr", "tidyr", "stringr", "forcats", "tibble",
  "ggplot2", "ggalluvial", "patchwork", "scales", "cowplot",
  "sf", "officer", "rvg", "magick", "DiagrammeR", "DiagrammeRsvg", "rsvg",
  "ape", "fs", "DBI", "RSQLite", "writexl"
))
if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install(c("ggtree", "treeio"))
```

### 1.3 Python packages / Python 包

```bash
pip install python-docx pandas openpyxl
```

### 1.4 System libraries (macOS, for editable PPTX) / 系统库

```bash
brew install pkgconf cairo fontconfig gettext libpng
```

If `rvg::dml(ggobj=…)` fails with `Cannot open data source` or
`UnsupportedOperationException`, rebuild `gdtools` and `rvg` from source
against your installed R version:

```bash
# gdtools (patch configure to drop --static which pulls in libintl)
R -e 'install.packages("gdtools", type="source", repos="https://cloud.r-project.org/")'
# rvg
R -e 'install.packages("rvg",     type="source", repos="https://cloud.r-project.org/")'
```

---

## 2. Data sources / 数据来源

| Resource | Where it must live | Used by |
|---|---|---|
| Master Excel `鸟类新纪录20260508.xlsx` | repository parent dir, OR via env `CBNR_MASTER_XLSX` | `01c`, `09c` |
| `Updated_reanalysis/data/hbw_v9_checklist.csv` (HBW BirdLife v9 checklist with synonyms) | exported from BOTW.gpkg via SQLite (see §4) | `13`, `14`, `server_compute_directional_only.R` |
| `BOTW_clean.gpkg` (466-species pre-clipped) | repository parent dir | `13` (Scenario S2) |
| `BOTW_2024_2.gpkg` (full BirdLife 2024) | server only (8.9 GB) | `server_compute_directional_only.R` (S1, S3) |
| WorldClim v2.1 5′ baselines + CRU TS 4.09 | server only (~10 GB) | server climate computation |
| `data/directional_3scenarios/server_climate_direction.csv` | shipped in repo if you have it, else copy from server | `14` |
| McTavish 2025 avian phylogeny (`summary_dated_clements.nex`) | `data/external/` or via env `BIRD_MCTAVISH_TREE` | phylogeny script |
| Province shapefile (`省.shp`) | `data/shapefile_base/` | spatiotemporal script |

Set every absolute path through an environment variable so the scripts
remain portable. The repo's defaults assume the master Excel lives in the
repository parent directory.

---

## 3. End-to-end run / 端到端流程

```bash
git clone https://github.com/dingchenchen6/CBNR-china-bird-new-records.git
cd CBNR-china-bird-new-records
ROOT=$PWD
CLEAN=$ROOT/data/cbnr_clean_events.csv

# === Step 1. Clean the master spreadsheet → canonical CSV ===
# Reads ../鸟类新纪录20260508.xlsx by default.
Rscript code/01_pipeline/01c_build_canonical_keep_all_years.R

# === Step 2. Domain analyses (env vars redirect outputs into the repo) ===
BIRD_CLEAN_PATH=$CLEAN \
  BIRD_TASK_DIR=$ROOT/figures/spatiotemporal_run \
  BIRD_SHAPE_DIR=$ROOT/data/shapefile_base \
  Rscript code/02_analyses/make_spatiotemporal_keepall.R

BIRD_CLEAN_PATH=$CLEAN \
  BIRD_TASK_DIR=$ROOT/figures/sankey_run \
  BIRD_SANKEY_N_COLLAPSE=5 \
  Rscript code/02_analyses/make_sankey_topN_others_keepall.R

BIRD_TASK_DIR=$ROOT/figures/phylogeny_run \
  BIRD_MASTER_XLSX=$ROOT/../鸟类新纪录20260508.xlsx \
  BIRD_CORRECTED_EVENTS_CSV=$CLEAN \
  BIRD_MCTAVISH_TREE=$ROOT/data/external/summary_dated_clements.nex \
  Rscript code/02_analyses/run_bird_phylogeny_new_records_mctavish.R

# === Step 3. Compose Figure 1, 2, flowchart ===
Rscript code/03_figures/07c_compose_figure2_v3_aligned.R
Rscript code/03_figures/08c_make_flowchart_and_fig1.R

# Editable PPTX exports for Fig 1 + Fig 2 (point CBNR_TASK_ROOT to repo)
CBNR_TASK_ROOT=$ROOT \
  Rscript code/03_figures/10c_make_editable_fig1_fig2_pptx.R

# === Step 4. Directional analysis (3 scenarios) ===
# 4a. Local Scenario 2 (BOTW_clean.gpkg in repo parent dir)
Rscript code/05_directional/13_local_compute_botw_clean_scenario.R

# 4b. Merge S1+S2+S3 (needs server climate+direction CSV)
# Set CBNR_SERVER_CLIMATE_CSV if your copy is elsewhere.
CBNR_SERVER_CLIMATE_CSV=$ROOT/data/directional_3scenarios/server_climate_direction.csv \
  Rscript code/05_directional/14_merge_and_render_3scenarios.R

# 4c. Compose Figure 3 (3-scenario composite)
Rscript code/05_directional/15_compose_figure3_3scenarios.R

# === Step 5. Update DOCX with tracked changes ===
python3 code/04_manuscript/09c_update_manuscript_v3_tracked.py
```

All outputs land under `data/`, `figures/`, and `results/` in the repo.

---

## 4. Exporting the HBW v9 checklist from BOTW.gpkg / 导出 HBW 同物异名表

The synonym lookup is shipped at
`Updated_reanalysis/data/hbw_v9_checklist.csv` in upstream working
copies. To regenerate it from the BirdLife `BOTW_2024_2.gpkg`:

```bash
sqlite3 -header -csv BOTW_2024_2.gpkg \
  "SELECT Order_, FamilyName, CommonName, ScientificName, Synonyms
     FROM main_BL_HBW_Checklist_V9" \
  > hbw_v9_checklist.csv
```

The file is small (~3 MB) and can be committed to a working branch.

---

## 5. Troubleshooting / 排错

### 5.1 "Cannot open data source" on GPKG

The problem is usually that a network filesystem holding the GPKG drops
the SQLite WAL file lock. Either:
- Copy the `.gpkg` to local SSD first, or
- Use SQLite (`sqlite3` CLI) + `RSQLite` to read attributes and
  manually parse the GPKG geometry-blob header
  (see `server_compute_directional_only.R` for the helper function).

### 5.2 `s2_geog_from_wkb` errors

Set `sf::sf_use_s2(FALSE)` before any geometry operations; the scripts
already do this.

### 5.3 `st_intersection` CRS mismatch

Ensure both layers are in EPSG:4326 (`st_transform(4326)`); the China
boundary is reprojected at the top of every spatial script.

### 5.4 Editable PPTX export fails with `gdtools` missing-symbol error

Rebuild `gdtools` AND `rvg` from source so they link against your live
R binary. Verified recipe in §1.4.

### 5.5 Large GitHub push fails (HTTP 408)

Some VPNs / proxies break long uploads. Workarounds:
- Disable VPN before `git push`
- Push one commit at a time:
  `git push --no-thin origin <sha>:main`
- Increase buffer: `git config http.postBuffer 1048576000`

### 5.6 DOCX is corrupted after `09c_update_manuscript_v3_tracked.py`

Run the script with `python3 -W ignore` to suppress warnings, then open
the result in Word. The image-replacement step rewrites the underlying
`.docx` zip — close any open copy in Word first.

---

## 6. Where to ask / 联系

Open an issue at <https://github.com/dingchenchen6/CBNR-china-bird-new-records/issues>
or email Chenchen Ding (chenchending1992@gmail.com).
