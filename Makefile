# Created from https://github.com/davisjp1822/stm32_nucleo_linux

CC=arm-none-eabi-gcc
AR=ar
OPENOCD=openocd
OBJCOPY=objcopy
SCREEN=screen

LIBDIR=./lib

LINKER_FILE=linker/STM32F401VEHx_FLASH.ld

LD_FLAGS=-L${LIBDIR}		\
	  -lstm32f4xxbsp	\
	  -lstm32f4xxhal	\
          -Wl,--gc-sections

CFLAGS=-Wall		\
	-mcpu=cortex-m4 \
	-mlittle-endian \
	-mthumb		\
	-Os		\
	-DSTM32F401xE	#\
#       -fstack-usage   \
#       -ggdb

INCLUDES=-I./inc							\
	  -I./usuba/arch                                                \
	  -I./STM32Cube_FW/Drivers/CMSIS/Device/ST/STM32F4xx/Include	\
	  -I./STM32Cube_FW/Drivers/CMSIS/Include			\
	  -I./STM32Cube_FW/Drivers/BSP/STM32F4xx-Nucleo			\
	  -I./STM32Cube_FW/Drivers/STM32F4xx_HAL_Driver/Inc

################################################################

# Dependencies (hard-coded imports)
#
# src/startup_stm32f401xe.s:
# 	cp Drivers/CMSIS/Device/ST/STM32F4xx/Source/Templates/gcc/startup_stm32f401xe.s src/
#
# src/syscalls.c:
# 	cp Projects/STM32F401RE-Nucleo/Examples/UART/UART_Printf/SW4STM32/syscalls.c src/

################################################################
# Compile the benchmark results

include ciphers.mk


all:
	make -j4 drivers;                                                               \
	for cipher in $(CIPHERS);							\
	do										\
	  for mode in bitslice vslice;							\
	  do										\
	    make results/bench_"$$cipher"_"$$mode".dat;					\
	    for masking_order in $(MASKING_ORDERS);					\
	    do                                                                          \
	      make results/bench_masked_"$$masking_order"_"$$cipher"_"$$mode".dat;	\
	    done;									\
	  done;										\
        done

################################################################
# Global setup

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<
%.o: %.s
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

.PRECIOUS: %.o

################################################################
# HAL library

HAL_LIB_FILES = $(wildcard STM32Cube_FW/Drivers/STM32F4xx_HAL_Driver/Src/*.c)
HAL_LIB_OBJS = $(patsubst %.c,%.o, $(HAL_LIB_FILES))

lib/libstm32f4xxhal.a: $(HAL_LIB_OBJS)
	$(AR) rcs $@ $^

################################################################
# BSP library

BSP_LIB_FILES = $(wildcard STM32Cube_FW/Drivers/BSP/STM32F4xx-Nucleo/*.c)
BSP_LIB_OBJS = $(patsubst %.c,%.o, $(BSP_LIB_FILES))

lib/libstm32f4xxbsp.a: $(BSP_LIB_OBJS)
	$(AR) rcs $@ $^

################################################################
# Benchmarks, bitslice & vslice

SRC_FILES = $(wildcard src/*.c src/*.s)
SRC_OBJS = $(patsubst %.s,%.o, $(patsubst %.c,%.o, $(SRC_FILES)))

%.hex: %.elf
	objcopy -Oihex $*.elf $*.hex

DRIVER_OBJS=$(foreach MODE, vslice bitslice,								\
	    $(foreach CIPHER, $(CIPHERS),								\
	      usuba/nist/$(CIPHER)/usuba/bench/$(CIPHER)_ua_$(MODE).o					\
	      $(foreach MASKING_ORDER, $(MASKING_ORDERS),						\
	        usuba/nist/$(CIPHER)/usuba/bench/masked_$(MASKING_ORDER)_$(CIPHER)_ua_$(MODE).o )))

drivers: $(DRIVER_OBJS)

define masked-vars-rule
usuba/nist/$(CIPHER)/usuba/bench/masked_$(MASKING_ORDER)_$(CIPHER)_ua_$(MODE).o: usuba/nist/$(CIPHER)/usuba/bench/masked_$(CIPHER)_ua_$(MODE).c
	$(CC) $(CFLAGS) $(INCLUDES)								\
	  -D MASKING_ORDER=$(MASKING_ORDER)							\
	  -c usuba/nist/$(CIPHER)/usuba/bench/masked_$(CIPHER)_ua_$(MODE).c			\
          -o usuba/nist/$(CIPHER)/usuba/bench/masked_$(MASKING_ORDER)_$(CIPHER)_ua_$(MODE).o
endef

$(foreach CIPHER, $(CIPHERS),			\
$(foreach MASKING_ORDER, $(MASKING_ORDERS),	\
$(foreach MODE, bitslice vslice,		\
$(eval $(masked-vars-rule)))))

%.elf: %.o $(SRC_OBJS) lib/libstm32f4xxhal.a lib/libstm32f4xxbsp.a
	$(CC) $(CFLAGS) -T$(LINKER_FILE) $<					\
		src/stm32f4xx_it.o src/stm32f4xx_hal_msp.o			\
		src/syscalls.o src/system_stm32f4xx.o				\
		src/startup_stm32f401xe.o src/main.o				\
		 -o $@ $(LD_FLAGS)

################################################################
# Cleaning

clean:
	rm -f lib/libstm32f4xxhal.a		\
	      lib/libstm32f4xxbsp.a		\
	      $(BSP_LIB_OBJS) $(HAL_LIB_OBJS)	\
	      $(SRC_OBJS)			\
	      $(DRIVER_OBJS)			\
	      b_*.elf				\
	      v_*.elf

clean-all:
	make clean; \
	rm -f results/*.dat b_*.hex v_*.hex

################################################################
# Interactions with the board

# Restart the board
reboot:
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset; exit"

# Read output on serial port (close with C-a \)
read:
	sudo $(SCREEN) /dev/ttyACM0 9600,cs7,ixoff

# Load .hex file to the board
%.upload: %.hex
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset halt; flash write_image erase $<; reset run; exit"

# Save serial input to the given file
%.log: %.hex
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset halt; flash write_image erase $<; reset run; exit"
	./bin/serial.sh $@

# Run the benchmark for the given cipher
define bench-raw-vars-rule
results/bench_$(CIPHER)_$(MODE).dat: usuba/nist/$(CIPHER)/usuba/bench/$(CIPHER)_ua_$(MODE).log
	cp $$< $$@
endef

define bench-masked-vars-rule
results/bench_masked_$(MASKING_ORDER)_$(CIPHER)_$(MODE).dat: usuba/nist/$(CIPHER)/usuba/bench/masked_$(MASKING_ORDER)_$(CIPHER)_ua_$(MODE).log
	cp $$< $$@
endef

$(foreach CIPHER, $(CIPHERS),			\
$(foreach MODE, bitslice vslice,		\
$(eval $(bench-raw-vars-rule))			\
$(foreach MASKING_ORDER, $(MASKING_ORDERS),	\
$(eval $(bench-masked-vars-rule)))))

force:
	true

################################################################
# Setup and pull the local Usuba repository

clone-usuba:
	git clone -b embedded-usuba https://github.com/DadaIsCrazy/usuba.git usuba

pull-usuba:
	cd usuba; git pull
