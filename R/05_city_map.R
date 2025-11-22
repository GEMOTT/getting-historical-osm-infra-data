## R/04_city_maps.R
## Read files and create tmap maps for ONE city and ONE version

# ---------------------------------------------------------------------
# Read perimeter
# ---------------------------------------------------------------------
read_perimeter <- function() {
  perim_path <- file.path("data", city_tag, paste0(city_tag, "_perimeter.gpkg"))
  if (!file.exists(perim_path)) {
    stop("Perimeter file not found: ", perim_path)
  }
  
  sf::st_read(perim_path, quiet = TRUE) |>
    sf::st_transform(4326)
}

# ---------------------------------------------------------------------
# Read lines for a specific version
# ---------------------------------------------------------------------
read_infra <- function(version) {
  gpkg <- file.path("data", city_tag, paste0(city_tag, "_", version, "_lines.gpkg"))
  lyr  <- paste0(city_tag, "_", version, "_lines")
  
  if (!file.exists(gpkg)) {
    warning("Lines file not found for version ", version)
    return(NULL)
  }
  
  tryCatch(
    sf::st_read(gpkg, layer = lyr, quiet = TRUE),
    error = function(e) NULL
  )
}

# ---------------------------------------------------------------------
# Build a single map for ONE snapshot (version)
# ---------------------------------------------------------------------
make_city_map_tm <- function(version    = snapshot_version,
                             city_name  = NULL,
                             year_label = NULL) {
  # 1) Perimeter
  perim <- read_perimeter()
  
  # Fallback to global city_name if not passed
  if (is.null(city_name) && exists("city_name", inherits = TRUE)) {
    city_name <- get("city_name", inherits = TRUE)
  }
  
  # 2) Read network for this version and classify
  streets <- read_infra(version) |>
    add_highway_aggr(perim) |>
    dplyr::filter(!is.na(highway_aggr))
  
  if (is.null(streets) || nrow(streets) == 0L) {
    stop("Infrastructure file is missing or empty for version ", version)
  }
  
  streets$highway_aggr <- factor(
    streets$highway_aggr,
    levels = names(pal_highway_aggr)
  )
  
  # Split into grey "others" and coloured categories
  streets_grey <- streets |> dplyr::filter(highway_aggr == "others")
  streets_col  <- streets |> dplyr::filter(highway_aggr != "others")
  
  # If no explicit year_label is given, use the version in the title
  if (is.null(year_label)) year_label <- version
  
  # 3) Plot with tmap v4
  tm_shape(perim) +
    tm_borders(col = "grey80", lwd = 0.2) +
    
    # Base grey streets
    tm_shape(streets_grey) +
    tm_lines(
      col = "grey80",
      lwd = 0.3,
      col_alpha = 0.4,
      legend.show = FALSE
    ) +
    
    # Colored streets - force to top with zindex
    tm_shape(streets_col) +
    tm_lines(
      col = "highway_aggr",
      col.scale = tm_scale(values = pal_highway_aggr, value.na = NA),
      lwd = 1.2,
      col_alpha = 0.8,
      col.legend = tm_legend(
        title = "",
        frame = FALSE,
        frame.lwd = 0,
        bg.color = NA
      )
    ) +
    
    tm_title(
      paste0(city_name, " ", year_label),
      position = "top",
      size = 1,
      fontface = "bold"
    ) +
    tm_layout(
      legend.outside = FALSE,
      legend.position = c("left", "top"),
      frame = FALSE,
      panel.show = FALSE
    )
}

plot_city_map_tm <- function(version    = snapshot_version,
                             city_name  = NULL,
                             year_label = NULL) {
  tmap_mode("plot")
  m <- make_city_map_tm(
    version    = version,
    city_name  = city_name,
    year_label = year_label
  )
  print(m)
}

