#!/usr/bin/env Rscript

# ============================================================
# Server-side editable PPTX for Figure 1 (phylogeny)
# 服务器端生成 Figure 1 可编辑 PPTX
# ============================================================

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(forcats)
  library(ape)
  library(officer)
  library(rvg)
  library(gridGraphics)
})

TASK_ROOT <- "~/projects/bird-new-distribution-records/tasks/cbnr_v3_server_pptx"
DATA_DIR <- file.path(TASK_ROOT, "data")
FIG_DIR  <- file.path(TASK_ROOT, "figures")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

master_xlsx <- file.path(DATA_DIR, "鸟类新纪录20260508.xlsx")
corrected_events_csv <- file.path(DATA_DIR, "cbnr_clean_events.csv")
tree_path <- file.path(DATA_DIR, "summary_dated_clements.nex")
tree_url <- "https://raw.githubusercontent.com/McTavishLab/AvesData/main/Tree_versions/Aves_1.4/Clements2023/summary_dated_clements.nex"

# Download tree if needed
if (!file.exists(tree_path) || file.info(tree_path)$size < 1000000) {
  download.file(tree_url, tree_path, mode = "wb", quiet = TRUE)
}
tree_full <- read.nexus(tree_path)

# Species rank filter
strict_species_rank_filter <- function(x) {
  x <- str_squish(x)
  word_n <- str_count(x, " ") + 1L
  rank_marker <- str_detect(x, regex(" subsp\\.| spp\\.| sp\\.| cf\\.| aff\\.| x ", ignore_case = TRUE))
  word_n == 2L & !rank_marker
}

# Read checklist
catalog_raw <- read_excel(master_xlsx, sheet = "2025中国生物物种名录", .name_repair = "minimal")
catalog_block <- catalog_raw[, 1:14]
names(catalog_block) <- c(
  "species", "species_cn", "kingdom_latin", "kingdom_cn", "phylum_latin", "phylum_cn",
  "class_latin", "class_cn", "order_raw", "order_cn", "family_raw", "family_cn",
  "genus_raw", "genus_cn"
)
checklist_all_birds <- catalog_block %>%
  mutate(across(everything(), ~ if (is.character(.x)) str_squish(.x) else .x)) %>%
  filter(class_latin == "Aves", !is.na(species), species != "")
checklist_species_pool <- checklist_all_birds %>%
  mutate(
    is_strict_species_rank = strict_species_rank_filter(species),
    order = str_to_title(str_to_lower(order_raw)),
    family = family_raw,
    genus = genus_raw
  ) %>%
  filter(is_strict_species_rank) %>%
  distinct(species, .keep_all = TRUE) %>%
  select(species, species_cn, order, order_cn, family, family_cn, genus, genus_cn)

# Read corrected events
corrected_events <- read.csv(corrected_events_csv, stringsAsFactors = FALSE, check.names = FALSE) %>%
  mutate(species = str_squish(species), species_cn = str_squish(species_cn),
         order = str_squish(order))

pick_mode_or_first <- function(x) {
  x <- x[!is.na(x) & x != ""]
  if (length(x) == 0) return(NA_character_)
  tb <- sort(table(x), decreasing = TRUE)
  names(tb)[1]
}

new_record_species <- corrected_events %>%
  arrange(species, year, province) %>%
  group_by(species) %>%
  summarise(
    species_cn = pick_mode_or_first(species_cn),
    order = pick_mode_or_first(order),
    n_event_records = n(),
    .groups = "drop"
  ) %>%
  arrange(order, species)

