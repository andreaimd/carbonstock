#Creating grid of 1 km2 cells for San Martin, Peru.
#The boundary comes from GADM and the grid is built with sf.
#Output: grid.shp
##############################################################################

#LIBRARIES
rm(list = ls())
pacman::p_load(sf, dplyr, geodata)


#PATH
main <- "./"


#Load----
#Extract San Martin department boundaries from GADM. Level 1 of GADM are the departments.
sm <- geodata::gadm("PER", level = 1, path = tempdir()) %>%
  st_as_sf() %>%
  filter(NAME_1 == "San Martín") %>%
  st_transform(32718)    #UTM Zone 18S


#Functions used
#st_as_sf turns the downloaded boundary into an sf object: a table with a geometry column
#st_transform changes the coordinate system. UTM zone 18S covers all of San Martin and measures in meters


#Create grids----
#For UTM
grid <- st_make_grid(sm, cellsize = c(1000, 1000), what = "polygons", square = TRUE)
grid <- st_as_sf(grid)

#Cut
grid <- grid[sm,]

#id
grid <- as_tibble(grid) #it needs to be tibble to apply select
grid <- grid %>% mutate(id = row_number()) %>% dplyr::select(id, everything())


#Functions used
#st_make_grid builds square cells that cover the bounding box of an object. The cell size is in the units of the coordinate system so c(1000, 1000) means 1km2.
#what = "polygons" gives square cells. "centers" and "corners" would create points at the middle of each cell and at the corners of the cells.
#square = FALSE would give hexagons.
#grid[sm,] keeps only the cells that touch the boundary. The cells stay whole, so the ones on the border are partly outside of the boundary.


#Save----
dir.create(paste0(main, "data/int/grid"), showWarnings = FALSE, recursive = TRUE)
st_write(grid, paste0(main,"data/int/grid/grid.shp"))

#Load
grid <- st_read(paste0(main,"data/int/grid/grid.shp"))


#Functions used
#st_write saves a spatial object as a file
#st_read reads a spatial file into R