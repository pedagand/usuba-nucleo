# Modified from https://github.com/davisjp1822/stm32_nucleo_linux

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
	#-ggdb

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

all:
	make $(patsubst %,results/bench_b_%.dat,$(CIPHERS))
	make $(patsubst %,results/bench_v_%.dat,$(CIPHERS))

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<
%.o: %.s
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

.PRECIOUS: %.o

# HAL library

HAL_LIB_FILES = $(wildcard STM32Cube_FW/Drivers/STM32F4xx_HAL_Driver/Src/*.c)
HAL_LIB_OBJS = $(patsubst %.c,%.o, $(HAL_LIB_FILES))

lib/libstm32f4xxhal.a: $(HAL_LIB_OBJS)
	$(AR) rcs $@ $^

# BSP library

BSP_LIB_FILES = $(wildcard STM32Cube_FW/Drivers/BSP/STM32F4xx-Nucleo/*.c)
BSP_LIB_OBJS = $(patsubst %.c,%.o, $(BSP_LIB_FILES))

lib/libstm32f4xxbsp.a: $(BSP_LIB_OBJS)
	$(AR) rcs $@ $^

# Application

SRC_FILES = $(wildcard src/*.c src/*.s)
SRC_OBJS = $(patsubst %.s,%.o, $(patsubst %.c,%.o, $(SRC_FILES)))

# out.elf: lib/libstm32f4xxhal.a lib/libstm32f4xxbsp.a  $(SRC_OBJS)
# 	$(CC) $(CFLAGS) -T$(LINKER_FILE)			\
# 		src/stm32f4xx_it.o src/stm32f4xx_hal_msp.o	\
# 		src/syscalls.o src/system_stm32f4xx.o		\
# 		src/startup_stm32f401xe.o src/main.o		\
# 		 -o out.elf $(LD_FLAGS)

%.hex: %.elf
	objcopy -Oihex $*.elf $*.hex

CIPHERS=ace photon ascon pyjamask gift skinny clyde gimli

DRIVERS=usuba/nist/ace/usuba/bench/ace_ua_bitslice.c			\
	usuba/nist/ace/usuba/bench/ace_ua_vslice.c			\
	usuba/nist/photon/usuba/bench/photon_ua_bitslice.c	\
	usuba/nist/photon/usuba/bench/photon_ua_vslice.c		\
	usuba/nist/ascon/usuba/bench/ascon_ua_bitslice.c		\
	usuba/nist/ascon/usuba/bench/ascon_ua_vslice.c			\
	usuba/nist/pyjamask/usuba/bench/pyjamask_ua_bitslice.c		\
        usuba/nist/pyjamask/usuba/bench/pyjamask_ua_vslice.c		\
	usuba/nist/gift/usuba/bench/gift_ua_bitslice.c		\
	usuba/nist/gift/usuba/bench/gift_ua_vslice.c		\
	usuba/nist/skinny/usuba/bench/skinny_ua_bitslice.c		\
	usuba/nist/skinny/usuba/bench/skinny_ua_vslice.c		\
	usuba/nist/clyde/usuba/bench/clyde_ua_bitslice.c		\
        usuba/nist/clyde/usuba/bench/clyde_ua_vslice.c			\
	usuba/nist/gimli/usuba/bench/gimli_ua_bitslice.c		\
	usuba/nist/gimli/usuba/bench/gimli_ua_vslice.c
DRIVERS_OBJ=$(patsubst %.c,%.o, $(DRIVERS))


b_%.elf v_%.elf: $(DRIVERS_OBJ) $(SRC_OBJS) lib/libstm32f4xxhal.a lib/libstm32f4xxbsp.a
	$(CC) $(CFLAGS) -T$(LINKER_FILE)			\
		usuba/nist/$*/usuba/bench/$*_ua_bitslice.o      \
		src/stm32f4xx_it.o src/stm32f4xx_hal_msp.o	\
		src/syscalls.o src/system_stm32f4xx.o		\
		src/startup_stm32f401xe.o src/main.o		\
		 -o b_$*.elf $(LD_FLAGS)
	$(CC) $(CFLAGS) -T$(LINKER_FILE)			\
		usuba/nist/$*/usuba/bench/$*_ua_vslice.o        \
		src/stm32f4xx_it.o src/stm32f4xx_hal_msp.o	\
		src/syscalls.o src/system_stm32f4xx.o		\
		src/startup_stm32f401xe.o src/main.o		\
		 -o v_$*.elf $(LD_FLAGS)

################################################################

clean:
	rm -f lib/libstm32f4xxhal.a		\
	      lib/libstm32f4xxbsp.a		\
	      $(BSP_LIB_OBJS) $(HAL_LIB_OBJS)	\
	      $(SRC_OBJS)			\
	      b_*.elf		\
	      v_*.elf

clean-all:
	make clean; \
	rm -f b_*.hex v_*.hex

################################################################

upload-%:
	make $*.hex
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset halt; flash write_image erase $*.hex; reset run; exit"

reboot:
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset; exit"
read:
	sudo $(SCREEN) /dev/ttyACM0 9600,cs7,ixoff

save-%:
	./bin/serial.sh $*

results/bench_%.dat: force
	make upload-$* && make save-$*

force:
	true

################################################################

clone-usuba:
	git clone -b embedded-usuba https://github.com/DadaIsCrazy/usuba.git usuba

pull-usuba:
	cd usuba; git pull
