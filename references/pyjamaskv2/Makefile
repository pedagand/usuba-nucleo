# Created from https://github.com/davisjp1822/stm32_nucleo_linux

CC=arm-none-eabi-gcc
GDB=arm-none-eabi-gdb
AR=ar
OPENOCD=openocd
OBJCOPY=objcopy
SCREEN=screen

LIBDIR=../../lib

LINKER_FILE=../../linker/STM32F401VEHx_FLASH.ld

LD_FLAGS=-L${LIBDIR}		\
	  -lstm32f4xxbsp	\
	  -lstm32f4xxhal	\
          -Wl,--gc-sections

CFLAGS=-Wall		\
	-Wno-missing-braces	\
	-mcpu=cortex-m4 \
	-mlittle-endian \
	-mthumb		\
	-std=gnu11 \
	-O3		\
	-DSTM32F401xE   \
	-DNUCLEO	\
	-DFAST

MASKING_ORDERS=4 8 16 32 64 128

INCLUDES=-I../../inc								\
	  -I../../STM32Cube_FW/Drivers/CMSIS/Device/ST/STM32F4xx/Include	\
	  -I../../STM32Cube_FW/Drivers/CMSIS/Include				\
	  -I../../STM32Cube_FW/Drivers/BSP/STM32F4xx-Nucleo			\
	  -I../../STM32Cube_FW/Drivers/STM32F4xx_HAL_Driver/Inc


all:
	make -j12 drivers;                                  \
	for masking_order in $(MASKING_ORDERS);				\
	do                                                  \
	   make ref_masked_"$$masking_order".dat;	    \
    done

DRIVER_OBJS=$(foreach MASKING_ORDER, $(MASKING_ORDERS), ref_masked_$(MASKING_ORDER).o)
drivers: $(DRIVER_OBJS)

# define bench-masked-vars-rule
# ref_masked_$(MASKING_ORDER).dat: ref_masked_$(MASKING_ORDER).log
# 	cp $$< $$@
# endef

define masked-vars-rule-c
ref_masked_$(MASKING_ORDER).o: masked_pyjamask.c
	$(CC) $(CFLAGS) $(INCLUDES)					\
	  -D MASKING_ORDER=$(MASKING_ORDER)			\
	  -c masked_pyjamask.c		              	\
      -o ref_masked_$(MASKING_ORDER).o
endef

define masked-vars-rule-asm
ref_masked_asm_$(MASKING_ORDER).o: masked_pyjamask_asm.S
	$(CC) $(CFLAGS) $(INCLUDES)	               \
	  -D MASKING_ORDER=$(MASKING_ORDER)	       \
	  -c masked_pyjamask_asm.S	               \
	  -o ref_masked_asm_$(MASKING_ORDER).o
endef

$(foreach MASKING_ORDER, $(MASKING_ORDERS),	$(eval $(masked-vars-rule-c)))
$(foreach MASKING_ORDER, $(MASKING_ORDERS),	$(eval $(masked-vars-rule-asm)))


SRC_FILES = $(wildcard ../../src/*.c ../../src/*.s)
SRC_OBJS = $(patsubst %.s,%.o, $(patsubst %.c,%.o, $(SRC_FILES)))

define masked-vars-rule-elf
ref_masked_$(MASKING_ORDER).elf: ref_masked_$(MASKING_ORDER).o ref_masked_asm_$(MASKING_ORDER).o $(SRC_OBJS) ../../lib/libstm32f4xxhal.a ../../lib/libstm32f4xxbsp.a
	$(CC) $(CFLAGS) -T$(LINKER_FILE) \
	ref_masked_$(MASKING_ORDER).o ref_masked_asm_$(MASKING_ORDER).o \
	../../src/stm32f4xx_it.o ../../src/stm32f4xx_hal_msp.o			\
	../../src/syscalls.o ../../src/system_stm32f4xx.o				\
	../../src/startup_stm32f401xe.o ../../src/main.o				\
	-o ref_masked_$(MASKING_ORDER).elf $(LD_FLAGS)
endef

$(foreach MASKING_ORDER, $(MASKING_ORDERS),	$(eval $(masked-vars-rule-elf)))

# %.elf: %.o $(SRC_OBJS) ../../lib/libstm32f4xxhal.a ../../lib/libstm32f4xxbsp.a
# 	$(CC) $(CFLAGS) -T$(LINKER_FILE) $<					\
# 		../../src/stm32f4xx_it.o ../../src/stm32f4xx_hal_msp.o			\
# 		../../src/syscalls.o ../../src/system_stm32f4xx.o				\
# 		../../src/startup_stm32f401xe.o ../../src/main.o				\
# 		 -o $@ $(LD_FLAGS)

%.hex: %.elf
	objcopy -Oihex $*.elf $*.hex

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<
%.o: %.S
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

# masked_pyjamask.elf: masked_pyjamask.o masked_pyjamask_asm.o $(SRC_OBJS) ../../lib/libstm32f4xxhal.a ../../lib/libstm32f4xxbsp.a
# 	$(CC) $(CFLAGS) -T$(LINKER_FILE) masked_pyjamask_asm.o masked_pyjamask.o	\
# 		../../src/stm32f4xx_it.o ../../src/stm32f4xx_hal_msp.o			\
# 		../../src/syscalls.o ../../src/system_stm32f4xx.o			\
# 		../../src/startup_stm32f401xe.o ../../src/main.o			\
# 		 -o $@ $(LD_FLAGS)

# Save serial input to the given file
%.log: %.hex
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset halt; flash write_image erase $<; reset run; exit"
	../../bin/serial.sh $@


define bench-masked-vars-rule
ref_masked_$(MASKING_ORDER).dat: ref_masked_$(MASKING_ORDER).log
	cp $$< $$@
endef

$(foreach MASKING_ORDER, $(MASKING_ORDERS),$(eval $(bench-masked-vars-rule)))

reset:
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset halt"

gdb: masked_pyjamask.elf
	$(GDB) masked_pyjamask.elf -x load.gdb

upload: masked_pyjamask.elf
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset halt; flash write_image erase masked_pyjamask.elf; reset run; exit"

read:
	sudo $(SCREEN) /dev/ttyACM0 9600,cs7,ixoff

clean:
	rm -f *.o *.elf *.hex
