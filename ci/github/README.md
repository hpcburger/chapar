# GitHub Actions CI/CD for HPC Spack Environment

This directory contains GitHub Actions workflows and scripts for building and deploying HPC software stacks using Spack and Apptainer containers.

## Overview

The GitHub Actions CI/CD pipeline provides:

1. **Automated Spack Environment Building**: Concretizes and builds the skipper environment
2. **Container Generation**: Creates Apptainer containers for Rocky Linux 8 and 9
3. **Testing and Validation**: Comprehensive testing of environments and containers
4. **Container Registry Integration**: Automatic publishing to GitHub Container Registry (GHCR)
5. **Multi-trigger Support**: Supports push, PR, manual, and scheduled triggers

## Directory Structure

```
ci/github/
├── setup-spack.sh         # Spack setup script for GitHub Actions
├── build-container.sh     # Container build script for GitHub Actions
├── action-template.yml    # Reusable templates and configurations
├── variables.yml          # Environment variables documentation
└── README.md             # This file

.github/workflows/
├── spack-ci.yml           # Main CI/CD pipeline
├── container-build.yml    # Container-only build workflow
└── test-environment.yml   # Environment testing workflow
```

## Workflows

### 1. Main CI/CD Pipeline (`spack-ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`
- Git tags (releases)
- Manual dispatch with options

**Jobs:**
1. **Prepare**: Setup Spack and concretize environment
2. **Generate**: Create build matrix for packages
3. **Build Packages**: Build Spack packages in parallel
4. **Build Containers**: Create Rocky 8/9 Apptainer containers
5. **Test**: Validate container functionality
6. **Deploy**: Create deployment manifest and publish

**Features:**
- Parallel package builds with build cache
- Container builds for both Rocky Linux versions
- Automatic testing and validation
- GitHub Container Registry integration
- Artifact management with retention policies

### 2. Container Build Only (`container-build.yml`)

**Purpose**: Manual container builds without full package compilation

**Features:**
- Choice of target OS (Rocky 8, 9, or both)
- Optional registry push
- Optional testing
- Manual trigger with parameters

**Use Cases:**
- Quick container updates
- Testing container definitions
- Emergency container builds

### 3. Environment Testing (`test-environment.yml`)

**Purpose**: Validate Spack environment configurations

**Tests:**
- Environment concretization
- Spec file validation
- Sample package installation
- YAML linting

**Triggers:**
- Pull requests affecting environments or specs
- Manual dispatch

## Configuration

### GitHub Repository Settings

#### Required Secrets
```bash
# Optional but recommended
SPACK_SIGNING_KEY          # GPG key for package signing
AWS_ACCESS_KEY_ID          # For S3 build cache (optional)
AWS_SECRET_ACCESS_KEY      # For S3 build cache (optional)
```

#### Auto-provided Variables
- `GITHUB_TOKEN`: Automatic token for registry access
- `GITHUB_REPOSITORY`: Repository name
- `GITHUB_REF`: Branch/tag reference
- `GITHUB_SHA`: Commit SHA

#### Repository Permissions
Enable the following in repository settings:
- **Actions**: Read and write permissions
- **Packages**: Write permissions (for GHCR)
- **Contents**: Read permissions

### Environment Variables

All environment variables are documented in `variables.yml`. Key variables:

```yaml
# Spack Configuration
SPACK_ROOT: "/opt/spack"
SPACK_ENVIRONMENT: "skipper"
SPACK_BUILD_JOBS: "4"

# Container Configuration
CONTAINER_REGISTRY: "ghcr.io"
APPTAINER_VERSION: "1.2.5"

# Build Configuration
BUILDCACHE_DESTINATION: "file:///tmp/spack/buildcache"
```

## Usage

### Automatic Workflows

**Push to main branch:**
```bash
git push origin main
# Triggers: Full CI/CD pipeline with container builds and registry push
```

**Create pull request:**
```bash
gh pr create --title "Update environment" --body "Description"
# Triggers: Environment testing and validation
```

**Create release:**
```bash
git tag v1.0.0
git push origin v1.0.0
# Triggers: Full pipeline with release artifacts
```

### Manual Workflows

**Build containers only:**
1. Go to Actions tab in GitHub
2. Select "Build Containers Only" workflow
3. Click "Run workflow"
4. Choose options:
   - Target OS: rocky8, rocky9, or both
   - Push to registry: true/false
   - Run tests: true/false

**Test environment:**
1. Go to Actions tab
2. Select "Test Spack Environment"
3. Click "Run workflow"

### Local Testing

