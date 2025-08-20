# GitLab CI/CD for HPC Spack Environment

This directory contains the GitLab CI/CD configuration for building and deploying HPC software stacks using Spack and Apptainer containers.

## Overview

The CI/CD pipeline:

1. **Prepares** the Spack environment and concretizes dependencies
2. **Generates** a dynamic Spack CI pipeline for package builds
3. **Builds packages** using Spack CI with optimized caching and parallelization
4. **Creates Apptainer containers** for Rocky Linux 8 and 9
5. **Tests** the built containers for functionality
6. **Deploys** containers to the GitLab container registry

## Directory Structure

```
ci/
├── gitlab/
│   ├── variables.yml           # Centralized environment variables
│   ├── setup-spack.sh         # Spack setup script
│   ├── build-container.sh     # Container build script
│   └── spack-ci-template.yml  # Spack CI job templates
└── README.md                  # This file
```

## Configuration Files

### `variables.yml`
Centralized configuration for all CI/CD environment variables including:
- Spack paths and cache locations
- Container registry settings
- Build configuration parameters
- Security and access settings

### `setup-spack.sh`
Script to set up Spack in the CI environment:
- Clones and initializes Spack
- Creates necessary directories
- Finds system compilers
- Activates the specified environment

### `build-container.sh`
Script to build Apptainer containers:
- Installs Apptainer in CI environment
- Builds containers from definition files
- Tests container functionality
- Pushes to container registry

### `spack-ci-template.yml`
Reusable job templates for Spack CI:
- Platform-specific templates (Rocky 8/9)
- Compiler-specific configurations
- Build cache integration
- Security and signing templates

## GitLab CI/CD Variables

Set these variables in your GitLab project's CI/CD settings:

### Required Variables
- `SPACK_SIGNING_KEY`: GPG key for package signing (optional but recommended)
- `CI_REGISTRY_PASSWORD`: Registry password (auto-provided by GitLab)

### Optional Variables
- `AWS_ACCESS_KEY_ID`: For S3-based build cache
- `AWS_SECRET_ACCESS_KEY`: For S3-based build cache
- `SPACK_CACHE_BUCKET`: S3 bucket for build cache
- `SPACK_CACHE_REGION`: AWS region for build cache

### Auto-provided by GitLab
- `CI_REGISTRY`: Container registry URL
- `CI_REGISTRY_IMAGE`: Base image path
- `CI_COMMIT_REF_SLUG`: Branch/tag slug for tagging
- `CI_PROJECT_DIR`: Project directory path

## Pipeline Stages

### 1. Prepare Stage
- Sets up Spack environment
- Concretizes the skipper environment
- Creates `spack.lock` file with exact package versions

### 2. Generate Stage
- Uses `spack ci generate` to create dynamic pipeline
- Generates job definitions for all packages
- Configures build cache and artifact settings

### 3. Build Packages Stage
- Executes the generated Spack CI pipeline
- Builds packages in dependency order
- Uses build cache for faster rebuilds
- Runs in parallel across multiple runners

### 4. Build Containers Stage
- Creates Apptainer containers for Rocky 8 and 9
- Installs the built Spack environment
- Tests container functionality
- Pushes to GitLab container registry

### 5. Test Stage
- Validates container functionality
- Tests Spack environment activation
- Verifies MPI and other key packages

### 6. Deploy Stage
- Creates deployment manifest
- Publishes final container images
- Updates latest tags for stable releases

## Usage

### Automatic Triggers
The pipeline runs automatically on:
- **Merge requests**: Builds and tests changes
- **Main branch commits**: Full build and deploy
- **Tags**: Release builds with special handling

### Manual Triggers
Some jobs can be triggered manually:
- **Rocky 9 container builds**: Manual for resource management
- **Deployment**: Manual approval for production releases
- **Cache cleanup**: Manual maintenance tasks

### Running Locally

You can test parts of the pipeline locally:

