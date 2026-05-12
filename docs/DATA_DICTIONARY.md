# Data dictionary / 数据字典

Complete column catalogue for every published CSV in this repository.

本目录列出仓库内所有公开 CSV 的字段定义、单位、来源与缺失含义。

> Unless stated otherwise, coordinates are WGS84 (EPSG:4326), distances are
> in kilometres, areas in km², temperatures in °C, and precipitation in mm.
> Boolean columns use `TRUE / FALSE`. Missing values are `NA` (R) / empty
> (CSV) / `null` (JSON).

---

## 1. `data/cbnr_clean_events.csv` — canonical analytical table

1,020 rows × 36 columns. One row per validated species–province event.

| # | Column | Type | Description |
|---|---|---|---|
| 1  | `record_id`                 | int  | Stable row identifier across releases |
| 2  | `species`                   | text | Scientific binomial (Catalogue of Life China 2025) |
| 3  | `order_raw`                 | text | Raw taxonomic order as in the master spreadsheet |
| 4  | `order_cn`                  | text | Order in original encoding (CN/EN) |
| 5  | `province_cn`               | text | Province in original Chinese text |
| 6  | `province_en_raw`           | text | Province in original English text |
| 7  | `year`                      | int  | Event year (discovery > publication fallback) |
| 8  | `year_in_scope`             | bool | TRUE iff `2000 ≤ year ≤ 2025` |
| 9  | `iucn_raw`                  | text | IUCN code as written in source |
| 10 | `discover_cause_raw`        | text | Discovery cause / free text |
| 11 | `discovery_method_raw`      | text | Detection method / free text |
| 12 | `longitude`, `latitude`     | num  | Decimal degrees, WGS84 |
| 13 | `order`                     | text | Standardised order (English, Latin) |
| 14 | `province`                  | text | Standardised province (English) |
| 15 | `iucn`                      | text | Mapped IUCN code: `LC NT VU EN CR DD` |
| 16 | `discover_reason`           | text | Classified cause (Range shift / Survey gap / Taxonomic / Mixed / Other / Unclear) |
| 17 | `discovery_method`          | text | Classified method (Field observation / Specimen / Camera-trap / …) |
| 18 | `paper_id`                  | text | Stable source identifier (title \| DOI \| URL) |
| 19 | `species_cn`                | text | Chinese common name |
| 20 | `english_name`              | text | English common name |
| 21 | `naming_time`               | int  | Year of original scientific naming (if known) |
| 22 | `identity_source`           | text | Provenance of accepted name: `raw_table` / `duplicate_audit` / … |
| 23 | `identity_change_flag`      | bool | TRUE if scientific name changed during cleaning |
| 24 | `duplicate_group_size`      | int  | # rows in the (species × province) group before dedup |
| 25 | `keep_record`               | bool | TRUE for the kept (earliest) row in the group |
| 26 | `coord_status`              | text | `valid` / `lon_eq_lat_artefact` |
| 27 | `family`                    | text | Taxonomic family (English, Latin) |
| 28 | `discovery_sites`           | text | Free text locality description |
| 29 | `habitat`                   | text | Habitat description |
| 30 | `altitude`                  | text | Altitude / elevation as in source |
| 31 | `migratory_status`          | text | Full / Partial / Altitudinal / Not |
| 32 | `china_red_list`            | text | China Red List 2020 category |
| 33 | `endemic`                   | text | Yes / No / Unclear |
| 34 | `source_title`              | text | Article title |
| 35 | `source_journal`            | text | Journal name |
| 36 | `source_authors`            | text | Author list |
| 37 | `doi`                       | text | Digital Object Identifier |
| 38 | `link`                      | text | URL to source article |

---

## 2. `data/cbnr_trait_pool.csv` — species × trait table

Joins CBNR new-record species with the full Chinese bird species pool
(11,195 species) and AVONET morphological/ecological traits.

Key columns:
- `species`, `order`, `family` — taxonomic identity
- `is_new_record` — bool, TRUE iff in CBNR
- `Avibase.ID`, `Mass`, `Wing.Length`, `Hand-Wing.Index`, `Beak.Length_Culmen`,
  `Habitat`, `Migration`, `Trophic.Level`, `Trophic.Niche`, `Range.Size` —
  from AVONET (Tobias et al. 2022, *Ecol. Lett.*).

---

