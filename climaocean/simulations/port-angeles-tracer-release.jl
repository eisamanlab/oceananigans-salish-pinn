#=
Tracer release in Salish Sea 
using ECCO initialization and forced using JRA55
passive tracer initialized to unity in surface cells at start of simulation
before spinup

author:     Luke Gloege
date:       2024-12-24

improvementes:
* tracer should be set after the spinup
* need to add a sponge layer at the open boundaries
* add simple ecosystem model, start with NPZD
=#

#using Pkg
#Pkg.activate(".")

using ClimaOcean
using ClimaOcean.ECCO
using ClimaOcean.ECCO: ECCO4Monthly, NearestNeighborInpainting
using CFTime
using Dates
using Oceananigans
using Oceananigans.Units
using Oceananigans.Units: minute, minutes, hour, hours, day, days, meter, meters, kilometer, kilometers
using Printf
using CUDA: @allowscalar, device!


# --------------------------------------------------
# computing architecture
# --------------------------------------------------
arch = GPU()

# --------------------------------------------------
# grid
# --------------------------------------------------
latitude_range = (47, 51)
longitude_range = (234, 239)

# z grid
z_faces = stretched_vertical_faces(;
    depth = 2000, 
    surface_layer_Δz = 2.5,
    surface_layer_height = 25,
    stretching = PowerLawStretching(1.070)
)

# Number of latitude (φ) and longitude (λ) points
# The resolution is 1 / points_per_degree
points_per_degree = 25
Nφ = points_per_degree * (latitude_range[2] - latitude_range[1])
Nλ = points_per_degree * (longitude_range[2] - longitude_range[1])
Nz = length(z_faces) - 1

grid = LatitudeLongitudeGrid(
    arch, 
    size = (Nλ, Nφ, Nz),
    latitude = latitude_range,
    longitude = longitude_range,
    z = z_faces,
    halo = (7, 7, 7)
)

# --------------------------------------------------
# create bathymetry 
# apply ImmersedBoundaryGrid
# --------------------------------------------------
bathymetry = ClimaOcean.regrid_bathymetry(grid;
    interpolation_passes = 40,
    major_basins = 1
)

grid = ImmersedBoundaryGrid(grid, GridFittedBottom(bathymetry)) 

# --------------------------------------------------
# Temperature and salinity restoring force
# --------------------------------------------------
#    :temperature
#    :salinity
#    :u_velocity
#    :v_velocity
#    :free_surface
#    :sea_ice_thickness     
#    :sea_ice_area_fraction
#    :net_heat_flux         

restoring_rate  = 1 / 2days

dates = DateTimeProlepticGregorian(2000, 1, 1) : Month(1) : DateTimeProlepticGregorian(2004, 12, 1)

temperature = ECCOMetadata(:temperature, dates, ECCO4Monthly())
salinity    = ECCOMetadata(:salinity,    dates, ECCO4Monthly())

FT = ECCORestoring(temperature, arch; rate=restoring_rate, inpainting=NearestNeighborInpainting(50))
FS = ECCORestoring(salinity, arch;    rate=restoring_rate, inpainting=NearestNeighborInpainting(50))

# --------------------------------------------------
# boundary conditions
# --------------------------------------------------
c_bcs = FieldBoundaryConditions()

# --------------------------------------------------
# ocean model
# --------------------------------------------------
#momentum_advection = VectorInvariant()
#tracer_advection   = Centered(order=2)

#free_surface = SplitExplicitFreeSurface(grid; substeps=30)

ocean = ocean_simulation(grid;
#	momentum_advection, 
#	tracer_advection, 
#	free_surface,
    forcing = (T = FT, S = FS),
    tracers = (:T, :S, :c),
    boundary_conditions = (c = c_bcs,)
) 

# --------------------------------------------------
# initial conditions
# ToDo!! set tracer concentration after spinup
# --------------------------------------------------
# index of tracer release
lat_index = searchsortedfirst(grid.φᵃᶜᵃ, 48.22)
lon_index = searchsortedfirst(grid.λᶜᵃᵃ, -123.40 + 360)
surface_z_index = grid.Nz        

# initialize tracer values to zero
c_initial = ocean.model.tracers.c 

# set initial concentration to 10 mol / m3 near Port Angelesl
@allowscalar c_initial[lon_index, lat_index, surface_z_index] = 100

