#!/usr/bin/env Rscript

# ============================================================
# Server-side editable PPTX for Figure 2 (composite)
# Uses devEMF for maps + rvg::dml for sankey
# ============================================================

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(ggalluvial)
  library(officer)
  library(rvg)
  library(tibble)
  library(scales)
  library(tidyr)
  library(stringr)
  library(devEMF)
})

TASK_ROOT <- "~/projects/bird-new-distribution-records/tasks/cbnr_v3_server_pptx"
DATA_DIR <- file.path(TASK_ROOT, "data")
FIG_DIR  <- file.path(TASK_ROOT, "figures")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

recs <- read_csv(file.path(DATA_DIR, "cbnr_clean_events.csv"), show_col_types = FALSE)
shape_base <- "~/projects/bird-new-distribution-records/tasks/bird_spatiotemporal_patterns/data/shapefile_base"

china_crs <- "+proj=aea +lat_1=25 +lat_2=47 +lat_0=0 +lon_0=105 +ellps=GRS80 +units=m +no_defs"

province_sf_ll   <- st_read(file.path(shape_base, "省.shp"), quiet = TRUE, options = "ENCODING=UTF-8")
province_line_ll <- st_read(file.path(shape_base, "省_境界线.shp"), quiet = TRUE, options = "ENCODING=UTF-8")
ten_dash_ll      <- st_read(file.path(shape_base, "十段线.shp"), quiet = TRUE, options = "ENCODING=UTF-8")

province_sf   <- st_transform(province_sf_ll, china_crs)
province_line <- st_transform(province_line_ll, china_crs)
ten_dash      <- st_transform(ten_dash_ll, china_crs)

province_name_map <- c(
  "北京市"="Beijing","天津市"="Tianjin","河北省"="Hebei","山西省"="Shanxi",
  "内蒙古自治区"="Inner Mongolia","辽宁省"="Liaoning","吉林省"="Jilin",
  "黑龙江省"="Heilongjiang","上海市"="Shanghai","江苏省"="Jiangsu",
  "浙江省"="Zhejiang","安徽省"="Anhui","福建省"="Fujian","江西省"="Jiangxi",
  "山东省"="Shandong","河南省"="Henan","湖北省"="Hubei","湖南省"="Hunan",
  "广东省"="Guangdong","广西壮族自治区"="Guangxi","海南省"="Hainan",
  "重庆市"="Chongqing","四川省"="Sichuan","贵州省"="Guizhou","云南省"="Yunnan",
  "西藏自治区"="Tibet","陕西省"="Shaanxi","甘肃省"="Gansu","青海省"="Qinghai",
  "宁夏回族自治区"="Ningxia","新疆维吾尔自治区"="Xinjiang","台湾省"="Taiwan",
  "香港特别行政区"="Hong Kong","澳门特别行政区"="Macao"
)
province_sf$province_std <- province_name_map[province_sf$省名]
province_sf$province_std[is.na(province_sf$province_std)] <- province_sf$省名[is.na(province_sf$province_std)]

prov_counts <- recs %>% filter(!is.na(province)) %>% count(province, name = "count")
prov_counts$count_class <- cut(prov_counts$count,
  breaks = c(-Inf, 10, 20, 30, 40, 50, 60, Inf),
  labels = c("0 - 10","11 - 20","21 - 30","31 - 40","41 - 50","51 - 60","61 - 71")
)
province_map_sf <- province_sf %>% left_join(prov_counts, by = c("province_std" = "province"))
province_map_sf$count_class[is.na(province_map_sf$count_class)] <- "0 - 10"

recs_xy <- recs %>% filter(!is.na(longitude), !is.na(latitude)) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>%
  st_transform(china_crs) %>%
  mutate(x = st_coordinates(.)[,1], y = st_coordinates(.)[,2]) %>%
  st_drop_geometry()

top5 <- recs_xy %>% count(order, sort = TRUE) %>% slice_head(n = 5) %>% pull(order)
recs_xy$order_group <- ifelse(recs_xy$order %in% top5, recs_xy$order, "Others")

