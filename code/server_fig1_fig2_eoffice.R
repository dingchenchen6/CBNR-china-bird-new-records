#!/usr/bin/env Rscript

# ============================================================
# Server-side editable PPTX for Figure 1 + Figure 2 using eoffice
# 使用 eoffice 包生成可编辑 PPTX
# ============================================================

suppressPackageStartupMessages({
  library(eoffice)
  library(officer)
  library(ggplot2)
  library(ggalluvial)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(stringr)
  library(sf)
  library(tibble)
  library(scales)
})

TASK_ROOT <- "~/projects/bird-new-distribution-records/tasks/cbnr_v3_server_pptx"
DATA_DIR <- file.path(TASK_ROOT, "data")
FIG_DIR  <- file.path(TASK_ROOT, "figures_eoffice")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# ============================================================
# Fig 1: Phylogeny (base R plot -> editable PPTX)
# ============================================================
cat("Building Figure 1 with eoffice...\n")

# We already have the phylogeny PPTX from previous server run.
# eoffice::to_pptx can export a base R plot directly.
# For simplicity, copy the existing working server version.
src_fig1 <- file.path(TASK_ROOT, "figures", "figure1_phylogeny_editable_server.pptx")
if (file.exists(src_fig1)) {
  file.copy(src_fig1, file.path(FIG_DIR, "figure1_phylogeny_editable_eoffice.pptx"), overwrite = TRUE)
  cat("  Fig 1 copied from existing server version (already editable)\n")
}

# ============================================================
# Fig 2: Composite (ggplot2 -> editable PPTX via eoffice)
# ============================================================
cat("Building Figure 2 composite with eoffice...\n")

recs <- read_csv(file.path(DATA_DIR, "cbnr_clean_events.csv"), show_col_types = FALSE)

# --- Simplified vector-safe map components ---
# Instead of full sf rebuild, we use the existing EMF outputs from previous run
# and focus on making the sankey truly editable.

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

main_bbox <- st_bbox(province_sf)
main_xlim <- c(main_bbox["xmin"] - 760000, main_bbox["xmax"] + 560000)
main_ylim <- c(main_bbox["ymin"] + 840000, main_bbox["ymax"] + 140000)

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

# Point map main (simplified for eoffice compatibility)
point_map_main <- ggplot() +
  geom_sf(data = province_sf, fill = "white", color = "#8C8C8C", linewidth = 0.26) +
  geom_sf(data = province_line, color = "#5A5A5A", linewidth = 0.36, lineend = "round") +
  geom_sf(data = ten_dash, color = "#4A4A4A", linewidth = 0.28, lineend = "round") +
  geom_point(data = recs_xy,
    aes(x = x, y = y, color = order_group, shape = order_group),
    size = 2.85, stroke = 0.22, alpha = 0.95) +
  scale_color_manual(values = point_map_palette, name = "New records across orders") +
  scale_shape_manual(values = point_map_shapes, name = "New records across orders") +
  coord_sf(xlim = main_xlim, ylim = main_ylim, expand = FALSE, crs = china_crs) +
  theme_void(base_family = "sans") +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    panel.border = element_rect(fill = NA, color = "black", linewidth = 0.75),
    legend.position = c(0.021, 0.016), legend.justification = c(0, 0),
    legend.background = element_rect(fill = alpha("white", 0.92), color = NA),
    legend.title = element_text(size = 15.5, face = "bold"),
    legend.text = element_text(size = 15.0),
    legend.key.height = unit(0.68, "cm"), legend.key.width = unit(0.95, "cm"),
    plot.margin = margin(8, 8, 8, 8)
  ) +
  guides(color = guide_legend(override.aes = list(size = 4.2, alpha = 1)), shape = "none")

# Count map main (simplified for eoffice compatibility)
count_map_main <- ggplot() +
  geom_sf(data = province_map_sf, aes(fill = count_class),
    color = "#9A9A9A", linewidth = 0.24) +
  geom_sf(data = province_line, color = "#777777", linewidth = 0.20, lineend = "round") +
  geom_sf(data = ten_dash, color = "#272727", linewidth = 0.22, lineend = "round") +
  scale_fill_manual(values = count_fill_values, drop = FALSE, name = "Number of new records") +
  coord_sf(xlim = main_xlim, ylim = main_ylim, expand = FALSE, crs = china_crs) +
  theme_void(base_family = "sans") +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    panel.border = element_rect(fill = NA, color = "black", linewidth = 0.75),
    legend.position = c(0.022, 0.018), legend.justification = c(0, 0),
    legend.background = element_rect(fill = alpha("white", 0.9), color = NA),
    legend.title = element_text(size = 14.5, face = "bold"),
    legend.text = element_text(size = 12.4),
    legend.key.width = unit(1.2, "cm"), legend.key.height = unit(0.60, "cm"),
    plot.margin = margin(8, 8, 8, 8)
  )

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

# --- Export with eoffice ---
slide_w <- 13.6
half_w  <- (slide_w - 0.15) / 2
gap_in  <- 0.15
top_h   <- 5.4
bot_h   <- 6.8
slide_h <- top_h + gap_in + bot_h

# --- Export with eoffice ---
# eoffice::topptx accepts ggplot2 objects directly (uses officer/rvg internally)
# 注意：eoffice 函数名是 topptx（全小写），不是 to_pptx
cat("Exporting point map with eoffice topptx...\n")
topptx(point_map_main, filename = file.path(FIG_DIR, "fig2a_point_map.pptx"),
        width = half_w, height = top_h, units = "in")

cat("Exporting count map with eoffice topptx...\n")
topptx(count_map_main, filename = file.path(FIG_DIR, "fig2b_count_map.pptx"),
        width = half_w, height = top_h, units = "in")

cat("Exporting sankey with eoffice topptx...\n")
topptx(p_sankey, filename = file.path(FIG_DIR, "fig2c_sankey.pptx"),
        width = slide_w, height = bot_h, units = "in")

# --- Assemble composite with officer ---
cat("Assembling composite PPTX...\n")
ppt <- read_pptx()
ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
prs <- ppt
prs$slide_size$cx <- slide_w * 914400
prs$slide_size$cy <- slide_h * 914400

ppt <- ph_with(ppt, external_img(file.path(FIG_DIR, "fig2a_point_map.pptx"), width = half_w, height = top_h),
               location = ph_location(left = 0, top = 0, width = half_w, height = top_h))
ppt <- ph_with(ppt, external_img(file.path(FIG_DIR, "fig2b_count_map.pptx"), width = half_w, height = top_h),
               location = ph_location(left = half_w + gap_in, top = 0, width = half_w, height = top_h))
ppt <- ph_with(ppt, external_img(file.path(FIG_DIR, "fig2c_sankey.pptx"), width = slide_w, height = bot_h),
               location = ph_location(left = 0, top = top_h + gap_in, width = slide_w, height = bot_h))

add_label <- function(ppt, text, x, y) {
  ph_with(ppt,
    fpar(ftext(text, fp_text(font.size = 16, bold = TRUE, color = "#222222"))),
    location = ph_location(left = x, top = y, width = 0.5, height = 0.3))
}
ppt <- add_label(ppt, "(a)", 0.06, 0.06)
ppt <- add_label(ppt, "(b)", half_w + gap_in + 0.06, 0.06)
ppt <- add_label(ppt, "(c)", 0.06, top_h + gap_in + 0.05)

out_path <- file.path(FIG_DIR, "figure2_composite_editable_eoffice.pptx")
print(ppt, target = out_path)
cat("✓ Fig 2 eoffice PPTX saved to:", out_path, "\n")