# Taxonomy bridge (simplified essential entries)
taxonomy_bridge <- tibble::tribble(
  ~source_species,              ~target_tree_label,
  "Haliaeetus humilis",         "Icthyophaga_humilis",
  "Haliaeetus leucogaster",     "Icthyophaga_leucogaster",
  "Charadrius alexandrinus",    "Anarhynchus_alexandrinus",
  "Charadrius asiaticus",       "Anarhynchus_asiaticus",
  "Charadrius atrifrons",       "Anarhynchus_atrifrons",
  "Charadrius dealbatus",       "Anarhynchus_dealbatus",
  "Charadrius leschenaultii",   "Anarhynchus_leschenaultii",
  "Charadrius mongolus",        "Anarhynchus_mongolus",
  "Charadrius veredus",         "Anarhynchus_veredus",
  "Larus brunnicephalus",       "Chroicocephalus_brunnicephalus",
  "Larus genei",                "Chroicocephalus_genei",
  "Larus ichthyaetus",          "Ichthyaetus_ichthyaetus",
  "Larus relictus",             "Ichthyaetus_relictus",
  "Grus canadensis",            "Antigone_canadensis",
  "Grus vipio",                 "Antigone_vipio",
  "Grus virgo",                 "Anthropoides_virgo",
  "Amaurornis cinerea",         "Poliolimnas_cinereus",
  "Gorsachius magnificus",      "Oroanassa_magnifica",
  "Otocichla mupinensis",       "Turdus_mupinensis",
  "Paradoxornis gularis",       "Psittiparus_gularis",
  "Paradoxornis heudei",        "Calamornis_heudei",
  "Pardaliparus venustulus",    "Periparus_venustulus",
  "Bubo nipalensis",            "Ketupa_nipalensis",
  "Leiopicus auriceps",         "Dendrocoptes_auriceps",
  "Anas carolinensis",          "Anas_crecca",
  "Phoenicopterus roseus",      "Phoenicopterus_roseus"
)

tree_tip_labels <- tree_full$tip.label

apply_tree_matching <- function(df) {
  df %>%
    mutate(tree_label_direct = str_replace_all(species, " ", "_")) %>%
    left_join(taxonomy_bridge, by = c("species" = "source_species")) %>%
    mutate(
      tree_label_final = coalesce(target_tree_label, tree_label_direct),
      exact_match = tree_label_direct %in% tree_tip_labels,
      bridged_match = !exact_match & !is.na(target_tree_label) & tree_label_final %in% tree_tip_labels,
      unresolved = !exact_match & !bridged_match,
      match_status = case_when(
        exact_match ~ "Exact match",
        bridged_match ~ "Bridged match",
        TRUE ~ "Unresolved"
      )
    )
}

checklist_matched <- apply_tree_matching(checklist_species_pool)
new_record_matched <- apply_tree_matching(new_record_species)

checklist_tip_map <- checklist_matched %>%
  filter(match_status != "Unresolved") %>%
  group_by(tree_label_final) %>%
  summarise(
    order = first(order),
    family = first(family),
    genus = first(genus),
    pool_species_concepts = n(),
    .groups = "drop"
  )

new_record_tip_map <- new_record_matched %>%
  filter(match_status != "Unresolved") %>%
  group_by(tree_label_final) %>%
  summarise(
    new_record_species_concepts = n(),
    order_new = first(order),
    .groups = "drop"
  )

tip_metadata <- checklist_tip_map %>%
  left_join(new_record_tip_map, by = "tree_label_final") %>%
  mutate(
    order = coalesce(order_new, order),
    is_new_record = !is.na(new_record_species_concepts),
    new_record_species_concepts = replace_na(new_record_species_concepts, 0L)
  )

tree_china <- keep.tip(tree_full, tip_metadata$tree_label_final)
tree_china <- ladderize(tree_china, right = TRUE)

tip_metadata <- tip_metadata %>%
  mutate(tree_label_final = factor(tree_label_final, levels = tree_china$tip.label)) %>%
  arrange(tree_label_final) %>%
  mutate(tree_label_final = as.character(tree_label_final), tip_index = row_number())

