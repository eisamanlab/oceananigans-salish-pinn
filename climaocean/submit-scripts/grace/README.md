# Submitting Slurm Script

Use the following to submit a run to the cluser. Is it good practice to run jobs on a compute node and save unprocessed output to `palmer_scratch`. Output files can get large, especially if saving full 3D fields.

**Submit job to cluster**

```sh
sbatch submit.sbatch
```

While a job is running, output logs are saved to `slurm-JOBID.out`. You can `tail` this file to checkup on the running simulation.

**Check status of job**

```sh
squeue --me
```

**Efficiency report of completed job**

```sh
seff <jobid>
```


## Notes
* YCRC documentation on using [Simple Linux Utility for Resource Management (SLURM)](https://docs.ycrc.yale.edu/clusters-at-yale/job-scheduling/)
* You may need to modify some of the path in the slurm script
