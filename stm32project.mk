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
systemheaders :=

# Load all the module.mk files.
include $(module_mks)

# Default for the build dir, build mode and object target directories.
buildmode ?= release
builddir ?= $(buildmode)

# Create the list of object names.
objects := $(patsubst %,$(builddir)/%.o,$(sources))
object_dirs := $(sort $(dir $(objects)))

# Build the includes list.
includepaths := $(patsubst %,-I %,$(sort $(dir $(headers))) $(includes)) $(patsubst %,-isystem %,$(sort $(dir $(systemheaders))))

# Tools.
cc ?= arm-none-eabi-gcc
as ?= arm-none-eabi-gcc
gpp ?= arm-none-eabi-g++
ld ?= arm-none-eabi-g++
oc ?= arm-none-eabi-objcopy
os ?= arm-none-eabi-size
oocd ?= openocd

# Warnings configuration.
warn_common := -Werror -Wall -Wextra -Wcast-align -Wcast-qual -Wdisabled-optimization -Wformat=2 \
	-Winit-self -Wlogical-op -Wmissing-include-dirs -Wredundant-decls -Wstrict-overflow=5 \
	-Wno-unused -Wno-variadic-macros -Wno-parentheses -Wshadow
warn_c := 
warn_cpp := -Wnoexcept -Woverloaded-virtual -Wsign-promo -Wstrict-null-sentinel -Wold-style-cast \
	-Wpedantic 

# Dependency generation.
depgen = -MMD -MP -MF"$(@:%.o=%.d)"
deps := $(patsubst %.o,%.d,$(objects))

# arch is dependent on the chip
ifeq ($(chip),stm32f303xc)
arch := -mcpu=cortex-m4 -mthumb -mfloat-abi=softfp -mfpu=fpv4-sp-d16
defines += -DSTM32F303xC
chipfamily := stm32f3
endif
ifeq ($(chip),stm32f407)
arch := -mcpu=cortex-m4 -mthumb -mfloat-abi=softfp -mfpu=fpv4-sp-d16
defines += -DSTM32F407xx
chipfamily := stm32f4
endif
defines += -D$(chipfamily)
# TODO: consider moving the above to chipsupport.mk and add more support for different chips

# linker script selection
ldscript := buildscripts/$(chip)-$(buildmode).ld

# Compiler/assembler flags for release mode.
ifeq ($(buildmode),release)
cflags_common = -c $(depgen) $(warn_common) -DNDEBUG -ffunction-sections -fdata-sections -Wa,-adhlns="$@.lst" -fmessage-length=0
cflags = $(cflags_common) $(warn_c) -std=c99 -fno-builtin
cppflags = $(cflags_common) $(warn_cpp) -std=c++11 -O3 -fno-exceptions -fno-unwind-tables -fno-rtti
asflags = -c -Wall -O3
endif

# Compiler/assembler flags for debug mode.
ifeq ($(buildmode),debug)
cflags_common = -c $(depgen) $(warn_common) -ffunction-sections -fdata-sections -Wa,-adhlns="$@.lst" -fmessage-length=0
cflags = $(cflags_common) $(warn_c) -std=c99 -fno-builtin
cppflags = $(cflags_common) $(warn_cpp) -std=c++11 -O0 -fno-exceptions -fno-unwind-tables -fno-rtti -g3 -gdwarf-2
asflags = -c -Wall -O0 -g3 -gdwarf-2
endif

# Linker,objcopy flags. 
ldflags = -T "$(ldscript)" -Xlinker --gc-sections -fno-exceptions -nostartfiles -Wl,-Map=$(builddir)/$(project).map
ocflags = -O binary

# Output artefacts.
elffile := $(builddir)/$(project).elf
binfile := $(builddir)/$(project).bin

# List of phony targets.
.PHONY: all info clean flash oocd

all: $(object_dirs) $(binfile)

info:
	@echo "module_dirs:   $(module_dirs)"
	@echo "module_mks:    $(module_mks)"
	@echo "sources:       $(sources)"
	@echo "headers:       $(headers)"
	@echo "systemheaders: $(systemheaders)"
	@echo "objects:       $(objects)"
	@echo "builddir:      $(builddir)"
	@echo "includepaths:  $(includepaths)"
	@echo "object_dirs:   $(object_dirs)"
	@echo "cflags:        $(cflags)"
	@echo "cpplags:       $(cppflags)"
	@echo "asflags:       $(asflags)"
	@echo "ldflags:       $(ldflags)"
	@echo "deps:          $(deps)"

clean:
	rm -rf $(builddir)

$(object_dirs):
	mkdir -p $(object_dirs)

$(elffile): $(objects)
	$(ld) $(arch) $(ldflags) $(objects) -o $(elffile)
	@echo "---------------------------------------"
	$(os) $(elffile)
	@echo "---------------------------------------"

$(binfile): $(elffile)
	$(oc) $(ocflags) $(elffile) $(binfile)

flash: $(binfile)
	$(oocd) $(oocdcfgs) $(oocdcmds)

oocd: $(binfile)
	$(oocd) $(oocdcfgs)

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(deps)),)
-include $(deps)
endif
endif

$(builddir)/%.s.o : %.s
	$(as) $(arch) $(asflags) -o "$@" "$<"

$(builddir)/%.c.o : %.c
	$(cc) $(arch) $(cflags) $(includepaths) $(defines) -o "$@" "$<"

$(builddir)/%.cpp.o : %.cpp 
	$(gpp) $(arch) $(cppflags) $(includepaths) $(defines) -o "$@" "$<"

