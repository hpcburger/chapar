#!/bin/bash
set -euo pipefail

# Spack Setup Script for GitHub Actions
# This script sets up Spack in the GitHub Actions environment

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
SPACK_ROOT="${SPACK_ROOT:-/opt/spack}"
SPACK_VERSION="${SPACK_VERSION:-develop}"
SPACK_ENVIRONMENT="${SPACK_ENVIRONMENT:-skipper}"

main() {
    log_info "Setting up Spack for GitHub Actions..."
    
    # Create necessary directories
    log_info "Creating Spack directories..."
    sudo mkdir -p "${SPACK_SOURCE_CACHE}" "${SPACK_MISC_CACHE}" "${SPACK_TEST_CACHE}" "${SPACK_CCACHE_DIR}"
    sudo mkdir -p "${SPACK_BUILD_STAGE}" || true
    sudo mkdir -p "${SPACK_BUILD_STAGE_RAM}" || true
    sudo mkdir -p "$(dirname "${SPACK_ROOT}")"
    
    # Set permissions
    sudo chown -R $(whoami):$(whoami) /tmp/spack /opt/ || true
    
    # Clone or update Spack
    if [ ! -d "${SPACK_ROOT}" ]; then
        log_info "Cloning Spack repository..."
        if [ "${SPACK_VERSION}" = "develop" ]; then
            git clone --depth=1 https://github.com/spack/spack.git "${SPACK_ROOT}"
        else
            git clone --depth=1 --branch="${SPACK_VERSION}" https://github.com/spack/spack.git "${SPACK_ROOT}"
        fi
    else
        log_info "Spack already exists, updating..."
        cd "${SPACK_ROOT}"
        git fetch origin
        git reset --hard origin/"${SPACK_VERSION}"
    fi
    
    # Set ownership
    sudo chown -R $(whoami):$(whoami) "${SPACK_ROOT}"
    
    # Initialize Spack
    log_info "Initializing Spack..."
    export PATH="${SPACK_ROOT}/bin:${PATH}"
    source "${SPACK_ROOT}/share/spack/setup-env.sh"
    
    # Verify Spack installation
    log_info "Verifying Spack installation..."
    spack --version
    
    # Find system compilers
    log_info "Finding system compilers..."
    spack compiler find
    spack compiler list
    
    # Install additional system packages if needed
    if command -v apt-get >/dev/null 2>&1; then
        log_info "Installing additional system packages..."
        sudo apt-get update
        sudo apt-get install -y \
            build-essential \
            gfortran \
            cmake \
            ninja-build \
            ccache \
            pkg-config \
            libssl-dev \
            libffi-dev \
            libbz2-dev \
            libreadline-dev \
            libsqlite3-dev \
            libncurses5-dev \
            libncursesw5-dev \
            xz-utils \
            tk-dev \
            libxml2-dev \
            libxmlsec1-dev \
            libffi-dev \
            liblzma-dev || true
    fi
    
    # Show Spack configuration
    log_info "Spack configuration:"
    spack config get config || true
    
    # Set up environment if specified
    if [ -n "${SPACK_ENVIRONMENT}" ] && [ -d "environments/${SPACK_ENVIRONMENT}" ]; then
        log_info "Setting up Spack environment: ${SPACK_ENVIRONMENT}"
        cd "environments/${SPACK_ENVIRONMENT}"
        spack env activate .
        spack env status
        
        # Show environment info
        log_info "Environment specs:"
        spack find || true
    fi
    
    # Set up GitHub Actions specific configurations
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        log_info "Configuring for GitHub Actions..."
        
        # Add Spack to PATH for subsequent steps
        echo "${SPACK_ROOT}/bin" >> $GITHUB_PATH
        
        # Set environment variables for subsequent steps
        {
            echo "SPACK_ROOT=${SPACK_ROOT}"
            echo "PATH=${SPACK_ROOT}/bin:${PATH}"
        } >> $GITHUB_ENV
        
        # Create setup script for other steps
        cat > /tmp/setup-spack-env.sh << 'EOF'
#!/bin/bash
export SPACK_ROOT="${SPACK_ROOT:-/opt/spack}"
export PATH="${SPACK_ROOT}/bin:${PATH}"
source "${SPACK_ROOT}/share/spack/setup-env.sh"
EOF
        chmod +x /tmp/setup-spack-env.sh
    fi
    
    log_success "Spack setup completed successfully!"
}

# Run main function
main "$@"
