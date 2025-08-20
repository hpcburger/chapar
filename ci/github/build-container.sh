#!/bin/bash
set -euo pipefail

# Container Build Script for GitHub Actions
# This script builds Apptainer containers in the GitHub Actions environment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# Configuration
CONTAINER_OS="${1:-rocky8}"
CONTAINER_PREFIX="${CONTAINER_PREFIX:-hpc-spack-skipper}"
BUILD_DIR="${GITHUB_WORKSPACE}/containers"
DEFINITION_FILE="${BUILD_DIR}/${CONTAINER_OS}/skipper-${CONTAINER_OS}.def"
OUTPUT_FILE="${BUILD_DIR}/${CONTAINER_PREFIX}-${CONTAINER_OS}.sif"
APPTAINER_VERSION="${APPTAINER_VERSION:-1.2.5}"

usage() {
    cat << EOF
Usage: $0 [CONTAINER_OS]

Build Apptainer container for the specified OS in GitHub Actions.

Arguments:
    CONTAINER_OS    Target OS (rocky8, rocky9) - default: rocky8

Environment Variables:
    CONTAINER_PREFIX       Container name prefix
    BUILD_DIR             Build directory
    GITHUB_WORKSPACE      GitHub Actions workspace directory
    APPTAINER_VERSION     Apptainer version to install

Examples:
    $0 rocky8          # Build Rocky Linux 8 container
    $0 rocky9          # Build Rocky Linux 9 container
EOF
}

install_apptainer() {
    log_info "Installing Apptainer ${APPTAINER_VERSION}..."
    
    # Check if already installed
    if command -v apptainer >/dev/null 2>&1; then
        local current_version=$(apptainer --version | cut -d' ' -f3)
        log_info "Apptainer already installed: ${current_version}"
        return 0
    fi
    
    # Install dependencies
    sudo apt-get update
    sudo apt-get install -y wget
    
    # Download and install Apptainer
    local deb_file="apptainer_${APPTAINER_VERSION}_amd64.deb"
    wget "https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/${deb_file}"
    sudo apt-get install -y "./${deb_file}"
    rm -f "${deb_file}"
    
    # Verify installation
    if command -v apptainer >/dev/null 2>&1; then
        log_success "Apptainer installed successfully: $(apptainer --version)"
    else
        log_error "Failed to install Apptainer"
        exit 1
    fi
}

setup_build_environment() {
    log_info "Setting up build environment..."
    
    # Create necessary directories
    sudo mkdir -p /tmp/apptainer-build
    sudo chown -R $(whoami):$(whoami) /tmp/apptainer-build
    
    # Set Apptainer environment variables for GitHub Actions
    {
        echo "APPTAINER_TMPDIR=/tmp/apptainer-build"
        echo "APPTAINER_CACHEDIR=/tmp/apptainer-cache"
    } >> $GITHUB_ENV
    
    export APPTAINER_TMPDIR=/tmp/apptainer-build
    export APPTAINER_CACHEDIR=/tmp/apptainer-cache
    
    # Create cache directory
    mkdir -p "${APPTAINER_CACHEDIR}"
    
    log_success "Build environment setup complete"
}

build_container() {
    local os="$1"
    local def_file="$2"
    local output_file="$3"
    
    log_info "Building container for ${os}..."
    log_info "Definition file: ${def_file}"
    log_info "Output file: ${output_file}"
    
    # Verify definition file exists
    if [ ! -f "${def_file}" ]; then
        log_error "Definition file not found: ${def_file}"
        exit 1
    fi
    
    # Create output directory
    mkdir -p "$(dirname "${output_file}")"
    
    # Build the container
    log_info "Starting Apptainer build (this may take a very long time)..."
    
    # Build with fakeroot and custom tmpdir
    local build_args=(
        --fakeroot
        --tmpdir /tmp/apptainer-build
    )
    
    # Build the container
    if sudo -E apptainer build "${build_args[@]}" "${output_file}" "${def_file}"; then
        log_success "Container built successfully: ${output_file}"
        
        # Show container info
        ls -lh "${output_file}"
        apptainer inspect "${output_file}" | head -10
        
        return 0
    else
        log_error "Container build failed"
        return 1
    fi
}

test_container() {
    local output_file="$1"
    
    log_info "Testing container: ${output_file}"
    
    # Basic functionality tests
    if apptainer test "${output_file}"; then
        log_success "Container tests passed"
    else
        log_error "Container tests failed"
        return 1
    fi
    
    # Additional manual tests
    log_info "Running additional tests..."
    
    # Test Spack
    if apptainer exec "${output_file}" spack --version; then
        log_success "Spack is working"
    else
        log_error "Spack test failed"
        return 1
    fi
    
    # Test environment activation
    if apptainer exec "${output_file}" bash -c "source /opt/spack/share/spack/setup-env.sh && spack env list"; then
        log_success "Spack environment is accessible"
    else
        log_error "Spack environment test failed"
        return 1
    fi
    
    log_success "All container tests passed"
}

push_to_registry() {
    local output_file="$1"
    local os="$2"
    
    if [ -z "${GITHUB_TOKEN:-}" ] || [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
        log_warn "Skipping registry push (no token or pull request)"
        return 0
    fi
    
    log_info "Converting container to Docker format and pushing to registry..."
    
    local image_name="ghcr.io/${GITHUB_REPOSITORY_OWNER}/hpc-spack-${os}:${GITHUB_REF_NAME}"
    local latest_name="ghcr.io/${GITHUB_REPOSITORY_OWNER}/hpc-spack-${os}:latest"
    
    # Convert SIF to Docker format
    if command -v docker >/dev/null 2>&1; then
        log_info "Converting to Docker format..."
        docker import "${output_file}" "${image_name}"
        
        # Tag as latest if on main branch
        if [ "${GITHUB_REF_NAME:-}" = "main" ]; then
            docker tag "${image_name}" "${latest_name}"
        fi
        
        # Push to registry
        log_info "Pushing to registry..."
        docker push "${image_name}"
        
        if [ "${GITHUB_REF_NAME:-}" = "main" ]; then
            docker push "${latest_name}"
        fi
        
        log_success "Container pushed to registry: ${image_name}"
    else
        log_warn "Docker not available, skipping registry push"
    fi
}

main() {
    # Parse arguments
    if [ $# -gt 1 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        usage
        exit 0
    fi
    
    local os="${1:-rocky8}"
    
    # Validate OS
    if [ "${os}" != "rocky8" ] && [ "${os}" != "rocky9" ]; then
        log_error "Invalid OS: ${os}. Must be rocky8 or rocky9"
        exit 1
    fi
    
    # Set up file paths
    local def_file="${BUILD_DIR}/${os}/skipper-${os}.def"
    local output_file="${BUILD_DIR}/${CONTAINER_PREFIX}-${os}.sif"
    
    log_info "GitHub Actions Container Build Script"
    log_info "OS: ${os}"
    log_info "Definition: ${def_file}"
    log_info "Output: ${output_file}"
    log_info "Workspace: ${GITHUB_WORKSPACE:-unknown}"
    
    # Install Apptainer if needed
    install_apptainer
    
    # Setup build environment
    setup_build_environment
    
    # Build the container
    build_container "${os}" "${def_file}" "${output_file}"
    
    # Test the container
    test_container "${output_file}"
    
    # Push to registry if in GitHub Actions
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        push_to_registry "${output_file}" "${os}"
    fi
    
    log_success "Container build completed successfully!"
}

# Run main function
main "$@"
