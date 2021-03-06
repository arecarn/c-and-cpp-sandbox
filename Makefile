# get the normalized current directory
THIS_DIR := .

BUILD_TYPES := Debug Release luasan tsan
# Default to a Debug build. If you want to enable debugging flags, run
# "make BT=Release"
BT ?= Debug
ifneq ($(filter $(BT),$(BUILD_TYPES)),)
    $(info $(BT) exists in $(BUILD_TYPES))
else
    $(error $(BT) is not a valid BT value it should be one of the following: $(BUILD_TYPES))
endif

BUILD_TYPE_LOWER := $(shell echo $(BT) | tr A-Z a-z)

BUILD_DIR ?= build

# Figure out where to build the software. Use BUILD_PREFIX if it was passed in.
BUILD_PREFIX ?= $(THIS_DIR)/$(BUILD_DIR)/$(BUILD_TYPE_LOWER)

BUILD_TOOL ?= ninja
ifneq "$(BUILD_TOOL)" "ninja"
    ifneq "$(BUILD_TOOL)" "make"
        $(error Bad BUILD_TOOL value "$(BUILD_TOOL)" please use "ninja" or "make")
    endif
endif

CMAKE_GENERATOR ?= Ninja
BUILD_FILE ?= build.ninja
ifeq "$(BUILD_TOOL)" "make"
    BUILD_FILE = Makefile
    CMAKE_GENERATOR = "Unix Makefiles"
endif

# Get number of jobs Make is being called with. This only works with '-j' and not --jobs'
BUILD_TOOL_PID := $(shell echo $$PPID)
JOB_FLAG := $(filter -j%, $(subst -j ,-j,$(shell ps T | grep "^\s*$(BUILD_TOOL_PID).*$(BUILD_TOOL)")))

INSTALL_PREFIX ?= $(shell echo $(THIS_DIR)/$(BUILD_DIR)/$(BUILD_TYPE_LOWER)/install )

# Default to a Debug build. If you want to enable debugging flags, run
# "make BT=Release"
CLANG_TIDY_FIX ?= OFF
ifneq "$(CLANG_TIDY_FIX)" "ON"
    ifneq "$(CLANG_TIDY_FIX)" "OFF"
        $(error Bad CLANG_TIDY_FIX value "$(CLANG_TIDY_FIX)" please use "ON" or "OFF")
    endif
endif

ifeq "$(CMAKE_OPTIONS)" ""
    CMAKE_OPTIONS := -G $(CMAKE_GENERATOR) -DCLANG_TIDY_FIX=$(CLANG_TIDY_FIX) -DCMAKE_INSTALL_PREFIX=$(INSTALL_PREFIX) -DCMAKE_BUILD_TYPE=$(BT)
else
   # force cmake to be re-run if we change the cmake options
   $(shell rm $(BUILD_PREFIX)/$(BUILD_FILE))
endif

export UID=$(shell id -u)
export GID=$(shell id -g)

USE_DOCKER ?= $(shell ./tools/not_running_in_docker)
DOCKER_CMD = docker-compose run --rm dev bash
ifeq ($(USE_DOCKER),1)
    define docker_cmd
        $(DOCKER_CMD) -c '$(1)'
    endef
else
    define docker_cmd
        $(1)
    endef
endif


.PHONY: default
default: all ctest

define build_type_template =
$(1):
	@set -o xtrace; \
	make BT=$(1)
endef

$(foreach bt, $(BUILD_TYPES), \
    $(eval \
        $(call build_type_template,$(bt)) \
    ) \
)

.PHONY: full
full: $(BUILD_TYPES)


.PHONY: h
h:
	@echo 'make [OPTIONS...] [TARGETS...]'
	@echo
	@echo 'TARGETS:'
	@echo
	@echo '<any>'
	@echo '    Any targets generated by CMake, e.g. all, test'
	@echo
	@echo 'nuke'
	@echo '    delete the build directory'
	@echo
	@echo 'ctest [a="<ctest arguments>"]'
	@echo '    Runs ctest'
	@echo '    e.g.'
	@echo '    $$make ctest a="-R target.test"'
	@echo
	@echo 'OPTIONS:'
	@echo
	@echo 'BT=<Debug|Release>'
	@echo '    specifies the CMake build type, and the build subdirectory'
	@echo '    default: Debug'
	@echo
	@echo 'BUILD_TOOL=<ninja|make>'
	@echo '    Specifies the cmake generator'
	@echo '    default: ninja'
	@echo
	@echo 'CLANG_TIDY_FIX=<ON|OFF>'
	@echo '    Specifies if clang-tidy should run fixits or not'
	@echo '    default: OFF'
	@echo
	@echo 'INSTALL_PREFIX=<path>'
	@echo '    Specifies the CMAKE_INSTALL_PREFIX CMake variable value'
	@echo '    default when BT is Debug: ./build/debug/install'
	@echo '    default when BT is Release: ./build/release/install'
	@echo
	@echo '-j <jobs>'
	@echo '    <jobs> pass -j flag to underlying BUILD_TOOL to set the job number'
	@echo '    default: '''
	@echo
	@echo 'EXAMPLES:'
	@echo
	@echo 'make BT=Release all -j8'
	@echo 'make target'

.PHONY: nuke
nuke:
	rm -rf $(BUILD_DIR)/

$(BUILD_PREFIX)/$(BUILD_FILE):
	# create the temporary build directory if needed
	mkdir -p $(BUILD_PREFIX)
	touch -c $@
	# allow this to fail when not in a git repo
	git config core.hooksPath .githooks || true
	# run CMake to generate and configure the build scripts
	ln -sf $(BUILD_PREFIX)/compile_commands.json compile_commands.json
	$(call docker_cmd,\
		cd $(BUILD_PREFIX); \
		cmake ../.. $(CMAKE_OPTIONS) \
	)

# Other (custom) targets are passed through to the cmake-generated $(BUILD_FILE)
%: $(BUILD_PREFIX)/$(BUILD_FILE)
	$(call docker_cmd,\
		export CTEST_OUTPUT_ON_FAILURE=1; \
		cmake --build $(BUILD_PREFIX) --target $@ -- $(JOB_FLAG) ${a} \
	)

# All the Makefiles read themselves and get matched if a target exists for them,
# so they will get matched by a Match anything target %:. This target is here to
# prevent the %: Match-anything target from matching, and instead and do
# nothing.
Makefile:
	;

.PHONY: ctest
ctest:
	$(call docker_cmd,\
		cd $(BUILD_PREFIX);\
		ctest ${a}\
	)

.PHONY: docker-shell
docker-shell:
	$(DOCKER_CMD)

.PHONY: docker-down
docker-down:
	docker-compose down

.PHONY: docker-build
docker-build:
	docker-compose build
