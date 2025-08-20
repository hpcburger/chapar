# Makefile for HPC Spack Container Management
# 
# This Makefile provides convenient targets for building and managing
# Apptainer containers based on the skipper Spack environment.

# Configuration
CONTAINER_PREFIX ?= hpc-spack-skipper
BUILD_SCRIPT = scripts/build-containers.sh
OUTPUT_DIR = .
PARALLEL_BUILDS ?= 1

# Container targets
ROCKY8_SIF = $(CONTAINER_PREFIX)-rocky8.sif
ROCKY9_SIF = $(CONTAINER_PREFIX)-rocky9.sif
ALL_SIFS = $(ROCKY8_SIF) $(ROCKY9_SIF)

# Default target
.PHONY: all
all: $(ALL_SIFS)

# Help target
.PHONY: help
help:
	@echo "HPC Spack Container Management"
	@echo ""
	@echo "Available targets:"
	@echo "  all          - Build all containers (default)"
	@echo "  rocky8       - Build Rocky Linux 8 container"
	@echo "  rocky9       - Build Rocky Linux 9 container"
	@echo "  parallel     - Build all containers in parallel"
	@echo "  test         - Test all built containers"
	@echo "  test-rocky8  - Test Rocky Linux 8 container"
	@echo "  test-rocky9  - Test Rocky Linux 9 container"
	@echo "  clean        - Remove all built containers"
	@echo "  info         - Show container information"
	@echo "  shell-rocky8 - Start interactive shell in Rocky 8 container"
	@echo "  shell-rocky9 - Start interactive shell in Rocky 9 container"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Configuration variables:"
	@echo "  CONTAINER_PREFIX  - Prefix for container names (default: $(CONTAINER_PREFIX))"
	@echo "  PARALLEL_BUILDS   - Number of parallel builds (default: $(PARALLEL_BUILDS))"
	@echo "  OUTPUT_DIR        - Output directory (default: $(OUTPUT_DIR))"
	@echo ""
	@echo "Examples:"
	@echo "  make rocky8                    # Build Rocky 8 container"
	@echo "  make parallel PARALLEL_BUILDS=2  # Build in parallel"
	@echo "  make test                      # Test all containers"
	@echo "  make clean                     # Remove all containers"

# Individual container builds
.PHONY: rocky8
rocky8: $(ROCKY8_SIF)

.PHONY: rocky9
rocky9: $(ROCKY9_SIF)

