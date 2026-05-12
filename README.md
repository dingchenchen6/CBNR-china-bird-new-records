# CBNR — China Bird New Distribution Records (2000–2025)

[![License: MIT (code)](https://img.shields.io/badge/Code-MIT-blue.svg)](LICENSE)
[![Data: CC-BY-4.0](https://img.shields.io/badge/Data-CC--BY--4.0-orange.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Manuscript-Scientific%20Data%20in%20prep-yellow.svg)](#citation)

**Author:** Chenchen Ding (Peking University) & coauthors
**Repository release:** 2026-05-11 (3-scenario directional + climate)
**Public repository:** <https://github.com/dingchenchen6/CBNR-china-bird-new-records>

A reproducible, peer-reviewed literature-based database of provincial-level
new bird distribution records in China (2000–2025), accompanied by the full
analytical pipeline that produces every figure and table in the companion
*Scientific Data* manuscript.

中国鸟类省级新分布纪录（CBNR）数据库 (2000–2025) 与配套 Scientific Data
稿件全套可复现分析管线。

---

## Table of contents / 目录

- [Headline numbers](#headline-numbers--关键统计)
- [Directional analysis — three scenarios](#directional-analysis--three-range-definition-scenarios--三方案方向性分析)
- [Repository layout](#repository-layout--目录结构)
- [How to reproduce](#how-to-reproduce--如何复现)
- [R / Python dependencies](#r--python-dependencies--依赖)
- [Data dictionary](#data-dictionary--数据字典)
- [Documentation files](#documentation-files--辅助文档)
- [Citation](#citation--引用)
- [License](#license--许可)
- [Acknowledgements & contact](#acknowledgements--致谢)

---

## Headline numbers / 关键统计

| 指标 | 数值 |
|---|---|
| Validated species–province events | **1,020** |
| · within 2000–2025 study scope    | 1,011 |
| · pre-2000 (flagged but retained) | 9 |
| Unique species                    | 564 |
| Orders                            | 23 |
| Provincial-level units            | 33 |
| Source articles                   | 670 |
| Year span                         | 1981 – 2025 |

---

## Directional analysis — three range-definition scenarios / 三方案方向性分析

For each new record, bearing, distance and lon/lat displacement are computed
against the species' historical BirdLife range polygon within China under
**three alternative range definitions**:

每条新纪录在以下 **三种范围定义** 下计算方位、位移、距离与经纬度变化：

| Scenario | Range definition | Records with polygon | Median dist. to centroid | Median dist. to edge | Mean point ΔT (°C, 1970–2000 → year-of-record) |
|---|---|---|---|---|---|
| **S1** | Resident + Breeding (BOTW 2024, SEASONAL = 1, 2) | 762 (74.7 %) | 1,936 km | 510 km | +0.89 |
| **S2** | User-curated `BOTW_clean.gpkg` (466 species pre-clipped) | 771 (75.6 %) | 1,262 km | 548 km | +0.90 |
| **S3** | All seasonal categories pooled (no filter) | 860 (84.3 %) | 2,024 km | 469 km | +0.88 |

- Synonyms resolved via the BirdLife HBW v9 checklist (11,195 accepted + 2,734 alternative forms).
- 563 / 564 CBNR species mapped to BirdLife taxonomy (1 unmatched name audited).
- Climate metrics use WorldClim v2.1 5′ baseline + CRU TS 4.09 annual data.
- Main outputs: `data/directional_3scenarios/` and `figures/directional_3scenarios/`.

---

## Repository layout / 目录结构

```
.
├── README.md                                    This file
├── LICENSE                                      MIT (code) + CC-BY-4.0 (data)
├── CITATION.cff                                 Machine-readable citation
├── .gitignore  .gitattributes
│
├── code/
│   ├── 01_pipeline/                             ▶ STEP 1: clean & validate
│   │   └── 01c_build_canonical_keep_all_years.R   Keep all years + flag pre-2000
│   ├── 02_analyses/                             ▶ STEP 2: per-domain analyses
│   │   ├── make_spatiotemporal_keepall.R         → Fig 2 panels (a)(b) maps
│   │   ├── make_sankey_topN_others_keepall.R     → Fig 2 panel (c) sankey
│   │   └── run_bird_phylogeny_new_records_mctavish.R  → Fig 1 circular tree
│   ├── 03_figures/                              ▶ STEP 3: compose figures
│   │   ├── 07c_compose_figure2_v3_aligned.R       Fig 2 composite (a/b/c)
│   │   ├── 08c_make_flowchart_and_fig1.R          Flowchart + Fig 1 trim
│   │   └── 10c_make_editable_fig1_fig2_pptx.R     Editable PPTX export
│   ├── 04_manuscript/                           ▶ STEP 4: assemble DOCX
│   │   └── 09c_update_manuscript_v3_tracked.py    Tracked-changes DOCX
│   └── 05_directional/                          ▶ STEP 5: directional analysis
│       ├── 11c_directional_radar_windrose_figures.R   Single-source radar+windrose
│       ├── 12c_compose_figure3_directional.R          Single-source Fig 3
│       ├── 13_local_compute_botw_clean_scenario.R     S2 local compute
│       ├── 14_merge_and_render_3scenarios.R           Merge S1+S2+S3, render
│       ├── 15_compose_figure3_3scenarios.R            3-scenario Fig 3 composite
│       └── server_compute_directional_only.R          BOTW 2024 server compute
│
├── data/
│   ├── cbnr_clean_events.csv                    Canonical analytical table (1,020 rows)
│   ├── cbnr_trait_pool.csv                      Species pool + AVONET traits
│   ├── Table3_order_breakdown.csv               Manuscript Table 3 (Wilson 95% CI)
│   ├── qc_before_after_summary.csv              QC denominator changes
│   ├── qc_duplicate_drop_log.csv                Province-level dedup log
│   ├── directional/                             Early (single-source) directional analysis
│   │   ├── cbnr_directional_metrics_per_record.csv
│   │   ├── cbnr_directional_species_summary.csv
│   │   ├── cbnr_directional_synonym_audit.csv
│   │   └── direction_*_counts_*.csv              8-sector counts
│   └── directional_3scenarios/                  3-scenario release ★
│       ├── cbnr_directional_3scenarios_merged.csv   Per-record (1,020 × 77 cols)
│       ├── scenario_botw_clean_direction_metrics.csv  S2 detail
│       └── scenario_climate_summary.csv         Cross-scenario summary
│
├── figures/
│   ├── figure1_phylogeny_trimmed.{png,pdf,pptx}                    Fig 1
│   ├── figure2_combined_aligned.{png,pdf,pptx}                     Fig 2 (a)(b)(c)
│   ├── figure2_panel_{a,b,c}_*.{png,pdf,pptx}                      Per-panel
│   ├── figure5_qc_validation.{png,pdf}                             Fig 5
│   ├── figure_flowchart_pipeline.{png,pdf,svg,pptx}                Technical flowchart
│   ├── directional/                             Early directional figures
│   └── directional_3scenarios/                  3-scenario directional figures ★
│       ├── figure3_directional_3scenarios_combined.{png,pdf,pptx}  Manuscript Fig 3
│       └── scenario{1,2,3}_overall_*.{png,pdf,pptx}                Per-scenario panels
│
├── docs/
│   ├── REPRODUCE.md                             Step-by-step reproduction recipe
│   ├── DATA_DICTIONARY.md                       Full column catalogue
│   └── CHANGELOG.md                             Release history
│
└── results/
    ├── CBNR_ScientificData_20260510_v3_tracked.docx   Tracked-changes manuscript
    ├── 深度审查报告_中国鸟类新纪录研究_20260510.md       In-depth review report
    └── run_log_01c.md                                 Cleaning run log
```

★ = 3-scenario release (2026-05-11). See [docs/CHANGELOG.md](docs/CHANGELOG.md).

---

## How to reproduce / 如何复现

The pipeline runs locally with one master Excel file and one R/Python
environment.  For directional analysis Scenarios 1 and 3 you also need the
server-computed climate+direction CSV (see "Data sources" in
[docs/REPRODUCE.md](docs/REPRODUCE.md)).

完整复现需要一个主 Excel 表 + R/Python 环境。Scenarios 1 & 3 需要服务端
预计算的气候+方向 CSV — 详见 [docs/REPRODUCE.md](docs/REPRODUCE.md)。

```bash
# Prerequisites
#   R ≥ 4.5, Python ≥ 3.9
#   Master spreadsheet `鸟类新纪录20260508.xlsx` in repository parent dir
#   (or override via env var CBNR_MASTER_XLSX)

ROOT=$PWD
CLEAN=$ROOT/data/cbnr_clean_events.csv

# 1. Clean the master spreadsheet → canonical CSV
Rscript code/01_pipeline/01c_build_canonical_keep_all_years.R

# 2. Run domain analyses (env vars redirect outputs into the repo)
BIRD_CLEAN_PATH=$CLEAN  BIRD_TASK_DIR=$ROOT/figures/spatiotemporal \
  BIRD_SHAPE_DIR=$ROOT/data/shapefile_base \
  Rscript code/02_analyses/make_spatiotemporal_keepall.R

BIRD_CLEAN_PATH=$CLEAN  BIRD_TASK_DIR=$ROOT/figures/sankey \
  BIRD_SANKEY_N_COLLAPSE=5 \
  Rscript code/02_analyses/make_sankey_topN_others_keepall.R

BIRD_TASK_DIR=$ROOT/figures/phylogeny \
  BIRD_MASTER_XLSX=$ROOT/../鸟类新纪录20260508.xlsx \
  BIRD_CORRECTED_EVENTS_CSV=$CLEAN \
  Rscript code/02_analyses/run_bird_phylogeny_new_records_mctavish.R

# 3. Compose Figure 1 (trim), Figure 2 (composite), flowchart
Rscript code/03_figures/07c_compose_figure2_v3_aligned.R
Rscript code/03_figures/08c_make_flowchart_and_fig1.R
Rscript code/03_figures/10c_make_editable_fig1_fig2_pptx.R    # editable PPTX

# 4. Directional analysis (3 scenarios + Figure 3 composite)
Rscript code/05_directional/13_local_compute_botw_clean_scenario.R   # S2 local
Rscript code/05_directional/14_merge_and_render_3scenarios.R         # merge S1/S2/S3
Rscript code/05_directional/15_compose_figure3_3scenarios.R          # Fig 3

# 5. Update DOCX with tracked changes
python3 code/04_manuscript/09c_update_manuscript_v3_tracked.py
```

A guided walk-through with environment-variable references and external
data location notes lives in [`docs/REPRODUCE.md`](docs/REPRODUCE.md).

---

## R / Python dependencies / 依赖

**R ≥ 4.5** packages (CRAN unless noted):

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

**Python ≥ 3.9** packages:

```bash
pip install python-docx pandas openpyxl
```

**System libraries (macOS via Homebrew)** — for editable PPTX (rvg/gdtools):

```bash
brew install pkgconf cairo fontconfig gettext libpng
# gdtools / rvg may need a source build to match the running R version;
# see docs/REPRODUCE.md §System libraries for the verified recipe.
```

---

## Data dictionary / 数据字典

See [`docs/DATA_DICTIONARY.md`](docs/DATA_DICTIONARY.md) for the full
77-column catalogue of `data/directional_3scenarios/cbnr_directional_3scenarios_merged.csv`
plus all other published CSVs.

The canonical event table (`data/cbnr_clean_events.csv`) key columns:

| Column | Type | Description |
|---|---|---|
| `record_id`            | int    | Stable row identifier |
| `species`              | text   | Scientific binomial (Catalogue of Life China 2025) |
| `species_cn`           | text   | Chinese common name |
| `english_name`         | text   | English common name |
| `order` / `family`     | text   | Taxonomic order / family |
| `province`             | text   | Standardised province name (English) |
| `longitude`/`latitude` | num    | Decimal degrees (WGS84) |
| `coord_status`         | text   | `valid` / `lon_eq_lat_artefact` |
| `year`                 | int    | Discovery year (fallback to publication year) |
| `year_in_scope`        | bool   | TRUE if year ≥ 2000 (study scope) |
| `iucn`                 | text   | IUCN Red List code (LC/NT/VU/EN/CR/DD) |
| `china_red_list`       | text   | China Red List 2020 category |
| `migratory_status`     | text   | Full / Partial / Altitudinal / Not |
| `discovery_method`     | text   | Field observation / Specimen / Camera-trap … |
| `discover_reason`      | text   | Range shift / Survey gap / Taxonomic / Mixed … |
| `paper_id`             | text   | Source identifier (title / DOI / link) |
| `keep_record`          | bool   | TRUE for the earliest publication in a sp×prov group |

---

## Documentation files / 辅助文档

| Path | What's inside |
|---|---|
| [`docs/REPRODUCE.md`](docs/REPRODUCE.md)         | Step-by-step reproduction recipe (data sources, env vars, system libs, troubleshooting) |
| [`docs/DATA_DICTIONARY.md`](docs/DATA_DICTIONARY.md) | Every column in every published CSV |
| [`docs/CHANGELOG.md`](docs/CHANGELOG.md)         | Release history (v1 → v2 → v3 → 3-scenario) |
| [`results/深度审查报告_中国鸟类新纪录研究_20260510.md`](results/深度审查报告_中国鸟类新纪录研究_20260510.md) | In-depth methodological review (bilingual) |

---

## Citation / 引用

If you reuse the CBNR analytical release or the pipeline, please cite:

> Ding, C. et al. (in prep.). A peer-reviewed literature-based database of
> provincial-level new bird distribution records in China (2000–2025).
> *Scientific Data*.

Machine-readable citation in [`CITATION.cff`](CITATION.cff).

---

## License / 许可

- **Code** (`code/**`): MIT — see [`LICENSE`](LICENSE).
- **Data** (`data/**`, `figures/**`, `results/**`): CC-BY-4.0.

---

## Acknowledgements / 致谢

This work builds on the framework developed for Chinese mammal new records
(Ding et al. 2025, *Global Ecology and Biogeography* 34: e70165). We thank
all contributors to the LLM-extraction calibration set and to the
canonical-identity audit, and the BirdLife International / HBW team for
the global avian range polygons.

**Contact:** Chenchen Ding — <chenchending1992@gmail.com>
