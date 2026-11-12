# SPDX-License-Identifier: GPL-2.0-or-later
# Keep dependency discovery and compilation in CMake, Cargo and pyproject.toml.
ifneq ($(filter 0.% 1.% 2.% 3.% 4.0 4.0.% 4.1 4.1.%,$(MAKE_VERSION)),)
$(error GNU Make 4.2 or newer is required; found $(MAKE_VERSION))
endif

.DEFAULT_GOAL := build

CMAKE ?= cmake
CTEST ?= ctest
CARGO ?= cargo
PYTHON ?= python
BUILD_DIR ?= build
# GNU Make 4.2+ can read the existing cache without a shell dependency.
BUILD_TYPE ?= $(or $(word 2,$(subst =, ,$(filter CMAKE_BUILD_TYPE:%,$(file <$(BUILD_DIR)/CMakeCache.txt)))),Release)
RUST_MANIFEST ?= bindings/rust/Cargo.toml
RUST_PROFILE ?= $(if $(filter Debug,$(BUILD_TYPE)),dev,release)
DIST_DIR ?= dist
CPP_DIST_BUILD_DIR ?= build-dist-cpp
CPP_DIST_CONFIG ?= RelWithDebInfo
CPP_DIST_CMAKE_ARGS ?=
JOBS ?= 2
CMAKE_ARGS ?=
CTEST_ARGS ?=
CARGO_ARGS ?=
PYTHON_BUILD_ARGS ?=

.PHONY: all configure build build-cpp build-rust build-python package-python dist-cpp \
        test test-cpp test-rust test-python clean clean-cpp clean-rust help

all: build

# The native default build includes Python when its development files are found.
build: build-cpp build-rust

configure:
	"$(CMAKE)" -S . -B "$(BUILD_DIR)" -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) $(CMAKE_ARGS)

# Use the default CMake target for C/C++, or request the Python module explicitly
# so build-python fails rather than silently skipping missing development files.
build-cpp build-python: configure
	"$(CMAKE)" --build "$(BUILD_DIR)" --config "$(BUILD_TYPE)" --parallel $(JOBS) $(if $(filter build-python,$@),--target buipy)

build-rust:
	"$(CARGO)" build --manifest-path "$(RUST_MANIFEST)" --workspace --profile "$(RUST_PROFILE)" --jobs $(JOBS) $(CARGO_ARGS)

# Use a separate tree: SDK compiler/configuration choices do not alter BUILD_DIR.
dist-cpp:
	"$(CMAKE)" -S . -B "$(CPP_DIST_BUILD_DIR)" -DCMAKE_BUILD_TYPE="$(CPP_DIST_CONFIG)" -DBUI_BUILD_CPP_SDK=ON -DBUI_BUILD_TESTS=OFF -DBUI_BUILD_EXAMPLES=OFF -DBUI_BUILD_PYTHON_BINDINGS=OFF -DBUI_CPP_DIST_DIR:PATH="$(abspath $(DIST_DIR))/cpp" $(CPP_DIST_CMAKE_ARGS)
	"$(CMAKE)" --build "$(CPP_DIST_BUILD_DIR)" --config "$(CPP_DIST_CONFIG)" --target dist-cpp --parallel $(JOBS)

package-python:
	"$(PYTHON)" -m build --outdir "$(DIST_DIR)" $(PYTHON_BUILD_ARGS)

# CTest includes the native and Python suites. Cargo tests the Rust workspace.
test: test-cpp test-rust

test-cpp test-python: build-cpp
	"$(CTEST)" --test-dir "$(BUILD_DIR)" -C "$(BUILD_TYPE)" --output-on-failure $(if $(filter test-python,$@),-R "^buipy") $(CTEST_ARGS) --no-tests=error

test-rust:
	"$(CARGO)" test --manifest-path "$(RUST_MANIFEST)" --workspace --profile "$(RUST_PROFILE)" --jobs $(JOBS) $(CARGO_ARGS)

clean: clean-cpp clean-rust

# Keep CMake's cache and dependencies; let each build system clean its outputs.
clean-cpp:
	"$(CMAKE)" --build "$(BUILD_DIR)" --config "$(BUILD_TYPE)" --target clean

clean-rust:
	"$(CARGO)" clean --manifest-path "$(RUST_MANIFEST)"

help:
	@echo "Requires GNU Make 4.2 or newer; run from the repository root"
	@echo "make build          Build C/C++, discovered Python bindings, and Rust"
	@echo "make build-cpp      Build the CMake project (including enabled bindings)"
	@echo "make build-rust     Build the Rust workspace"
	@echo "make build-python   Build the buipy extension and its native dependencies"
	@echo "make dist-cpp       Build a relocatable C/C++ SDK ZIP in dist/cpp (Windows PDBs included)"
	@echo "make package-python Build Python wheel and sdist (pip install build first)"
	@echo "make test           Run CTest (C/C++ and Python) and Rust tests"
	@echo "make test-python    Build native targets and run only Python CTest suites"
	@echo "make test-cpp        Build native targets and run all CTest suites"
	@echo "make test-rust       Run Rust workspace tests"
	@echo "make clean          Clean CMake and Cargo outputs; retain CMake configuration"
	@echo "Options: BUILD_DIR BUILD_TYPE RUST_PROFILE RUST_MANIFEST JOBS DIST_DIR"
	@echo "C++ SDK options: CPP_DIST_BUILD_DIR CPP_DIST_CONFIG CPP_DIST_CMAKE_ARGS"
	@echo "Tools: CMAKE CTEST CARGO PYTHON"
	@echo "Extra flags: CMAKE_ARGS CTEST_ARGS CARGO_ARGS PYTHON_BUILD_ARGS"
