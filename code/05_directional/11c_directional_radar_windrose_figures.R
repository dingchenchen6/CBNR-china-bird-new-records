#!/usr/bin/env Rscript

# ============================================================
# Directional radar + windrose figures (v3) — based on CBNR x BirdLife
# CBNR × BirdLife 范围多边形方向性 — 雷达 + 风玫瑰图
# ============================================================
#
# Reproduces the visual style of bird_directional_windrose_radar/
# but using the new server-computed per-record directional metrics
# (centroid-based and nearest-edge-based) over the keep-all-years
# CBNR analytical release.
# 严格复刻 bird_directional_windrose_radar/ 的雷达 + 风玫瑰图风格，
# 但数据来自服务端基于 BirdLife 范围多边形重新计算的方向指标
# （含中心方位 + 最近边缘方位），覆盖 keep-all-years CBNR 数据集。
#
# Output / 输出
#   ../directional_v3/figures/
#     overall_direction_radar_centroid.{png,pdf,pptx}
#     overall_direction_windrose_centroid.{png,pdf,pptx}
#     overall_direction_radar_nearest_edge.{png,pdf,pptx}
#     overall_direction_windrose_nearest_edge.{png,pdf,pptx}
#     order_direction_windrose_facets_centroid.{png,pdf,pptx}
#     order_direction_windrose_facets_nearest_edge.{png,pdf,pptx}
#     order_direction_radar_facets_centroid.{png,pdf,pptx}
#   ../directional_v3/data/  (per-order tables)
#   ../directional_v3/results/  (run log)
# ============================================================

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(stringr)
  library(forcats); library(tibble); library(ggplot2); library(scales)
  library(patchwork); library(ggradar); library(officer); library(rvg)
})

# ------- Paths -------
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
code_dir  <- if (dir.exists(HERE)) HERE else dirname(HERE)
TASK_ROOT <- normalizePath(file.path(code_dir, ".."))
DIRV3 <- file.path(TASK_ROOT, "directional_v3")
fig_d   <- file.path(DIRV3, "figures");  dir.create(fig_d, FALSE, TRUE)
data_d  <- file.path(DIRV3, "data");     dir.create(data_d, FALSE, TRUE)
res_d   <- file.path(DIRV3, "results");  dir.create(res_d,  FALSE, TRUE)

metrics <- read_csv(file.path(data_d, "cbnr_directional_metrics_per_record.csv"),
                     show_col_types = FALSE)

# ------- Style constants from original script -------
direction_levels_full <- c("North","Northeast","East","Southeast",
                            "South","Southwest","West","Northwest")
abbr_to_full <- setNames(direction_levels_full,
                          c("N","NE","E","SE","S","SW","W","NW"))
repo_six_colors <- c("#00bfc4","#be84db","#f8766d","#7ad151","#f1b722","#619cff")
extended_colors <- c("#F29FB7","#F4B183","#C4A46B","#B7C36B","#9DCC8A",
                     "#78C8A0","#5FCFCF","#7FB3FF","#C3A4FF","#E2A9E5")

