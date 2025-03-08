# Config
TARGET := megaman64

BASEROM := baserom.us.z64
ROM_SIZE := 0xC00000


# Folders
BUILD_DIR := build
SRC_DIR := src
ASM_DIR := asm
BIN_DIR := bin
#ASM_DIRS := $(filter-out $(wildcard $(ASM_DIR)/*.*), $(wildcard asm/*))
ASM_DIRS := $(shell find $(ASM_DIR) -type d)
BIN_DIRS := $(shell find $(BIN_DIR) -type d)
SRC_DIRS := $(filter-out $(wildcard $(SRC_DIR)/*.*), $(wildcard src/*))
SRC_BUILD_DIRS := $(addprefix $(BUILD_DIR)/,$(SRC_DIRS))
ASM_BUILD_DIR := $(BUILD_DIR)/$(ASM_DIR)
ASM_BUILD_DIRS := $(addprefix $(BUILD_DIR)/,$(ASM_DIRS))
BIN_BUILD_DIR := $(BUILD_DIR)/$(BIN_DIR)
BIN_BUILD_DIRS := $(addprefix $(BUILD_DIR)/,$(BIN_DIRS))

# Files
C_SRCS := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.c))
C_ASMS := $(addprefix $(BUILD_DIR)/, $(C_SRCS:.c=.s))
C_OBJS := $(C_ASMS:.s=.o)
AS_SRCS := $(wildcard $(ASM_DIR)/*.s) $(foreach dir,$(ASM_DIRS),$(wildcard $(dir)/*.s))
AS_OBJS := $(addprefix $(BUILD_DIR)/, $(AS_SRCS:.s=.s.o))
BINS := $(wildcard $(BIN_DIR)/*.bin)
BIN_SRCS := $(wildcard $(BIN_DIR)/*.bin) $(foreach dir,$(BIN_DIRS),$(wildcard $(dir)/*.bin))
BIN_OBJS := $(addprefix $(BUILD_DIR)/, $(BIN_SRCS:.bin=.bin.o))
OBJS := $(C_OBJS) $(AS_OBJS) $(BIN_OBJS)
LD_SCRIPT := megaman64.ld
LD_MAP    := $(BUILD_DIR)/$(TARGET).map
Z64 := $(BUILD_DIR)/$(TARGET).z64
ELF := $(Z64:.z64=.elf)

# Tools
CPP := mips-linux-gnu-cpp
CC := tools/sn/gnu/cc1n64.exe # TODO figure out how to make this work outside WSL
AS := mips-linux-gnu-gcc
OBJCOPY := mips-linux-gnu-objcopy
LD := mips-linux-gnu-ld
#LD := mips-linux-gnu-gcc

# Flags
CPPFLAGS := -Iinclude
CFLAGS := -G0 -mcpu=vr4300 -mips2 -fno-exceptions -funsigned-char -gdwarf \
   -Wa,-G0,-EB,-mips3,-mabi=32,-mgp32,-march=vr4300,-mfp32,-mno-shared
OPTFLAGS := -O2
ASFLAGS := -march=vr4300 -mabi=32 -mgp32 -mfp32 -mips3 -mno-abicalls -G0 -fno-pic -gdwarf -c -I include
BINOFLAGS := -I binary -O elf32-tradbigmips
CPP_LDFLAGS := -P -Wno-trigraphs -DBUILD_DIR=$(BUILD_DIR)
#LDFLAGS := $(LD_SCRIPT) --accept-unknown-input-arch -T undefined_syms_auto.txt --no-check-sections -T undefined_syms.txt
#LDFLAGS := -march=vr4300 -mabi=32 -mgp32 -mfp32 -mips3 -mno-abicalls -G0 -fno-pic -gdwarf -nostartfiles -Wl,-T,$(LD_SCRIPT) -Wl,-T,undefined_syms_auto.txt undefined_funcs_auto.txt -Wl,--build-id=none
LDFLAGS  := -T undefined_syms.txt -T undefined_funcs_auto.txt -T undefined_syms_auto.txt -T $(LD_SCRIPT) -Map $(LD_MAP) --no-check-sections
#LDFLAGS   := -march=vr4300 -mabi=32 -mgp32 -mfp32 -mips3 -mno-abicalls -G0 -fno-pic -gdwarf -nostartfiles -nostdlib -Wl,-T,undefined_syms_auto.txt undefined_funcs_auto.txt symbol_addrs.txt undefined_syms.txt -Wl,--build-id=none -Wl,--emit-relocs \
	-Wl,--whole-archive
Z64OFLAGS := -O binary --gap-fill=0x00

MKDIR := mkdir -p
RMDIR := rm -rf
DIFF := diff

all: check

$(BUILD_DIR) :
	$(MKDIR) $(BUILD_DIR)

$(SRC_DIR) $(SRC_BUILD_DIRS) $(ASM_BUILD_DIRS) $(BIN_BUILD_DIRS) :
	$(MKDIR) $@
	@echo $(BIN_BUILD_DIRS)

$(BUILD_DIR)/%.s.o : $(BUILD_DIR)/%.s
	$(AS) $(ASFLAGS) $(CPPFLAGS) $< -o $@

$(BUILD_DIR)/%.s.o : %.s | $(ASM_BUILD_DIRS) $(SRC_BUILD_DIRS)
	$(AS) $(ASFLAGS) $(CPPFLAGS) $< -o $@

$(BUILD_DIR)/%.bin.o : %.bin | $(BIN_BUILD_DIR)
	$(OBJCOPY) $(BINOFLAGS) $< $@
	
#$(ELF) : $(OBJS)
#	$(LD) -Wl,-T,$(LD_SCRIPT) -Wl,-Map,$(@:.elf=.map) $(LDFLAGS) -o $@

$(BUILD_DIR)/$(TARGET).elf: $(OBJS)
	$(LD) $(LDFLAGS) -o $@

$(Z64) : $(ELF)
	$(OBJCOPY) $(Z64OFLAGS) $< $@
	@readelf -s ./build/megaman64.elf > ./research/readELF.txt
	
clean:
	$(RMDIR) $(BUILD_DIR)

check: $(Z64)
	@$(DIFF) $(BASEROM) $(Z64) && printf "OK\n"

setup:
	$(RMDIR) $(ASM_DIR) $(BIN_DIR)
	tools/splat/split.py megaman64.yaml

.SUFFIXES:
MAKEFLAGS += --no-builtin-rules

keep-asm: $(C_ASMS)

.PHONY: all keep-asm clean check setup

print-% : ; $(info $* is a $(flavor $*) variable set to [$($*)]) @true