order_pool_summary <- checklist_species_pool %>% count(order, name = "n_china_species")
order_new_summary  <- new_record_species %>% count(order, name = "n_new_species")
order_summary <- order_pool_summary %>%
  left_join(order_new_summary, by = "order") %>%
  mutate(n_new_species = replace_na(n_new_species, 0L),
         prop_new_species = n_new_species / pmax(n_china_species, 1),
         prop_pct = prop_new_species * 100) %>%
  arrange(desc(n_new_species), desc(prop_new_species))

order_levels <- order_summary %>% filter(n_new_species > 0) %>% pull(order)
order_palette_defaults <- c(
  Passeriformes = "#19E51E", Charadriiformes = "#FFF000", Accipitriformes = "#FF1A1A",
  Anseriformes = "#00E8F2", Pelecaniformes = "#FF8ED1", Gruiformes = "#13D7E0",
  Strigiformes = "#FF8C25", Columbiformes = "#9CCAE1", Galliformes = "#B2E84D",
  Coraciiformes = "#FFBF52", Piciformes = "#39D6D0", Suliformes = "#8E6AE8",
  Procellariiformes = "#7CC7F2", Ciconiiformes = "#A8D8F8", Cuculiformes = "#71BFFF",
  Caprimulgiformes = "#8E7CD7", Gaviiformes = "#1EB2D8", Podicipediformes = "#7E57FF",
  Phoenicopteriformes = "#F4B5FF", Otidiformes = "#F4A100", Pterocliformes = "#FF5CB8",
  Trogoniformes = "#F04E98", Falconiformes = "#F06A6A"
)
missing_orders <- setdiff(order_levels, names(order_palette_defaults))
if (length(missing_orders) > 0) {
  extra_cols <- grDevices::hcl(h = seq(15, 375, length.out = length(missing_orders) + 1)[-1], c = 85, l = 68)
  names(extra_cols) <- missing_orders
  order_palette_defaults <- c(order_palette_defaults, extra_cols)
}
order_palette <- order_palette_defaults[order_levels]