Test workflows locally using [act](https://github.com/nektos/act):

```bash
# Install act
brew install act  # macOS
# or
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Test environment workflow
act pull_request -W .github/workflows/test-environment.yml

# Test container build (requires Docker)
act workflow_dispatch -W .github/workflows/container-build.yml
```

## GitHub Container Registry

### Container Images

Built containers are automatically pushed to GitHub Container Registry:

```bash
# Rocky Linux 8
ghcr.io/OWNER/hpc-spack-rocky8:main
ghcr.io/OWNER/hpc-spack-rocky8:latest

# Rocky Linux 9  
ghcr.io/OWNER/hpc-spack-rocky9:main
ghcr.io/OWNER/hpc-spack-rocky9:latest
```

### Using Containers

```bash
# Pull container
docker pull ghcr.io/OWNER/hpc-spack-rocky8:latest

# Or use with Apptainer/Singularity
apptainer pull docker://ghcr.io/OWNER/hpc-spack-rocky8:latest

# Run interactively
apptainer shell hpc-spack-rocky8_latest.sif
```

### Registry Permissions

Configure package visibility in repository settings:
- **Public**: Anyone can pull containers
- **Internal**: Organization members can pull
- **Private**: Only collaborators can pull

## Performance Optimization

### Build Cache

GitHub Actions uses file-based build cache by default:

```yaml
# Cache configuration
cache:
  key: spack-build-${{ runner.os }}-${{ hashFiles('environments/*/spack.lock') }}
  paths:
    - /tmp/spack/buildcache
    - /tmp/spack/ccache
```

### Parallel Builds

Optimize parallel job execution:

```yaml
# Matrix strategy
strategy:
  fail-fast: false
  max-parallel: 4  # Adjust based on runner limits
  matrix:
    include:
      - os: rocky8
      - os: rocky9
```

### Resource Management

GitHub Actions provides:
- **Standard runners**: 2 cores, 7GB RAM, 14GB storage
- **Larger runners**: Available for GitHub Enterprise
- **Self-hosted runners**: For custom hardware

## Troubleshooting

### Common Issues

1. **Build timeouts**
   ```yaml
   # Increase timeout in workflow
   timeout-minutes: 240  # 4 hours
   ```

2. **Out of disk space**
   ```bash
   # Clean up in workflow
   - name: Free disk space
     run: |
       sudo rm -rf /usr/share/dotnet
       sudo rm -rf /opt/ghc
       sudo rm -rf "/usr/local/share/boost"
       sudo rm -rf "$AGENT_TOOLSDIRECTORY"
   ```

3. **Container build failures**
   ```bash
   # Check Apptainer installation
   apptainer --version
   
   # Check available space
   df -h /tmp
   
   # Check definition file
   apptainer build --dry-run container.sif definition.def
   ```

4. **Registry push failures**
   ```bash
   # Check permissions
   echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
   
   # Verify repository settings
   # Settings > Actions > General > Workflow permissions
   ```

### Debug Mode

Enable debug logging:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

### Log Analysis

Access logs from:
1. Actions tab in GitHub repository
2. Individual workflow runs
3. Job-specific logs with timestamps
4. Artifact downloads for build outputs

## Security Considerations

### Secrets Management

```yaml
# Use GitHub secrets for sensitive data
env:
  SIGNING_KEY: ${{ secrets.SPACK_SIGNING_KEY }}
  
# Never log secrets
run: |
  echo "Using signing key: [REDACTED]"
```

### Container Security

- Base images updated regularly
- Containers run as non-root user
- Security scanning available via GitHub Security tab
- Dependabot alerts for vulnerabilities

### Access Control

```yaml
# Restrict sensitive jobs
if: github.event_name != 'pull_request' && github.actor != 'dependabot[bot]'
```

## Monitoring and Maintenance

### Workflow Health

Monitor via GitHub repository:
- **Actions tab**: Workflow run history
- **Insights tab**: Action usage and performance
- **Settings > Actions**: Usage limits and billing

### Maintenance Tasks

1. **Weekly**: Review failed workflows
2. **Monthly**: Update runner images and dependencies
3. **Quarterly**: Review and optimize workflow performance
4. **Annually**: Security audit of secrets and permissions

### Metrics

Track important metrics:
- Build success rate
- Average build time
- Container image sizes
- Registry storage usage

## Integration with HPC Systems

### Container Deployment

```bash
# On HPC system
module load apptainer
apptainer pull docker://ghcr.io/OWNER/hpc-spack-rocky8:latest

# Use in job script
#SBATCH --job-name=hpc-job
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=48

srun apptainer exec hpc-spack-rocky8_latest.sif mpirun ./my_app
```

### Environment Modules

Generate modules from containers:

```bash
# Create module file
cat > /modules/hpc-spack/1.0 << 'EOF'
#%Module1.0
set container /path/to/hpc-spack-rocky8_latest.sif
setenv HPC_CONTAINER $container
set-alias hpc-shell "apptainer shell $container"
set-alias hpc-exec "apptainer exec $container"
EOF
```

## Best Practices

### Workflow Design

1. **Fail Fast**: Use `fail-fast: false` for matrix builds
2. **Timeouts**: Set appropriate timeouts for all jobs
3. **Artifacts**: Clean up artifacts with retention policies
4. **Caching**: Use effective cache keys and restore keys

### Container Management

1. **Tagging**: Use semantic versioning for releases
2. **Cleanup**: Regularly clean old container versions
3. **Testing**: Always test containers before deployment
4. **Documentation**: Keep container documentation updated

### Development Workflow

1. **Branch Protection**: Require PR reviews for main branch
2. **Status Checks**: Require successful CI before merge
3. **Automated Testing**: Test all changes in PRs
4. **Release Process**: Use tags for versioned releases

## Support and Contributing

### Getting Help

1. **GitHub Issues**: Report problems and request features
2. **Discussions**: Ask questions and share ideas
3. **Documentation**: Check workflow logs and artifacts
4. **Community**: Engage with Spack and HPC communities

### Contributing

1. **Fork and PR**: Standard GitHub contribution model
2. **Testing**: Test changes in your fork first
3. **Documentation**: Update docs for new features
4. **Review**: Participate in code reviews

### Extending Workflows

Add new workflows by:
1. Creating new workflow files in `.github/workflows/`
2. Using existing templates from `action-template.yml`
3. Testing with `act` or in fork
4. Following existing patterns and conventions