#date = DateTimeProlepticGregorian(2000, 1, 1)
#set!(ocean.model, T=ECCOMetadata(:temperature; dates=date),
#                  S=ECCOMetadata(:salinity; dates=date))

# sets temperature and salinity based on ECCO2 
# don't reallly like this, like the commented out approach above
set!(ocean.model, T = temperature[1], S = salinity[1], c = c_initial) 

# --------------------------------------------------
# Prescribed atmosphere and radiation
# --------------------------------------------------
# Next we build a prescribed atmosphere state and radiation model,
# which will drive the ocean simulation. We use the default `Radiation` model,
# The radiation model specifies an ocean albedo emissivity to compute the net radiative
# fluxes. The default ocean albedo is based on Payne (1982) and depends on cloud cover
# (calculated from the ratio of maximum possible incident solar radiation to actual
# incident solar radiation) and latitude. The ocean emissivity is set to 0.97.

radiation = Radiation(arch)

# The atmospheric data is prescribed using the JRA55 dataset.
# The JRA55 dataset provides atmospheric data such as temperature, humidity, and winds
# to calculate turbulent fluxes using bulk formulae, see [`CrossRealmFluxes`](@ref).
# The number of snapshots that are loaded into memory is determined by
# the `backend`. Here, we load 41 snapshots at a time into memory.

atmosphere = JRA55PrescribedAtmosphere(arch; backend=JRA55NetCDFBackend(41))

# --------------------------------------------------
# Coupled simulation
# --------------------------------------------------
# Assemble the ocean, atmosphere, and radiation into a coupled model,

coupled_model = OceanSeaIceModel(ocean; atmosphere, radiation)

# Create a coupled simulation. 
# We start with a small-ish time step of 90 seconds
# We run the simulation for 10 days with this small-ish time step.

simulation = Simulation(coupled_model; Δt=60, stop_time=10days)

# --------------------------------------------------
# callbacks
# --------------------------------------------------
function progress(sim)
    ocean = sim.model.ocean 
    u, v, w = ocean.model.velocities
    T, S = ocean.model.tracers

    @info @sprintf("Time: %s, Iteration %d, Δt %s, max(vel): (%.2e, %.2e, %.2e), max(T, S): %.2f, %.2f\n",
                   prettytime(sim.model.clock.time),
                   sim.model.clock.iteration,
                   prettytime(sim.Δt),
                   maximum(abs, u), maximum(abs, v), maximum(abs, w),
                   maximum(abs, T), maximum(abs, S))
end

simulation.callbacks[:progress] = Callback(progress, IterationInterval(10))

# --------------------------------------------------
# Run the real simulation
# --------------------------------------------------
# Now that the solution has adjusted to the bathymetry we can ramp up the time
# step size. We use a `TimeStepWizard` to automatically adapt to a CFL of 0.2.

wizard = TimeStepWizard(; cfl = 0.2, max_Δt = 10minutes, max_change = 1.1)

ocean.callbacks[:wizard] = Callback(wizard, IterationInterval(10))

# --------------------------------------------------
# output writer
# --------------------------------------------------
# We define output writers to save the simulation data at regular intervals.
# In this case, we save ocean tracers at a relatively high frequency (every day).
# The `indices` keyword argument allows us to save only a slice of the three dimensional variable.
# Below, we use `indices` to save only the values of the variables at the surface

filename = "test-release_$(string(today()))"

outputs = merge(ocean.model.tracers, ocean.model.velocities)

ocean.output_writers[:surface_slice_writer] = NetCDFOutputWriter(
    ocean.model, outputs;
    filename = filename * ".nc",
    schedule = AveragedTimeInterval(1day, window=1day),
    indices=(:, :, grid.Nz),
    #with_halos = true,
    overwrite_existing = true,
    array_type = Array{Float32}
)

# --------------------------------------------------
# Spinning up the simulation
# --------------------------------------------------
# We spin up the simulation with a small-ish time-step to resolve the "initialization shock"
# associated with starting from ECCO2 initial conditions that are both interpolated and also
# satisfy a different dynamical balance than our simulation. 
# The bathymetry might also have little mismatches that might crash the simulation. 
# We warm up the simulation with a little time step for few iterations 
# to allow the solution to adjust to the new grid bathymetry.

run!(simulation)

# --------------------------------------------------
# Running the simulation for real
# --------------------------------------------------
# After the initial spin up of 10 days, we can increase the time-step and run for longer.

simulation.stop_time = 1095days
simulation.Δt = 5minutes
run!(simulation)
