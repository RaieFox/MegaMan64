# Config
TARGET := megaman64

BASEROM := baserom.us.z64
ROM_SIZE := 0xC00000


# Folders
BUILD_DIR := build
SRC_DIR := src
ASM_DIR := asm
#ASM_DIRS := $(filter-out $(wildcard $(ASM_DIR)/*.*), $(wildcard asm/*))
ASM_DIRS := $(shell find $(ASM_DIR) -type d)
BIN_DIR := bin
SRC_DIRS := $(filter-out $(wildcard $(SRC_DIR)/*.*), $(wildcard src/*))
SRC_BUILD_DIRS := $(addprefix $(BUILD_DIR)/,$(SRC_DIRS))
ASM_BUILD_DIR := $(BUILD_DIR)/$(ASM_DIR)
ASM_BUILD_DIRS := $(addprefix $(BUILD_DIR)/,$(ASM_DIRS))
BIN_BUILD_DIR := $(BUILD_DIR)/$(BIN_DIR)

# Files
C_SRCS := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.c))
C_ASMS := $(addprefix $(BUILD_DIR)/, $(C_SRCS:.c=.s))
C_OBJS := $(C_ASMS:.s=.o)
AS_SRCS := $(wildcard $(ASM_DIR)/*.s) $(foreach dir,$(ASM_DIRS),$(wildcard $(dir)/*.s))
AS_OBJS := $(addprefix $(BUILD_DIR)/, $(AS_SRCS:.s=.o))
BINS := $(wildcard $(BIN_DIR)/*.bin)
BIN_OBJS := $(addprefix $(BUILD_DIR)/, $(BINS:.bin=.o))
OBJS := $(C_OBJS) $(AS_OBJS) $(BIN_OBJS)
LD_SCRIPT := megaman64.ld
Z64 := $(BUILD_DIR)/$(TARGET).z64
ELF := $(Z64:.z64=.elf)

# Tools
CPP := mips-linux-gnu-cpp
CC := tools/sn/gnu/cc1n64.exe # TODO figure out how to make this work outside WSL
AS := mips-linux-gnu-gcc
OBJCOPY := mips-linux-gnu-objcopy
#LD := mips-linux-gnu-ld
LD := mips-linux-gnu-gcc

# Flags
CPPFLAGS := -Iinclude
CFLAGS := -G0 -mcpu=vr4300 -mips2 -fno-exceptions -funsigned-char -gdwarf \
   -Wa,-G0,-EB,-mips3,-mabi=32,-mgp32,-march=vr4300,-mfp32,-mno-shared
OPTFLAGS := -O2
ASFLAGS := -march=vr4300 -mabi=32 -mgp32 -mfp32 -mips3 -mno-abicalls -G0 -fno-pic -gdwarf -c
BINOFLAGS := -I binary -O elf32-tradbigmips
CPP_LDFLAGS := -P -Wno-trigraphs -DBUILD_DIR=$(BUILD_DIR)
#LDFLAGS := $(LD_SCRIPT) --accept-unknown-input-arch -T undefined_syms_auto.txt --no-check-sections -T undefined_syms.txt
#LDFLAGS := -march=vr4300 -mabi=32 -mgp32 -mfp32 -mips3 -mno-abicalls -G0 -fno-pic -gdwarf -nostartfiles -Wl,-T,$(LD_SCRIPT) -Wl,-T,undefined_syms_auto.txt undefined_funcs_auto.txt -Wl,--build-id=none
LDFLAGS   := -march=vr4300 -mabi=32 -mgp32 -mfp32 -mips3 -mno-abicalls -G0 -fno-pic -gdwarf -nostartfiles -nostdlib -Wl,-T,undefined_syms_auto.txt undefined_funcs_auto.txt symbol_addrs.txt -Wl,--build-id=none -Wl,--emit-relocs \
	-Wl,--whole-archive
Z64OFLAGS := -O binary --gap-fill=0x00

MKDIR := mkdir -p
RMDIR := rm -rf
DIFF := diff

all: check

$(SRC_DIR) $(SRC_BUILD_DIRS) $(ASM_BUILD_DIRS) $(BIN_BUILD_DIR) :
	$(MKDIR) $@

$(BUILD_DIR)/%.o : $(BUILD_DIR)/%.s
	$(AS) $(ASFLAGS) $(CPPFLAGS) $< -o $@

$(BUILD_DIR)/%.o : %.s | $(ASM_BUILD_DIRS) $(SRC_BUILD_DIRS)
	$(AS) $(ASFLAGS) $(CPPFLAGS) $< -o $@

$(BUILD_DIR)/%.o : %.bin | $(BIN_BUILD_DIR)
	$(OBJCOPY) $(BINOFLAGS) $< $@

#$(ELF) : $(OBJS)
#	$(LD) $(LDFLAGS) -Wl,-Map,$(@:.elf=.map) -o $@
	
$(ELF) : $(OBJS)
	$(LD) -Wl,-T,$(LD_SCRIPT) -Wl,-Map,$(@:.elf=.map) $(LDFLAGS) -o $@

$(Z64) : $(ELF)
	$(OBJCOPY) $(Z64OFLAGS) $< $@

clean:
	$(RMDIR) $(BUILD_DIR)

check: $(Z64)
	@$(DIFF) $(BASEROM) $(Z64) && printf "OK\n"

setup:
	$(RMDIR) $(ASM_DIR) $(BIN_DIR)
	tools/splat/split.py megaman64.yaml

create-dirs:
	echo $(ASM_BUILD_DIRS)
	$(MKDIR) $(ASM_BUILD_DIRS)
# tools/splat/split.py baserom.us.z64 tools/megaman64.yaml .

.SUFFIXES:
MAKEFLAGS += --no-builtin-rules

keep-asm: $(C_ASMS)

.PHONY: all keep-asm clean check setup create-dirs

print-% : ; $(info $* is a $(flavor $*) variable set to [$($*)]) @true
