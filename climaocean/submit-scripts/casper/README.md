# submit script for Casper

Use the following to submit jobs to the clsuter

```sh
qsub submit.pbs

```
Use the following to check job status

```sh
qstat -u <username>
```
Use the following to see what environements a specific module needs (in this case what do we need to load to activate julia/1.11.2)
```sh
module spider julia/1.11.2
```
## Notes
* NCAR documentation on using [Portable Batch System (PBS)](https://ncar-hpc-docs.readthedocs.io/en/latest/pbs/job-scripts/)

