
# SyncroInterMod

This repository contains the code for the project on replanning in synchromodal transportation networks under various interruption scenarios.

## Table of Contents

- [SyncroInterMod](#syncrointermod)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [1. Clone the Repository](#1-clone-the-repository)
    - [2. Import into a New Workspace](#2-import-into-a-new-workspace)
  - [Usage](#usage)
    - [Running the Model](#running-the-model)
  - [Key Files](#key-files)
  - [Additional Notes](#additional-notes)


## Introduction

This project focuses on exploring the benefits of replanning in synchromodal transportation networks when faced with various interruption scenarios. The optimization model is implemented using IBM ILOG CPLEX Optimization Studio and utilizes OPL (Optimization Programming Language).

## Prerequisites

- **IBM ILOG CPLEX Optimization Studio**: Ensure that you have the latest version installed, as the project relies on OPL and the CPLEX solver.
- **Git**: For cloning the repository.

## Installation

Follow these steps to set up the project on your local machine:

### 1. Clone the Repository

Open your terminal and execute the following command to clone the repository:

```bash
git clone https://github.com/CHENZhoujing/SyncroInterMod.git
```

### 2. Import into a New Workspace

After cloning, it is recommended to import the project into a new workspace in your development environment. Opening the project directly may cause issues, especially with solver connections. Importing it into a fresh workspace ensures that all necessary configurations are correctly established.

## Usage

### Running the Model

1. Open IBM ILOG CPLEX Optimization Studio.
2. Import the project into a new workspace.
3. Open the `.mod` file (Model File) in your OPL environment.
4. Ensure that the data files are correctly referenced in your project settings.
5. Run the model.

By following these steps, you should be able to replicate the experiments and explore the benefits of replanning in synchromodal transportation networks under various interruption scenarios.

## Key Files

The project's functionality is driven by three essential files:

- **Model File (`*.mod`)**: Contains the computational model that defines the optimization problem.
- **Scenario Data File (`scenario.dat`)**: Provides detailed information about the shipment requests, including their characteristics and constraints.
- **Transportation Modal Data File**: Includes comprehensive data about the transportation network, such as available modes, routes, capacities, and associated costs.

Make sure you understand the structure and content of these files, as they are crucial for running and modifying the model.

## Additional Notes

- **Solver Connections**: If you encounter issues with solver connections, verify that the solver is properly configured in your development environment.
- **Data Files**: Ensure that the data files are in the correct directory and properly referenced in your project settings.
- **Modifying the Model**: If you wish to modify the model or data, make sure to update the corresponding `.mod` and `.dat` files accordingly.