# ------- Helper plot builders (verbatim style from original) -------
build_windrose_core <- function(plot_df, color_value, show_axis_labels = TRUE) {
  ymax <- max(plot_df$count, na.rm = TRUE)
  if (!is.finite(ymax) || ymax <= 0) ymax <- 1
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

build_header_strip <- function(title_text) {
  ggplot() +
    annotate("rect", xmin = 0, xmax = 1, ymin = 0, ymax = 1,
             fill = "#D9D9D9", color = "#6B6B6B", linewidth = 0.5) +
    annotate("text", x = 0.5, y = 0.5, label = title_text,
             family = "sans", fontface = "bold", size = 4.1, color = "#222") +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
    theme_void()
}
compose_with_strip <- function(p, title_text, strip_height = 0.12) {
  build_header_strip(title_text) / p + plot_layout(heights = c(strip_height, 1))
}

# ------- Save helper: PNG + PDF + (editable PPTX via subprocess fallback) -------
save_plot_bundle <- function(p, stem, width, height, dpi = 600,
                              pptx_mode = c("editable","raster")) {
  pptx_mode <- match.arg(pptx_mode)
  png_path <- file.path(fig_d, paste0(stem, ".png"))
  pdf_path <- file.path(fig_d, paste0(stem, ".pdf"))
  pptx_path<- file.path(fig_d, paste0(stem, ".pptx"))
  ggsave(png_path, p, width = width, height = height, dpi = dpi, bg = "white")
  ggsave(pdf_path, p, width = width, height = height,
         device = grDevices::cairo_pdf, bg = "white")
  ok <- FALSE
  if (pptx_mode == "editable") {
    rds <- tempfile(fileext = ".rds")
    saveRDS(list(p = p, w = width, h = height, out = pptx_path), rds)
    sub <- system2("Rscript", c("-e", shQuote(sprintf(
      "args <- readRDS('%s'); suppressPackageStartupMessages({library(ggplot2);library(officer);library(rvg)}); ppt <- read_pptx(); ppt <- add_slide(ppt, layout='Blank'); ppt <- ph_with(ppt, dml(ggobj=args$p), location=ph_location(left=0,top=0,width=args$w,height=args$h)); print(ppt, target=args$out); cat('OK\\n')", rds))),
      stdout = TRUE, stderr = TRUE)
    file.remove(rds)
    if (file.exists(pptx_path) && file.info(pptx_path)$size > 1000) ok <- TRUE
  }
  if (!ok) {
    ppt <- read_pptx()
    ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
    ppt <- ph_with(ppt, external_img(png_path, width = width, height = height),
                   location = ph_location(left = 0, top = 0, width = width, height = height))
    print(ppt, target = pptx_path)
  }
  message("✓ ", stem, if (ok) " -> PNG + PDF + editable PPTX" else " -> PNG + PDF + raster PPTX")
}

# ------- Build directional tables for both references -------
# Filter to records that have a BirdLife polygon (396 records)
with_poly <- metrics %>% filter(has_range_polygon, !is.na(direction_8_centroid))
cat("Records with BirdLife range polygon:", nrow(with_poly), "\n")
cat("Records outside polygon:", sum(!with_poly$point_inside_range, na.rm = TRUE), "\n")

build_dir_tables <- function(df, dir_col, scope_label) {
  d <- df %>%
    transmute(species = bl_accepted, order, direction_abbr = .data[[dir_col]]) %>%
    filter(!is.na(direction_abbr)) %>%
    mutate(direction = factor(abbr_to_full[direction_abbr], levels = direction_levels_full)) %>%
    distinct(species, order, direction)

  overall <- d %>% count(direction, name = "count") %>%
    complete(direction = direction_levels_full, fill = list(count = 0)) %>%
    mutate(direction = factor(direction, levels = direction_levels_full),
           proportion = count / pmax(sum(count), 1))

  ord_totals <- d %>% count(order, name = "n_total") %>% arrange(desc(n_total))
  ord_counts <- d %>% count(order, direction, name = "count") %>%
    complete(order, direction = direction_levels_full, fill = list(count = 0)) %>%
    left_join(ord_totals, by = "order") %>%
    mutate(direction = factor(direction, levels = direction_levels_full),
           proportion = if_else(n_total > 0, count / n_total, 0))

  list(scope = scope_label, sp = d, overall = overall,
       ord_counts = ord_counts, ord_totals = ord_totals)
}

T_cen  <- build_dir_tables(with_poly,                                 "direction_8_centroid",     "centroid")
# For nearest-edge, use only records OUTSIDE the polygon (otherwise edge direction is degenerate)
outside_poly <- with_poly %>% filter(!isTRUE(point_inside_range) | point_inside_range == FALSE)
T_edge <- build_dir_tables(outside_poly %>% filter(!is.na(direction_8_nearest_edge)),
                            "direction_8_nearest_edge", "nearest_edge")

write_csv(T_cen$overall,     file.path(data_d, "direction_overall_counts_centroid.csv"))
write_csv(T_edge$overall,    file.path(data_d, "direction_overall_counts_nearest_edge.csv"))
write_csv(T_cen$ord_counts,  file.path(data_d, "direction_order_counts_centroid.csv"))
write_csv(T_edge$ord_counts, file.path(data_d, "direction_order_counts_nearest_edge.csv"))

# ------- Build figures for each reference -------
build_overall_figs <- function(T_obj, stem_suffix) {
  scope_label <- T_obj$scope
  ymax <- max(T_obj$overall$count) * 1.08
  if (ymax < 1) ymax <- 1

  # overall single-color windrose
  p_w <- ggplot(T_obj$overall, aes(x = direction, y = count, group = 1)) +
    geom_polygon(fill = alpha("#4477AA", 0.26), color = "#4477AA", linewidth = 1.0) +
    geom_line(color = "#4477AA", linewidth = 1.0) +
    geom_point(color = "#4477AA", size = 2.3) +
    annotate("segment", x = 1:8, xend = 1:8, y = 0, yend = ymax,
             color = "#707070", linewidth = 0.32) +
    scale_y_continuous(limits = c(0, ymax),
                       breaks = c(ymax * 0.5, ymax),
                       labels = function(x) paste0(round(x), "")) +
    coord_polar(start = -pi/8) +
    labs(x = NULL, y = NULL,
         title = paste0("New-record directional distribution — relative to ",
                         scope_label, " of BirdLife range")) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.major = element_line(color = "#79CBE3", linewidth = 0.55, linetype = "22"),
          panel.grid.minor = element_blank(),
          axis.text.y = element_text(size = 7, color = "#6B6B6B"),
          axis.text.x = element_text(size = 10, face = "bold", color = "#222"),
          axis.title = element_blank(),
          plot.title = element_text(face = "bold", size = 11, hjust = 0.5,
                                     margin = margin(b = 6)),
          plot.background  = element_rect(fill = "white", color = NA),
          panel.background = element_rect(fill = "white", color = NA),
          plot.margin = margin(6, 6, 6, 6))
  save_plot_bundle(p_w, paste0("overall_direction_windrose_", stem_suffix),
                   width = 8.6, height = 8.0)

  # overall radar overlay across top 6 orders
  top6 <- T_obj$ord_totals %>% slice_head(n = 6) %>% pull(order)
  rad_in <- T_obj$ord_counts %>%
    filter(order %in% top6) %>%
    mutate(order = factor(order, levels = top6)) %>%
    select(order, direction, proportion) %>%
    pivot_wider(names_from = direction, values_from = proportion, values_fill = 0) %>%
    mutate(across(where(is.numeric), ~ . * 100)) %>%
    rename(group = order) %>%
    select(group, all_of(direction_levels_full))

  p_r <- ggradar(rad_in,
                  grid.min = 0, grid.mid = 50, grid.max = 100,
                  values.radar = c("0%", "50%", "100%"),
                  group.line.width = 1.15, group.point.size = 2.15,
                  background.circle.colour = "#F7FBFD",
                  gridline.mid.colour = "#79CBE3",
                  gridline.max.colour = "#79CBE3",
                  gridline.min.colour = "#79CBE3",
                  axis.label.size = 3.0, grid.label.size = 2.4,
                  legend.position = "right",
                  group.colours = repo_six_colors[seq_along(top6)]) +
    labs(title = paste0("Order-level overlay — relative to ", scope_label,
                         " of BirdLife range")) +
    theme(plot.background  = element_rect(fill = "white", color = NA),
          panel.background = element_rect(fill = "white", color = NA),
          plot.title = element_text(face = "bold", size = 11, hjust = 0.5),
          plot.margin = margin(6, 6, 6, 6))
  save_plot_bundle(p_r, paste0("overall_direction_radar_", stem_suffix),
                   width = 11.5, height = 8.0)
}
build_overall_figs(T_cen,  "centroid")
build_overall_figs(T_edge, "nearest_edge")

