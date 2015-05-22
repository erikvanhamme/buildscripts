# Collect all the module.mk files from the module_dirs.
module_mks := $(patsubst %,%/module.mk,$(module_dirs))

# These variables will be expanded by the module.mk files.
includepaths :=
sources :=
headers :=
test_sources :=
test_headers :=

# Load all the module.mk files.
include $(module_mks)

# Default for the build dir and object target directories.
builddir ?= build

# Create the list of object names.
objects := $(patsubst %,$(builddir)/mut/%.o,$(sources))
test_objects := $(patsubst %,$(builddir)/test/%.o,$(test_sources))
object_dirs := $(sort $(dir $(objects)) $(dir $(test_objects)))

# Google test related variables. Variable gtest should be set before this mk is included.
gtest_dir ?= dep
gtest_file := $(gtest).zip
gtest_path := $(gtest_dir)/$(gtest_file)
gtest_builddir := $(builddir)/$(gtest)
gtest_libdir := $(builddir)/$(gtest)/lib/.libs
gtest_incdir := $(builddir)/$(gtest)/include

# Build the includes list.
includepaths += $(patsubst %,-I %,$(sort $(dir $(headers)) $(dir $(test_headers))) $(gtest_incdir))

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
deps := $(patsubst %.o,%.d,$(objects) $(test_objects))

# Compiler flags.
cpp_cflags_common = $(depgen) $(warn_common) $(warn_cpp) -c -std=c++11 -O0 -fno-exceptions -fno-rtti
cpp_cflags = $(cpp_cflags_common) -fprofile-arcs -ftest-coverage -g
cpp_test_cflags = $(cpp_cflags_common)

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
	@echo "module_dirs:     $(module_dirs)"
	@echo "module_mks:      $(module_mks)"
	@echo "sources:         $(sources)"
	@echo "headers:         $(headers)"
	@echo "test_sources:    $(test_sources)"
	@echo "test_headers:    $(test_headers)"
	@echo "objects:         $(objects)"
	@echo "test_objects:    $(test_objects)"
	@echo "builddir:        $(builddir)"
	@echo "includepaths:    $(includepaths)"
	@echo "object_dirs:     $(object_dirs)"
	@echo "cpp_cflags:      $(cpp_cflags)"
	@echo "cpp_test_cflags: $(cpp_test_cflags)"
	@echo "deps:            $(deps)"
	@echo "note_files:      $(note_files)"

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
	rm -rf $(object_dirs) $(executable)

$(object_dirs):
	mkdir -p $(object_dirs)

$(executable): $(objects) $(test_objects)
	$(ld) $(objects) $(test_objects) $(ldflags) -o $(executable)

run: $(executable)
	LD_LIBRARY_PATH="$(gtest_libdir)" ./$(executable)

coverage: run $(note_files)
	$(gcov) $(note_files)
	mv *.gcov $(builddir)

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(deps)),)
-include $(deps)
endif
endif

$(builddir)/mut/%.cpp.o : %.cpp 
	$(cc) $(cpp_cflags) $(includepaths) -o "$@" "$<"

$(builddir)/test/%.cpp.o : %.cpp
	$(cc) $(cpp_test_cflags) $(includepaths) -o "$@" "$<"
	

