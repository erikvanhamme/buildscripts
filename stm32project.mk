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

# Collect all the module.mk and useflags.mk files from the module_dirs.
module_mks := $(patsubst %,%/module.mk,$(module_dirs))
useflags_mks := $(patsubst %,%/useflags.mk,$(module_dirs))

# Load all useflags.mk files. These file are optional in the modules.
# These files are loaded first because they help setup the variable $(use)
# which is used in the module.mk files.
-include $(useflags_mks)

# Load all the module.mk files.
include $(module_mks)

# Use flags also become defines.
defines += $(patsubst %,-D%,$(sort $(use)))

# Default for the build dir, build mode and object target directories.
buildmode ?= release
builddir ?= $(buildmode)

# Create the list of object names.
objects := $(patsubst %,$(builddir)/%.o,$(sources)) $(patsubst %,$(builddir)/%sys.o,$(systemsources))
object_dirs := $(sort $(dir $(objects)))

# Build the includes list.
includepaths := $(patsubst %,-I %,$(includes)) $(patsubst %,-isystem %,$(systemincludes))

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
warn_c := $(warn_common)
warn_cpp := $(warn_common) -Wnoexcept -Woverloaded-virtual -Wsign-promo -Wstrict-null-sentinel -Wold-style-cast -Wpedantic
warn_as := -Wall

# Dependency generation.
depgen = -MMD -MP -MF"$(@:%.o=%.d)"
deps := $(patsubst %.o,%.d,$(objects))

# Linker script handling.
memldscript := $(builddir)/memory.ld
ldscript := buildscripts/stm32fxxxxx-$(buildmode).ld

# Compiler/assembler flags for release mode.
ifeq ($(buildmode),release)
cflags_common = -c $(depgen) -ffunction-sections -fdata-sections -Wa,-adhlns="$@.lst" -fmessage-length=0
cflags = $(cflags_common) -std=c99 -fno-builtin
cppflags = $(cflags_common) -std=c++11 -O3 -fno-exceptions -fno-unwind-tables -fno-rtti
asflags = -c -O3
defines += -DNDEBUG
endif

# Compiler/assembler flags for debug mode.
ifeq ($(buildmode),debug)
cflags_common = -c $(depgen) -ffunction-sections -fdata-sections -Wa,-adhlns="$@.lst" -fmessage-length=0
cflags = $(cflags_common) -std=c99 -fno-builtin
cppflags = $(cflags_common) -std=c++11 -O0 -fno-exceptions -fno-unwind-tables -fno-rtti -g3 -gdwarf-2
asflags = -c -O0 -g3 -gdwarf-2
endif

# Linker,objcopy flags. 
ldflags = -T "$(ldscript)" -Xlinker --gc-sections -fno-exceptions -nostartfiles -Wl,-Map=$(builddir)/$(project).map
ocflags = -O binary

# Output artefacts.
elffile := $(builddir)/$(project).elf
binfile := $(builddir)/$(project).bin

# List of phony targets.
.PHONY: all info info_chip info_verbose clean flash oocd

all: $(object_dirs) $(binfile)

info:
	@echo "module_dirs:   $(module_dirs)"
	@echo ""
	@echo "builddir:      $(builddir)"
	@echo ""
	@echo "includepaths:  $(includepaths)"
	@echo ""
	@echo "cflags:        $(cflags)"
	@echo ""
	@echo "cpplags:       $(cppflags)"
	@echo ""
	@echo "asflags:       $(asflags)"
	@echo ""
	@echo "ldflags:       $(ldflags)"
	@echo ""
	@echo "use:           $(sort $(use))"
	@echo ""
	@echo "defines:       $(sort $(defines))"
	@echo ""

# ---- Chip info for stm32f4 --------------------------------------------------
ifneq ($(strip $(findstring STM32F4,$(use))),)
info_chip:
	@echo "sup. chips:    $(sort $(supported_chips))"
	@echo ""
	@echo "chip:          $(chip)"
	@echo "flashsize:     $(flashsize)"
	@echo "sramsize:      $(sramsize)"
	@echo "ccmsize:       $(ccmsize)"
	@echo "----------------------------------------"
	@echo "/* Memory map for $(chip). */"
	@echo "MEMORY"
	@echo "{"
	@echo "	flash (rx)  : ORIGIN = 0x08000000, LENGTH = $(flashsize)"
	@echo "	sram (rwx)  : ORIGIN = 0x20000000, LENGTH = $(sramsize)"
	@echo "	ccm (rwx)   : ORIGIN = 0x10000000, LENGTH = $(ccmsize)"
	@echo "}"
