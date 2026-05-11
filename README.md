# CBNR — China Bird New Distribution Records (2000–2025)

**Authors:** Chenchen Ding (Peking University) & coauthors
**Status:** Scientific Data manuscript in preparation
**Repository date:** 2026-05-11 (directional 3-scenario release)

A reproducible, peer-reviewed literature-based database of provincial-level
new bird distribution records in China, plus the analytical pipeline that
produces every figure and table in the accompanying *Scientific Data*
manuscript.

中国鸟类省级新分布纪录（CBNR）数据库 (2000–2025) 与配套 Scientific Data
稿件全套可复现分析管线。

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

| Scenario | Range definition | Records covered | Median dist. to centroid | Median dist. to edge | Mean point ΔT (°C, 1970–2000 → year-of-record) |
|---|---|---|---|---|---|
| **S1** | Resident + Breeding (BOTW 2024, SEASONAL=1,2) | 762 (74.7%) | 1,936 km | 510 km | +0.89 |
| **S2** | User-curated `BOTW_clean.gpkg` (466 species pre-clipped) | 771 (75.6%) | 1,262 km | 548 km | +0.90 |
| **S3** | All seasonal categories pooled (no filter) | 860 (84.3%) | 2,024 km | 469 km | +0.88 |

- Synonyms resolved via the BirdLife HBW v9 checklist (11,195 accepted + 2,734 alternative forms).
- 563/564 CBNR species mapped to BirdLife taxonomy; 1 unmatched name audited.
- Climate metrics use WorldClim v2.1 5 m × 5 m baseline + CRU TS annual data.

Main outputs are in `data/directional_3scenarios/` and `figures/directional_3scenarios/`.

---

## Repository layout / 目录结构

```
.
├── code/                                        Scripts (R + Python)
│   ├── 01_pipeline/
│   │   └── 01c_build_canonical_keep_all_years.R     Master cleaning + flag
│   ├── 02_analyses/
│   │   ├── make_spatiotemporal_keepall.R            Maps Fig 2(a)(b)
│   │   ├── make_sankey_topN_others_keepall.R        Sankey Fig 2(c)
│   │   └── run_bird_phylogeny_new_records_mctavish.R Circular tree Fig 1
│   ├── 03_figures/
│   │   ├── 07c_compose_figure2_v3_aligned.R         Composite Fig 2
│   │   └── 08c_make_flowchart_and_fig1.R            Flowchart + trim
│   └── 04_manuscript/
│       └── 09c_update_manuscript_v3_tracked.py      Tracked-changes DOCX
│
├── data/                                        Tabular outputs
│   ├── cbnr_clean_events.csv                    Canonical analytical table
│   ├── cbnr_trait_pool.csv                      Species pool + AVONET traits
│   ├── qc_before_after_summary.csv              QC denominator changes
│   ├── qc_duplicate_drop_log.csv                Province-level dedup log
│   └── Table3_order_breakdown.csv               Manuscript Table 3 (Wilson CI)
│
├── figures/                                     Final manuscript figures
│   ├── figure1_phylogeny_trimmed.{png,pdf,pptx}
│   ├── figure2_combined_aligned.{png,pdf,pptx}  Map + Map + Sankey composite
│   ├── figure2_panel_a_count_map.{png,pdf,pptx} (a) Choropleth + SCS inset
│   ├── figure2_panel_b_point_map.{png,pdf,pptx} (b) Points + SCS inset
│   ├── figure2_panel_c_sankey_topN.{png,pdf,pptx} (c) Sankey w/ Others
│   ├── figure5_qc_validation.{png,pdf}          QC three-panel
│   └── figure_flowchart_pipeline.{png,pdf,svg,pptx} Technical flowchart
│
└── results/                                     Documents & reports
    ├── run_log_01c.md
    ├── CBNR_ScientificData_20260510_v3_tracked.docx
    └── 深度审查报告_中国鸟类新纪录研究_20260510.md
```

---

## How to reproduce / 如何复现

```bash
# Pre-requisites: R ≥ 4.5; Python ≥ 3.9; the master spreadsheet
#   `鸟类新纪录20260508.xlsx` must be in the parent directory of code/.
# 必备：R ≥ 4.5；Python ≥ 3.9；主表 `鸟类新纪录20260508.xlsx` 放在 code/ 上一级。

# 1) Build canonical analytical CSV (keep-all-years rule)
Rscript code/01_pipeline/01c_build_canonical_keep_all_years.R

# 2) Re-run downstream analyses (use env vars to redirect outputs)
ROOT=$PWD
CLEAN=$ROOT/data/cbnr_clean_events.csv

BIRD_CLEAN_PATH=$CLEAN  BIRD_TASK_DIR=$ROOT/results/spatiotemporal \
  BIRD_SHAPE_DIR=$ROOT/data/shapefile_base \
  Rscript code/02_analyses/make_spatiotemporal_keepall.R

BIRD_CLEAN_PATH=$CLEAN  BIRD_TASK_DIR=$ROOT/results/sankey \
  BIRD_SANKEY_N_COLLAPSE=5 \
  Rscript code/02_analyses/make_sankey_topN_others_keepall.R

BIRD_TASK_DIR=$ROOT/results/phylogeny \
  BIRD_MASTER_XLSX=$ROOT/../鸟类新纪录20260508.xlsx \
  BIRD_CORRECTED_EVENTS_CSV=$CLEAN \
  BIRD_MCTAVISH_TREE=$ROOT/data/external/summary_dated_clements.nex \
  Rscript code/02_analyses/run_bird_phylogeny_new_records_mctavish.R

# 3) Compose Figure 2 + flowchart + trim Fig 1
Rscript code/03_figures/07c_compose_figure2_v3_aligned.R
Rscript code/03_figures/08c_make_flowchart_and_fig1.R

# 4) Update DOCX with tracked changes
python3 code/04_manuscript/09c_update_manuscript_v3_tracked.py
```

---

## R package dependencies / R 包依赖

```r
install.packages(c(
  "readxl", "readr", "dplyr", "tidyr", "stringr", "forcats", "tibble",
  "ggplot2", "ggalluvial", "patchwork", "scales", "cowplot",
  "sf", "officer", "rvg", "export", "magick",
  "DiagrammeR", "DiagrammeRsvg", "rsvg",
  "ape", "fs"
))
# Bioconductor:
BiocManager::install(c("ggtree", "treeio"))
```

System libraries (macOS via Homebrew):
```
brew install pkgconf cairo fontconfig gettext libpng
# gdtools/rvg may need source build to match the running R version:
#   R CMD INSTALL gdtools_<v>.tar.gz   (may need to patch configure to drop --static)
#   R CMD INSTALL rvg_<v>.tar.gz       (may need PKG_CPPFLAGS/PKG_LIBS to libpng)
```

---

## Data dictionary (cbnr_clean_events.csv) / 数据字典节选

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

## License / 许可

- **Code**: MIT
- **Data**: CC-BY-4.0 (please cite Ding et al., in preparation)

If you reuse the CBNR analytical release in published work, please cite:

> Ding, C. et al. (in prep.). A peer-reviewed literature-based database of
> provincial-level new bird distribution records in China (2000–2025).
> *Scientific Data*.

---

## Acknowledgements / 致谢

This work builds on the framework developed for Chinese mammal new records
(Ding et al. 2025, *Global Ecology and Biogeography* 34: e70165). We thank
all contributors to the LLM-extraction calibration set and to the
canonical-identity audit.

---

## Contact / 联系

Chenchen Ding — chenchending1992@gmail.com
