#!/usr/bin/env Rscript

# ============================================================
# Local Scenario 2 (BOTW_clean.gpkg) — direction + climate
# 本地 Scenario 2：基于 BOTW_clean.gpkg 计算方向 + 经纬度位移
# ============================================================
#
# What this does
# Compute per-record directional metrics (bearing/distance/lon-lat
# deltas, inside flag) against each species' historical range polygon
# in BOTW_clean.gpkg (user's curated 466-species, China-clipped layer).
# Climate metrics from this scenario require WorldClim rasters that
# are not staged locally; for climate change we therefore re-use the
# existing server-computed CSV's `point_temp_delta_from_point_baseline`
# (which is point-only and scenario-independent).
# 本脚本基于用户上传的 BOTW_clean.gpkg 计算方向位移指标；气候变化量
# 复用服务端已计算的逐点气候差值列（点位级，与方案无关）。
#
# Output / 输出
#   ../directional_v3/data/scenario_botw_clean_direction_metrics.csv
# ============================================================

suppressPackageStartupMessages({
  library(sf); library(dplyr); library(stringr); library(readr); library(purrr); library(tibble)
})
sf_use_s2(FALSE)

get_script_path <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", ca, value = TRUE)
  if (length(fa) > 0) {
    cand <- sub("^--file=", "", fa[1])
    if (file.exists(cand)) return(normalizePath(cand))
  }
  normalizePath(getwd())
}
HERE <- get_script_path()
code_dir <- if (dir.exists(HERE)) HERE else dirname(HERE)
TASK_ROOT <- normalizePath(file.path(code_dir, ".."))
PROJECT_ROOT <- normalizePath(file.path(TASK_ROOT, ".."))

cbnr_csv  <- file.path(TASK_ROOT, "data", "bird_new_records_clean_corrected_keepall.csv")
botw_gpkg <- file.path(PROJECT_ROOT, "BOTW_clean.gpkg")
out_dir   <- file.path(TASK_ROOT, "directional_v3", "data"); dir.create(out_dir, FALSE, TRUE)
out_csv   <- file.path(out_dir, "scenario_botw_clean_direction_metrics.csv")

# Synonym lookup (CBNR scientific name → BirdLife accepted via HBW v9)
# We re-use the per-record CSV already on disk if available; else fall back to direct name
records <- read_csv(cbnr_csv, show_col_types = FALSE) %>%
  filter(!is.na(species), !is.na(longitude), !is.na(latitude)) %>%
  mutate(species = str_squish(species))

canonize <- function(x) {
  pieces <- str_split_fixed(str_squish(as.character(x)), " ", 2)
  paste(str_to_sentence(str_to_lower(pieces[, 1])), str_to_lower(pieces[, 2]))
}
records$species_canon <- canonize(records$species)

# Try to enrich with HBW v9 synonym table if present
hbw_csv <- file.path(TASK_ROOT, "directional_v3", "..", "directional_v3",
                     "..", "..", "..", "Updated_reanalysis", "data",
                     "hbw_v9_checklist.csv")
hbw_paths <- c(
  file.path(PROJECT_ROOT, "Updated_reanalysis", "data", "hbw_v9_checklist.csv"),
  file.path(PROJECT_ROOT, "hbw_v9_checklist.csv")
)
hbw_path <- hbw_paths[file.exists(hbw_paths)][1]
syn_lookup <- NULL
if (!is.na(hbw_path) && length(hbw_path) > 0) {
  cat("Loading HBW v9 checklist for synonyms:", hbw_path, "\n")
  hbw <- read_csv(hbw_path, show_col_types = FALSE)
  if (all(c("ScientificName","Synonyms") %in% names(hbw))) {
    split_syn <- function(s) {
      if (is.na(s) || s == "") return(character(0))
      parts <- unlist(strsplit(s, "[;,]")); parts <- str_squish(parts)
      parts[parts != "" & !grepl("[(\\[]", parts)]
    }
    acc <- hbw %>%
      transmute(input_name = canonize(ScientificName),
                accepted   = canonize(ScientificName), match_type = "accepted")
    syn <- hbw %>%
      filter(!is.na(Synonyms)) %>%
      mutate(syns = map(Synonyms, split_syn)) %>%
      select(accepted = ScientificName, syns) %>%
      tidyr::unnest(syns) %>%
      transmute(input_name = canonize(syns),
                accepted = canonize(accepted), match_type = "synonym")
    syn_lookup <- bind_rows(acc, syn) %>% distinct(input_name, .keep_all = TRUE)
  }
}
if (!is.null(syn_lookup)) {
  records <- records %>%
    left_join(syn_lookup, by = c("species_canon" = "input_name")) %>%
    mutate(bl_accepted = coalesce(accepted, species_canon),
           bl_match_type = coalesce(match_type, "no_lookup"))
} else {
  records <- records %>% mutate(bl_accepted = species_canon,
                                  bl_match_type = "no_lookup")
}

cat("CBNR records with coords:", nrow(records),
    " | unique target species (BL):", n_distinct(records$bl_accepted), "\n")

# Load BOTW_clean polygons
cat("Loading BOTW_clean.gpkg...\n")
poly_sf <- st_read(botw_gpkg, quiet = TRUE) %>%
  st_set_crs(4326) %>%
  st_make_valid()
cat("Polygons:", nrow(poly_sf), " | unique species:",
    n_distinct(poly_sf$sci_name), "\n")