sf_to_polygon_df <- function(sf_obj, keep_cols = character()) {
  obj <- st_cast(sf_obj, "MULTIPOLYGON", warn = FALSE)
  coords <- as_tibble(st_coordinates(obj))
  attrs <- st_drop_geometry(obj)
  coords <- coords %>% mutate(feature_id = L3, piece_id = paste(L3, L2, L1, sep = "_"))
  bind_cols(coords, attrs[coords$feature_id, keep_cols, drop = FALSE])
}
sf_to_path_df <- function(sf_obj, keep_cols = character()) {
  obj <- st_cast(sf_obj, "MULTILINESTRING", warn = FALSE)
  coords <- as_tibble(st_coordinates(obj))
  attrs <- st_drop_geometry(obj)
  coords <- coords %>% mutate(feature_id = L2, piece_id = paste(L2, L1, sep = "_"))
  bind_cols(coords, attrs[coords$feature_id, keep_cols, drop = FALSE])
}

main_bbox <- st_bbox(province_sf)
main_xlim <- c(main_bbox["xmin"] - 760000, main_bbox["xmax"] + 560000)
main_ylim <- c(main_bbox["ymin"] + 840000, main_bbox["ymax"] + 140000)

build_bbox_from_longlat <- function(xmin, xmax, ymin, ymax, target_crs) {
  bbox_ll <- st_as_sfc(st_bbox(c(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), crs = st_crs(4326)))
  st_bbox(st_transform(bbox_ll, target_crs))
}
inset_bbox <- build_bbox_from_longlat(104, 125, 2, 26, china_crs)

ten_dash_main_bbox <- c(
  xmin = unname(as.numeric(main_xlim[1])),
  xmax = unname(as.numeric(main_xlim[2])),
  ymin = unname(as.numeric(main_ylim[1])),
  ymax = unname(as.numeric(main_ylim[1] + diff(main_ylim) * 0.18))
)
ten_dash_main_sf <- st_crop(ten_dash, ten_dash_main_bbox)

province_poly_df    <- sf_to_polygon_df(province_map_sf, keep_cols = "count_class")
province_line_df    <- sf_to_path_df(province_line)
ten_dash_main_df    <- sf_to_path_df(ten_dash_main_sf)
count_inset_poly_df <- sf_to_polygon_df(st_crop(province_map_sf, inset_bbox), keep_cols = "count_class")
count_inset_line_df <- sf_to_path_df(st_crop(province_line, inset_bbox))
count_inset_dash_df <- sf_to_path_df(st_crop(ten_dash, inset_bbox))
point_main_poly_df  <- sf_to_polygon_df(province_sf)
point_inset_poly_df <- sf_to_polygon_df(st_crop(province_sf, inset_bbox))
point_inset_line_df <- sf_to_path_df(st_crop(province_line, inset_bbox))
point_inset_dash_df <- sf_to_path_df(st_crop(ten_dash, inset_bbox))

point_inset_df <- recs_xy %>% filter(
  x >= inset_bbox["xmin"], x <= inset_bbox["xmax"],
  y >= inset_bbox["ymin"], y <= inset_bbox["ymax"]
)

count_fill_values <- c(
  "0 - 10" = "#3494C7", "11 - 20" = "#84B3B1", "21 - 30" = "#C4D88B",
  "31 - 40" = "#FFF95C", "41 - 50" = "#FDB84A",
  "51 - 60" = "#FF6D2D", "61 - 71" = "#F11313"
)
point_map_palette <- c(
  "Passeriformes" = "#54FF19", "Charadriiformes" = "#FFB31A", "Anseriformes" = "#38C8FF",
  "Accipitriformes" = "#FF1C1C", "Pelecaniformes" = "#C925FF", "Others" = "#111111"
)
point_map_shapes <- c(
  "Passeriformes" = 16, "Charadriiformes" = 15, "Anseriformes" = 17,
  "Accipitriformes" = 18, "Pelecaniformes" = 8, "Others" = 16
)

