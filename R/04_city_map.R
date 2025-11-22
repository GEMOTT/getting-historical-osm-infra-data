## R/04_city_maps.R
## Read files and create tmap panels for ONE city

# ---------------------------------------------------------------------
# Read perimeter
# ---------------------------------------------------------------------
read_perimeter <- function() {
  perim_path <- file.path("data", city_tag, paste0(city_tag, "_perimeter.gpkg"))
  if (!file.exists(perim_path)) stop("Perimeter file not found")
  
  sf::st_read(perim_path, layer = city_tag, quiet = TRUE) |>
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
# Build side-by-side maps for two versions (years)
# ---------------------------------------------------------------------
make_city_panel_tm <- function(city_name = NULL) {
  # 1) Perimeter
  perim <- read_perimeter()
  
  # If no city_name is passed, fall back to a global city_tag (if you use one)
  if (is.null(city_name) && exists("city_tag", inherits = TRUE)) {
    city_name <- get("city_tag", inherits = TRUE)
  }
  
  # 2) Networks for two years
  x17 <- read_infra("170101") |> add_highway_aggr(perim)
  x24 <- read_infra("240101") |> add_highway_aggr(perim)
  
  if (is.null(x17) || nrow(x17) == 0L ||
      is.null(x24) || nrow(x24) == 0L) {
    stop("One of the infra files is missing or empty")
  }
  
  # 3) Bind + add year labels
  streets <- dplyr::bind_rows(
    dplyr::mutate(x17, year = "2016"),
    dplyr::mutate(x24, year = "2023")
  ) |>
    dplyr::filter(!is.na(highway_aggr))
  
  streets$highway_aggr <- factor(
    streets$highway_aggr,
    levels = names(pal_highway_aggr)
  )
  
  # 4) Build one map per year (only first keeps legend)
  streets_16 <- dplyr::filter(streets, year == "2016")
  streets_23 <- dplyr::filter(streets, year == "2023")
  
  map_2016 <- tm_shape(perim) +
    tm_borders(col = "grey80", lwd = 0.2) +
    tm_shape(streets_16) +
    tm_lines(
      col        = "highway_aggr",
      col.scale  = tm_scale(values = pal_highway_aggr, value.na = NA),
      lwd        = 0.3,
      col_alpha  = 0.6,
      col.legend = tm_legend(title = "")   # vertical by default
    ) +
    tm_layout(
      legend.outside  = FALSE,             # put it INSIDE the map
      legend.position = c(0.05, 0.8),       # x = centre, y = 0.8 (between centre and top)
      legend.show     = TRUE,
      frame           = FALSE,
      panel.show      = FALSE
    ) +
    tm_credits(
      "2016",
      position = c("left", "top"),
      size     = 0.7,
      col      = "grey50"
    )
  
  
  map_2023 <- tm_shape(perim) +
    tm_borders(col = "grey80", lwd = 0.2) +
    tm_shape(streets_23) +
    tm_lines(
      col        = "highway_aggr",
      col.scale  = tm_scale(values = pal_highway_aggr, value.na = NA),
      lwd        = 0.3,
      col_alpha  = 0.6,
      col.legend = tm_legend(title = "")
    ) +
    tm_layout(
      main.title  = "",
      legend.show = FALSE,
      frame       = FALSE,
      panel.show  = FALSE
    ) +
    tm_credits(
      "2023",
      position = c("left", "top"),
      size     = 0.7,
      col      = "grey50"
    )
  
  # Arrange side by side: ONE legend (from map_2016)
  tmap_arrange(map_2016, map_2023, ncol = 2)
}

plot_city_panel_tm <- function(city_name = NULL) {
  tmap_mode("plot")
  print(make_city_panel_tm(city_name = city_name))
}