# Build targets
$(ROCKY8_SIF): rocky8/skipper-rocky8.def $(BUILD_SCRIPT) ../specs/* ../environments/skipper/*
	@echo "Building Rocky Linux 8 container..."
	./$(BUILD_SCRIPT) --output-dir $(OUTPUT_DIR) rocky8

$(ROCKY9_SIF): rocky9/skipper-rocky9.def $(BUILD_SCRIPT) ../specs/* ../environments/skipper/*
	@echo "Building Rocky Linux 9 container..."
	./$(BUILD_SCRIPT) --output-dir $(OUTPUT_DIR) rocky9

# Parallel build
.PHONY: parallel
parallel:
	@echo "Building all containers in parallel ($(PARALLEL_BUILDS) jobs)..."
	./$(BUILD_SCRIPT) --parallel $(PARALLEL_BUILDS) --output-dir $(OUTPUT_DIR) all

# Force rebuild targets
.PHONY: force-rocky8
force-rocky8:
	@echo "Force rebuilding Rocky Linux 8 container..."
	./$(BUILD_SCRIPT) --force --output-dir $(OUTPUT_DIR) rocky8

.PHONY: force-rocky9
force-rocky9:
	@echo "Force rebuilding Rocky Linux 9 container..."
	./$(BUILD_SCRIPT) --force --output-dir $(OUTPUT_DIR) rocky9

.PHONY: force-all
force-all:
	@echo "Force rebuilding all containers..."
	./$(BUILD_SCRIPT) --force --output-dir $(OUTPUT_DIR) all

# Test targets
.PHONY: test
test: test-rocky8 test-rocky9

.PHONY: test-rocky8
test-rocky8: $(ROCKY8_SIF)
	@echo "Testing Rocky Linux 8 container..."
	@if command -v apptainer >/dev/null 2>&1; then \
		apptainer test $(ROCKY8_SIF); \
	elif command -v singularity >/dev/null 2>&1; then \
		singularity test $(ROCKY8_SIF); \
	else \
		echo "Error: Neither apptainer nor singularity found"; exit 1; \
	fi

.PHONY: test-rocky9
test-rocky9: $(ROCKY9_SIF)
	@echo "Testing Rocky Linux 9 container..."
	@if command -v apptainer >/dev/null 2>&1; then \
		apptainer test $(ROCKY9_SIF); \
	elif command -v singularity >/dev/null 2>&1; then \
		singularity test $(ROCKY9_SIF); \
	else \
		echo "Error: Neither apptainer nor singularity found"; exit 1; \
	fi

# Interactive shell targets
.PHONY: shell-rocky8
shell-rocky8: $(ROCKY8_SIF)
	@echo "Starting interactive shell in Rocky Linux 8 container..."
	@if command -v apptainer >/dev/null 2>&1; then \
		apptainer shell $(ROCKY8_SIF); \
	elif command -v singularity >/dev/null 2>&1; then \
		singularity shell $(ROCKY8_SIF); \
	else \
		echo "Error: Neither apptainer nor singularity found"; exit 1; \
	fi

.PHONY: shell-rocky9
shell-rocky9: $(ROCKY9_SIF)
	@echo "Starting interactive shell in Rocky Linux 9 container..."
	@if command -v apptainer >/dev/null 2>&1; then \
		apptainer shell $(ROCKY9_SIF); \
	elif command -v singularity >/dev/null 2>&1; then \
		singularity shell $(ROCKY9_SIF); \
	else \
		echo "Error: Neither apptainer nor singularity found"; exit 1; \
	fi

# Information targets
.PHONY: info
info:
	@echo "Container Information:"
	@echo "====================="
	@for sif in $(ALL_SIFS); do \
		if [ -f "$$sif" ]; then \
			echo ""; \
			echo "Container: $$sif"; \
			echo "Size: $$(du -h "$$sif" | cut -f1)"; \
			echo "Modified: $$(stat -c %y "$$sif" 2>/dev/null || stat -f %Sm "$$sif" 2>/dev/null || echo "unknown")"; \
			if command -v apptainer >/dev/null 2>&1; then \
				echo "Labels:"; \
				apptainer inspect "$$sif" | grep -E "(Author|Version|OS)" || true; \
			elif command -v singularity >/dev/null 2>&1; then \
				echo "Labels:"; \
				singularity inspect "$$sif" | grep -E "(Author|Version|OS)" || true; \
			fi; \
		else \
			echo ""; \
			echo "Container: $$sif (not built)"; \
		fi; \
	done

# Utility targets
.PHONY: list
list:
	@echo "Available containers:"
	@ls -la *.sif 2>/dev/null || echo "No containers found"

.PHONY: clean
clean:
	@echo "Removing all built containers..."
	@rm -f $(ALL_SIFS)
	@echo "Containers removed"

.PHONY: clean-cache
clean-cache:
	@echo "Cleaning Apptainer cache..."
	@if command -v apptainer >/dev/null 2>&1; then \
		apptainer cache clean --all; \
	elif command -v singularity >/dev/null 2>&1; then \
		singularity cache clean --all; \
	else \
		echo "Error: Neither apptainer nor singularity found"; \
	fi

# Development targets
.PHONY: check-deps
check-deps:
	@echo "Checking dependencies..."
	@./$(BUILD_SCRIPT) --help >/dev/null && echo "✓ Build script is executable" || echo "✗ Build script not executable"
	@command -v apptainer >/dev/null 2>&1 && echo "✓ Apptainer found" || \
		(command -v singularity >/dev/null 2>&1 && echo "✓ Singularity found" || echo "✗ Neither apptainer nor singularity found")
	@[ -f "../specs/config.yaml" ] && echo "✓ Config specs found" || echo "✗ Config specs missing"
	@[ -f "../specs/global.yaml" ] && echo "✓ Global specs found" || echo "✗ Global specs missing"
	@[ -f "../environments/skipper/spack.yaml" ] && echo "✓ Skipper environment found" || echo "✗ Skipper environment missing"

# Show build status
.PHONY: status
status:
	@echo "Build Status:"
	@echo "============="
	@for sif in $(ALL_SIFS); do \
		if [ -f "$$sif" ]; then \
			echo "✓ $$sif (built)"; \
		else \
			echo "✗ $$sif (not built)"; \
		fi; \
	done