add_north_arrow_projected <- function(plot_obj, xlim, ylim, scale_x = 0.018, scale_y = 0.040) {
  xr <- diff(xlim); yr <- diff(ylim)
  x <- xlim[2] - xr * 0.055; y <- ylim[2] - yr * 0.085
  dx <- xr * scale_x; dy <- yr * scale_y
  plot_obj +
    annotate("text", x = x, y = y + dy * 1.14, label = "N", size = 8.2, family = "sans") +
    annotate("polygon",
      x = c(x, x - dx * 0.55, x, x + dx * 0.55),
      y = c(y + dy * 0.78, y - dy * 0.95, y - dy * 0.02, y - dy * 0.95),
      fill = "black", color = "black", linewidth = 0.26) +
    annotate("polygon",
      x = c(x, x - dx * 0.17, x, x + dx * 0.17),
      y = c(y + dy * 0.49, y - dy * 0.62, y + dy * 0.02, y - dy * 0.62),
      fill = "white", color = "white") +
    annotate("segment", x = x, xend = x, y = y - dy * 0.01, yend = y + dy * 0.53,
             linewidth = 0.15, color = "white")
}

map_theme <- function() {
  theme_void(base_family = "sans") +
    theme(plot.background = element_rect(fill = "white", color = NA),
          panel.background = element_rect(fill = "white", color = NA),
          panel.border = element_rect(fill = NA, color = "black", linewidth = 0.75),
          legend.position = c(0.022, 0.018), legend.justification = c(0, 0),
          legend.background = element_rect(fill = alpha("white", 0.9), color = NA),
          legend.title = element_text(size = 14.5, face = "bold"),
          legend.text = element_text(size = 12.4),
          legend.key.width = unit(1.2, "cm"), legend.key.height = unit(0.60, "cm"),
          plot.margin = margin(8, 8, 8, 8))
}
point_map_theme <- function() {
  theme_void(base_family = "sans") +
    theme(plot.background = element_rect(fill = "white", color = NA),
          panel.background = element_rect(fill = "white", color = NA),
          panel.border = element_rect(fill = NA, color = "black", linewidth = 0.75),
          legend.position = c(0.021, 0.016), legend.justification = c(0, 0),
          legend.background = element_rect(fill = alpha("white", 0.92), color = NA),
          legend.title = element_text(size = 15.5, face = "bold"),
          legend.text = element_text(size = 15.0),
          legend.key.height = unit(0.68, "cm"), legend.key.width = unit(0.95, "cm"),
          plot.margin = margin(8, 8, 8, 8))
}

count_map_main <- ggplot() +
  geom_polygon(data = province_poly_df,
    aes(x = X, y = Y, group = piece_id, fill = count_class),
    color = "#9A9A9A", linewidth = 0.24) +
  geom_path(data = province_line_df,
    aes(x = X, y = Y, group = piece_id),
    color = "#777777", linewidth = 0.20, lineend = "round") +
  geom_path(data = ten_dash_main_df,
    aes(x = X, y = Y, group = piece_id),
    color = "#272727", linewidth = 0.22, lineend = "round") +
  scale_fill_manual(values = count_fill_values, drop = FALSE, name = "Number of new records") +
  coord_equal(xlim = main_xlim, ylim = main_ylim, expand = FALSE) +
  map_theme()
count_map_main <- add_north_arrow_projected(count_map_main, main_xlim, main_ylim)

count_map_inset <- ggplot() +
  geom_polygon(data = count_inset_poly_df,
    aes(x = X, y = Y, group = piece_id, fill = count_class),
    color = "#8A8A8A", linewidth = 0.18) +
  geom_path(data = count_inset_line_df,
    aes(x = X, y = Y, group = piece_id),
    color = "#777777", linewidth = 0.18, lineend = "round") +
  geom_path(data = count_inset_dash_df,
    aes(x = X, y = Y, group = piece_id),
    color = "#272727", linewidth = 0.24, lineend = "round") +
  scale_fill_manual(values = count_fill_values, drop = FALSE, guide = "none") +
  coord_equal(xlim = c(inset_bbox["xmin"], inset_bbox["xmax"]),
              ylim = c(inset_bbox["ymin"], inset_bbox["ymax"]), expand = FALSE) +
  theme_void() +
  theme(panel.border = element_rect(color = "black", fill = NA, linewidth = 0.7))

