#!/usr/bin/env Rscript

# ============================================================
# Merge 3 directional scenarios + render radar / windrose / order facets
# 合并三方案 + 出雷达 / 风玫瑰 / 各目拼图
# ============================================================
#
# Scenarios / 三个方案
#   S1: resident + breeding (server-precomputed, BOTW 2024)
#   S2: BOTW_clean.gpkg (user-curated, 466 species, local)
#   S3: all seasons / no seasonal filter (server-precomputed, BOTW 2024)
#
# Output / 输出 (under ../directional_v3_3scn/)
#   data/cbnr_directional_3scenarios_merged.csv
#   figures/  per-scenario:
#     scenario{1,2,3}_overall_windrose_{centroid,nearest_edge}.{png,pdf,pptx}
#     scenario{1,2,3}_overall_radar_{centroid,nearest_edge}.{png,pdf,pptx}
#     scenario{1,2,3}_order_windrose_facets_{centroid,nearest_edge}.{png,pdf,pptx}
#   figures/figure3_directional_3scenarios_combined.{png,pdf,pptx}
# ============================================================

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(stringr)
  library(forcats); library(tibble); library(ggplot2); library(scales)
  library(patchwork); library(ggradar); library(officer); library(rvg)
  library(magick); library(cowplot)
})

# Paths
get_script_path <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", ca, value = TRUE)
  if (length(fa) > 0) { c <- sub("^--file=", "", fa[1]); if (file.exists(c)) return(normalizePath(c)) }
  normalizePath(getwd())
}
HERE <- get_script_path()
code_dir  <- if (dir.exists(HERE)) HERE else dirname(HERE)
TASK_ROOT <- normalizePath(file.path(code_dir, ".."))
PROJECT_ROOT <- normalizePath(file.path(TASK_ROOT, ".."))

OUT_DIR <- file.path(TASK_ROOT, "directional_v3_3scn")
data_d  <- file.path(OUT_DIR, "data");    dir.create(data_d, FALSE, TRUE)
fig_d   <- file.path(OUT_DIR, "figures"); dir.create(fig_d,  FALSE, TRUE)
res_d   <- file.path(OUT_DIR, "results"); dir.create(res_d,  FALSE, TRUE)

# Server-computed climate+direction table (resident_breeding + all_seasons).
# Override via env CBNR_SERVER_CLIMATE_CSV; default looks for
# data/directional_3scenarios/server_climate_direction.csv shipped with the
# repo or under TASK_ROOT.
# 服务端预计算的气候+方向表（resident_breeding 与 all_seasons）。
server_csv <- Sys.getenv(
  "CBNR_SERVER_CLIMATE_CSV",
  unset = file.path(TASK_ROOT, "data", "directional_3scenarios",
                     "server_climate_direction.csv"))
if (!file.exists(server_csv)) {
  stop(sprintf(paste0(
    "Server climate+direction CSV not found at:\n  %s\n",
    "Set env var CBNR_SERVER_CLIMATE_CSV to its path or copy the file ",
    "(see README §Data sources)."), server_csv))
}
botw_csv   <- file.path(TASK_ROOT, "directional_v3", "data",
                        "scenario_botw_clean_direction_metrics.csv")
cbnr_csv   <- file.path(TASK_ROOT, "data", "bird_new_records_clean_corrected_keepall.csv")

# -----------------------------------------------------------
# 1. Load and merge — anchored on the keep-all 1020 CBNR set
# -----------------------------------------------------------
cbnr <- read_csv(cbnr_csv, show_col_types = FALSE)
server <- read_csv(server_csv, show_col_types = FALSE)
botw   <- read_csv(botw_csv,   show_col_types = FALSE)

