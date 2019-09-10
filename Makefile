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
	-DSTM32F401xE	\
	-ggdb

INCLUDES=-I./inc							\
	  -I./STM32Cube_FW/Drivers/CMSIS/Device/ST/STM32F4xx/Include	\
	  -I./STM32Cube_FW/Drivers/CMSIS/Include			\
	  -I./STM32Cube_FW/Drivers/BSP/STM32F4xx-Nucleo			\
	  -I./STM32Cube_FW/Drivers/STM32F4xx_HAL_Driver/Inc

all: out.hex

# Dependencies (hard-coded imports)
#
# src/startup_stm32f401xe.s: 
# 	cp Drivers/CMSIS/Device/ST/STM32F4xx/Source/Templates/gcc/startup_stm32f401xe.s src/
#
# src/syscalls.c:
# 	cp Projects/STM32F401RE-Nucleo/Examples/UART/UART_Printf/SW4STM32/syscalls.c src/

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<
%.o: %.s
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

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

out.elf: lib/libstm32f4xxhal.a lib/libstm32f4xxbsp.a  $(SRC_OBJS)
	$(CC) $(CFLAGS) -T$(LINKER_FILE)			\
		src/stm32f4xx_it.o src/stm32f4xx_hal_msp.o	\
		src/syscalls.o src/system_stm32f4xx.o		\
		src/startup_stm32f401xe.o src/main.o		\
		 -o out.elf $(LD_FLAGS)

out.hex: out.elf
	objcopy -Oihex out.elf out.hex

upload:
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset halt; flash write_image erase out.hex; reset run; exit"

reboot:
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset; exit"
read:
	sudo $(SCREEN) /dev/ttyACM0 9600,cs7,ixoff

clean:
	rm -f lib/libstm32f4xxhal.a		\
	      lib/libstm32f4xxbsp.a		\
	      $(BSP_LIB_OBJS) $(HAL_LIB_OBJS)	\
	      $(SRC_OBJS) out.elf

clean-all:
	make clean; rm out.hex