```bash
# Set up Spack
./ci/gitlab/setup-spack.sh

# Build a container
./ci/gitlab/build-container.sh rocky8

# Test the built container
apptainer test containers/hpc-spack-skipper-rocky8.sif
```

## Customization

### Adding New OS Targets
1. Create new container definition in `containers/`
2. Add OS-specific job template in `spack-ci-template.yml`
3. Update the skipper environment's CI configuration
4. Add build job in `.gitlab-ci.yml`

### Modifying Package Selection
1. Edit `specs/global.yaml` to change package matrix
2. Update `environments/skipper/spack.yaml` if needed
3. Pipeline will automatically pick up changes

### Changing Build Configuration
1. Modify variables in `ci/gitlab/variables.yml`
2. Update job templates in `spack-ci-template.yml`
3. Adjust `.gitlab-ci.yml` stages if needed

## Performance Optimization

### Build Cache
- Uses file-based build cache by default
- Can be configured for S3 or other backends
- Significantly reduces build times for unchanged packages

### Parallel Builds
- Spack CI automatically parallelizes package builds
- Container builds can run in parallel
- Configure `MAX_PARALLEL_JOBS` to control resource usage

### Caching Strategy
- Source cache for downloaded files
- Build cache for compiled packages
- Container layer caching in registry

## Troubleshooting

### Common Issues

1. **Build failures due to missing compilers**
   - Check compiler detection in setup phase
   - Verify runner has required development tools
   - Update compiler configurations if needed

2. **Container build timeouts**
   - Increase `JOB_TIMEOUT` in variables.yml
   - Use build cache to reduce build time
   - Consider splitting large builds

3. **Registry push failures**
   - Verify registry credentials
   - Check available storage space
   - Ensure proper network connectivity

4. **Spack concretization conflicts**
   - Review package constraints in specs
   - Check for version conflicts
   - Use `spack solve` to debug locally

### Debug Mode
Enable debug output by setting:
```yaml
variables:
  SPACK_DEBUG: "true"
  SPACK_VERBOSE: "true"
  CI_DEBUG: "true"
```

### Log Analysis
- Check job logs for specific error messages
- Review Spack build logs in artifacts
- Use GitLab's pipeline visualization for dependency issues

## Security Considerations

### Package Signing
- Configure GPG keys for package signing
- Use protected runners for sensitive builds
- Verify signatures in deployment stage

### Access Control
- Use protected branches for production builds
- Limit registry access to authorized users
- Rotate signing keys regularly

### Container Security
- Base images are updated regularly
- Containers run as non-root user
- Security scanning can be added as additional stage

## Monitoring and Maintenance

### Pipeline Health
- Monitor build success rates
- Track build times and resource usage
- Set up alerts for persistent failures

### Cache Management
- Regular cleanup of old cache entries
- Monitor cache hit rates
- Optimize cache keys for better reuse

### Resource Usage
- Monitor runner capacity and utilization
- Adjust parallel job limits as needed
- Scale runners based on demand

## Integration with HPC Systems

### Deployment Strategies
1. **Direct container deployment**: Use built containers directly on HPC systems
2. **Environment installation**: Use Spack environment for native installation
3. **Hybrid approach**: Containers for development, native for production

### Module Integration
- Containers can generate environment modules
- Integration with existing module systems (Lmod, TCL modules)
- Automatic module file generation in pipeline

### Scheduler Integration
- Containers work with Slurm, PBS, and other schedulers
- MPI integration tested across different fabrics
- GPU support through CUDA-aware builds

## Support and Contributing

### Getting Help
- Check pipeline logs for specific errors
- Review Spack documentation for package issues
- Use GitLab issues for CI/CD problems

### Contributing
- Test changes in merge requests
- Update documentation for new features
- Follow existing patterns for consistency

### Best Practices
- Keep builds deterministic and reproducible
- Use semantic versioning for container tags
- Document any custom configurations
- Test thoroughly before merging changes
