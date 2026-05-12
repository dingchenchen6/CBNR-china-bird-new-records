#!/usr/bin/env Rscript

# ============================================================
# Build truly editable PPTX for Figure 1 (phylogeny) and Figure 2
# (3-panel composite) by embedding existing vector assets.
# 生成真正可编辑的 Figure 1 与 Figure 2 PPTX。
# ============================================================
#
# Strategy / 实施
# - Fig 1: copy the phylogeny PPTX produced by ggtree+rvg (DrawingML vector
#   in slide1.xml; PhyloPic silhouettes embedded as PNG are kept as-is).
# - Fig 2: build a single-slide PPTX where
#     (a) point map  ← embed fig_sp03 main+inset EMF (vector, editable)
#     (b) count map  ← embed fig_sp01 main+inset EMF (vector, editable)
#     (c) sankey     ← re-render the ggalluvial ggplot via rvg::dml so the
#                      strata, alluvia and labels are individual editable shapes
#
# Output / 输出
#   ../figures_v3/figure1_phylogeny_editable.pptx
#   ../figures_v3/figure2_combined_editable.pptx
# ============================================================

suppressPackageStartupMessages({
  library(officer); library(rvg); library(ggplot2); library(ggalluvial)
  library(dplyr); library(tidyr); library(readr); library(stringr); library(fs)
})

# Portable script-relative resolution + env-var override (no machine paths).
# 可移植脚本：依次尝试脚本位置、CWD、CBNR_TASK_ROOT 环境变量。
get_script_path <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", ca, value = TRUE)
  if (length(fa) > 0) {
    cand <- sub("^--file=", "", fa[1])
    if (file.exists(cand)) return(normalizePath(cand))
  }
  if (sys.nframe() >= 1 && !is.null(sys.frames()[[1]]$ofile))
    return(normalizePath(sys.frames()[[1]]$ofile, mustWork = FALSE))
  normalizePath(getwd())
}
HERE <- get_script_path()
HERE <- if (dir.exists(HERE)) HERE else dirname(HERE)
TASK_ROOT <- Sys.getenv(
  "CBNR_TASK_ROOT",
  unset = normalizePath(file.path(HERE, "..", ".."), mustWork = FALSE)
)
if (!dir.exists(TASK_ROOT) || !file.exists(file.path(TASK_ROOT, "code"))) {
  stop(sprintf(
    "Cannot resolve task root. Set CBNR_TASK_ROOT to the directory containing 'code/'. Got: %s",
    TASK_ROOT))
}
fig_v3   <- file.path(TASK_ROOT, "figures_v3")
phy_dir  <- file.path(TASK_ROOT, "phylogeny_v3", "figures")
sp_dir   <- file.path(TASK_ROOT, "spatiotemporal_v3", "figures")
sk_dir   <- file.path(TASK_ROOT, "sankey_v3", "figures")
data_csv <- file.path(TASK_ROOT, "data", "bird_new_records_clean_corrected_keepall.csv")
dir_create(fig_v3, recurse = TRUE)

# ----- Fig 1: copy editable phylogeny PPTX -----
src <- file.path(phy_dir, "fig_phy01_mctavish_bird_new_records_phylogeny.pptx")
dst <- file.path(fig_v3, "figure1_phylogeny_editable.pptx")
file.copy(src, dst, overwrite = TRUE)
message("✓ Fig 1 editable PPTX -> ", dst)

# ----- Fig 2: build single-slide PPTX with editable shapes -----
emf_a_main  <- file.path(sp_dir, "fig_sp03_across_order_point_map_main.emf")
emf_a_inset <- file.path(sp_dir, "fig_sp03_across_order_point_map_inset.emf")
emf_b_main  <- file.path(sp_dir, "fig_sp01_province_new_record_count_map_main.emf")
emf_b_inset <- file.path(sp_dir, "fig_sp01_province_new_record_count_map_inset.emf")
stopifnot(all(file.exists(c(emf_a_main, emf_a_inset, emf_b_main, emf_b_inset))))

# Rebuild sankey ggplot from the canonical CSV (collapse bottom-5 → Others)
recs <- read_csv(data_csv, show_col_types = FALSE)
clean <- recs %>%
  transmute(species, order, province, year = as.integer(year)) %>%
  filter(!is.na(species), !is.na(order), !is.na(province), !is.na(year)) %>%
  distinct(species, order, province, year)
n_collapse <- 5
ord_full <- clean %>% count(order, name = "n") %>% arrange(desc(n))
keep_orders <- ord_full$order[seq_len(max(1, nrow(ord_full) - n_collapse))]
clean <- clean %>% mutate(order = if_else(order %in% keep_orders, order, "Others"))
ord_lvl  <- c(keep_orders, "Others")
prov_lvl <- clean %>% count(province, sort = TRUE) %>% pull(province)
yr_lvl   <- sort(unique(clean$year))
sankey_df <- clean %>%
  count(order, province, year, name = "n_records") %>%
  mutate(order = factor(order, levels = ord_lvl),
         province = factor(province, levels = prov_lvl),
         year = factor(year, levels = yr_lvl))

