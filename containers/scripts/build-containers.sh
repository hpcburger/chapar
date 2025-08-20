#!/bin/bash
set -euo pipefail

# Container build script for HPC Spack environments
# Builds Apptainer/Singularity containers for Rocky Linux 8 and 9

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINERS_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$CONTAINERS_DIR")"

# Configuration
CONTAINER_PREFIX="${CONTAINER_PREFIX:-hpc-spack-skipper}"
BUILD_PARALLEL="${BUILD_PARALLEL:-1}"
CACHE_DIR="${APPTAINER_CACHE_DIR:-$HOME/.apptainer/cache}"
TMPDIR="${TMPDIR:-/tmp}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TARGETS]

Build Apptainer containers for HPC Spack environments.

OPTIONS:
    -h, --help          Show this help message
    -p, --parallel N    Build N containers in parallel (default: 1)
    -c, --cache-dir     Apptainer cache directory (default: ~/.apptainer/cache)
    -o, --output-dir    Output directory for .sif files (default: containers/)
    -t, --tmpdir        Temporary directory for builds (default: /tmp)
    --no-cache          Disable Apptainer cache
    --force             Force rebuild even if .sif exists
    --test              Run container tests after build

TARGETS:
    rocky8              Build Rocky Linux 8 container
    rocky9              Build Rocky Linux 9 container
    all                 Build all containers (default)

EXAMPLES:
    $0                  # Build all containers
    $0 rocky8           # Build only Rocky 8 container
    $0 --parallel 2     # Build containers in parallel
    $0 --force rocky9   # Force rebuild Rocky 9 container

ENVIRONMENT VARIABLES:
    CONTAINER_PREFIX    Prefix for container names (default: hpc-spack-skipper)
    BUILD_PARALLEL      Number of parallel builds (default: 1)
    APPTAINER_CACHE_DIR Cache directory location
EOF
}