## 3. `data/Table3_order_breakdown.csv` — Manuscript Table 3

| Column | Description |
|---|---|
| `order` | Taxonomic order |
| `n_china_species` | # of Chinese species in this order (Catalogue of Life China 2025) |
| `n_new_record_species` | # of species with ≥ 1 provincial new record |
| `n_records` | Total records (events) |
| `pct_within_order` | `n_new_record_species / n_china_species × 100` |
| `wilson_lo`, `wilson_hi` | Wilson 95 % confidence interval for `pct_within_order` |

---

## 4. `data/qc_before_after_summary.csv` — QC denominator changes

One row per cleaning stage with `n_rows`, `n_species`, `n_provinces`,
`year_min`, `year_max`, `comment`.

## 5. `data/qc_duplicate_drop_log.csv` — duplicate audit

One row per (species × province) duplicate group that needed resolution,
showing which row was kept (earliest publication year) and which dropped.

---

## 6. `data/directional/*` — single-source directional metrics (early version)

Coverage: 396 / 1,020 records (38.8 %) using the older shapefile
`all_birds_qgis.shp`. **Superseded** by `data/directional_3scenarios/`
(BOTW 2024) but retained for traceability.

Files:
- `cbnr_directional_metrics_per_record.csv`     per record metrics
- `cbnr_directional_species_summary.csv`        per species rollup
- `cbnr_directional_synonym_audit.csv`          synonym resolution audit
- `direction_overall_counts_{centroid,nearest_edge}.csv`   8-sector totals
- `direction_order_counts_{centroid,nearest_edge}.csv`     order × sector totals

---

## 7. `data/directional_3scenarios/cbnr_directional_3scenarios_merged.csv` ★

**The flagship directional output.** 1,020 rows × 77 columns. Three
scenarios computed independently, prefixed by scenario tag:
- `resident_breeding_*` (Scenario 1; BOTW 2024, SEASONAL = 1, 2)
- `bot_*`               (Scenario 2; user-curated BOTW_clean.gpkg)
- `all_seasons_*`       (Scenario 3; no seasonal filter)

### 7a. Identity (cols 1–9)

| # | Column | Description |
|---|---|---|
| 1 | `record_id`     | Foreign key to `cbnr_clean_events.csv` |
| 2 | `species`       | Scientific binomial as in source (Cat. Life China 2025) |
| 3 | `order`         | Standardised order |
| 4 | `province`      | Standardised province (English) |
| 5 | `year`          | Event year |
| 6 | `year_in_scope` | TRUE iff `2000 ≤ year ≤ 2025` |
| 7 | `longitude`     | New-record longitude (WGS84) |
| 8 | `latitude`      | New-record latitude (WGS84) |
| 9 | `iucn`          | IUCN Red List code |

### 7b. Point-level climate (cols 10–15)

| # | Column | Description |
|---|---|---|
| 10 | `point_baseline_temp` | 1970–2000 mean annual temperature at the record point (WorldClim v2.1 5′, °C) |
| 11 | `point_baseline_prec` | 1970–2000 mean annual precipitation at the point (mm) |
| 12 | `point_year_temp`     | Annual mean temperature at the point in `year` (CRU TS 4.09) |
| 13 | `point_year_prec`     | Annual precipitation at the point in `year` |
| 14 | `point_temp_delta_from_point_baseline` | `point_year_temp − point_baseline_temp` |
| 15 | `point_prec_delta_from_point_baseline` | `point_year_prec − point_baseline_prec` |

### 7c. Scenario S1 — Resident + Breeding (cols 16–38)

