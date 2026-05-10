#!/usr/bin/env Rscript

# ============================================================
# Bird new-record canonical builder — KEEP ALL YEARS variant
# 中国鸟类新纪录 canonical 数据构建（保留所有年份；< 2000 仅作标记）
# ============================================================
#
# Difference vs 01b_build_canonical_from_cbnr20260508.R:
# - Records with discovery year < 2000 are NO LONGER excluded.
#   They are retained and flagged with `year_in_scope = FALSE` so that
#   downstream summaries can choose to include or exclude them.
# - 4 lon=lat coordinate artefacts are still flagged via `coord_status`
#   but kept in counts.
# 与 01b 的区别：发现年份 < 2000 的记录不再剔除，仅以 year_in_scope = FALSE 标记，
# 便于下游按需筛选；4 条 lon=lat 录入伪造仍然 flag 但保留在计数内。
#
# Output / 输出
#   ../data/bird_new_records_clean_corrected_keepall.csv   (canonical, 1020 rows)
#   ../data/bird_species_pool_with_traits_corrected_keepall.csv
#   ../data/before_after_summary_keepall.csv
#   ../data/duplicate_drop_log_keepall.csv
#   ../figures_v3/fig_qa_identity_synonym_duplicate_keepall.{png,pdf}
# ============================================================

suppressPackageStartupMessages({
  library(readxl); library(dplyr); library(tidyr); library(stringr)
  library(ggplot2); library(patchwork); library(scales); library(readr)
  library(fs); library(tibble)
})

get_script_path <- function() {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", cmd_args, value = TRUE)
  if (length(fa) > 0) {
    cand <- sub("^--file=", "", fa[1])
    if (file.exists(cand)) return(normalizePath(cand))
  }
  normalizePath(getwd())
}
script_path <- get_script_path()
code_dir  <- if (dir.exists(script_path)) script_path else dirname(script_path)
task_root <- normalizePath(file.path(code_dir, ".."))
data_dir  <- file.path(task_root, "data")
fig_dir   <- file.path(task_root, "figures_v3")
res_dir   <- file.path(task_root, "results")
dir_create(c(data_dir, fig_dir, res_dir), recurse = TRUE)

project_root <- normalizePath(file.path(task_root, ".."))
master_xlsx  <- file.path(project_root, "鸟类新纪录20260508.xlsx")
stopifnot(file.exists(master_xlsx))

# ----- Read CBNR English sheet -----
cbnr_raw <- read_xlsx(master_xlsx, sheet = "CBNR（EN）", guess_max = 5000)
n_raw <- nrow(cbnr_raw); message("[01c] CBNR (EN) raw rows: ", n_raw)

prov_recode <- c("Tibet" = "Xizang", "Xizang" = "Xizang",
                 "Inner Mongolia" = "Inner Mongolia",
                 "Hong Kong" = "Hong Kong", "Macau" = "Macau", "Macao" = "Macau")
order_cn_to_la <- c("雀形目" = "PASSERIFORMES", "鸻形目" = "CHARADRIIFORMES",
                    "雁形目" = "ANSERIFORMES", "鹰形目" = "ACCIPITRIFORMES",
                    "鹈形目" = "PELECANIFORMES", "鹤形目" = "GRUIFORMES")