# ------- Per-order facet panels (windrose 4x4 + radar 4x4) -------
build_facet_panels <- function(T_obj, stem_suffix, n_panels = 16) {
  sel <- T_obj$ord_totals %>%
    filter(n_total >= 2) %>%
    slice_head(n = n_panels) %>%
    pull(order)
  if (length(sel) < 1) return(invisible())
  pal <- c(repo_six_colors, extended_colors)[seq_along(sel)]
  names(pal) <- sel

  # Windrose facets
  windrose_panels <- lapply(sel, function(ord) {
    df <- T_obj$ord_counts %>% filter(order == ord)
    p <- build_windrose_core(df, color_value = pal[[ord]])
    compose_with_strip(p,
                       sprintf("%s (n=%d)", ord, T_obj$ord_totals$n_total[T_obj$ord_totals$order == ord]),
                       strip_height = 0.15)
  })
  ncol_panels <- min(4, length(windrose_panels))
  fig_w <- wrap_plots(windrose_panels, ncol = ncol_panels)
  save_plot_bundle(fig_w,
                   paste0("order_direction_windrose_facets_", stem_suffix),
                   width = 3.6 * ncol_panels,
                   height = 3.7 * ceiling(length(windrose_panels) / ncol_panels))
}
build_facet_panels(T_cen,  "centroid",      n_panels = 16)
build_facet_panels(T_edge, "nearest_edge",  n_panels = 16)

writeLines(c(
  "# Directional figures v3 run log",
  paste("- records with polygon:", nrow(with_poly)),
  paste("- records outside polygon:", nrow(outside_poly)),
  paste("- distinct species (centroid):", n_distinct(T_cen$sp$species)),
  paste("- distinct species (edge, outside):", n_distinct(T_edge$sp$species)),
  paste("- orders with ≥2 records (centroid):",
        sum(T_cen$ord_totals$n_total >= 2)),
  paste("- orders with ≥2 records (edge):",
        sum(T_edge$ord_totals$n_total >= 2))
), file.path(res_d, "directional_v3_run_log.md"))

cat("\nDone. Outputs in: ", fig_d, "\n", sep = "")