# Match records to polygons
records <- records %>%
  mutate(has_polygon = bl_accepted %in% poly_sf$sci_name)
cat("Records with BOTW_clean polygon:", sum(records$has_polygon),
    "/", nrow(records),
    sprintf(" (%.1f%%)", 100 * sum(records$has_polygon) / nrow(records)), "\n")

# Bearing helpers
initial_bearing_deg <- function(lon1, lat1, lon2, lat2) {
  phi1 <- lat1 * pi / 180; phi2 <- lat2 * pi / 180
  dl   <- (lon2 - lon1) * pi / 180
  y <- sin(dl) * cos(phi2)
  x <- cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dl)
  ((atan2(y, x) * 180 / pi) + 360) %% 360
}
classify_8 <- function(d) {
  if (is.na(d)) return(NA_character_)
  c("N","NE","E","SE","S","SW","W","NW")[((round(d / 45) %% 8) + 1)]
}

# Pre-compute centroids
centroids <- poly_sf %>%
  mutate(cen = st_centroid(geom)) %>%
  st_drop_geometry() %>%
  bind_cols(do.call(rbind, lapply(seq_len(nrow(poly_sf)), function(i) {
    crd <- st_coordinates(st_centroid(poly_sf$geom[i]))
    data.frame(centroid_lon = crd[1, 1], centroid_lat = crd[1, 2])
  })))

china_crs <- "+proj=aea +lat_1=25 +lat_2=47 +lat_0=0 +lon_0=105 +ellps=GRS80 +units=m +no_defs"

cat("Computing per-record metrics...\n")
n <- nrow(records); out <- vector("list", n)
for (i in seq_len(n)) {
  r <- records[i, ]
  if (!r$has_polygon) {
    out[[i]] <- tibble(record_id = r$record_id,
                       bot_centroid_lon = NA_real_, bot_centroid_lat = NA_real_,
                       bot_nearest_edge_lon = NA_real_, bot_nearest_edge_lat = NA_real_,
                       bot_bearing_from_centroid_deg = NA_real_,
                       bot_direction_8_centroid = NA_character_,
                       bot_bearing_from_nearest_edge_deg = NA_real_,
                       bot_direction_8_nearest_edge = NA_character_,
                       bot_centroid_delta_lon_deg = NA_real_,
                       bot_centroid_delta_lat_deg = NA_real_,
                       bot_edge_delta_lon_deg = NA_real_,
                       bot_edge_delta_lat_deg = NA_real_,
                       bot_distance_to_centroid_km = NA_real_,
                       bot_distance_to_nearest_edge_km = NA_real_,
                       bot_point_inside_range = NA)
    next
  }
  poly <- poly_sf$geom[poly_sf$sci_name == r$bl_accepted][1]
  cen  <- centroids[centroids$sci_name == r$bl_accepted, ][1, ]
  pt   <- st_sfc(st_point(c(r$longitude, r$latitude)), crs = 4326)
  pt_p <- st_transform(pt, china_crs)
  pl_p <- st_transform(poly, china_crs)
  cn_p <- st_transform(st_sfc(st_point(c(cen$centroid_lon, cen$centroid_lat)),
                                crs = 4326), china_crs)
  inside <- as.logical(st_intersects(pt, poly, sparse = FALSE)[1, 1])
  d_edge <- as.numeric(st_distance(pt_p, pl_p)) / 1000
  d_cen  <- as.numeric(st_distance(pt_p, cn_p))  / 1000
  nearest <- st_nearest_points(pt, poly) %>% st_cast("POINT")
  ec <- st_coordinates(nearest[2])
  b_c <- initial_bearing_deg(cen$centroid_lon, cen$centroid_lat,
                              r$longitude, r$latitude)
  b_e <- initial_bearing_deg(ec[1,1], ec[1,2],
                              r$longitude, r$latitude)
  out[[i]] <- tibble(
    record_id = r$record_id,
    bot_centroid_lon = cen$centroid_lon, bot_centroid_lat = cen$centroid_lat,
    bot_nearest_edge_lon = ec[1,1], bot_nearest_edge_lat = ec[1,2],
    bot_bearing_from_centroid_deg = b_c,
    bot_direction_8_centroid = classify_8(b_c),
    bot_bearing_from_nearest_edge_deg = b_e,
    bot_direction_8_nearest_edge = classify_8(b_e),
    bot_centroid_delta_lon_deg = r$longitude - cen$centroid_lon,
    bot_centroid_delta_lat_deg = r$latitude  - cen$centroid_lat,
    bot_edge_delta_lon_deg = r$longitude - ec[1,1],
    bot_edge_delta_lat_deg = r$latitude  - ec[1,2],
    bot_distance_to_centroid_km = d_cen,
    bot_distance_to_nearest_edge_km = d_edge,
    bot_point_inside_range = inside
  )
  if (i %% 200 == 0) cat("    progress:", i, "/", n, "\n")
}

metrics <- bind_rows(out)
final <- records %>%
  select(record_id, species, bl_accepted, bl_match_type, order, province,
         year, longitude, latitude, has_polygon, year_in_scope) %>%
  rename(bot_has_polygon = has_polygon) %>%
  left_join(metrics, by = "record_id")

write_csv(final, out_csv)
cat("\nWritten:", out_csv, "\n")
cat("Scenario 2 (BOTW_clean) coverage:",
    sum(final$bot_has_polygon), "/", nrow(final),
    sprintf(" (%.1f%%)", 100*sum(final$bot_has_polygon)/nrow(final)), "\n")
