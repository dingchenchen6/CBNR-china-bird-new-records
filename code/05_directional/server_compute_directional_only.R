#!/usr/bin/env Rscript

# ============================================================
# CBNR directional-only metrics (no climate)
# CBNR 仅空间方向指标计算（不含气候）
# ============================================================
#
# Scientific question / 科学问题
# For each new bird record point in the CBNR keep-all-years analytical
# release, quantify (i) its bearing and displacement relative to the
# species' historical BirdLife range CENTROID in China, and (ii) the
# bearing/displacement relative to the NEAREST EDGE of that range.
# Synonyms are resolved through the HBW BirdLife v9 checklist so that
# CBNR scientific names mapped to different BirdLife names are still
# matched to a range polygon.
# 对 CBNR keep-all-years 数据集中每条记录，量化其相对物种 BirdLife
# 中国历史分布区 (i) 几何中心 与 (ii) 最近边缘 的方位、位移与经纬度变化。
# 同物异名通过 HBW v9 checklist 解析。
#
# Output / 输出
#   results/cbnr_directional_metrics_per_record.csv
#   results/cbnr_directional_species_summary.csv
#   results/cbnr_directional_synonym_audit.csv
#   results/historical_range_polygons_china.gpkg
#
# Inputs / 输入
#   - cbnr_clean_events_keepall.csv  (uploaded; 1020 events)
#   - hbw_v9_checklist.csv           (exported from BOTW gpkg via sqlite3)
#   - /home/dingchenchen/DCC/BIRDLIFE1/all_birds_qgis.shp (range polygons)
#   - /home/dingchenchen/projects/bird-sdm-inputs/province/省.shp (China)
# ============================================================

suppressPackageStartupMessages({
  library(sf); library(dplyr); library(tidyr); library(stringr); library(readr)
  library(purrr); library(tibble)
})
sf_use_s2(FALSE)  # avoid s2 spherical-geometry validation issues

t0 <- Sys.time()
TASK_ROOT <- "/home/dingchenchen/projects/bird-new-distribution-records/tasks/bird_directional_v3_server"
RES <- file.path(TASK_ROOT, "results"); dir.create(RES, showWarnings = FALSE, recursive = TRUE)
LOG <- file.path(TASK_ROOT, "logs");    dir.create(LOG, showWarnings = FALSE, recursive = TRUE)

cbnr_csv     <- file.path(TASK_ROOT, "cbnr_clean_events_keepall.csv")
checklist_csv <- file.path(TASK_ROOT, "hbw_v9_checklist.csv")
range_shp     <- "/home/dingchenchen/DCC/BIRDLIFE1/all_birds_qgis.shp"
china_shp     <- "/home/dingchenchen/projects/bird-sdm-inputs/province/省.shp"

# ----------------------------------------------------------
# Step 1. Read inputs
# 第 1 步：读取输入
# ----------------------------------------------------------
records <- read_csv(cbnr_csv, show_col_types = FALSE) %>%
  filter(!is.na(species), !is.na(longitude), !is.na(latitude)) %>%
  mutate(species = str_squish(species))
cat("[1] Records with coords:", nrow(records), " | unique species:",
    n_distinct(records$species), "\n")

checklist <- read_csv(checklist_csv, show_col_types = FALSE) %>%
  rename(scientific_name = ScientificName, synonyms = Synonyms,
         order = Order_, family = FamilyName, common = CommonName) %>%
  mutate(scientific_name = str_squish(scientific_name),
         synonyms = ifelse(is.na(synonyms) | synonyms == "", NA_character_,
                            as.character(synonyms)))

# Build accepted + synonym lookup table
# 构建 accepted + synonym 双重查表
canonize <- function(x) {
  x <- str_squish(as.character(x))
  pieces <- str_split_fixed(x, " ", 2)
  paste(str_to_sentence(str_to_lower(pieces[, 1])), str_to_lower(pieces[, 2]))
}
split_synonym <- function(s) {
  if (is.na(s) || s == "") return(character(0))
  parts <- unlist(strsplit(s, "[;,]"))
  parts <- str_squish(parts)
  parts <- parts[parts != "" & !grepl("[(\\[]", parts)]
  parts
}
acc <- checklist %>%
  transmute(input_name = canonize(scientific_name),
            accepted = canonize(scientific_name),
            match_type = "accepted")
syn <- checklist %>%
  filter(!is.na(synonyms)) %>%
  mutate(syns = map(synonyms, split_synonym)) %>%
  select(accepted = scientific_name, syns) %>%
  unnest(syns) %>%
  transmute(input_name = canonize(syns),
            accepted = canonize(accepted),
            match_type = "synonym") %>%
  distinct(input_name, .keep_all = TRUE)
synonym_lookup <- bind_rows(acc, syn) %>%
  distinct(input_name, .keep_all = TRUE)
cat("[1] Synonym lookup: accepted=", sum(synonym_lookup$match_type == "accepted"),
    " synonym=", sum(synonym_lookup$match_type == "synonym"), "\n", sep = "")

