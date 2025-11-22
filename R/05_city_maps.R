## R/04_city_maps.R
## Read files and create tmap maps for ONE city and ONE version

# ---------------------------------------------------------------------
# Read perimeter
# ---------------------------------------------------------------------
read_perimeter <- function(city_tag = get("city_tag", envir = .GlobalEnv)) {
  perim_path <- file.path("data", city_tag, paste0(city_tag, "_perimeter.gpkg"))
  if (!file.exists(perim_path)) {
    stop("Perimeter file not found: ", perim_path)
  }
  
  sf::st_read(perim_path, quiet = TRUE) |>
    sf::st_transform(4326)
}

# ---------------------------------------------------------------------
# Read lines for a specific version (full network)
# ---------------------------------------------------------------------
read_infra <- function(version,
                       city_tag = get("city_tag", envir = .GlobalEnv)) {
  gpkg <- file.path("data", city_tag, paste0(city_tag, "_", version, "_lines.gpkg"))
  lyr  <- paste0(city_tag, "_", version, "_lines")
  
  if (!file.exists(gpkg)) {
    stop("Lines file not found for version ", version)
  }
  
  sf::st_read(gpkg, layer = lyr, quiet = TRUE)
}

# ---------------------------------------------------------------------
# 1) FULL NETWORK MAP  (map 1)
# ---------------------------------------------------------------------
make_city_map_full_tm <- function(
    version    = snapshot_version,
    city_tag   = get("city_tag", envir = .GlobalEnv),
    city_name  = NULL,
    year_label = NULL
) {
  perim <- read_perimeter(city_tag)
  dat   <- read_infra(version, city_tag)
  
  # palette you want
  pal_highway_aggr <- c(
    "cycleway"      = "#E41A1C",
    "pedestrian"    = "#377EB8",
    "living street" = "#4DAF4A",
    "others"        = "grey"
  )
  
  # aggregate + assign hex colour
  dat <- dat |>
    dplyr::mutate(
      highway_aggr = dplyr::case_when(
        highway %in% c("cycleway", "track") ~ "cycleway",
        highway %in% "pedestrian"           ~ "pedestrian",
        highway %in% "living_street"        ~ "living street",
        TRUE                                ~ "others"
      ),
      col_hex = unname(pal_highway_aggr[highway_aggr])
    )
  
  # split into background (others) and foreground (cycle infra etc.)
  dat_bg <- dat |>
    dplyr::filter(highway_aggr == "others")
  
  dat_fg <- dat |>
    dplyr::filter(highway_aggr != "others")
  
  if (is.null(city_name))  city_name  <- city_tag
  if (is.null(year_label)) year_label <- version
  
  tmap::tm_shape(perim) +
    tmap::tm_polygons(col = NA, border.col = "grey80", border.lwd = 0.4) +
    
    # background network (grey "others")
    tmap::tm_shape(dat_bg) +
    tmap::tm_lines(
      col        = "col_hex",
      lwd        = 0.5,
      alpha      = 0.5,
      col.scale  = NULL,
      col.legend = NULL
    ) +
    
    # foreground network (cycleway / pedestrian / living street)
    tmap::tm_shape(dat_fg) +
    tmap::tm_lines(
      col        = "col_hex",
      lwd        = 1.0,
      alpha      = 0.9,
      col.scale  = NULL,
      col.legend = NULL
    ) +
    # manual legend
    tmap::tm_add_legend(
      type     = "line",
      col      = unname(pal_highway_aggr),
      labels   = names(pal_highway_aggr),
      title    = "Network types",
      position = c("left", "center")
    ) +
    tmap::tm_title(
      paste0(city_name, " ", year_label, ": full network"),
      position = "top",
      size     = 1,
      fontface = "bold"
    ) +
    tmap::tm_layout(
      legend.outside = FALSE,
      frame          = FALSE
    )
}

plot_city_map_full_tm <- function(
    version    = snapshot_version,
    city_name  = NULL,
    year_label = NULL
) {
  tmap::tmap_mode("plot")
  m <- make_city_map_full_tm(
    version    = version,
    city_name  = city_name,
    year_label = year_label
  )
  print(m)
}