cbnr_clean <- cbnr_raw %>%
  transmute(
    record_id = as.integer(ID),
    species = str_squish(`Taxonomy_scientific_name_CatalogueofLifeChina_2025AnnualChecklist...9`),
    species_cn = `Taxonomy_Chinese_name`,
    english_name = `Taxonomy_English_name`,
    order_la_raw = `OrderLA_CatalogueofLifeChina_2025AnnualChecklist`,
    family = `FamilyLA_CatalogueofLifeChina_2025AnnualChecklist`,
    province_raw = `New_distribution_province`,
    discovery_sites = Discovery_sites,
    longitude = suppressWarnings(as.numeric(Longitude)),
    latitude  = suppressWarnings(as.numeric(Latitude)),
    discovery_date = Discovery_date,
    habitat = Habitat, altitude = Altitude,
    migratory_status = Migratory_Status,
    discovery_method_raw = Discovery_method,
    discover_cause_raw   = Potential_discovery_cause,
    iucn_raw       = `IUCN RED LIST`,
    china_red_list = CHINA_RED_LIST_2020,
    endemic        = Endemsim,
    source_title   = Source_title,
    source_journal = Source_journal,
    source_authors = Source_authors,
    year_pub = suppressWarnings(as.integer(Source_publication_year)),
    doi = DOI, link = Link
  ) %>%
  mutate(
    year_disc = suppressWarnings(as.integer(format(as.Date(discovery_date), "%Y"))),
    year = coalesce(year_disc, year_pub),
    year_in_scope = !is.na(year) & year >= 2000 & year <= 2025,
    province = recode(str_squish(as.character(province_raw)), !!!prov_recode),
    order_la_raw = recode(str_squish(as.character(order_la_raw)), !!!order_cn_to_la),
    order = str_to_title(str_to_lower(order_la_raw)),
    iucn  = str_extract(toupper(as.character(iucn_raw)), "CR|EN|VU|NT|LC|DD|NE"),
    discovery_method = discovery_method_raw,
    discover_reason  = case_when(
      str_detect(coalesce(discover_cause_raw, ""), regex("range shift", ignore_case = TRUE)) &
        str_detect(coalesce(discover_cause_raw, ""), regex("survey",       ignore_case = TRUE)) ~
        "Mixed: range change + survey/technology",
      str_detect(coalesce(discover_cause_raw, ""), regex("range shift", ignore_case = TRUE)) ~
        "Range shift or distribution change",
      str_detect(coalesce(discover_cause_raw, ""), regex("survey",       ignore_case = TRUE)) ~
        "Survey gap or under-sampling",
      str_detect(coalesce(discover_cause_raw, ""), regex("taxonom",      ignore_case = TRUE)) ~
        "Taxonomic revision",
      str_detect(coalesce(discover_cause_raw, ""), regex("technol|photo|camera",
                                                          ignore_case = TRUE)) ~
        "Technology or improved detection",
      is.na(discover_cause_raw) ~ "Unclear",
      TRUE ~ "Other"
    ),
    paper_id = coalesce(source_title, doi, link,
                        paste(source_authors, source_journal, year_pub, sep = " | "))
  )

n_pre2000 <- sum(!cbnr_clean$year_in_scope, na.rm = TRUE)
message("[01c] year < 2000 records flagged (kept): ", n_pre2000)

artefact_mask <- with(cbnr_clean, !is.na(longitude) & !is.na(latitude) & longitude == latitude)
cbnr_clean <- cbnr_clean %>%
  mutate(coord_status = if_else(artefact_mask, "lon_eq_lat_artefact", "valid"))
n_artefact <- sum(artefact_mask)
message("[01c] lon=lat artefacts flagged (kept): ", n_artefact)

# ----- Species-province deduplication (earliest year retention) -----
dup_log <- cbnr_clean %>%
  filter(!is.na(species), !is.na(province), !is.na(year)) %>%
  group_by(species, province) %>%
  arrange(year, record_id, .by_group = TRUE) %>%
  mutate(
    duplicate_group_size = n(),
    duplicate_rank = row_number(),
    keep_record = duplicate_rank == 1L,
    duplicate_rule = case_when(
      duplicate_group_size == 1 ~ "Unique species-province combination; retained.",
      keep_record ~ "Retained as the earliest publication for this species-province combination.",
      TRUE ~ "Dropped because an earlier publication already established this provincial record."
    )
  ) %>%
  ungroup()

records_canonical <- dup_log %>%
  filter(keep_record) %>%
  mutate(identity_change_flag = FALSE,
         identity_source = "raw_table")
extra_rows <- cbnr_clean %>%
  filter(is.na(species) | is.na(province) | is.na(year)) %>%
  mutate(duplicate_group_size = NA_integer_, duplicate_rank = NA_integer_,
         keep_record = TRUE,
         duplicate_rule = "Retained but excluded from duplicate-resolution groups.",
         identity_change_flag = FALSE, identity_source = "raw_table")
