# Oceananigans Salish Sea PINN

This repository contains all the code used in the NCAR hacakathon for Team SNL. The goal of the project is to run a regional tracer release simulation in the Salish Sea and emulate the output using a physics-informed neural network (PINN).

## Repository Structure

The tree below outlines the structure of this repo.

```
├── LICENSE               <-- Repo license file
├── README.md             <-- Top-level documentation
├── notebooks/            <-- Jupyter notebooks
├── oceananigans-env/     <-- julia environment files
│   └── Project.toml
├── simulation-output/    <-- NetCDF output from the simulations
└── simulations/          <-- Oceananigans simulation code 
```

## Setup SSH key
This is only for the maintainers of this repository

1.  Run the following command in your terminal to show your SSH public key

```bash
more ~/.ssh/id_rsa.pub
```

2. Copy The public key to your clipboard
3. Open a web brwoser and log into your [GitHub](https://github.com) account
4. Click on profile icon in the upper right and click on `Settings`
5. On the left side slick on `SSH and GPC keys`
6. click on the green `New SSH key` button
7. Give the key a meaninful name that explains its purpose
8. Paste the public SSH key from step 2  in the "key" field and click `add ssh key`
9. Now you can clone and push to this repo effortlessly :)