# Keep server cols of interest (climate + S1 + S3 direction metrics)
keep_cols <- c("record_id",
  # climate (point + range delta)
  "point_baseline_temp","point_baseline_prec","point_year_temp","point_year_prec",
  "point_temp_delta_from_point_baseline","point_prec_delta_from_point_baseline",
  # S1 (resident+breeding) climate + direction
  "resident_breeding_baseline_temp_mean","resident_breeding_baseline_prec_mean",
  "resident_breeding_range_year_temp_mean","resident_breeding_range_year_prec_mean",
  "resident_breeding_range_temp_delta_from_baseline","resident_breeding_range_prec_delta_from_baseline",
  "point_temp_minus_resident_breeding_baseline","point_prec_minus_resident_breeding_baseline",
  "resident_breeding_bearing_from_centroid_deg","resident_breeding_direction_8",
  "resident_breeding_bearing_from_nearest_edge_deg","resident_breeding_direction_8_from_nearest_edge",
  "resident_breeding_range_centroid_lon","resident_breeding_range_centroid_lat",
  "resident_breeding_nearest_edge_lon","resident_breeding_nearest_edge_lat",
  "resident_breeding_centroid_delta_lon_deg","resident_breeding_centroid_delta_lat_deg",
  "resident_breeding_edge_delta_lon_deg","resident_breeding_edge_delta_lat_deg",
  "resident_breeding_distance_to_range_edge_km","resident_breeding_distance_to_range_centroid_km",
  "resident_breeding_point_inside_historical_range",
  # S3 (all seasons)
  "all_seasons_baseline_temp_mean","all_seasons_baseline_prec_mean",
  "all_seasons_range_year_temp_mean","all_seasons_range_year_prec_mean",
  "all_seasons_range_temp_delta_from_baseline","all_seasons_range_prec_delta_from_baseline",
  "point_temp_minus_all_seasons_baseline","point_prec_minus_all_seasons_baseline",
  "all_seasons_bearing_from_centroid_deg","all_seasons_direction_8",
  "all_seasons_bearing_from_nearest_edge_deg","all_seasons_direction_8_from_nearest_edge",
  "all_seasons_range_centroid_lon","all_seasons_range_centroid_lat",
  "all_seasons_nearest_edge_lon","all_seasons_nearest_edge_lat",
  "all_seasons_centroid_delta_lon_deg","all_seasons_centroid_delta_lat_deg",
  "all_seasons_edge_delta_lon_deg","all_seasons_edge_delta_lat_deg",
  "all_seasons_distance_to_range_edge_km","all_seasons_distance_to_range_centroid_km",
  "all_seasons_point_inside_historical_range"
)
server_sub <- server[, intersect(keep_cols, names(server))]
botw_sub <- botw %>% select(-any_of(c("species","bl_accepted","bl_match_type",
                                         "order","province","year",
                                         "longitude","latitude","year_in_scope")))

merged <- cbnr %>%
  select(record_id, species, order, province, year, year_in_scope,
         longitude, latitude, iucn) %>%
  left_join(server_sub, by = "record_id") %>%
  left_join(botw_sub,   by = "record_id")

write_csv(merged, file.path(data_d, "cbnr_directional_3scenarios_merged.csv"))
cat("Merged rows:", nrow(merged), " | cols:", ncol(merged), "\n")
cat("S1 (R+B) coverage      :", sum(!is.na(merged$resident_breeding_distance_to_range_centroid_km)),
    "/", nrow(merged), "\n")
cat("S2 (BOTW_clean) coverage:", sum(!is.na(merged$bot_distance_to_centroid_km)),
    "/", nrow(merged), "\n")
cat("S3 (all seasons) coverage:", sum(!is.na(merged$all_seasons_distance_to_range_centroid_km)),
    "/", nrow(merged), "\n")

# -----------------------------------------------------------
# 2. Figure builders (style from bird_directional_windrose_radar/)
# -----------------------------------------------------------
dir_levels_full <- c("North","Northeast","East","Southeast",
                      "South","Southwest","West","Northwest")
abbr_to_full <- setNames(dir_levels_full, c("N","NE","E","SE","S","SW","W","NW"))
repo_six <- c("#00bfc4","#be84db","#f8766d","#7ad151","#f1b722","#619cff")
extended_colors <- c("#F29FB7","#F4B183","#C4A46B","#B7C36B","#9DCC8A",
                     "#78C8A0","#5FCFCF","#7FB3FF","#C3A4FF","#E2A9E5")

build_windrose_core <- function(plot_df, color_value, show_axis_labels = TRUE) {
  ymax <- max(plot_df$count, na.rm = TRUE); if (!is.finite(ymax)||ymax<=0) ymax<-1
  ggplot(plot_df, aes(x = direction, y = count, group = 1)) +
    geom_polygon(fill = alpha(color_value, 0.26), color = color_value, linewidth = 0.92) +
    geom_line(color = color_value, linewidth = 0.92) +
    geom_point(color = color_value, size = 2.0) +
    annotate("segment", x = 1:8, xend = 1:8, y = 0, yend = ymax,
             color = "#707070", linewidth = 0.32) +
    scale_y_continuous(limits = c(0, ymax),
                       breaks = c(ymax * 0.5, ymax),
                       labels = function(x) paste0(round(100*x/ymax), "%")) +
    coord_polar(start = -pi/8) +
    labs(x = NULL, y = NULL) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.major = element_line(color = "#79CBE3", linewidth = 0.55, linetype = "22"),
          panel.grid.minor = element_blank(),
          axis.text.y = element_text(size = 7, color = "#6B6B6B"),
          axis.text.x = if (show_axis_labels) element_text(size = 8.5, color = "#222") else element_blank(),
          axis.title = element_blank(),
          plot.background  = element_rect(fill = "white", color = NA),
          panel.background = element_rect(fill = "white", color = NA),
          plot.margin = margin(3, 3, 3, 3))
}
build_strip <- function(title_text) {
  ggplot() +
    annotate("rect", xmin = 0, xmax = 1, ymin = 0, ymax = 1,
             fill = "#D9D9D9", color = "#6B6B6B", linewidth = 0.5) +
    annotate("text", x = 0.5, y = 0.5, label = title_text,
             family = "sans", fontface = "bold", size = 4.1, color = "#222") +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
    theme_void()
}
compose_with_strip <- function(p, t) { build_strip(t) / p + plot_layout(heights = c(0.15, 1)) }

