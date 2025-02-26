# Salish Sea Simulation on Grace

This contains code, submit script, and environment files to run a simulation. 
The simuation is based on example experiments provided by Clima. 
This is mainly based on the one-degree global simulation. 

Use the following to submit a run to the cluser:

```sh
sbatch submit.sbatch
```

Note you will need to modify some paths in this script


## Things to fix

* Add a sponge layer at the open boundaries
* Initialize the tracer after the spinup
* Add simple ecosystem model, start with NPZD
