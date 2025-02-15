using Oceananigans

grid = RectilinearGrid(size=128, z=(-0.5, 0.5), topology=(Flat, Flat, Bounded))

closure = ScalarDiffusivity(κ=1)

ScalarDiffusivity{ExplicitTimeDiscretization}(ν=0.0, κ=1.0)

model = NonhydrostaticModel(; grid, closure, tracers=:T)

width = 0.1
initial_temperature(z) = exp(-z^2 / (2width^2))
set!(model, T=initial_temperature)

using CairoMakie
set_theme!(Theme(fontsize = 24, linewidth=3))

fig = Figure()
axis = (xlabel = "Temperature (ᵒC)", ylabel = "z")
label = "t = 0"
lines(model.tracers.T; label, axis)
