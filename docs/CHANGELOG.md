# Changelog / 变更日志

All notable releases of the CBNR repository are recorded here.

仓库的每次重要修订均记录在此。

The format roughly follows [Keep a Changelog](https://keepachangelog.com/),
and versions roughly follow [SemVer](https://semver.org/) for the data
release line (`v0.MAJOR.MINOR`).

---

## [v0.3.0-3scenarios] — 2026-05-11

### Added

- **3-scenario directional analysis** based on BirdLife BOTW 2024
  (11,181 species), replacing the earlier `all_birds_qgis.shp`
  (~6,000 species) that had limited Chinese coverage.
  - Scenario S1: Resident + Breeding (BOTW 2024, SEASONAL = 1, 2) — 762/1020 (74.7 %)
  - Scenario S2: user-curated `BOTW_clean.gpkg` (466 species) — 771/1020 (75.6 %)
  - Scenario S3: all seasonal categories pooled — 860/1020 (84.3 %)
- New per-record output `data/directional_3scenarios/cbnr_directional_3scenarios_merged.csv`
  (1,020 × 77 cols) with bearing, distance, lon/lat delta, climate-niche
  shift, and inside-range flag under all 3 scenarios.
- New scripts: `code/05_directional/13–15_*.R`.
- Manuscript composite **Figure 3** in `figures/directional_3scenarios/`
  (PNG/PDF/PPTX × per-scenario windrose / radar / order facets +
  3-scenario combined panel).
- `docs/DATA_DICTIONARY.md`, `docs/REPRODUCE.md`, `docs/CHANGELOG.md`,
  `CITATION.cff`.

### Fixed

- **Root-cause fix for the earlier 38.8 % match rate**: 265 common species
  (`Accipiter gularis`, `Aythya collaris`, `Branta canadensis`, …) that
  had been missing from `all_birds_qgis.shp` are now recovered from
  `BOTW_2024_2.gpkg` (264 of 265 found).
- Hardcoded `/Users/dingchenchen/…` paths replaced with env-var fallback
  in `code/03_figures/10c_make_editable_fig1_fig2_pptx.R` and
  `code/05_directional/14_merge_and_render_3scenarios.R`.
- DOCX (`results/CBNR_ScientificData_20260510_v3_tracked.docx`) regenerated
  with embedded 3-scenario Figure 3 + bilingual caption.

---

## [v0.2.0-directional] — 2026-05-10

### Added

- Earlier (single-source) directional analysis using
  `all_birds_qgis.shp` (BirdLife 2017-19) — kept in `data/directional/`
  and `figures/directional/` for traceability.
- Manuscript Figure 3 (single-scenario composite).
- Truly editable PPTX exports for Figure 1 and Figure 2 (cowplot + officer
  with native ggplot vector rendering).
- `code/05_directional/11c_directional_radar_windrose_figures.R`
  + `12c_compose_figure3_directional.R`
  + `server_compute_directional_only.R`.

---

## [v0.1.0-initial] — 2026-05-10

### Added

- Initial CBNR release.
- **Headline numbers:** 1,020 validated species–province events
  (1,011 in scope + 9 pre-2000 flagged) across 564 species, 23 orders,
  33 provincial units, 670 source articles.
- Cleaning pipeline `01c_build_canonical_keep_all_years.R`
  (Catalogue of Life China 2025 harmonisation + Zheng 2023 cross-walk;
  earliest-publication retention; lon/lat artefact flagging).
- Spatiotemporal analysis (`make_spatiotemporal_keepall.R`) with
  Albers Equal Area maps + South China Sea inset.
- Sankey diagram (`make_sankey_topN_others_keepall.R`) with bottom-5
  orders collapsed into `Others`.
- Phylogenetic-coverage figure on the McTavish (2025) global avian
  backbone (`run_bird_phylogeny_new_records_mctavish.R`).
- Tracked-changes DOCX manuscript with bilingual captions and embedded
  Figures 1/2/5 + flowchart.
- README + LICENSE (MIT for code, CC-BY-4.0 for data).

---

## Roadmap / 后续规划

- Add a CRU TS-based annual `data/directional_3scenarios/scenario_climate_per_record.csv`
  shipped directly in the repo (instead of requiring server data).
- Provide `renv.lock` and `requirements.txt` for fully pinned R / Python
  environments.
- Migrate large binary figures (PPTX/PDF > 20 MB) to Git LFS or
  Zenodo / Figshare deposit; keep only PNG previews in the repo.
- Publish a tagged release with a Zenodo DOI when the *Scientific Data*
  manuscript is accepted.