bird_corrected <- bind_rows(records_canonical, extra_rows) %>% arrange(record_id)
n_final <- nrow(bird_corrected)
message("[01c] Final canonical events: ", n_final,
        " (sp-prov duplicates removed: ", sum(!dup_log$keep_record), ")")

# ----- Write canonical CSV (full column contract + year_in_scope flag) -----
clean_corrected <- bird_corrected %>%
  transmute(
    record_id, species,
    order_raw = order_la_raw, order_cn = order_la_raw,
    province_cn = NA_character_, province_en_raw = province_raw,
    year, year_in_scope,
    iucn_raw, discover_cause_raw, discovery_method_raw,
    longitude, latitude,
    order, province, iucn, discover_reason, discovery_method, paper_id,
    species_cn, english_name, naming_time = NA_integer_,
    identity_source, identity_change_flag,
    duplicate_group_size, keep_record, coord_status,
    family, discovery_sites, habitat, altitude, migratory_status,
    china_red_list, endemic, source_title, source_journal, source_authors,
    doi, link
  )
write_csv(clean_corrected,
          file.path(data_dir, "bird_new_records_clean_corrected_keepall.csv"))

# ----- Trait pool (AVONET) -----
av <- read_xlsx(master_xlsx, sheet = "AVONET traits", guess_max = 12000) %>%
  rename(species = Species1) %>%
  transmute(
    species, order = str_to_title(str_to_lower(Order1)), family = Family1,
    body_mass_g = as.numeric(Mass), wing_length_mm = as.numeric(`Wing.Length`),
    tail_length_mm = as.numeric(`Tail.Length`),
    beak_length_culmen_mm = as.numeric(`Beak.Length_Culmen`),
    hand_wing_index = as.numeric(`Hand-Wing.Index`),
    centroid_latitude = as.numeric(`Centroid.Latitude`),
    centroid_longitude = as.numeric(`Centroid.Longitude`),
    range_size_km2 = as.numeric(`Range.Size`),
    habitat_avonet = Habitat, migration_avonet = Migration,
    trophic_level = `Trophic.Level`, trophic_niche = `Trophic.Niche`,
    primary_lifestyle = `Primary.Lifestyle`
  )
species_counts <- clean_corrected %>%
  filter(!is.na(species), species != "") %>%
  count(species, order, name = "n_new_records") %>%
  mutate(new_record = 1L)
trait_pool_corrected <- av %>%
  full_join(species_counts, by = c("species", "order")) %>%
  mutate(n_new_records = replace_na(n_new_records, 0L),
         new_record = replace_na(new_record, 0L)) %>%
  arrange(desc(new_record), desc(n_new_records), order, species)
write_csv(trait_pool_corrected,
          file.path(data_dir, "bird_species_pool_with_traits_corrected_keepall.csv"))

# ----- Before/after summary (drives Figure 5 QC) -----
valid_pre <- cbnr_clean %>%
  filter(!is.na(species), species != "", !is.na(province), province != "",
         !is.na(year))
valid_after <- clean_corrected %>%
  filter(!is.na(species), species != "", !is.na(province), province != "",
         !is.na(year))
before_after_summary <- bind_rows(
  tibble(stage = "Before species-province deduplication",
         n_records = nrow(valid_pre),
         n_species = n_distinct(valid_pre$species),
         n_species_province = n_distinct(paste(valid_pre$species,
                                                valid_pre$province, sep = " | ")),
         n_orders = n_distinct(valid_pre$order),
         n_provinces = n_distinct(valid_pre$province),
         year_min = min(valid_pre$year, na.rm = TRUE),
         year_max = max(valid_pre$year, na.rm = TRUE)),
  tibble(stage = "After earliest-publication retention",
         n_records = nrow(valid_after),
         n_species = n_distinct(valid_after$species),
         n_species_province = n_distinct(paste(valid_after$species,
                                                valid_after$province, sep = " | ")),
         n_orders = n_distinct(valid_after$order),
         n_provinces = n_distinct(valid_after$province),
         year_min = min(valid_after$year, na.rm = TRUE),
         year_max = max(valid_after$year, na.rm = TRUE))
)
write_csv(before_after_summary,
          file.path(data_dir, "before_after_summary_keepall.csv"))

