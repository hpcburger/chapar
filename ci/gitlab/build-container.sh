#!/bin/bash
set -euo pipefail

# Container Build Script for GitLab CI
# This script builds Apptainer containers in the CI environment

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
BUILD_DIR="${CI_PROJECT_DIR}/containers"
DEFINITION_FILE="${BUILD_DIR}/${CONTAINER_OS}/skipper-${CONTAINER_OS}.def"
OUTPUT_FILE="${BUILD_DIR}/${CONTAINER_PREFIX}-${CONTAINER_OS}.sif"

usage() {
    cat << EOF
Usage: $0 [CONTAINER_OS]

Build Apptainer container for the specified OS.

Arguments:
    CONTAINER_OS    Target OS (rocky8, rocky9) - default: rocky8

Environment Variables:
    CONTAINER_PREFIX    Container name prefix
    BUILD_DIR          Build directory
    CI_PROJECT_DIR     GitLab CI project directory

Examples:
    $0 rocky8          # Build Rocky Linux 8 container
    $0 rocky9          # Build Rocky Linux 9 container
EOF
}

install_apptainer() {
    log_info "Installing Apptainer..."
    
    # Check if already installed
    if command -v apptainer >/dev/null 2>&1; then
        log_info "Apptainer already installed: $(apptainer --version)"
        return 0
    fi
    
    # Install dependencies
    if command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y curl wget
    elif command -v yum >/dev/null 2>&1; then
        # RHEL/CentOS/Rocky
        yum install -y curl wget
    elif command -v apk >/dev/null 2>&1; then
        # Alpine
        apk add --no-cache curl wget bash
    fi
    
    # Install Apptainer using the official installer
    curl -s https://raw.githubusercontent.com/apptainer/apptainer/main/tools/install-unprivileged.sh | bash -s - /usr/local
    export PATH="/usr/local/bin:${PATH}"
    
    # Verify installation
    if command -v apptainer >/dev/null 2>&1; then
        log_success "Apptainer installed successfully: $(apptainer --version)"
    else
        log_error "Failed to install Apptainer"
        exit 1
    fi
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
    log_info "Starting Apptainer build (this may take a long time)..."
    
    # Use fakeroot if available, otherwise try without
    local build_args=()
    if apptainer help build | grep -q "\--fakeroot"; then
        build_args+=(--fakeroot)
        log_info "Using fakeroot for build"
    else
        log_warn "Fakeroot not available, building without it"
    fi
    
    # Set temporary directory
    build_args+=(--tmpdir /tmp)
    
    # Build the container
    if apptainer build "${build_args[@]}" "${output_file}" "${def_file}"; then
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
    
    if [ -z "${CI_REGISTRY:-}" ] || [ -z "${CI_REGISTRY_IMAGE:-}" ]; then
        log_warn "Registry variables not set, skipping push"
        return 0
    fi
    
    log_info "Converting container to Docker format and pushing to registry..."
    
    local image_name="${CI_REGISTRY_IMAGE}/hpc-spack-${os}:${CI_COMMIT_REF_SLUG:-latest}"
    local latest_name="${CI_REGISTRY_IMAGE}/hpc-spack-${os}:latest"
    
    # Convert SIF to Docker format
    if command -v docker >/dev/null 2>&1; then
        log_info "Converting to Docker format..."
        docker import "${output_file}" "${image_name}"
        
        # Tag as latest if on main branch
        if [ "${CI_COMMIT_REF_NAME:-}" = "${CI_DEFAULT_BRANCH:-main}" ]; then
            docker tag "${image_name}" "${latest_name}"
        fi
        
        # Push to registry
        log_info "Pushing to registry..."
        docker push "${image_name}"
        
        if [ "${CI_COMMIT_REF_NAME:-}" = "${CI_DEFAULT_BRANCH:-main}" ]; then
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
    
    log_info "Container Build Script"
    log_info "OS: ${os}"
    log_info "Definition: ${def_file}"
    log_info "Output: ${output_file}"
    
    # Install Apptainer if needed
    install_apptainer
    
    # Build the container
    build_container "${os}" "${def_file}" "${output_file}"
    
    # Test the container
    test_container "${output_file}"
    
    # Push to registry if in CI
    if [ -n "${CI:-}" ]; then
        push_to_registry "${output_file}" "${os}"
    fi
    
    log_success "Container build completed successfully!"
}

# Run main function
main "$@"
