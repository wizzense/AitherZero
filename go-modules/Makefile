# AitherZero Go Modules - Makefile

BINARY_DIR = bin
CMD_DIR = cmd
PKG_DIR = pkg

# Binaries to build
BINARIES = config-parser test-parser validator utils

# Go parameters
GOCMD = go
GOBUILD = $(GOCMD) build
GOTEST = $(GOCMD) test
GOCLEAN = $(GOCMD) clean
GOGET = $(GOCMD) get
GOMOD = $(GOCMD) mod

# Build flags
BUILD_FLAGS = -v
LDFLAGS = -s -w

# Detect OS
ifeq ($(OS),Windows_NT)
    BINARY_EXT = .exe
else
    BINARY_EXT =
endif

# Targets
.PHONY: all build test clean install deps fmt lint quality help

all: deps test build

# Build all binaries
build: $(BINARIES)

$(BINARIES):
	@echo "Building $@..."
	@mkdir -p $(BINARY_DIR)
	$(GOBUILD) $(BUILD_FLAGS) -ldflags "$(LDFLAGS)" -o $(BINARY_DIR)/$@$(BINARY_EXT) ./$(CMD_DIR)/$@

# Run tests
test:
	$(GOTEST) -v -cover ./...

# Run tests with coverage
coverage:
	$(GOTEST) -v -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Clean build artifacts
clean:
	$(GOCLEAN)
	rm -rf $(BINARY_DIR)
	rm -f coverage.out coverage.html

# Install binaries to parent bin directory
install: build
	@echo "Installing binaries to ../bin/go-modules/"
	@mkdir -p ../bin/go-modules
	@cp -f $(BINARY_DIR)/*$(BINARY_EXT) ../bin/go-modules/
	@echo "Installation complete"

# Download dependencies
deps:
	$(GOMOD) download
	$(GOMOD) tidy

# Format code
fmt:
	$(GOCMD) fmt ./...

# Lint code (requires golangci-lint)
lint:
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "golangci-lint not installed, skipping lint"; \
		echo "Install: https://golangci-lint.run/usage/install/"; \
	fi

# Run all quality checks
quality: fmt lint test

# Help
help:
	@echo "AitherZero Go Modules - Available targets:"
	@echo "  make build     - Build all binaries"
	@echo "  make test      - Run tests"
	@echo "  make coverage  - Generate coverage report"
	@echo "  make install   - Install binaries to ../bin/go-modules/"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make deps      - Download dependencies"
	@echo "  make fmt       - Format code"
	@echo "  make lint      - Lint code (requires golangci-lint)"
	@echo "  make quality   - Run fmt, lint, and test"
	@echo "  make help      - Show this help"
