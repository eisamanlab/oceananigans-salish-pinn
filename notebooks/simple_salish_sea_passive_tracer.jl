#model uses 2024 GEBCO bathymetry file downloaded in the repo 


import Pkg
Pkg.activate(@__DIR__)  
Pkg.instantiate()        # all dependencies are installed -- do once only

# #in case activate environment does not work
# using Pkg
# using Oceananigans
# using Oceananigans.Units
# import ClimaOcean
# using Printf
# using Dates, CFTime
# Pkg.add("Interpolations")
# Pkg.add("NCDatasets")
# Pkg.add("CairoMakie")
for pkg in ["Interpolations", "Oceananigans", "NCDatasets", "CairoMakie", "ClimaOcean"]
    if !haskey(Pkg.dependencies(), pkg)
        Pkg.add(pkg)
    end
end

using Oceananigans, Oceananigans.Units
import ClimaOcean
using Printf, Dates, CFTime, NCDatasets, CairoMakie, Interpolations

using NCDatasets
p = "[filepath]" 

#using the netcdf
ds = NCDataset(p)

println(ds)
println("Variables in dataset: ", keys(ds))
println("Dimensions: ", ds.dim)

lon = ds["lon"][:]  
lat = ds["lat"][:]  
depth = ds["elevation"][:, :] 
lat_res = abs(lat[2] - lat[1])  
lon_res = abs(lon[2] - lon[1])  

println("lat Resolution: ", lat_res, " degrees")
println("long Resolution: ", lon_res, " degrees")

close(ds)
#500 m resolution 

Nx = length(lon) 
Ny = length(lat)
Nz = 25
long_min = (minimum(lon))
long_max = (maximum(lon))
lat_min = (minimum(lat))
lat_max = (maximum(lat))
min_z = (minimum(depth))
arch = GPU() #change to GPU 

grid = LatitudeLongitudeGrid(arch,
                             size = (length(lon), length(lat), 25), 
                             halo = (7, 7, 7),  
                             longitude = (minimum(lon), maximum(lon)),
                             latitude = (minimum(lat), maximum(lat)),
                             z = (minimum(depth), 0))

# Pkg.add("Interpolations") #if needed

using Interpolations

bathymetry_interp = interpolate((lon, lat), depth, Gridded(Linear()))

bottom_height = [bathymetry_interp(lon[i], lat[j]) for i in 1:length(lon), j in 1:length(lat)]

grid = ImmersedBoundaryGrid(grid, GridFittedBottom(bottom_height))


## plots the new bathymetry (this plot does not look right)
# using CairoMakie
# longitudes = range(long_min, long_max, length=Nx) #start:step:end --> first value, step size, last value
# latitudes = range(lat_min, lat_max, length=Ny)  

# #make a map of bathymetry
# fig = Figure()
# ax  = Axis(fig[1, 1],xlabel = "Longitude", ylabel = "Latitude", aspect = 0.6)
# hm = heatmap!(longitudes, latitudes, bottom_height, colorrange = (-250, 250), colormap = :bukavu)
# cb = Colorbar(fig[1,2], hm, label = "depth (m)")
# cb.height = Relative(1.0)
# # scatter!(236.5425 - 360, 48.24, color= :red, markersize = 10)

# display(fig)


# using CairoMakie #(better plot)
# fig = Figure()
# ax = Axis(fig[1,1], title= "bathymetry")
# hm = heatmap!(ax, bathymetry_interp, colormap=:topo, colorrange=(minimum(bathymetry_interp), maximum(bathymetry_interp)))
# display(fig)
# # save bathymetry if wanted
# # save("SalishSea_bathymetry1.png", fig)

# # check resolution / might need to check variable names
# using Statistics

# km_per_degree_lon = 111.32 * cosd(mean(latitudes))  
# km_per_degree_lat = 111.32 

# Δx_M = Δλ * km_per_degree_lon *100
# Δy_M = Δφ * km_per_degree_lat  *100

# @show Δx_M, Δy_M

#finds the nearest grid indices (x,y) corresponding with a lat and long
function find_nearest_index(grid, lon, lat, z)
    ugrid = grid.underlying_grid #determined using underlying grid when inspecting grid meta data 

    lon_vals = collect(ugrid.λᶜᵃᵃ)  # centered longitude
    lat_vals = collect(ugrid.φᵃᶜᵃ)  # centered latitude
    z_vals   = collect(ugrid.zᵃᵃᶜ)  # correct depth values
    z_idx = argmin(abs.(z_vals .- z))  


    lon_idx = argmin(abs.(lon_vals .- lon)) #subtracts each long value from desired lon value & finds the index of the closest value
    lat_idx = argmin(abs.(lat_vals .- lat))

    println("Nearest indices found: lon_idx=$lon_idx, lat_idx=$lat_idx")
    return lon_idx, lat_idx, z_idx
end

z = 0
const lat_release = 48.12   
const lon_release = -123.40 

lon_idx, lat_idx, z_idx = find_nearest_index(grid, lon_release, lat_release, z)

using Oceananigans
using Oceananigans.Fields: CenterField

#from luke's code

u₁₀ = 10    # Wind speed at 10m height (m/s)
ρₒ = 1026.0 # Ocean surface density (kg/m³)
cᴰ = 2.5e-3 # Drag coefficient (dimensionless)
ρₐ = 1.225  # Air density at sea level (kg/m³)