| # | Column | Description |
|---|---|---|
| 16 | `resident_breeding_baseline_temp_mean` | Mean 1970–2000 T over the species' R+B range polygon in China (°C) |
| 17 | `resident_breeding_baseline_prec_mean` | Mean 1970–2000 P over the same polygon (mm) |
| 18 | `resident_breeding_range_year_temp_mean` | Mean T over the polygon in `year` |
| 19 | `resident_breeding_range_year_prec_mean` | Mean P over the polygon in `year` |
| 20 | `resident_breeding_range_temp_delta_from_baseline` | Range-scale ΔT |
| 21 | `resident_breeding_range_prec_delta_from_baseline` | Range-scale ΔP |
| 22 | `point_temp_minus_resident_breeding_baseline` | Point T − Range baseline T (niche shift) |
| 23 | `point_prec_minus_resident_breeding_baseline` | Point P − Range baseline P (niche shift) |
| 24 | `resident_breeding_bearing_from_centroid_deg` | Initial bearing centroid → record point (°, 0 = N) |
| 25 | `resident_breeding_direction_8`               | 8-sector class: `N NE E SE S SW W NW` |
| 26 | `resident_breeding_bearing_from_nearest_edge_deg` | Initial bearing nearest-edge → record point |
| 27 | `resident_breeding_direction_8_from_nearest_edge` | 8-sector class for edge bearing |
| 28 | `resident_breeding_range_centroid_lon` | Centroid longitude (WGS84) |
| 29 | `resident_breeding_range_centroid_lat` | Centroid latitude |
| 30 | `resident_breeding_nearest_edge_lon`   | Nearest-edge point longitude on the polygon |
| 31 | `resident_breeding_nearest_edge_lat`   | Nearest-edge point latitude |
| 32 | `resident_breeding_centroid_delta_lon_deg` | `longitude − centroid_lon` |
| 33 | `resident_breeding_centroid_delta_lat_deg` | `latitude − centroid_lat` |
| 34 | `resident_breeding_edge_delta_lon_deg`     | `longitude − nearest_edge_lon` |
| 35 | `resident_breeding_edge_delta_lat_deg`     | `latitude − nearest_edge_lat` |
| 36 | `resident_breeding_distance_to_range_edge_km`     | Great-circle distance to nearest edge |
| 37 | `resident_breeding_distance_to_range_centroid_km` | Great-circle distance to centroid |
| 38 | `resident_breeding_point_inside_historical_range` | TRUE iff point ∈ polygon |

### 7d. Scenario S3 — All seasons (cols 39–61)

Same 23 columns as S1, prefix `all_seasons_*` instead of `resident_breeding_*`.

### 7e. Scenario S2 — BOTW_clean.gpkg (cols 62–77)

Local computation against the user-curated 466-species pre-clipped polygon
set. Prefix `bot_*`.

| # | Column | Description |
|---|---|---|
| 62 | `bot_has_polygon` | TRUE iff the species has a polygon in `BOTW_clean.gpkg` |
| 63 | `bot_centroid_lon` | Centroid longitude |
| 64 | `bot_centroid_lat` | Centroid latitude |
| 65 | `bot_nearest_edge_lon` | Nearest-edge longitude |
| 66 | `bot_nearest_edge_lat` | Nearest-edge latitude |
| 67 | `bot_bearing_from_centroid_deg` | Bearing centroid → point |
| 68 | `bot_direction_8_centroid` | 8-sector centroid bearing |
| 69 | `bot_bearing_from_nearest_edge_deg` | Bearing edge → point |
| 70 | `bot_direction_8_nearest_edge` | 8-sector edge bearing |
| 71 | `bot_centroid_delta_lon_deg` | longitude − centroid_lon |
| 72 | `bot_centroid_delta_lat_deg` | latitude − centroid_lat |
| 73 | `bot_edge_delta_lon_deg` | longitude − nearest_edge_lon |
| 74 | `bot_edge_delta_lat_deg` | latitude − nearest_edge_lat |
| 75 | `bot_distance_to_centroid_km` | Distance to centroid |
| 76 | `bot_distance_to_nearest_edge_km` | Distance to nearest edge |
| 77 | `bot_point_inside_range` | TRUE iff point ∈ polygon |

### 7f. Missing-value semantics

- For records whose species has no polygon under a scenario, every column
  for that scenario is `NA` (centroid/edge/bearing/distance/delta).
- `*_inside_historical_range` is `TRUE` (point inside), `FALSE` (point
  outside but polygon exists), or `NA` (no polygon).
- Scenario coverage rates:
  - S1 resident + breeding: 762 / 1,020 (74.7 %)
  - S2 BOTW_clean:          771 / 1,020 (75.6 %)
  - S3 all seasons:         860 / 1,020 (84.3 %)

---

## 8. `data/directional_3scenarios/scenario_botw_clean_direction_metrics.csv`

Same content as S2 columns above but stored as a standalone CSV with
identity columns.

## 9. `data/directional_3scenarios/scenario_climate_summary.csv`

Cross-scenario summary statistics (mean, median, quartile of `*_delta`,
`*_distance` and `*_inside` columns).
