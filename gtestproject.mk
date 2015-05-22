# Copyright 2015 Erik Van Hamme
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Collect all the module.mk files from the module_dirs.
module_mks := $(patsubst %,%/module.mk,$(module_dirs))

# These variables will be expanded by the module.mk files.
includes :=
sources :=
headers :=

# Load all the module.mk files.
include $(module_mks)

# Default for the build dir and object target directories.
builddir ?= build

# Create the list of object names.
objects := $(patsubst %,$(builddir)/%.o,$(sources))
object_dirs := $(sort $(dir $(objects)))

# Find the current directory.
makefile_path := $(abspath $(firstword $(MAKEFILE_LIST)))
current_dir := $(patsubst %/,%,$(dir $(makefile_path)))

# Google test related variables. Variable gtest should be set before this mk is included.
# The include is added as an absolute path because gcov will pick it up otherwise.
gtest_dir ?= dep
gtest_file := $(gtest).zip
gtest_path := $(gtest_dir)/$(gtest_file)
gtest_builddir := $(builddir)/$(gtest)
gtest_libdir := $(builddir)/$(gtest)/lib/.libs
gtest_incdir := $(current_dir)/$(builddir)/$(gtest)/include

# Build the includes list.
includepaths := $(patsubst %,-I %,$(sort $(dir $(headers))) $(gtest_incdir) $(includes))

# Tools.
cc := g++
ld := g++
gcov := gcov

# Warnings configuration.
warn_common := -Werror -Wall -Wextra -Wcast-align -Wcast-qual -Wdisabled-optimization -Wformat=2 \
	-Winit-self -Wlogical-op -Wmissing-include-dirs -Wredundant-decls -Wstrict-overflow=5 \
	-Wno-unused -Wno-variadic-macros -Wno-parentheses -Wshadow
warn_cpp := -Wnoexcept -Woverloaded-virtual -Wsign-promo -Wstrict-null-sentinel -Wold-style-cast \
	-Wpedantic 

# Dependency generation.
depgen = -MMD -MP -MF"$(@:%.o=%.d)"
deps := $(patsubst %.o,%.d,$(objects))

# Compiler flags.
cflags_common = $(depgen) $(warn_common) 
cppflags = $(cflags_common) $(warn_cpp) -c -std=c++11 -O0 -fno-exceptions -fno-rtti \
	-fprofile-arcs -ftest-coverage -g

# Linker flags.
ldflags = -L$(gtest_libdir) -lgtest -lpthread -fprofile-arcs

# Executable for output.
executable := $(builddir)/$(project)

# Coverage note files.
note_files := $(patsubst %.o,%.gcno,$(objects))

# List of phony targets.
.PHONY: all info prepare distclean clean run coverage

all: $(object_dirs) $(executable)

info:
	@echo "module_dirs:   $(module_dirs)"
	@echo "module_mks:    $(module_mks)"
	@echo "sources:       $(sources)"
	@echo "headers:       $(headers)"
	@echo "objects:       $(objects)"
	@echo "builddir:      $(builddir)"
	@echo "includepaths:  $(includepaths)"
	@echo "object_dirs:   $(object_dirs)"
	@echo "cpp_cflags:    $(cpp_cflags)"
	@echo "deps:          $(deps)"
	@echo "note_files:    $(note_files)"
	@echo "makefile_path: $(makefile_path)"
	@echo "current_dir:   $(current_dir)"

prepare:
	mkdir -p $(builddir)
	cp $(gtest_path) $(builddir)
	cd $(builddir) && unzip $(gtest_file)
	cd $(gtest_builddir) && ./configure
	cd $(gtest_builddir) && make
	cd $(builddir) && rm $(gtest_file)

distclean:
	rm -rf $(builddir)

clean:
	rm -rf $(object_dirs) $(executable) $(builddir)/*.gcov

$(object_dirs):
	mkdir -p $(object_dirs)

$(executable): $(objects)
	$(ld) $(objects) $(ldflags) -o $(executable)

run: $(executable)
	LD_LIBRARY_PATH="$(gtest_libdir)" ./$(executable)

coverage: run $(note_files)
	$(gcov) -r -s $(gtest_builddir) $(note_files)
	mv *.gcov $(builddir)

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(deps)),)
-include $(deps)
endif
endif

$(builddir)/%.cpp.o : %.cpp 
	$(cc) $(cppflags) $(includepaths) -o "$@" "$<"