save_plot_bundle <- function(p, stem, w, h, dpi = 600) {
  png_path <- file.path(fig_d, paste0(stem, ".png"))
  pdf_path <- file.path(fig_d, paste0(stem, ".pdf"))
  pptx_path<- file.path(fig_d, paste0(stem, ".pptx"))
  ggsave(png_path, p, width = w, height = h, dpi = dpi, bg = "white")
  ggsave(pdf_path, p, width = w, height = h, device = grDevices::cairo_pdf, bg = "white")
  ok <- FALSE
  rds <- tempfile(fileext = ".rds")
  saveRDS(list(p = p, w = w, h = h, out = pptx_path), rds)
  sub <- system2("Rscript", c("-e", shQuote(sprintf(
    "args <- readRDS('%s'); suppressPackageStartupMessages({library(ggplot2);library(officer);library(rvg)}); ppt<-read_pptx(); ppt<-add_slide(ppt,layout='Blank'); ppt<-ph_with(ppt, dml(ggobj=args$p), location=ph_location(left=0,top=0,width=args$w,height=args$h)); print(ppt, target=args$out); cat('OK\\n')", rds))),
    stdout = TRUE, stderr = TRUE)
  file.remove(rds)
  if (file.exists(pptx_path) && file.info(pptx_path)$size > 1000) ok <- TRUE
  if (!ok) {
    ppt <- read_pptx()
    ppt <- add_slide(ppt, layout = "Blank")
    ppt <- ph_with(ppt, external_img(png_path, width = w, height = h),
                   location = ph_location(left = 0, top = 0, width = w, height = h))
    print(ppt, target = pptx_path)
  }
  message("✓ ", stem, if (ok) " (editable)" else " (raster)")
}

# Build tables for one scenario+reference
build_tables <- function(df, dir_col, inside_col, scenario_label) {
  # Accept both abbreviations ("N","NE",...) and full names ("North","Northeast")
  # 兼容两种方向标签：缩写与全称
  d <- df %>%
    filter(!is.na(.data[[dir_col]])) %>%
    transmute(species, order,
              direction_raw = as.character(.data[[dir_col]]),
              inside = if (is.character(.data[[inside_col]]))
                         .data[[inside_col]] == "TRUE"
                       else as.logical(.data[[inside_col]])) %>%
    mutate(direction = if_else(nchar(direction_raw) <= 2,
                                abbr_to_full[direction_raw],
                                direction_raw)) %>%
    mutate(direction = factor(direction, levels = dir_levels_full)) %>%
    distinct(species, order, direction, inside)
  overall <- d %>% count(direction, name = "count") %>%
    complete(direction = dir_levels_full, fill = list(count = 0)) %>%
    mutate(direction = factor(direction, levels = dir_levels_full)) %>%
    arrange(direction)
  ord_tot <- d %>% count(order, name = "n_total") %>% arrange(desc(n_total))
  ord_cnt <- d %>% count(order, direction, name = "count") %>%
    complete(order, direction = dir_levels_full, fill = list(count = 0)) %>%
    mutate(direction = factor(direction, levels = dir_levels_full)) %>%
    left_join(ord_tot, by = "order") %>%
    mutate(proportion = if_else(n_total > 0, count / n_total, 0)) %>%
    arrange(order, direction)
  list(scenario = scenario_label, d = d, overall = overall,
       ord_totals = ord_tot, ord_counts = ord_cnt)
}