# Parse command line arguments
TARGETS=()
OUTPUT_DIR="$CONTAINERS_DIR"
USE_CACHE=true
FORCE_BUILD=false
RUN_TESTS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -p|--parallel)
            BUILD_PARALLEL="$2"
            shift 2
            ;;
        -c|--cache-dir)
            CACHE_DIR="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -t|--tmpdir)
            TMPDIR="$2"
            shift 2
            ;;
        --no-cache)
            USE_CACHE=false
            shift
            ;;
        --force)
            FORCE_BUILD=true
            shift
            ;;
        --test)
            RUN_TESTS=true
            shift
            ;;
        rocky8|rocky9|all)
            TARGETS+=("$1")
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Default to all if no targets specified
if [[ ${#TARGETS[@]} -eq 0 ]]; then
    TARGETS=("all")
fi

# Expand "all" target
if [[ " ${TARGETS[*]} " =~ " all " ]]; then
    TARGETS=(rocky8 rocky9)
fi

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for apptainer/singularity
    if ! command -v apptainer >/dev/null 2>&1 && ! command -v singularity >/dev/null 2>&1; then
        log_error "Neither apptainer nor singularity found in PATH"
        log_error "Please install Apptainer: https://apptainer.org/docs/admin/main/installation.html"
        exit 1
    fi
    
    # Determine which command to use
    if command -v apptainer >/dev/null 2>&1; then
        CONTAINER_CMD="apptainer"
    else
        CONTAINER_CMD="singularity"
    fi
    
    log_info "Using container command: $CONTAINER_CMD"
    
    # Check for definition files
    for target in "${TARGETS[@]}"; do
        def_file="$CONTAINERS_DIR/$target/skipper-$target.def"
        if [[ ! -f "$def_file" ]]; then
            log_error "Definition file not found: $def_file"
            exit 1
        fi
    done
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    log_success "Prerequisites check passed"
}

# Build a single container
build_container() {
    local target="$1"
    local def_file="$CONTAINERS_DIR/$target/skipper-$target.def"
    local sif_file="$OUTPUT_DIR/${CONTAINER_PREFIX}-$target.sif"
    
    log_info "Building container: $target"
    log_info "Definition file: $def_file"
    log_info "Output file: $sif_file"
    
    # Check if container already exists
    if [[ -f "$sif_file" ]] && [[ "$FORCE_BUILD" != "true" ]]; then
        log_warn "Container already exists: $sif_file"
        log_warn "Use --force to rebuild"
        return 0
    fi
    
    # Build arguments
    local build_args=()
    
    # Cache settings
    if [[ "$USE_CACHE" == "true" ]]; then
        export APPTAINER_CACHE_DIR="$CACHE_DIR"
        log_info "Using cache directory: $CACHE_DIR"
    else
        build_args+=(--disable-cache)
        log_info "Cache disabled"
    fi
    
    # Set temporary directory
    export APPTAINER_TMPDIR="$TMPDIR"
    
    # Change to repo root for build context
    cd "$REPO_ROOT"
    
    # Build the container
    log_info "Starting build for $target (this may take a very long time...)"
    
    if $CONTAINER_CMD build "${build_args[@]}" "$sif_file" "$def_file"; then
        log_success "Container built successfully: $sif_file"
        
        # Run tests if requested
        if [[ "$RUN_TESTS" == "true" ]]; then
            log_info "Running container tests for $target..."
            if $CONTAINER_CMD test "$sif_file"; then
                log_success "Container tests passed for $target"
            else
                log_error "Container tests failed for $target"
                return 1
            fi
        fi
        
        # Show container info
        log_info "Container information:"
        $CONTAINER_CMD inspect "$sif_file" | head -20
        
        return 0
    else
        log_error "Container build failed for $target"
        return 1
    fi
}

# Build containers in parallel
build_containers_parallel() {
    local pids=()
    local results=()
    
    log_info "Building ${#TARGETS[@]} containers with parallelism: $BUILD_PARALLEL"
    
    # Start builds
    for target in "${TARGETS[@]}"; do
        # Wait if we've reached the parallel limit
        while [[ ${#pids[@]} -ge $BUILD_PARALLEL ]]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[i]}" 2>/dev/null; then
                    wait "${pids[i]}"
                    results[i]=$?
                    unset pids[i]
                fi
            done
            sleep 1
        done
        
        # Start build in background
        log_info "Starting build for $target in background..."
        (build_container "$target") &
        pids+=($!)
    done
    
    # Wait for all builds to complete
    log_info "Waiting for all builds to complete..."
    for pid in "${pids[@]}"; do
        wait "$pid"
        results+=($?)
    done
    
    # Check results
    local failed=0
    for i in "${!TARGETS[@]}"; do
        if [[ ${results[i]} -ne 0 ]]; then
            log_error "Build failed for ${TARGETS[i]}"
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        log_success "All container builds completed successfully!"
    else
        log_error "$failed container build(s) failed"
        exit 1
    fi
}

# Main execution
main() {
    log_info "HPC Spack Container Builder"
    log_info "Targets: ${TARGETS[*]}"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Parallel builds: $BUILD_PARALLEL"
    
    check_prerequisites
    
    if [[ $BUILD_PARALLEL -eq 1 ]]; then
        # Sequential builds
        for target in "${TARGETS[@]}"; do
            build_container "$target" || exit 1
        done
        log_success "All container builds completed successfully!"
    else
        # Parallel builds
        build_containers_parallel
    fi
    
    # Show final summary
    log_info "Built containers:"
    for target in "${TARGETS[@]}"; do
        sif_file="$OUTPUT_DIR/${CONTAINER_PREFIX}-$target.sif"
        if [[ -f "$sif_file" ]]; then
            size=$(du -h "$sif_file" | cut -f1)
            log_success "  $sif_file ($size)"
        fi
    done
}

# Run main function
main "$@"
