#!/usr/bin/env Rscript

# ============================================================
# Assemble Figure 2 composite locally: EMF maps + eoffice sankey
# 本地拼合 Figure 2：EMF 矢量地图 + eoffice 可编辑 sankey
# ============================================================

suppressPackageStartupMessages({
  library(officer)
  library(xml2)
})

FIG_DIR <- "/Users/dingchenchen/Documents/NEW DISTRIBUTION RECORDS/figures"
OUT_PATH <- file.path(FIG_DIR, "figure2_combined_editable.pptx")

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

emf_a_main  <- file.path(FIG_DIR, "fig2_a_main.emf")
emf_a_inset <- file.path(FIG_DIR, "fig2_a_inset.emf")
emf_b_main  <- file.path(FIG_DIR, "fig2_b_main.emf")
emf_b_inset <- file.path(FIG_DIR, "fig2_b_inset.emf")
sankey_pptx <- file.path(FIG_DIR, "fig2c_sankey_eoffice.pptx")

stopifnot(all(file.exists(c(emf_a_main, emf_a_inset, emf_b_main, emf_b_inset, sankey_pptx))))

cat("Assembling Figure 2 composite PPTX...\n")

# Step 1. Create blank slide with custom size
ppt <- read_pptx()
ppt <- add_slide(ppt, layout = "Blank", master = "Office Theme")
prs <- ppt
prs$slide_size$cx <- slide_w * 914400
prs$slide_size$cy <- slide_h * 914400

# Step 2. Insert EMF maps
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

# Step 3. Panel labels
add_label <- function(ppt, text, x, y) {
  ph_with(ppt,
    fpar(ftext(text, fp_text(font.size = 16, bold = TRUE, color = "#222222"))),
    location = ph_location(left = x, top = y, width = 0.5, height = 0.3))
}
ppt <- add_label(ppt, "(a)", 0.06, 0.06)
ppt <- add_label(ppt, "(b)", half_w + gap_in + 0.06, 0.06)
ppt <- add_label(ppt, "(c)", 0.06, top_h + gap_in + 0.05)

# Step 4. Extract DrawingML from eoffice sankey PPTX and insert
# eoffice's topptx embeds the plot as a GraphicFrame with DrawingML.
# We extract the GraphicFrame from slide1 and insert it into our composite.
# 从 eoffice PPTX 的 slide1 中提取 GraphicFrame (DrawingML) 并插入当前 slide

cat("Extracting DrawingML from eoffice sankey PPTX...\n")
tmp_dir <- tempfile()
dir.create(tmp_dir)
unzip(sankey_pptx, exdir = tmp_dir)

slide1_xml <- file.path(tmp_dir, "ppt/slides/slide1.xml")
slide1_doc <- xml2::read_xml(slide1_xml)
spTree <- xml2::xml_find_first(slide1_doc, "/p:sld/p:cSld/p:spTree")
children <- xml2::xml_children(spTree)

# Filter out nvGrpSpPr and grpSpPr, keep the plot GraphicFrame(s)
plot_nodes <- children[!xml2::xml_name(children) %in% c("nvGrpSpPr", "grpSpPr")]
cat("Found", length(plot_nodes), "plot node(s) in sankey slide\n")

# Get the slide XML of our composite
composite_slide <- ppt$slide$get_slide(1)
composite_xml <- composite_slide$get()
composite_spTree <- xml2::xml_find_first(composite_xml, "/p:sld/p:cSld/p:spTree")

# Reposition the sankey DrawingML to bottom panel
# We need to set the GraphicFrame's xfrm offset/ext to match our layout
for (node in plot_nodes) {
  # Clone the node via read_xml(as.character()) since xml2 lacks xml_clone
  cloned <- xml2::read_xml(as.character(node))

  # Find the xfrm (transform) and set position/size
  xfrm <- xml2::xml_find_first(cloned, ".//a:xfrm")
  if (!is.na(xfrm)) {
    # Set offset and ext for bottom panel
    off <- xml2::xml_find_first(xfrm, "a:off")
    ext <- xml2::xml_find_first(xfrm, "a:ext")
    if (!is.na(off)) {
      xml2::xml_set_attr(off, "x", as.character(round(0 * 12700)))           # left = 0 EMU
      xml2::xml_set_attr(off, "y", as.character(round((top_h + gap_in) * 914400)))
    }
    if (!is.na(ext)) {
      xml2::xml_set_attr(ext, "cx", as.character(round(slide_w * 914400)))
      xml2::xml_set_attr(ext, "cy", as.character(round(bot_h * 914400)))
    }
  }

  # Add to composite slide
  xml2::xml_add_child(composite_spTree, cloned)
}

# Write modified slide XML back
xml2::write_xml(composite_xml, file.path(tmp_dir, "ppt/slides/slide1_composite.xml"))

# Save the PPTX (officer will handle packaging)
print(ppt, target = OUT_PATH)

# Cleanup
unlink(tmp_dir, recursive = TRUE)

cat("✓ Figure 2 composite saved to:", OUT_PATH, "\n")
