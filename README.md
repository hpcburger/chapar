<<<<<<< Current (Your changes)
# HPC Software Delivery

I am moving my my code base on how I develop software delivery for industrial HPC clusters in here. Step by step.
=======
## Industrial HPC Software Delivery with Spack

A reproducible, configurable software delivery blueprint for industrial HPC clusters built around Spack. This repository captures, step by step, how to stand up and manage optimized MPI stacks, multiple compiler toolchains, and common developer utilities across Rocky Linux 8/9 based environments.

### Highlights
- **Reproducible stacks**: Centralized specs drive consistent builds across hosts and OS variants.
- **Multiple MPI implementations**: OpenMPI, MPICH, and Intel oneAPI MPI tuned for UCX/libfabric.
- **Compiler choice**: GCC 8.5/11.4 and Intel oneAPI compilers.
- **CUDA-aware networking**: UCX/libfabric built with `+cuda` for GPU clusters.
- **Cache-aware builds**: Source, binary, test, and ccache locations pre-configured.

## Repository layout
- `environments/`
  - `automated/ci.yaml`: Placeholder for CI automation wiring.
  - `skipper/spack.yaml`: Example host-specific environment for a production-like node.
  - `test/spack.yaml`: Reference/test environment to validate specs and changes.
- `specs/global.yaml`: Central Spack specs matrix (MPI, UCX, libfabric, Python, Rust, compilers, OS targets).

Note: The `spack.yaml` files include `../specs/specs.yaml`. In this repo the file is named `global.yaml`. Either:
- Create a symlink: `ln -s global.yaml specs/specs.yaml`, or
- Update the `include:` path in each `spack.yaml` to `../specs/global.yaml`.

## Prerequisites
- A recent Spack checkout initialized in your shell (`share/spack/setup-env.sh`).
- Rocky Linux 8 or 9 compatible nodes (as configured), or adjust OS targets in specs.
- Sufficient storage for caches and install tree. Default paths in `spack.yaml` assume shared scratch and install roots:
  - `install_tree.root`: `/share/base/bin` (change this to a user-writable path if not installing system-wide)
  - caches under `/scratch/spack/*` and `/dev/shm/spack/*` (adjust if unavailable)
- Optional: `ccache` for faster rebuilds (configured in environments).

## Quick start
1) Install and initialize Spack
```bash
git clone https://github.com/spack/spack.git ~/spack
source ~/spack/share/spack/setup-env.sh
```

2) Choose an environment
```bash
cd environments/test    # or environments/skipper
```

3) Fix include path if needed
```bash
# Option A: create a symlink so the include matches
cd ../../specs && ln -s global.yaml specs.yaml || true
cd -
# Option B: edit environments/*/spack.yaml to use ../specs/global.yaml
```

4) Activate, concretize, and install
```bash
spack env activate .
spack concretize -f
spack install --fail-fast -j $(nproc)
```

5) Use the stack
```bash
# List what got built
spack find -vl

# Load packages on demand
spack load openmpi
spack load python@3.12

# Or generate modules (example for Lmod)
spack module lmod refresh -y
module avail
module load openmpi/4.1.6
```

## Customization
- **Install root**: Change `spack.config.install_tree.root` in `environments/*/spack.yaml` to a path you control.
- **Compilers**: Adjust the `compilers:` section or run `spack compiler find` to detect site compilers.
- **OS targets**: The matrix in `specs/global.yaml` targets Rocky 8/9 via `oses: [os=rocky8, os=rocky9]`. Modify for your distro.
- **MPI flavors**: Enable/disable OpenMPI, MPICH, or oneAPI MPI by editing the relevant `matrix` entries.
- **CUDA**: UCX/libfabric and MPI are specified with `+cuda`. Ensure appropriate NVIDIA drivers/toolkits are present or pin CUDA via Spack if needed.
- **Views**: Views are disabled (`view: false`). Enable views if you prefer a merged prefix for user environments.

## Environments explained
- `environments/test/spack.yaml`
  - Safe place to validate concretization and builds with the shared specs.
  - Uses caches and `ccache` to accelerate repeated builds.
- `environments/skipper/spack.yaml`
  - Example of a host-scoped configuration with the same shared specs.
  - Tune `install_tree`, caches, and compiler targets for your production nodes.

## CI/CD Automation
Complete GitLab CI/CD pipeline using Spack CI for automated builds and container generation:

### Pipeline Features
- **Spack CI Integration**: Dynamic pipeline generation for package builds
- **Apptainer Containers**: Automated container builds for Rocky Linux 8/9
- **Build Cache**: Optimized caching for faster rebuilds
- **Multi-platform**: Support for different OS and compiler combinations
- **Testing**: Automated validation of built environments and containers

### Pipeline Stages
1. **Prepare**: Environment setup and concretization
2. **Generate**: Dynamic Spack CI pipeline creation  
3. **Build Packages**: Parallel package compilation with Spack CI
4. **Build Containers**: Apptainer container creation
5. **Test**: Functionality validation
6. **Deploy**: Container registry publishing

### Configuration Files
- `.gitlab-ci.yml`: Main pipeline configuration
- `ci/gitlab/variables.yml`: Centralized environment variables
- `ci/gitlab/setup-spack.sh`: Spack initialization script
- `ci/gitlab/build-container.sh`: Container build automation
- `environments/skipper/spack.yaml`: Updated with CI configuration

See `ci/README.md` for detailed CI/CD documentation.

## Troubleshooting
- **Permission issues**: Point `install_tree.root` and caches to user-writable locations.
- **Concretizer conflicts**: Use `spack solve --show-cores` to diagnose; relax variants or pin versions.
- **MPI providers**: Ensure `fabrics` and providers (UCX, OFI/libfabric) match your network (Infiniband, RoCE).
- **SLURM integration**: OpenMPI/MPICH entries include `+slurm`/`schedulers=slurm` where relevant; make sure `slurm` dev packages are available on builders.

## Roadmap
- Fill in CI automation and binary cache publishing.
- Add site config overlays for GPUs and multi-NIC systems.
- Expand test matrix (ARM/Power targets, additional CUDA versions).

## Contributing
Issues and PRs to expand specs or improve portability are welcome. Please validate changes in `environments/test` and include the concretization output when relevant.

---
Status: active WIP migration of an industrial HPC software delivery workflow into this repository.
>>>>>>> Incoming (Background Agent changes)
