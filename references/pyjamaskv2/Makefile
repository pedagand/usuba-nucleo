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
	-mcpu=cortex-m4 \
	-mlittle-endian \
	-mthumb		\
	-O3		\
	-DSTM32F401xE   \
	-DNUCLEO	\
	-DFAST          
#        -ggdb
#       -fstack-usage   \

INCLUDES=-I../../inc								\
	  -I../../STM32Cube_FW/Drivers/CMSIS/Device/ST/STM32F4xx/Include	\
	  -I../../STM32Cube_FW/Drivers/CMSIS/Include				\
	  -I../../STM32Cube_FW/Drivers/BSP/STM32F4xx-Nucleo			\
	  -I../../STM32Cube_FW/Drivers/STM32F4xx_HAL_Driver/Inc

%.hex: %.elf
	objcopy -Oihex $*.elf $*.hex

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<
%.o: %.S
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

masked_pyjamask.elf: masked_pyjamask.o masked_pyjamask_asm.o $(SRC_OBJS) ../../lib/libstm32f4xxhal.a ../../lib/libstm32f4xxbsp.a
	$(CC) $(CFLAGS) -T$(LINKER_FILE) masked_pyjamask_asm.o masked_pyjamask.o	\
		../../src/stm32f4xx_it.o ../../src/stm32f4xx_hal_msp.o			\
		../../src/syscalls.o ../../src/system_stm32f4xx.o			\
		../../src/startup_stm32f401xe.o ../../src/main.o			\
		 -o $@ $(LD_FLAGS)

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