endif


# ---- Chip info for stm32f7 --------------------------------------------------
ifneq ($(strip $(findstring STM32F7,$(use))),)
info_chip:
	@echo "sup. chips:    $(sort $(supported_chips))"
	@echo ""
	@echo "chip:          $(chip)"
	@echo "itcmsize:      $(itcmsize)"
	@echo "flashsize:     $(flashsize)"
	@echo "dtcmsize:      $(dtcmsize)"
	@echo "sramsize:      $(sramsize)"
	@echo "----------------------------------------"
	@echo "/* Memory map for $(chip). */"
	@echo "MEMORY"
	@echo "{"
	@echo "	itcm (rwx) : ORIGIN = 0x00000000, LENGTH = $(itcmsize)"
	@echo "	flash (rx) : ORIGIN = 0x08000000, LENGTH = $(flashsize)"
	@echo "	dtcm (rwx) : ORIGIN = 0x20000000, LENGTH = $(dtcmsize)"
	@echo "	sram (rwx) : ORIGIN = 0x20010000, LENGTH = $(sramsize)"
	@echo "}"
endif


info_verbose: info
	@echo "module_mks:    $(module_mks)"
	@echo ""
	@echo "useflags_mks:  $(useflags_mks)"
	@echo ""
	@echo "sources:       $(sources)"
	@echo ""
	@echo "headers:       $(headers)"
	@echo ""
	@echo "systemheaders: $(systemheaders)"
	@echo ""
	@echo "object_dirs:   $(object_dirs)"
	@echo ""
	@echo "objects:       $(objects)"
	@echo ""
	@echo "deps:          $(deps)"
	@echo ""

clean:
	rm -rf $(builddir)

$(object_dirs):
	mkdir -p $(object_dirs)

# ---- Memory mapping for stm32f4 ---------------------------------------------
ifneq ($(strip $(findstring STM32F4,$(use))),)

$(memldscript):
	@echo "Generating memory.ld linker include script for chosen chip."
	@echo "/* Memory map for $(chip). */" > $(memldscript)
	@echo "MEMORY" >> $(memldscript)
	@echo "{" >> $(memldscript)
	@echo "	flash (rx)  : ORIGIN = 0x08000000, LENGTH = $(flashsize)" >> $(memldscript)
	@echo "	sram (rwx)  : ORIGIN = 0x20000000, LENGTH = $(sramsize)" >> $(memldscript)
	@echo "	ccm (rwx)   : ORIGIN = 0x10000000, LENGTH = $(ccmsize)" >> $(memldscript)
	@echo "}" >> $(memldscript)

endif


# ---- Memory mapping for stm32f7 ---------------------------------------------
ifneq ($(strip $(findstring STM32F7,$(use))),)

$(memldscript):
	@echo "Generating memory.ld linker include script for chosen chip."
	@echo "/* Memory map for $(chip). */" > $(memldscript)
	@echo "MEMORY" >> $(memldscript)
	@echo "{" >> $(memldscript)
	@echo "	itcm (rwx)  : ORIGIN = 0x00000000, LENGTH = $(itcmsize)" >> $(memldscript)
	@echo "	flash (rx)  : ORIGIN = 0x08000000, LENGTH = $(flashsize)" >> $(memldscript)
	@echo " dtcm (rwx)  : ORIGIN = 0x20000000, LENGTH = $(dtcmsize)" >> $(memldscript)
	@echo "	sram (rwx)  : ORIGIN = 0x20010000, LENGTH = $(sramsize)" >> $(memldscript)
	@echo "}" >> $(memldscript)

endif


$(elffile): $(objects) $(memldscript)
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
	$(as) $(arch) $(asflags) $(warn_as) -o "$@" "$<"

$(builddir)/%.c.o : %.c
	$(cc) $(arch) $(cflags) $(includepaths) $(defines) $(warn_c) -o "$@" "$<"

$(builddir)/%.cpp.o : %.cpp 
	$(gpp) $(arch) $(cppflags) $(includepaths) $(defines) $(warn_cpp) -o "$@" "$<"

$(builddir)/%.ssys.o : %.s
	$(as) $(arch) $(asflags) -o "$@" "$<"

$(builddir)/%.csys.o : %.c
	$(cc) $(arch) $(cflags) $(includepaths) $(defines) -o "$@" "$<"

$(builddir)/%.cppsys.o : %.cpp 
	$(gpp) $(arch) $(cppflags) $(includepaths) $(defines) -o "$@" "$<"