# Resolve each CBNR species name → BirdLife accepted name
records <- records %>%
  mutate(species_canon = canonize(species)) %>%
  left_join(synonym_lookup, by = c("species_canon" = "input_name")) %>%
  mutate(bl_match_type = case_when(
           !is.na(accepted) & match_type == "accepted" ~ "accepted",
           !is.na(accepted) & match_type == "synonym"  ~ "synonym",
           TRUE                                        ~ "unmatched"
         ),
         bl_accepted = coalesce(accepted, species_canon))

audit <- records %>%
  distinct(species, species_canon, bl_accepted, bl_match_type) %>%
  arrange(bl_match_type, species)
write_csv(audit, file.path(RES, "cbnr_directional_synonym_audit.csv"))
cat("[1] Audit: ", paste(names(table(audit$bl_match_type)),
                          table(audit$bl_match_type), sep = "=",
                          collapse = " | "), "\n")

# ----------------------------------------------------------
# Step 2. Read China boundary and BirdLife polygons (target species only)
# 第 2 步：读取中国边界与目标物种的 BirdLife 多边形
# ----------------------------------------------------------
china <- st_read(china_shp, quiet = TRUE) %>% st_make_valid() %>%
  st_transform(4326) %>%   # align CRS with BirdLife polygons (WGS84)
  st_union() %>% st_make_valid()
cat("[2] China union built\n")

target_species <- unique(records$bl_accepted)
target_species <- target_species[!is.na(target_species) & target_species != ""]
cat("[2] Target species to extract from BirdLife shapefile:", length(target_species), "\n")

# Build SQL WHERE clause to filter shapefile (handles ≤ several thousand IDs)
escape_sql <- function(x) str_replace_all(x, "'", "''")
where <- paste0("SELECT SCINAME, SEASONAL, PRESENCE, ORIGIN FROM all_birds_qgis WHERE SCINAME IN (",
                paste0("'", escape_sql(target_species), "'", collapse = ","), ") ",
                "AND PRESENCE IN (1,2,3,6) AND ORIGIN IN (1,2,5,6) ",
                "AND SEASONAL IN (1,2)")
cat("[2] Reading filtered range polygons via OGR-SQL (resident/breeding only)...\n")
ranges <- st_read(range_shp, query = where, quiet = TRUE) %>%
  st_make_valid()
cat("[2] Range features retrieved:", nrow(ranges),
    " | covering species:", n_distinct(ranges$SCINAME), "\n")

# Clip to China and dissolve by species
ranges_china <- st_intersection(ranges, china) %>%
  st_make_valid() %>%
  filter(!st_is_empty(.))
cat("[2] Clipped to China:", nrow(ranges_china), " features\n")

species_polys <- ranges_china %>%
  group_by(species = SCINAME) %>%
  summarise(geometry = st_union(geometry), .groups = "drop") %>%
  st_make_valid()
cat("[2] Per-species China polygons:", nrow(species_polys), "\n")
# Save per-species China polygons as RDS (GPKG driver not always available)
# 保存为 RDS 避免 GPKG 驱动缺失
saveRDS(species_polys, file.path(RES, "historical_range_polygons_china.rds"))

# ----------------------------------------------------------
# Step 3. Bearing helpers
# 第 3 步：方位角计算工具
# ----------------------------------------------------------
initial_bearing_deg <- function(lon1, lat1, lon2, lat2) {
  phi1 <- lat1 * pi / 180; phi2 <- lat2 * pi / 180
  dl <- (lon2 - lon1) * pi / 180
  y <- sin(dl) * cos(phi2)
  x <- cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dl)
  b <- atan2(y, x) * 180 / pi
  (b + 360) %% 360
}
classify_8 <- function(deg) {
  if (is.na(deg)) return(NA_character_)
  sectors <- c("N", "NE", "E", "SE", "S", "SW", "W", "NW")
  sectors[((round(deg / 45) %% 8) + 1)]
}

# ----------------------------------------------------------
# Step 4. Per-record directional metrics
# 第 4 步：逐记录方向指标
# ----------------------------------------------------------
sp_in_poly <- unique(species_polys$species)
records <- records %>% mutate(has_range_polygon = bl_accepted %in% sp_in_poly)
cat("[4] Records with a matched range polygon:",
    sum(records$has_range_polygon), "/", nrow(records), "\n")

# Project for accurate distances (Albers Equal Area for China)
china_crs <- "+proj=aea +lat_1=25 +lat_2=47 +lat_0=0 +lon_0=105 +ellps=GRS80 +units=m +no_defs"
species_polys_proj <- st_transform(species_polys, china_crs)

# Pre-compute centroids
centroids <- species_polys %>%
  mutate(geom_centroid = st_centroid(geometry)) %>%
  st_drop_geometry() %>%
  bind_cols(do.call(rbind, lapply(seq_len(nrow(species_polys)),
    function(i) {
      c <- st_centroid(species_polys$geometry[i])
      crd <- st_coordinates(c)
      data.frame(centroid_lon = crd[1, 1], centroid_lat = crd[1, 2])
    })))