# Define wind stress forcing (momentum flux at surface)
@inline wind_stress_x(x, y, t, p=nothing) = (- ρₐ / ρₒ * cᴰ * u₁₀ * abs(u₁₀)) * rand()
@inline wind_stress_y(x, y, t, p=nothing) = (- ρₐ / ρₒ * cᴰ * u₁₀ * abs(u₁₀)) * rand()


# Boundary conditions applying wind stress
u_top_bcs = FluxBoundaryCondition(wind_stress_x) #Adds momentum input at the surface (east-west wind)
v_top_bcs = FluxBoundaryCondition(wind_stress_y) #Adds momentum input at the surface (north-south wind)

u_bcs = FieldBoundaryConditions(top = u_top_bcs) 
v_bcs = FieldBoundaryConditions(top = v_top_bcs)

c_bcs = FieldBoundaryConditions()  # Passive tracer boundary condition


@time model = HydrostaticFreeSurfaceModel(; 
    grid = grid,
    clock = Clock{Float64}(time = 0),
    momentum_advection = VectorInvariant(),  
    tracer_advection = Centered(),
    forcing = NamedTuple(), 
    boundary_conditions = (u=u_bcs, v=v_bcs, c=c_bcs),  
    tracers = (:c,), 
    pressure = nothing,
    diffusivity_fields = nothing,
    velocities = nothing, 
    auxiliary_fields = NamedTuple(),
)



ugrid = grid.underlying_grid

#note here: setting tracer to entire associated zC column for sole purpose of simulating -- change this 

r = size(model.tracers.c, 3)  #the max valid depth index

for k in 1:r  # Ensure we don't exceed depth range
    model.tracers.c[lon_idx, lat_idx, k] = 5.0
end



## set!(model, c=c_initial) redundant if using above code

u_initial = similar(model.velocities.u) 
v_initial = similar(model.velocities.v)
w_initial = similar(model.velocities.w)

u_initial .= 0.2  # test case for simulation -- change
v_initial .= 0.0  # no flow
w_initial .= 0.0  # no flow 

set!(model.velocities.u, u_initial)
set!(model.velocities.v, v_initial)
set!(model.velocities.w, w_initial)



# #T and S: skipping this for now because ECCO not retrieving data correctly 
#confirmed user/pass for ecco but still not working 


# T = ClimaOcean.ECCOMetadata(:temperature; dates) #retreiving metadata only 
# S = ClimaOcean.ECCOMetadata(:salinity; dates)
# # FT = ECCORestoring(T, CPU(); rate=1/2days)
# # FS = ECCORestoring(S, CPU(); rate=1/2days)
# set!(ocean.model, T = ClimaOcean.ECCOMetadata(:temperature; dates),
# S = ClimaOcean.ECCOMetadata(:salinity; dates))

# ugrid = grid.underlying_grid

# x_size = length(ugrid.λᶜᵃᵃ)  # Number of longitude points
# y_size = length(ugrid.φᵃᶜᵃ)  # Number of latitude points


# # `cᵃᵃᶜ` : where tracers will be stored ( cell centers )
# depth_vals = collect(ugrid.z.cᵃᵃᶜ)
# println("Depth range: ", (minimum(depth_vals), maximum(depth_vals)))
# println("Sample depth values: ", depth_vals[1:10])


# #keep this code for checks --> prints ugrid fields 
# ugrid = grid.underlying_grid  
# println("Available fields in ugrid: ", fieldnames(typeof(ugrid)))
# println(propertynames(ugrid.z))  # all available fields inside `z`, ugrid.z.cᵃᵃᶜ contains cell center z



# # # 'z' specific
# # println("Possible depth fields: ",
# #     filter(name -> occursin("z", string(name)), propertynames(ugrid))
# # 


# #this runs for 10 days & would be full implementation: have not tried this yet 
# using Oceananigans
# using Oceananigans.OutputWriters

# simulation = Simulation(model, Δt=10minutes, stop_time=10days)

# wizard = TimeStepWizard(cfl=0.3)
# simulation.callbacks[:wizard] = Callback(wizard, IterationInterval(10))

# simulation.output_writers[:tracer] = NetCDFOutputWriter(model, model.tracers,
#                               filename = "Tracer_2_19.nc",
#                               schedule = TimeInterval(30minutes))  

# simulation.callbacks[:flush_output] = Callback(TimeInterval(60minutes)) do sim
#     println("Flushing NetCDF output at time: ", sim.model.clock.time)
#     sim.output_writers[:tracer].flush()
# end

# println("Starting simulation with NetCDF output...")
# println("Simulation will run from 0 to ", simulation.stop_time)

# run!(simulation) 

# println("Simulation complete! Output saved to 'Tracer_2_19.nc'.")


# #tests 
# @show size(model.tracers.c)
# @show model.closure
# @show extrema(model.tracers.c)
# @show sum(model.tracers.c)

#test case that I did run : 
using Oceananigans
using Oceananigans.OutputWriters

simulation = Simulation(model, Δt=10minutes, stop_time=60minutes) 

wizard = TimeStepWizard(cfl=0.2)
simulation.callbacks[:wizard] = Callback(wizard, IterationInterval(10))

simulation.output_writers[:output] = NetCDFOutputWriter(model, merge(model.tracers, model.velocities),
                              filename = "test4_output.nc", #update
                              schedule = TimeInterval(5minutes))
simulation.callbacks[:flush_output] = Callback(TimeInterval(60minutes)) do sim
    println("Checkpoint: NetCDF output written at time: ", sim.model.clock.time)
end

println("Starting short test run...")
println("Simulation will run for 1 hour of model time.")

run!(simulation) 

println("Test complete! Output saved to 'test_output.nc'.") #update