point_map_main <- ggplot() +
  geom_polygon(data = point_main_poly_df,
    aes(x = X, y = Y, group = piece_id),
    fill = "white", color = "#8C8C8C", linewidth = 0.26) +
  geom_path(data = province_line_df,
    aes(x = X, y = Y, group = piece_id),
    color = "#5A5A5A", linewidth = 0.36, lineend = "round") +
  geom_path(data = ten_dash_main_df,
    aes(x = X, y = Y, group = piece_id),
    color = "#4A4A4A", linewidth = 0.28, lineend = "round") +
  geom_point(data = recs_xy,
    aes(x = x, y = y, color = order_group, shape = order_group),
    size = 2.85, stroke = 0.22, alpha = 0.95) +
  scale_color_manual(values = point_map_palette, name = "New records across orders") +
  scale_shape_manual(values = point_map_shapes, name = "New records across orders") +
  coord_equal(xlim = main_xlim, ylim = main_ylim, expand = FALSE) +
  point_map_theme() +
  guides(color = guide_legend(override.aes = list(size = 4.2, alpha = 1)), shape = "none")
point_map_main <- add_north_arrow_projected(point_map_main, main_xlim, main_ylim)

point_map_inset <- ggplot() +
  geom_polygon(data = point_inset_poly_df,
    aes(x = X, y = Y, group = piece_id),
    fill = "white", color = "#B8B8B8", linewidth = 0.18) +
  geom_path(data = point_inset_line_df,
    aes(x = X, y = Y, group = piece_id),
    color = "#6A6A6A", linewidth = 0.22, lineend = "round") +
  geom_path(data = point_inset_dash_df,
    aes(x = X, y = Y, group = piece_id),
    color = "#222222", linewidth = 0.28, lineend = "round") +
  geom_point(data = point_inset_df,
    aes(x = x, y = y, color = order_group, shape = order_group),
    size = 1.8, stroke = 0.18, alpha = 0.92, show.legend = FALSE) +
  scale_color_manual(values = point_map_palette, guide = "none") +
  scale_shape_manual(values = point_map_shapes, guide = "none") +
  coord_equal(xlim = c(inset_bbox["xmin"], inset_bbox["xmax"]),
              ylim = c(inset_bbox["ymin"], inset_bbox["ymax"]), expand = FALSE) +
  theme_void() +
  theme(panel.border = element_rect(color = "black", fill = NA, linewidth = 0.7))

# Sankey
n_collapse <- 5
ord_full <- recs %>% count(order, name = "n") %>% arrange(desc(n))
keep_orders <- ord_full$order[seq_len(max(1, nrow(ord_full) - n_collapse))]
sankey_recs <- recs %>%
  transmute(species, order = ifelse(order %in% keep_orders, order, "Others"), province, year = as.integer(year)) %>%
  filter(!is.na(species), !is.na(order), !is.na(province), !is.na(year)) %>%
  distinct(species, order, province, year)
ord_lvl  <- c(keep_orders, "Others")
prov_lvl <- sankey_recs %>% count(province, sort = TRUE) %>% pull(province)
yr_lvl   <- sort(unique(sankey_recs$year))
sankey_df <- sankey_recs %>%
  count(order, province, year, name = "n_records") %>%
  mutate(order = factor(order, levels = ord_lvl),
         province = factor(province, levels = prov_lvl),
         year = factor(year, levels = yr_lvl))

base_palette <- c(
  "Passeriformes" = "#8FA8D6", "Charadriiformes" = "#F28E5B", "Anseriformes" = "#67C1B3",
  "Accipitriformes" = "#E78AC3", "Pelecaniformes" = "#8BC34A", "Gruiformes" = "#D9B26F",
  "Columbiformes" = "#9E9E9E", "Galliformes" = "#F1C40F", "Strigiformes" = "#B497D6",
  "Coraciiformes" = "#6FA8DC", "Phoenicopteriformes" = "#FF7043", "Suliformes" = "#26C6DA",
  "Cuculiformes" = "#7E57C2", "Piciformes" = "#26A69A", "Procellariiformes" = "#5D4037",
  "Caprimulgiformes" = "#9CCC65", "Ciconiiformes" = "#EF5350", "Gaviiformes" = "#42A5F5",
  "Podicipediformes" = "#AB47BC", "Falconiformes" = "#FFB300", "Pterocliformes" = "#8D6E63",
  "Trogoniformes" = "#789262", "Otidiformes" = "#A1887F", "Others" = "#BDBDBD"
)
extra <- setdiff(ord_lvl, names(base_palette))
if (length(extra)) base_palette <- c(base_palette, setNames(grDevices::hcl.colors(length(extra), "Set 3"), extra))
sankey_palette <- base_palette[ord_lvl]

