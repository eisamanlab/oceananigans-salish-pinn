using Pkg
Pkg.activate("../oceananigans-env")

using Oceananigans
using Oceananigans.Units
using Dates, CFTime
import ClimaOcean

arch = GPU()
grid = LatitudeLongitudeGrid(arch,
                             size = (1440, 560, 10),
                             halo = (7, 7, 7),
                             longitude = (0, 360),
                             latitude = (-70, 70),
                             z = (-3000, 0))

bathymetry = ClimaOcean.regrid_bathymetry(grid) # builds gridded bathymetry based on ETOPO1
grid = ImmersedBoundaryGrid(grid, GridFittedBottom(bathymetry))

# Build an ocean simulation initialized to the ECCO state estimate on Jan 1, 1993
ocean = ClimaOcean.ocean_simulation(grid)
dates = DateTimeProlepticGregorian(1993, 1, 1)
set!(ocean.model, T = ClimaOcean.ECCOMetadata(:temperature; dates),
                  S = ClimaOcean.ECCOMetadata(:salinity; dates))

# Build and run an OceanSeaIceModel (with no sea ice component) forced by JRA55 reanalysis
atmosphere = ClimaOcean.JRA55PrescribedAtmosphere(arch)
coupled_model = ClimaOcean.OceanSeaIceModel(ocean; atmosphere)
simulation = Simulation(coupled_model, Δt=5minutes, stop_time=2days)
run!(simulation)