identity_summary <- tibble(
  identity_source = c("raw_table","raw_table","duplicate_audit",
                       "format_mismatch","true_mismatch"),
  identity_change_flag = c("No binomial change","Name changed","Name changed",
                            "Name changed","Name changed"),
  n_records = c(n_final, 0L, sum(!dup_log$keep_record), 0L, 0L)
)
write_csv(identity_summary,
          file.path(data_dir, "identity_audit_candidates_keepall.csv"))

duplicate_drop_by_province <- dup_log %>%
  filter(!keep_record, !is.na(province)) %>%
  count(province, name = "n_dropped") %>%
  arrange(desc(n_dropped)) %>%
  slice_head(n = 12)
write_csv(duplicate_drop_by_province,
          file.path(data_dir, "duplicate_drop_log_keepall.csv"))

# ----- QC figure (3-panel patchwork) -----
summary_long <- before_after_summary %>%
  pivot_longer(cols = c(n_records, n_species, n_species_province),
               names_to = "metric", values_to = "value") %>%
  mutate(metric = recode(metric,
                          n_records = "Records",
                          n_species = "Species",
                          n_species_province = "Species-province combinations"))
p_a <- ggplot(summary_long, aes(metric, value, fill = stage)) +
  geom_col(position = position_dodge(width = 0.72), width = 0.62) +
  scale_fill_manual(values = c("Before species-province deduplication" = "#7FA2D9",
                                "After earliest-publication retention" = "#F29F67")) +
  scale_y_continuous(labels = comma) +
  labs(x = NULL, y = "Count", title = "Before-versus-after denominator changes") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), legend.position = "top",
        legend.title = element_blank())
p_b <- ggplot(identity_summary,
              aes(identity_source, n_records, fill = identity_change_flag)) +
  geom_col(width = 0.65) +
  scale_fill_manual(values = c("Name changed" = "#D55E00",
                                "No binomial change" = "#56B4E9")) +
  scale_y_continuous(labels = comma) +
  labs(x = NULL, y = "Rows", title = "Identity-audit contribution") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), legend.position = "top",
        legend.title = element_blank())
p_c <- ggplot(duplicate_drop_by_province,
              aes(reorder(province, n_dropped), n_dropped)) +
  geom_col(fill = "#6BA292", width = 0.68) +
  coord_flip() +
  scale_y_continuous(labels = comma) +
  labs(x = NULL, y = "Dropped later duplicate records",
       title = "Top provinces affected by duplicate removal") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank())
qa_plot <- (p_a | p_b) / p_c +
  plot_annotation(title = "Canonical-identity and duplicate-resolution diagnostics (keep-all-years)")
ggsave(file.path(fig_dir, "fig_qa_identity_synonym_duplicate_keepall.png"),
       qa_plot, width = 13.5, height = 9, dpi = 600, bg = "white")
ggsave(file.path(fig_dir, "fig_qa_identity_synonym_duplicate_keepall.pdf"),
       qa_plot, width = 13.5, height = 9, device = grDevices::cairo_pdf, bg = "white")

writeLines(c(
  "# 01c run summary (keep-all-years variant)",
  paste("- raw rows:", n_raw),
  paste("- year < 2000 (flagged but kept):", n_pre2000),
  paste("- final canonical events:", n_final),
  paste("- species-province duplicates removed:", sum(!dup_log$keep_record)),
  paste("- lon=lat coordinate artefacts flagged:", n_artefact)
), file.path(res_dir, "run_log_01c.md"))

cat("\n[01c] DONE — keep-all-years canonical written to:\n",
    "  ", file.path(data_dir, "bird_new_records_clean_corrected_keepall.csv"), "\n")