# ---------------------------------------------------------------------
# 2) CYCLING MAP – TAG BASED (map 2)
# ---------------------------------------------------------------------
make_city_map_cycling_tag_tm <- function(
    version    = snapshot_version,
    city_tag   = get("city_tag", envir = .GlobalEnv),
    city_name  = NULL,
    year_label = NULL
) {
  perim <- read_perimeter(city_tag)
  dat   <- read_cycling_network(
    method   = "osmextract",
    version  = version,
    city_tag = city_tag
  )
  
  # palette for cycling infra
  pal_cycling <- c(
    "off_road_path"   = "#1b9e77",
    "protected_track" = "#7570b3",
    "painted_lane"    = "#d95f02",
    "shared_footway"  = "#e7298a"
  )
  
  dat <- dat |>
    dplyr::filter(!is.na(infra_simple)) |>
    dplyr::mutate(
      infra_simple = factor(infra_simple, levels = names(pal_cycling)),
      col_hex      = unname(pal_cycling[infra_simple])  # direct hex mapping
    )
  
  if (is.null(city_name))  city_name  <- city_tag
  if (is.null(year_label)) year_label <- version
  
  tmap::tm_shape(perim) +
    tmap::tm_polygons(col = NA, border.col = "grey80", border.lwd = 0.4) +
    tmap::tm_shape(dat) +
    tmap::tm_lines(
      col   = "col_hex",   # use hex codes directly
      lwd   = 1,
      alpha = 0.8,
      col.scale  = NULL,
      col.legend = NULL
    ) +
    tmap::tm_add_legend(
      type     = "line",
      col      = unname(pal_cycling),
      labels   = names(pal_cycling),
      title    = "Cycling network types",
      position = c("left", "center")
    ) +
    tmap::tm_title(
      paste0(city_name, " ", year_label, ": cycling network (tag based)"),
      position = "top",
      size     = 1,
      fontface = "bold"
    ) + 
    tmap::tm_layout(
      legend.outside = FALSE,
      frame          = FALSE
    )
}

plot_city_map_cycling_tag_tm <- function(
    version    = snapshot_version,
    city_name  = NULL,
    year_label = NULL
) {
  tmap::tmap_mode("plot")
  m <- make_city_map_cycling_tag_tm(
    version    = version,
    city_name  = city_name,
    year_label = year_label
  )
  print(m)
}

# ---------------------------------------------------------------------
# 3) CYCLING MAP – OSMACTIVE (map 3)
# ---------------------------------------------------------------------
make_city_map_cycling_osmactive_tm <- function(
    version    = snapshot_version,
    city_tag   = get("city_tag", envir = .GlobalEnv),
    city_name  = NULL,
    year_label = NULL
) {
  perim <- read_perimeter(city_tag)
  dat   <- read_cycling_network(
    method   = "osmactive",
    version  = version,
    city_tag = city_tag
  )
  
  # same palette for comparison
  pal_cycling <- c(
    "off_road_path"   = "#1b9e77",
    "protected_track" = "#7570b3",
    "painted_lane"    = "#d95f02",
    "shared_footway"  = "#e7298a"
  )
  
  dat <- dat |>
    dplyr::filter(!is.na(infra_simple)) |>
    dplyr::mutate(
      infra_simple = factor(infra_simple, levels = names(pal_cycling)),
      col_hex      = unname(pal_cycling[infra_simple])  # direct hex mapping
    )
  
  if (is.null(city_name))  city_name  <- city_tag
  if (is.null(year_label)) year_label <- version
  
  tmap::tm_shape(perim) +
    tmap::tm_polygons(col = NA, border.col = "grey80", border.lwd = 0.4) +
    tmap::tm_shape(dat) +
    tmap::tm_lines(
      col   = "col_hex",
      lwd   = 1,
      alpha = 0.8,
      col.scale  = NULL,
      col.legend = NULL
    ) +
    tmap::tm_add_legend(
      type     = "line",
      col      = unname(pal_cycling),
      labels   = names(pal_cycling),
      title    = "Cycling network types",
      position = c("left", "center")
    ) +
    tmap::tm_title(
      paste0(city_name, " ", year_label, ": cycling network (osmactive)"),
      position = "top",
      size     = 1,
      fontface = "bold"
    ) +
    tmap::tm_layout(
      legend.outside = FALSE,
      frame          = FALSE
    )
}

plot_city_map_cycling_osmactive_tm <- function(
    version    = snapshot_version,
    city_name  = NULL,
    year_label = NULL
) {
  tmap::tmap_mode("plot")
  m <- make_city_map_cycling_osmactive_tm(
    version    = version,
    city_name  = city_name,
    year_label = year_label
  )
  print(m)
}