base_palette <- c(
  "Passeriformes" = "#8FA8D6", "Charadriiformes" = "#F28E5B",
  "Anseriformes"  = "#67C1B3", "Accipitriformes" = "#E78AC3",
  "Pelecaniformes" = "#8BC34A", "Gruiformes"     = "#D9B26F",
  "Columbiformes" = "#9E9E9E", "Galliformes"     = "#F1C40F",
  "Strigiformes"  = "#B497D6", "Coraciiformes"   = "#6FA8DC",
  "Phoenicopteriformes" = "#FF7043", "Suliformes" = "#26C6DA",
  "Cuculiformes"  = "#7E57C2", "Piciformes"      = "#26A69A",
  "Procellariiformes" = "#5D4037", "Caprimulgiformes" = "#9CCC65",
  "Ciconiiformes" = "#EF5350", "Gaviiformes"    = "#42A5F5",
  "Podicipediformes" = "#AB47BC", "Falconiformes" = "#FFB300",
  "Pterocliformes" = "#8D6E63", "Trogoniformes" = "#789262",
  "Otidiformes"   = "#A1887F",  "Others"         = "#BDBDBD"
)
extra <- setdiff(ord_lvl, names(base_palette))
if (length(extra)) base_palette <- c(base_palette,
  setNames(grDevices::hcl.colors(length(extra), "Set 3"), extra))
sankey_palette <- base_palette[ord_lvl]

p_sankey <- ggplot(sankey_df,
       aes(axis1 = order, axis2 = province, axis3 = year, y = n_records)) +
  geom_alluvium(aes(fill = order), width = 0.18, alpha = 0.70, knot.pos = 0.42) +
  geom_stratum(width = 0.18, fill = "#E9E9E9", color = "#707070", linewidth = 0.42) +
  geom_text(stat = "stratum", aes(label = after_stat(stratum)),
            size = 2.7, lineheight = 0.85, family = "sans") +
  scale_fill_manual(values = sankey_palette, guide = "none") +
  scale_x_discrete(limits = c("Order", "Province", "Year"),
                   expand = c(0.008, 0.008)) +
  labs(x = NULL, y = "Number of records") +
  theme_minimal(base_size = 11, base_family = "sans") +
  theme(axis.text.x = element_text(face = "bold", size = 12.5, color = "#303030",
                                    margin = margin(t = 1)),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title = element_text(face = "bold", size = 12.5),
        panel.grid = element_blank(),
        plot.margin = margin(6, 8, 4, 8))

# ----- Slide geometry (inches) -----
slide_w <- 13.6
half_w  <- (slide_w - 0.15) / 2     # leave ~1.5-letter gap between (a) and (b)
gap_in  <- 0.15
top_h   <- 5.4                      # height of map panels
bot_h   <- 6.8                      # height of sankey
slide_h <- top_h + gap_in + bot_h

# Inset placement within each map: bottom-right corner ~ 18% × 24% of panel
inset_w <- half_w * 0.155
inset_h <- top_h  * 0.235
inset_a_left <- half_w - inset_w - 0.02
inset_b_left <- slide_w - inset_w - 0.02
inset_top    <- top_h - inset_h - 0.02

# ----- Build PPTX -----
ppt <- read_pptx()
ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")

# Resize slide to match our geometry
prs <- ppt
prs$slide_size$cx <- slide_w * 914400
prs$slide_size$cy <- slide_h * 914400

# (a) point map main — left
ppt <- ph_with(ppt, external_img(emf_a_main, width = half_w, height = top_h),
               location = ph_location(left = 0, top = 0,
                                       width = half_w, height = top_h))
# (a) inset
ppt <- ph_with(ppt, external_img(emf_a_inset, width = inset_w, height = inset_h),
               location = ph_location(left = inset_a_left, top = inset_top,
                                       width = inset_w, height = inset_h))
# (b) count map main — right
ppt <- ph_with(ppt, external_img(emf_b_main, width = half_w, height = top_h),
               location = ph_location(left = half_w + gap_in, top = 0,
                                       width = half_w, height = top_h))
# (b) inset
ppt <- ph_with(ppt, external_img(emf_b_inset, width = inset_w, height = inset_h),
               location = ph_location(left = inset_b_left, top = inset_top,
                                       width = inset_w, height = inset_h))
# Panel labels (a)/(b)/(c) as text boxes
add_label <- function(ppt, text, x, y) {
  ph_with(ppt,
          fpar(ftext(text, fp_text(font.size = 16, bold = TRUE, color = "#222222"))),
          location = ph_location(left = x, top = y, width = 0.5, height = 0.3))
}
ppt <- add_label(ppt, "(a)", 0.06, 0.06)
ppt <- add_label(ppt, "(b)", half_w + gap_in + 0.06, 0.06)
ppt <- add_label(ppt, "(c)", 0.06, top_h + gap_in + 0.05)

# (c) sankey via rvg::dml — fully editable DrawingML
ppt <- ph_with(ppt, dml(ggobj = p_sankey),
               location = ph_location(left = 0, top = top_h + gap_in,
                                       width = slide_w, height = bot_h))

out <- file.path(fig_v3, "figure2_combined_editable.pptx")
print(ppt, target = out)
message("✓ Fig 2 editable composite PPTX -> ", out)

cat("\nDone. Outputs:\n  ", dst, "\n  ", out, "\n")