n <- nrow(records)
out <- vector("list", n)
for (i in seq_len(n)) {
  r <- records[i, ]
  if (!r$has_range_polygon) {
    out[[i]] <- tibble(record_id = r$record_id,
                       centroid_lon = NA_real_, centroid_lat = NA_real_,
                       nearest_edge_lon = NA_real_, nearest_edge_lat = NA_real_,
                       bearing_from_centroid_deg = NA_real_,
                       direction_8_centroid = NA_character_,
                       bearing_from_nearest_edge_deg = NA_real_,
                       direction_8_nearest_edge = NA_character_,
                       centroid_delta_lon_deg = NA_real_,
                       centroid_delta_lat_deg = NA_real_,
                       edge_delta_lon_deg = NA_real_,
                       edge_delta_lat_deg = NA_real_,
                       distance_to_centroid_km = NA_real_,
                       distance_to_nearest_edge_km = NA_real_,
                       point_inside_range = NA)
    next
  }
  sp_poly <- species_polys$geometry[species_polys$species == r$bl_accepted][1]
  cen <- centroids[centroids$species == r$bl_accepted, ][1, ]
  pt <- st_sfc(st_point(c(r$longitude, r$latitude)), crs = 4326)
  pt_proj <- st_transform(pt, china_crs)
  poly_proj <- st_transform(sp_poly, china_crs)
  cen_proj <- st_transform(st_sfc(st_point(c(cen$centroid_lon, cen$centroid_lat)),
                                   crs = 4326), china_crs)
  # Distances
  inside <- as.logical(st_intersects(pt, sp_poly, sparse = FALSE)[1, 1])
  dist_edge <- as.numeric(st_distance(pt_proj, poly_proj)) / 1000     # km to edge
  dist_cen  <- as.numeric(st_distance(pt_proj, cen_proj))  / 1000     # km to centroid
  # Nearest edge point
  nearest <- st_nearest_points(pt, sp_poly) %>% st_cast("POINT")
  edge_pt <- nearest[2]
  edge_crd <- st_coordinates(edge_pt)
  # Bearings
  b_c <- initial_bearing_deg(cen$centroid_lon, cen$centroid_lat,
                              r$longitude, r$latitude)
  b_e <- initial_bearing_deg(edge_crd[1, 1], edge_crd[1, 2],
                              r$longitude, r$latitude)
  out[[i]] <- tibble(
    record_id = r$record_id,
    centroid_lon = cen$centroid_lon,
    centroid_lat = cen$centroid_lat,
    nearest_edge_lon = edge_crd[1, 1],
    nearest_edge_lat = edge_crd[1, 2],
    bearing_from_centroid_deg = b_c,
    direction_8_centroid = classify_8(b_c),
    bearing_from_nearest_edge_deg = b_e,
    direction_8_nearest_edge = classify_8(b_e),
    centroid_delta_lon_deg = r$longitude - cen$centroid_lon,
    centroid_delta_lat_deg = r$latitude  - cen$centroid_lat,
    edge_delta_lon_deg = r$longitude - edge_crd[1, 1],
    edge_delta_lat_deg = r$latitude  - edge_crd[1, 2],
    distance_to_centroid_km = dist_cen,
    distance_to_nearest_edge_km = dist_edge,
    point_inside_range = inside
  )
  if (i %% 100 == 0) cat("    progress:", i, "/", n, "\n")
}
metrics <- bind_rows(out)
final <- records %>% select(record_id, species, bl_accepted, bl_match_type,
                             order, province, year, longitude, latitude,
                             has_range_polygon, year_in_scope) %>%
  left_join(metrics, by = "record_id")
write_csv(final, file.path(RES, "cbnr_directional_metrics_per_record.csv"))
cat("[4] Per-record metrics:", nrow(final), " written\n")

# ----------------------------------------------------------
# Step 5. Species-level summary
# 第 5 步：物种级别汇总
# ----------------------------------------------------------
spp <- final %>%
  filter(has_range_polygon) %>%
  group_by(bl_accepted, order) %>%
  summarise(
    n_records = n(),
    mean_dist_centroid_km = mean(distance_to_centroid_km, na.rm = TRUE),
    mean_dist_edge_km = mean(distance_to_nearest_edge_km, na.rm = TRUE),
    pct_inside_range = mean(point_inside_range, na.rm = TRUE) * 100,
    .groups = "drop"
  ) %>%
  arrange(desc(n_records))
write_csv(spp, file.path(RES, "cbnr_directional_species_summary.csv"))

t1 <- Sys.time()
writeLines(c(
  paste("# Directional pipeline run (server)"),
  paste("- start:", format(t0)),
  paste("- end:",   format(t1)),
  paste("- elapsed sec:", round(as.numeric(difftime(t1, t0, units = "secs")), 1)),
  paste("- records:", nrow(final)),
  paste("- with-range:", sum(final$has_range_polygon)),
  paste("- unique species in range polygons:", nrow(species_polys)),
  paste("- synonym lookup size:", nrow(synonym_lookup))
), file.path(LOG, "run_log.md"))
cat("\n=== DONE in", round(as.numeric(difftime(t1, t0, units = "mins")), 2),
    "minutes ===\n")
