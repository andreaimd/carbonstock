#Zonal statistics with exactextractr
#The chosen example shp is Aboveground biomass in the year 2000 (Mg/ha) from Global Forest Watch
#Inputs: grid.shp and free Global Forest Watch key saved (see README).
#Output: agb_cells.csv
##############################################################################

##LIBRARIES
rm(list = ls())
pacman::p_load(sf, dplyr, httr, readr, terra, exactextractr, geodata)


##PATH
main <- "./"


#San Martin boundaries----
sm <- geodata::gadm("PER", level = 1, path = tempdir()) %>%
  st_as_sf() %>%
  filter(NAME_1 == "San Martín")
sm <- st_make_valid(st_transform(sm, 32718))
bb <- st_bbox(sm)
env <- paste(bb["xmin"], bb["ymin"], bb["xmax"], bb["ymax"], sep = ",")


#Functions used:
#st_make_valid repairs shapes with errors, like a boundary that crosses itself. GADM boundaries are usually valid, so here it is a safeguard before st_union.
#In lat and long, sf checks shapes more strictly, so an invalid one can stop st_intersects and st_union.
#st_bbox gets the box that surrounds the boundary. 


#Identify tiles in San Martin----
base3 <- "https://services2.arcgis.com/g8WusZB13b9OegfU/ArcGIS/rest/services/Aboveground_Live_Woody_Biomass_Density/FeatureServer/0"

r <- GET(paste0(base3, "/query"), query = list(
  where = "1=1", geometry = env, geometryType = "esriGeometryEnvelope", inSR = 32718,
  spatialRel = "esriSpatialRelIntersects", outFields = "tile_id",
  returnGeometry = "true", outSR = 32718, f = "geojson"))

tiles <- st_read(content(r, as = "text", encoding = "UTF-8"), quiet = TRUE)
tiles_sf <- tiles[lengths(st_intersects(tiles, st_union(sm))) > 0, ]
ids <- tiles_sf$tile_id
print(ids)


#Functions used:
#st_bbox  is in meters, so the request says inSR = 32718 to tell the service the units. If not specified, the service assumes it's own coordinate system.
#st_union dissolves the boundary of San Martin into one shape, so when tiles are checked, each one is only checked once.
#st_intersects tells which tiles touch San Martin. The service returns the tiles that touch the box, so some lie outside the boundary and this step removes them


#Download tiles in San Martin----
key <- Sys.getenv("GFW_KEY")   #each user creates their own key in a Global Forest Watch account
links <- paste0("https://data-api.globalforestwatch.org/dataset/whrc_aboveground_woody_biomass_stock_2000/v1.4/download/geotiff?grid=10/40000&tile_id=",
                ids, "&pixel_meaning=Mg_ha-1&x-api-key=", key)
#One link per tile. If the key is empty, the link ends in x-api-key= and the server answers 403. If the coordinate system does not match in the identification step
#the ids will be empty and the server answers 403.

options(timeout = 7200) #the tiles are large, so R needs more than the default time to download them
dir.create(paste0(main, "data/raw/co2/tiles"), showWarnings = FALSE, recursive = TRUE)

for (i in seq_along(ids)) {
  f <- paste0(main, "data/raw/co2/tiles/", ids[i], ".tif")
  if (!file.exists(f)) download.file(links[i], destfile = f, mode = "wb")
}
#The loop downloads each tile once. If a file already exists, it is skipped. Therefore, the loop can be run again after an error.


#Cut the tiles to San Martin boundaries----
#The tile comes in latitude and longitude, so the San Martin boundary has to be transformed momentarily to lat and long for the crop and the mask.
sm <- st_transform(sm, 4326)

tiles <- list()
for (i in seq_along(ids)) {
  tiles[[i]] <- crop(rast(paste0(main, "data/raw/co2/tiles/", ids[i], ".tif")), ext(vect(sm)))
}
r <- if (length(tiles) > 1) do.call(merge, tiles) else tiles[[1]]
#In this case there is only 1 tile, so this line is only creating the raster. If there were more, it would be also merge them.
r <- mask(r, vect(sm))



#Zonal statistics----
grid <- st_read(paste0(main, "data/int/grid/grid.shp"))

#Extract the main statistics of biomass per cell: mean, median, minimum, maximum, standard deviation and count. Count is the sum of the pixel shares inside the cell, so edge pixels count by their share.
agb <- exact_extract(r, st_transform(grid, 4326), fun = c("mean", "median", "min", "max", "stdev", "count"), append_cols = "id")

#Calculates the total biomass per cell: the mean in Mg/ha times the 100 ha of a 1 km2 cell.
agb <- data.frame(id = agb$id, mean = agb$mean, median = agb$median, min = agb$min,
                  max = agb$max, sd = agb$stdev, pixel = agb$count, total_mg = agb$mean * 100)


#Functions used:
#exact_extract weights each pixel by the share inside the cell and summarizes the raster inside each cell according to an specific operation:
#mean, median, minimum, maximum, standard deviation, count and frac.


#Classify the cells into high, medium or low biomass according to their means----
#This are arbitrary limits for the purpose of this example.
rcl <- matrix(c(0, 50, 1,
                50, 150, 2,
                150, Inf, 3), ncol = 3, byrow = TRUE)
r <- classify(r, rcl, include.lowest = TRUE)

#frac gives the share of each class in the cell, weighted by how much of each pixel is inside the cell
share <- exact_extract(r, st_transform(grid, 4326), fun = "frac", append_cols = "id") %>%
  rename(low = frac_1, medium = frac_2, high = frac_3)
agb <- agb %>% left_join(share, by = "id")


#Calculate carbon stock----
#carbon and CO2 stock per cell in Mg. 0.47 is the carbon fraction of dry biomass and 44/12 turns carbon into CO2
agb$carbon <- agb$total_mg * 0.47
agb$co2 <- agb$carbon * 44 / 12



#Map of mean co2 per cell----
grid <- grid %>% left_join(agb, by = "id")

map <- ggplot() +
  geom_sf(data = grid, aes(fill = mean), color = NA) +
  scale_fill_viridis_c(name = "Biomass (Mg/ha)")

dir.create(paste0(main, "graphs"), showWarnings = FALSE, recursive = TRUE)
ggsave(paste0(main, "graphs/biomass_map.png"), plot = map, width = 8, height = 8, dpi = 150)


#Save----
dir.create(paste0(main, "data/int/agb"), showWarnings = FALSE, recursive = TRUE)
write_csv(agb, paste0(main, "data/int/agb/agb.csv"))


#Load
agb <- read_csv(paste0(main, "data/int/agb/agb.csv"))