p_sankey <- ggplot(sankey_df,
       aes(axis1 = order, axis2 = province, axis3 = year, y = n_records)) +
  geom_alluvium(aes(fill = order), width = 0.18, alpha = 0.70, knot.pos = 0.42) +
  geom_stratum(width = 0.18, fill = "#E9E9E9", color = "#707070", linewidth = 0.42) +
  geom_text(stat = "stratum", aes(label = after_stat(stratum)),
            size = 2.7, lineheight = 0.85, family = "sans") +
  scale_fill_manual(values = sankey_palette, guide = "none") +
  scale_x_discrete(limits = c("Order", "Province", "Year"), expand = c(0.008, 0.008)) +
  labs(x = NULL, y = "Number of records") +
  theme_minimal(base_size = 11, base_family = "sans") +
  theme(axis.text.x = element_text(face = "bold", size = 12.5, color = "#303030", margin = margin(t = 1)),
        axis.text.y = element_blank(), axis.ticks = element_blank(),
        axis.title = element_text(face = "bold", size = 12.5),
        panel.grid = element_blank(), plot.margin = margin(6, 8, 4, 8))

# ---- Save map components as EMF ----
slide_w <- 13.6
half_w  <- (slide_w - 0.15) / 2
gap_in  <- 0.15
top_h   <- 5.4
bot_h   <- 6.8
slide_h <- top_h + gap_in + bot_h

inset_w <- half_w * 0.155
inset_h <- top_h * 0.235
inset_a_left <- half_w - inset_w - 0.02
inset_b_left <- slide_w - inset_w - 0.02
inset_top    <- top_h - inset_h - 0.02

cat("Saving map EMFs...\n")
emf_a_main  <- file.path(FIG_DIR, "fig2_a_main.emf")
emf_a_inset <- file.path(FIG_DIR, "fig2_a_inset.emf")
emf_b_main  <- file.path(FIG_DIR, "fig2_b_main.emf")
emf_b_inset <- file.path(FIG_DIR, "fig2_b_inset.emf")

emf(emf_a_main,  width = half_w, height = top_h)
print(point_map_main)
dev.off()

emf(emf_a_inset, width = inset_w, height = inset_h)
print(point_map_inset)
dev.off()

emf(emf_b_main,  width = half_w, height = top_h)
print(count_map_main)
dev.off()

emf(emf_b_inset, width = inset_w, height = inset_h)
print(count_map_inset)
dev.off()

cat("Building composite PPTX...\n")
ppt <- read_pptx()
ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
prs <- ppt
prs$slide_size$cx <- slide_w * 914400
prs$slide_size$cy <- slide_h * 914400

ppt <- ph_with(ppt, external_img(emf_a_main, width = half_w, height = top_h),
               location = ph_location(left = 0, top = 0, width = half_w, height = top_h))
ppt <- ph_with(ppt, external_img(emf_a_inset, width = inset_w, height = inset_h),
               location = ph_location(left = inset_a_left, top = inset_top,
                                       width = inset_w, height = inset_h))
ppt <- ph_with(ppt, external_img(emf_b_main, width = half_w, height = top_h),
               location = ph_location(left = half_w + gap_in, top = 0,
                                       width = half_w, height = top_h))
ppt <- ph_with(ppt, external_img(emf_b_inset, width = inset_w, height = inset_h),
               location = ph_location(left = inset_b_left, top = inset_top,
                                       width = inset_w, height = inset_h))

add_label <- function(ppt, text, x, y) {
  ph_with(ppt,
    fpar(ftext(text, fp_text(font.size = 16, bold = TRUE, color = "#222222"))),
    location = ph_location(left = x, top = y, width = 0.5, height = 0.3))
}
ppt <- add_label(ppt, "(a)", 0.06, 0.06)
ppt <- add_label(ppt, "(b)", half_w + gap_in + 0.06, 0.06)
ppt <- add_label(ppt, "(c)", 0.06, top_h + gap_in + 0.05)

ppt <- ph_with(ppt, dml(ggobj = p_sankey, bg = "white"),
               location = ph_location(left = 0, top = top_h + gap_in,
                                       width = slide_w, height = bot_h))

out_path <- file.path(FIG_DIR, "figure2_composite_editable_server.pptx")
print(ppt, target = out_path)
cat("✓ Fig 2 editable PPTX saved to:", out_path, "\n")
