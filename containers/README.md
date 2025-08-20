# HPC Spack Containers

This directory contains Apptainer/Singularity container definitions and build scripts for creating reproducible HPC software environments based on the Spack package manager.

## Overview

The containers are built from the `skipper` Spack environment and provide:

- **Complete HPC software stack** with MPI implementations (OpenMPI, MPICH, Intel OneAPI MPI)
- **CUDA-aware networking** via UCX and libfabric
- **Multiple Python versions** (3.8-3.12) with optimizations
- **Compiler toolchains** (GCC 8.5/11.4, Intel OneAPI)
- **Development tools** and utilities
- **Environment modules** for easy package management

## Directory Structure

```
containers/
├── rocky8/
│   └── skipper-rocky8.def    # Rocky Linux 8 container definition
├── rocky9/
│   └── skipper-rocky9.def    # Rocky Linux 9 container definition
├── scripts/
│   └── build-containers.sh   # Container build script
├── Makefile                  # Build automation
└── README.md                 # This file
```

## Quick Start

### Prerequisites

- **Apptainer** or **Singularity** installed
- **Root/sudo access** for container builds (or fakeroot/user namespaces configured)
- **Sufficient disk space** (containers can be 5-10GB+ each)
- **Time** - full builds can take several hours

### Building Containers

#### Using Make (Recommended)

```bash
# Build all containers
make all

# Build specific container
make rocky8
make rocky9

# Build in parallel (faster)
make parallel PARALLEL_BUILDS=2

# Force rebuild
make force-all

# Show help
make help
```

#### Using Build Script Directly

```bash
# Build all containers
./scripts/build-containers.sh

# Build specific container
./scripts/build-containers.sh rocky8

# Build with custom options
./scripts/build-containers.sh --parallel 2 --force --test

# Show help
./scripts/build-containers.sh --help
```

## Usage Examples

### Running Containers

```bash
# Start interactive shell
apptainer shell hpc-spack-skipper-rocky8.sif

# Run command in container
apptainer exec hpc-spack-skipper-rocky8.sif spack find

# Run MPI application
apptainer exec hpc-spack-skipper-rocky8.sif mpirun -np 4 ./my_mpi_app
```

### Using the HPC Software Stack

Once inside the container, the Spack environment is automatically activated:

```bash
# List available packages
spack find

# Load MPI implementation
spack load openmpi
mpirun --version

# Load Python
spack load python@3.12
python3 --version

# Load multiple packages
spack load openmpi python@3.12 cmake

# Use environment modules (alternative to spack load)
module avail
module load openmpi/4.1.6
```

### Development Workflow

```bash
# Mount your code directory
apptainer shell --bind /path/to/your/code:/workspace hpc-spack-skipper-rocky8.sif

# Inside container
cd /workspace
spack load openmpi python@3.12
make  # or your build command
mpirun -np 4 ./your_app
```

## Container Details

### Rocky Linux 8 Container (`skipper-rocky8.def`)
- **Base**: `rockylinux:8`
- **Compilers**: GCC 8.5.0, GCC 11.4.1, Intel OneAPI
- **Target**: Production HPC environments using Rocky/RHEL 8

### Rocky Linux 9 Container (`skipper-rocky9.def`)
- **Base**: `rockylinux:9`
- **Compilers**: GCC 11.4.1, Intel OneAPI
- **Target**: Modern HPC environments using Rocky/RHEL 9

### Common Features
- **Spack Environment**: Pre-configured with skipper environment
- **MPI Implementations**: OpenMPI, MPICH, Intel OneAPI MPI with UCX/libfabric
- **Python Stack**: Multiple versions with optimizations
- **Development Tools**: Complete build toolchain
- **Environment Modules**: TCL modules for package management
- **CUDA Support**: Optional CUDA toolkit (commented in definitions)

## Customization

### Environment Variables

The build process supports several environment variables:

```bash
# Container naming
export CONTAINER_PREFIX="my-hpc-stack"

# Build configuration
export SPACK_BUILD_JOBS=16
export SPACK_INSTALL_ROOT="/opt/my-spack"

# Cache locations
export APPTAINER_CACHE_DIR="$HOME/.cache/apptainer"
```

### Modifying Containers

1. **Edit definition files** in `rocky8/` or `rocky9/` directories
2. **Customize Spack environment** by modifying `../environments/skipper/spack.yaml`
3. **Add system packages** in the `%post` section
4. **Modify environment** in the `%environment` section

### Adding CUDA Support

Uncomment the CUDA installation lines in the definition files:

```bash
# Uncomment these lines in the %post section
dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
dnf install -y cuda-toolkit-12-0
```

## Testing

### Automated Tests

```bash
# Test all containers
make test

# Test specific container
make test-rocky8

# Build with tests
./scripts/build-containers.sh --test
```

### Manual Testing

```bash
# Run container test suite
apptainer test hpc-spack-skipper-rocky8.sif

# Interactive testing
apptainer shell hpc-spack-skipper-rocky8.sif
# Inside container:
spack find
mpirun --version
python3 --version
```

## Troubleshooting

### Common Issues

1. **Permission denied during build**
   - Ensure you have root access or configure user namespaces
   - Use `--fakeroot` flag if available

2. **Build fails with "No space left on device"**
   - Check available disk space
   - Set `TMPDIR` to location with more space
   - Use `--tmpdir` option

3. **Spack concretization fails**
   - Check the skipper environment configuration
   - Verify compiler availability
   - Review Spack logs in the container

4. **MPI applications don't work**
   - Ensure proper MPI implementation is loaded
   - Check for conflicting MPI installations
   - Verify network fabric support

### Build Optimization

1. **Use binary cache** - Configure Spack binary cache for faster builds
2. **Parallel builds** - Use `--parallel` option for multiple containers
3. **Incremental builds** - Avoid `--force` unless necessary
4. **Cache management** - Use `make clean-cache` to free space

## Performance Considerations

- **Container size**: Expect 5-10GB per container
- **Build time**: 2-6 hours depending on hardware and network
- **Memory usage**: 4-8GB RAM during build
- **Network**: Significant download requirements for packages

## Integration with HPC Systems

### Slurm Integration

```bash
#!/bin/bash
#SBATCH --job-name=my-hpc-job
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=48

srun apptainer exec hpc-spack-skipper-rocky8.sif mpirun ./my_app
```

### Module Files

Create environment modules for easy container access:

```tcl
#%Module1.0
proc ModulesHelp { } {
    puts stderr "HPC Spack Container - Rocky 8"
}

set container /path/to/hpc-spack-skipper-rocky8.sif
setenv HPC_CONTAINER $container
set-alias hpc-shell "apptainer shell $container"
set-alias hpc-exec "apptainer exec $container"
```

## Contributing

To contribute improvements:

1. Test changes in the `test` environment first
2. Update both Rocky 8 and Rocky 9 definitions consistently
3. Document any new features or requirements
4. Ensure containers pass all tests

## Support

For issues and questions:
- Check the main project README
- Review Spack documentation
- Consult Apptainer/Singularity documentation
- Open issues in the project repository