# Per-scenario figure factory
make_scenario_figs <- function(T_obj, ref_label, scen_idx, only_outside = FALSE) {
  scn_lab <- T_obj$scenario
  ymax <- max(T_obj$overall$count) * 1.08; if (ymax < 1) ymax <- 1
  pw <- ggplot(T_obj$overall, aes(x = direction, y = count, group = 1)) +
    geom_polygon(fill = alpha("#4477AA", 0.26), color = "#4477AA", linewidth = 1.0) +
    geom_line(color = "#4477AA", linewidth = 1.0) +
    geom_point(color = "#4477AA", size = 2.3) +
    annotate("segment", x = 1:8, xend = 1:8, y = 0, yend = ymax,
             color = "#707070", linewidth = 0.32) +
    coord_polar(start = -pi/8) +
    scale_y_continuous(limits = c(0, ymax)) +
    labs(x = NULL, y = NULL,
         title = sprintf("Scenario %d — %s · reference = %s",
                          scen_idx, scn_lab, ref_label)) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.major = element_line(color = "#79CBE3", linewidth = 0.55, linetype = "22"),
          panel.grid.minor = element_blank(),
          axis.text.y = element_text(size = 7, color = "#6B6B6B"),
          axis.text.x = element_text(size = 10, face = "bold", color = "#222"),
          plot.title = element_text(face = "bold", size = 11, hjust = 0.5,
                                     margin = margin(b = 6)),
          plot.background = element_rect(fill = "white", color = NA),
          panel.background = element_rect(fill = "white", color = NA))
  ref_slug <- ifelse(ref_label == "centroid", "centroid", "nearest_edge")
  save_plot_bundle(pw, sprintf("scenario%d_overall_windrose_%s", scen_idx, ref_slug),
                   w = 8.6, h = 8.0)
  # radar overlay top-6
  top6 <- T_obj$ord_totals %>% slice_head(n = 6) %>% pull(order)
  if (length(top6) >= 2) {
    rad_in <- T_obj$ord_counts %>%
      filter(order %in% top6) %>%
      mutate(order = factor(order, levels = top6)) %>%
      select(order, direction, proportion) %>%
      pivot_wider(names_from = direction, values_from = proportion, values_fill = 0) %>%
      mutate(across(where(is.numeric), ~ . * 100)) %>%
      rename(group = order) %>%
      select(group, all_of(dir_levels_full))
    pr <- ggradar(rad_in,
                  grid.min = 0, grid.mid = 50, grid.max = 100,
                  values.radar = c("0%","50%","100%"),
                  group.line.width = 1.15, group.point.size = 2.15,
                  background.circle.colour = "#F7FBFD",
                  gridline.mid.colour = "#79CBE3",
                  gridline.max.colour = "#79CBE3",
                  gridline.min.colour = "#79CBE3",
                  axis.label.size = 3.0, grid.label.size = 2.4,
                  legend.position = "right",
                  group.colours = repo_six[seq_along(top6)]) +
      labs(title = sprintf("Scenario %d — order overlay · ref=%s",
                           scen_idx, ref_label)) +
      theme(plot.title = element_text(face = "bold", size = 11, hjust = 0.5))
    save_plot_bundle(pr, sprintf("scenario%d_overall_radar_%s", scen_idx, ref_slug),
                     w = 11.5, h = 8.0)
  }
  # facets
  sel <- T_obj$ord_totals %>% filter(n_total >= 2) %>% slice_head(n = 16) %>% pull(order)
  if (length(sel) >= 1) {
    pal <- c(repo_six, extended_colors)[seq_along(sel)]; names(pal) <- sel
    panels <- lapply(sel, function(ord) {
      df <- T_obj$ord_counts %>% filter(order == ord)
      p <- build_windrose_core(df, color_value = pal[[ord]])
      compose_with_strip(p, sprintf("%s (n=%d)", ord,
                                      T_obj$ord_totals$n_total[T_obj$ord_totals$order == ord]))
    })
    ncols <- min(4, length(panels))
    fw <- wrap_plots(panels, ncol = ncols)
    save_plot_bundle(fw, sprintf("scenario%d_order_windrose_facets_%s", scen_idx, ref_slug),
                     w = 3.6 * ncols, h = 3.7 * ceiling(length(panels) / ncols))
  }
}

# Build per-scenario per-reference tables
scn_specs <- list(
  list(idx = 1, label = "Resident + Breeding (BOTW 2024)",
       cen_dir  = "resident_breeding_direction_8",
       edge_dir = "resident_breeding_direction_8_from_nearest_edge",
       inside   = "resident_breeding_point_inside_historical_range"),
  list(idx = 2, label = "BOTW_clean (user-curated 466 spp)",
       cen_dir  = "bot_direction_8_centroid",
       edge_dir = "bot_direction_8_nearest_edge",
       inside   = "bot_point_inside_range"),
  list(idx = 3, label = "All Seasons (BOTW 2024)",
       cen_dir  = "all_seasons_direction_8",
       edge_dir = "all_seasons_direction_8_from_nearest_edge",
       inside   = "all_seasons_point_inside_historical_range")
)