# Draw function (simplified from local script)
draw_phylo_main <- function() {
  par(mar = c(0.2, 0.3, 0.2, 0.2), xpd = NA, bg = "white")
  edge_df <- tibble(edge_id = seq_len(nrow(tree_china$edge)),
                    parent = tree_china$edge[, 1], child = tree_china$edge[, 2])
  child_to_parent <- setNames(edge_df$parent, edge_df$child)
  child_to_edge   <- setNames(edge_df$edge_id, edge_df$child)

  edge_order_membership <- vector("list", nrow(edge_df))
  new_tip_rows <- tip_metadata %>% filter(is_new_record)
  for (i in seq_len(nrow(new_tip_rows))) {
    tip_id <- match(new_tip_rows$tree_label_final[i], tree_china$tip.label)
    if (is.na(tip_id)) next
    current_node <- tip_id
    while (!is.na(child_to_edge[as.character(current_node)])) {
      edge_id <- as.integer(child_to_edge[as.character(current_node)])
      edge_order_membership[[edge_id]] <- unique(c(edge_order_membership[[edge_id]], new_tip_rows$order[i]))
      current_node <- as.integer(child_to_parent[as.character(current_node)])
    }
  }

  edge_order_cols <- vapply(edge_order_membership, function(x) {
    if (length(x) == 1 && x %in% names(order_palette)) order_palette[[x]] else "#CFCFCF"
  }, character(1))
  edge_lwd <- vapply(edge_order_membership, function(x) if (length(x) >= 1) 0.92 else 0.40, numeric(1))

  base_layout <- plot.phylo(tree_china, type = "fan", use.edge.length = FALSE,
                            show.tip.label = FALSE, no.margin = TRUE,
                            edge.color = "#CFCFCF", edge.width = 0.40, cex = 0.08, plot = FALSE)

  plot.phylo(tree_china, type = "fan", use.edge.length = FALSE, show.tip.label = FALSE,
             no.margin = TRUE, edge.color = "#CFCFCF", edge.width = 0.40, cex = 0.08,
             x.lim = c(base_layout$x.lim[1] * 2.42, base_layout$x.lim[2] * 2.42),
             y.lim = c(base_layout$y.lim[1] * 1.48, base_layout$y.lim[2] * 1.48))

  lp <- get("last_plot.phylo", envir = .PlotPhyloEnv)
  n_tip <- lp$Ntip
  xx <- lp$xx[seq_len(n_tip)]
  yy <- lp$yy[seq_len(n_tip)]
  rr <- sqrt(xx^2 + yy^2)
  theta <- atan2(yy, xx)
  max_r <- max(rr)

  tip_plot_df <- tip_metadata %>%
    mutate(x = xx[match(tree_label_final, tree_china$tip.label)],
           y = yy[match(tree_label_final, tree_china$tip.label)],
           theta = theta[match(tree_label_final, tree_china$tip.label)])

  coloured_edge_df <- edge_df %>% mutate(edge_colour = edge_order_cols, edge_width = edge_lwd) %>%
    filter(edge_colour != "#CFCFCF")
  if (nrow(coloured_edge_df) > 0) {
    for (i in seq_len(nrow(coloured_edge_df))) {
      segments(x0 = lp$xx[coloured_edge_df$parent[i]], y0 = lp$yy[coloured_edge_df$parent[i]],
               x1 = lp$xx[coloured_edge_df$child[i]],  y1 = lp$yy[coloured_edge_df$child[i]],
               col = coloured_edge_df$edge_colour[i], lwd = coloured_edge_df$edge_width[i], lend = "round")
    }
  }

  tip_edge_df <- edge_df %>% filter(child <= n_tip) %>%
    mutate(tree_label_final = tree_china$tip.label[child]) %>% left_join(tip_plot_df, by = "tree_label_final")
  if (nrow(tip_edge_df) > 0) {
    for (i in seq_len(nrow(tip_edge_df))) {
      if (isTRUE(tip_edge_df$is_new_record[i])) {
        segments(x0 = lp$xx[tip_edge_df$parent[i]], y0 = lp$yy[tip_edge_df$parent[i]],
                 x1 = lp$xx[tip_edge_df$child[i]],  y1 = lp$yy[tip_edge_df$child[i]],
                 col = order_palette[tip_edge_df$order[i]], lwd = 1.85, lend = "round")
      }
    }
  }

  ordered_tip_df <- tip_plot_df %>% arrange(tip_index) %>%
    mutate(run_id = cumsum(order != lag(order, default = first(order))) + 1L)

  compute_theta_interval <- function(theta_values) {
    th <- theta_values %% (2 * pi)
    if ((max(th) - min(th)) > pi) th[th < pi] <- th[th < pi] + 2 * pi
    c(start = min(th), end = max(th))
  }

  sector_run_df <- ordered_tip_df %>% group_by(run_id, order) %>%
    summarise(n_tip_run = n(), interval = list(compute_theta_interval(theta)), .groups = "drop") %>%
    mutate(theta_start = vapply(interval, function(x) x[["start"]], numeric(1)),
           theta_end   = vapply(interval, function(x) x[["end"]],   numeric(1)),
           theta_mid = (theta_start + theta_end) / 2,
           theta_mid = if_else(theta_mid > 2 * pi, theta_mid - 2 * pi, theta_mid)) %>%
    select(-interval)

  for (i in seq_len(nrow(sector_run_df))) {
    th <- seq(sector_run_df$theta_start[i], sector_run_df$theta_end[i], length.out = 250)
    th <- ifelse(th > 2 * pi, th - 2 * pi, th)
    lines(x = (max_r + 0.032) * cos(th), y = (max_r + 0.032) * sin(th),
          col = grDevices::adjustcolor(order_palette[sector_run_df$order[i]], alpha.f = 0.95), lwd = 7.6, lend = "round")
  }

  points(x = (max_r + 0.066) * cos(tip_plot_df$theta),
         y = (max_r + 0.066) * sin(tip_plot_df$theta),
         pch = 15, cex = 1.18,
         col = ifelse(tip_plot_df$is_new_record, order_palette[tip_plot_df$order], "#E8E8E8"))

  # Percentage bubbles (simplified)
  bubble_orders <- sector_run_df %>% group_by(order) %>% slice_max(order_by = n_tip_run, n = 1, with_ties = FALSE) %>%
    ungroup() %>% left_join(order_summary, by = "order") %>% filter(n_new_species > 0) %>% arrange(theta_mid) %>%
    mutate(bubble_radius = max_r * 0.30, bubble_size = 0.055,
           x = bubble_radius * cos(theta_mid), y = bubble_radius * sin(theta_mid))

  for (i in seq_len(nrow(bubble_orders))) {
    symbols(bubble_orders$x[i], bubble_orders$y[i], circles = bubble_orders$bubble_size[i],
            inches = FALSE, add = TRUE,
            bg = grDevices::adjustcolor(order_palette[bubble_orders$order[i]], alpha.f = 0.94), fg = NA)
    text(bubble_orders$x[i], bubble_orders$y[i], labels = sprintf("%.1f%%", bubble_orders$prop_pct[i]),
         cex = 0.50, col = "black")
  }

  # Order labels without icons (simplified for server rendering stability)
  label_orders <- sector_run_df %>% group_by(order) %>% slice_max(order_by = n_tip_run, n = 1, with_ties = FALSE) %>%
    ungroup() %>% left_join(order_summary, by = "order") %>% filter(n_new_species > 0) %>% arrange(theta_mid) %>%
    mutate(side = ifelse(cos(theta_mid) >= 0, "right", "left"),
           guide_radius = max_r + 0.076,
           text_cex = ifelse(nchar(order) >= 18, 0.96, ifelse(nchar(order) >= 14, 1.03, 1.10)))

  label_right <- label_orders %>% filter(side == "right") %>% arrange(desc(sin(theta_mid))) %>%
    mutate(y_label = seq(max_r * 0.96, -max_r * 0.96, length.out = n()),
           x_anchor = max_r + 0.38, x_text = max_r + 0.55)
  label_left  <- label_orders %>% filter(side == "left")  %>% arrange(desc(sin(theta_mid))) %>%
    mutate(y_label = seq(max_r * 0.96, -max_r * 0.96, length.out = n()),
           x_anchor = -(max_r + 0.38), x_text = x_anchor - 0.40)
  label_orders <- bind_rows(label_right, label_left) %>% arrange(theta_mid)

  for (i in seq_len(nrow(label_orders))) {
    ang <- label_orders$theta_mid[i]
    x0 <- label_orders$guide_radius[i] * cos(ang)
    y0 <- label_orders$guide_radius[i] * sin(ang)
    xh <- label_orders$x_anchor[i]
    yi <- label_orders$y_label[i]
    xt <- label_orders$x_text[i]
    segments(x0, y0, xh, yi, col = "#111111", lwd = 0.75)
    text(xt, yi, labels = label_orders$order[i], cex = label_orders$text_cex[i],
         adj = c(ifelse(label_orders$side[i] == "right", 0, 1), 0.5), col = "#111111", font = 1)
  }
}

# Export to PPTX
cat("Rendering phylogeny to editable PPTX...\n")
ppt <- read_pptx()
ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
ppt <- ph_with(ppt,
  dml(code = {
    grid::grid.newpage()
    gridGraphics::grid.echo(draw_phylo_main, newpage = FALSE)
  }),
  location = ph_location(left = 0, top = 0, width = 13.333, height = 7.5)
)
out_path <- file.path(FIG_DIR, "figure1_phylogeny_editable_server.pptx")
print(ppt, target = out_path)
cat("✓ Fig 1 editable PPTX saved to:", out_path, "\n")
