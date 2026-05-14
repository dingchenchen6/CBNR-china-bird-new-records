#!/usr/bin/env Rscript

# ============================================================
# Server-side: export sankey only as editable PPTX via eoffice
# 单独导出 sankey 为可编辑 PPTX（eoffice，避免地图 segfault）
# ============================================================

suppressPackageStartupMessages({
  library(eoffice)
  library(ggplot2)
  library(ggalluvial)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(stringr)
  library(tibble)
})

TASK_ROOT <- "~/projects/bird-new-distribution-records/tasks/cbnr_v3_server_pptx"
DATA_DIR <- file.path(TASK_ROOT, "data")
FIG_DIR  <- file.path(TASK_ROOT, "figures_eoffice")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

recs <- read_csv(file.path(DATA_DIR, "cbnr_clean_events.csv"), show_col_types = FALSE)

# Sankey data
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

# Export with eoffice
cat("Exporting sankey with eoffice topptx...\n")
slide_w <- 13.6
bot_h   <- 6.8

topptx(p_sankey, filename = file.path(FIG_DIR, "fig2c_sankey_eoffice.pptx"),
       width = slide_w, height = bot_h, units = "in")

cat("✓ Sankey eoffice PPTX saved to:", file.path(FIG_DIR, "fig2c_sankey_eoffice.pptx"), "\n")