for (sc in scn_specs) {
  T_cen  <- build_tables(merged, sc$cen_dir,  sc$inside, sc$label)
  # for edge, only use records OUTSIDE polygon
  outside <- merged %>%
    filter(!is.na(.data[[sc$cen_dir]])) %>%
    filter(
      if (is.character(.data[[sc$inside]])) .data[[sc$inside]] != "TRUE"
      else !as.logical(.data[[sc$inside]])
    )
  T_edge <- build_tables(outside, sc$edge_dir, sc$inside, sc$label)
  cat(sprintf("\n[Scenario %d] %s\n  centroid n_species=%d  edge n_species=%d\n",
              sc$idx, sc$label, nrow(T_cen$d), nrow(T_edge$d)))
  make_scenario_figs(T_cen,  "centroid",     sc$idx)
  make_scenario_figs(T_edge, "nearest edge", sc$idx)
}

# -----------------------------------------------------------
# 3. Climate summary table per scenario
# -----------------------------------------------------------
clim_summary <- tibble(
  scenario = c("S1: Resident+Breeding (BOTW2024)",
               "S2: BOTW_clean (user-curated 466 spp)",
               "S3: All Seasons (BOTW2024)"),
  n_records_with_polygon = c(
    sum(!is.na(merged$resident_breeding_distance_to_range_centroid_km)),
    sum(!is.na(merged$bot_distance_to_centroid_km)),
    sum(!is.na(merged$all_seasons_distance_to_range_centroid_km))),
  pct_records = sprintf("%.1f%%", 100 * c(
    sum(!is.na(merged$resident_breeding_distance_to_range_centroid_km)),
    sum(!is.na(merged$bot_distance_to_centroid_km)),
    sum(!is.na(merged$all_seasons_distance_to_range_centroid_km))) / nrow(merged)),
  median_dist_centroid_km = round(c(
    median(merged$resident_breeding_distance_to_range_centroid_km, na.rm = TRUE),
    median(merged$bot_distance_to_centroid_km, na.rm = TRUE),
    median(merged$all_seasons_distance_to_range_centroid_km, na.rm = TRUE))),
  median_dist_edge_km = round(c(
    median(merged$resident_breeding_distance_to_range_edge_km, na.rm = TRUE),
    median(merged$bot_distance_to_nearest_edge_km, na.rm = TRUE),
    median(merged$all_seasons_distance_to_range_edge_km, na.rm = TRUE))),
  pct_inside_range = sprintf("%.1f%%", 100 * c(
    mean(merged$resident_breeding_point_inside_historical_range == "TRUE", na.rm = TRUE),
    mean(merged$bot_point_inside_range == TRUE | merged$bot_point_inside_range == "TRUE", na.rm = TRUE),
    mean(merged$all_seasons_point_inside_historical_range == "TRUE", na.rm = TRUE))),
  mean_point_temp_delta_C = round(c(
    mean(merged$point_temp_delta_from_point_baseline[!is.na(merged$resident_breeding_distance_to_range_centroid_km)], na.rm = TRUE),
    mean(merged$point_temp_delta_from_point_baseline[!is.na(merged$bot_distance_to_centroid_km)], na.rm = TRUE),
    mean(merged$point_temp_delta_from_point_baseline[!is.na(merged$all_seasons_distance_to_range_centroid_km)], na.rm = TRUE)), 3),
  mean_range_temp_delta_C = round(c(
    mean(merged$resident_breeding_range_temp_delta_from_baseline, na.rm = TRUE),
    NA_real_,   # BOTW_clean scenario lacks server-computed range temp delta
    mean(merged$all_seasons_range_temp_delta_from_baseline, na.rm = TRUE)), 3),
  mean_niche_shift_temp_C = round(c(
    mean(merged$point_temp_minus_resident_breeding_baseline, na.rm = TRUE),
    NA_real_,
    mean(merged$point_temp_minus_all_seasons_baseline, na.rm = TRUE)), 3)
)
write_csv(clim_summary, file.path(res_d, "scenario_climate_summary.csv"))
cat("\n=== Scenario climate summary ===\n")
print(clim_summary)
cat("\nDone. Outputs in:\n  ", OUT_DIR, "\n", sep = "")
