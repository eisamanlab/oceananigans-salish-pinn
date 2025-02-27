# Notebooks

This directory contains all of our Jupyter notebooks. These are used for testing code and generating figures

## Using Jupyterlab with Julia on Grace

The following steps outline how to setup a Julia environment on Grace

1. log into the devel partition

```sh
salloc -c4 -p devel
```

2. Load minicoda

```sh
module load miniconda
```

3. Create a new environment

```sh
conda create --name julia_jupyter python jupyter jupyterlab
```

4. update the ycrc conda environments

```sh
ycrc_conda_env.sh update
```
5. Activate your environment


```sh
conda activate julia_jupyter
```

6. Load julia. When this was written we were using julia version 1.11.3

```sh
module load Julia/1.11.3-linux-x86_64
```

7. install IJulia. Type `julia` to open the REPL. In the REPL type `]` to open the package manager then type `add IJulia` 

8. When you launch Jupyter from [Open OnDemand](https://docs.ycrc.yale.edu/clusters-at-yale/access/ood/) you must add `Julia/1.11.3-linux-x86_64` in the "additional modules" box.

9. When Jupyter launches you can select the Julia kernel from the launcher

