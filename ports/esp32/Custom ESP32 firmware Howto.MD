# Compiled .bins

A copy of compiled .bins files is stored under micropython/ports/esp32/boards/PINNACLE_SPIRAM and micropython/ports/esp32/boards/PINNACLE

# Install the tool chain:

Clone micropython with the following instructions:

https://docs.micropython.org/en/latest/develop/gettingstarted.html

# How to set up a custom board:

Make a copy of the GENERIC_SPIRAM or GENERIC subfolder in ports/esp32/boards under a new folder name. This new folder name serves as the name of your custome board. You will update the following files in the copy:
board.json is just a list for the micropython.org list of firmware so its keywords aren't affecting the compilation.
mpconfigboard.cmake includes cmake options. boards/[new folder name]/sdkconfig.board must have the correct board subfolder so all other settings are used.
    Adding to .cmake file add_compile_definitions(MICROPY_PY_NETWORK_HOSTNAME_MAX_LEN=31) will cause the dhcp host name size to increase from 15 to 30. The last byte is used for \0.
mpconfigboard.h has some definitions including the name that appears when entering mp REPL
sdkconfig.board includes the compilation switches. For instance, including CONFIG_ETH_SPI_ETHERNET_W5500=y will cause the firmware to include Wiznet W5500 support.

# How to compile the firmware:

## First, we need to export some path and constants:

cd ~/Documents/Projects/esp/esp-idf/
source export.sh

## Once you run the script, go to the work folder, which is the esp32 folder under port:

cd ~/Documents/Projects/liudr/micropython/ports/esp32/

You may have to manually erase the flash before uploading new firmware:
python3 -m esptool --baud 1500000 --chip esp32 --before default_reset --after hard_reset --port /dev/ttyUSB0 erase_flash

## Clean an existing build:

make BOARD=[new folder name] clean

## Make and upload new firmware:

make BOARD=[new folder name] deploy

## Serial port monitor:

picocom -b 115200 /dev/ttyUSB0

## The complete sequence:

cd ~/Documents/Projects/esp/esp-idf/
source export.sh
cd ~/Documents/Projects/liudr/micropython/ports/esp32/
make clean BOARD=PINNACLE_GENERIC_SPIRAM
python3 -m esptool --baud 1500000 --chip esp32 --before default_reset --after hard_reset --port /dev/ttyUSB0 erase_flash
make BOARD=PINNACLE_GENERIC_SPIRAM deploy
picocom -b 115200 /dev/ttyUSB0

# Notes and observations:

## Partition table:

Default:
# Name	   Type	 SubType	 Offset	  Size	 Flags
nvs	      data	 nvs	     0x9000	  0x6000	
phy_init	 data	 phy	     0xf000	  0x1000	
factory	  app	  factory	 0x10000	 0x1F0000	
vfs	      data	 fat	     0x200000	 0x200000	

This is a 4MB partition that is the most common.
What is not displayed is the location of the partition table at 0x8000 (32KB) with the length of 3072 (0xC00) bytes and MD5 checksum to total a 4KB FLASH sector.
The first partition starting at 0x9000 (36KB) is an nvs (non-volatile storage) partition that is 24KB long, which is the default ESP-IDF setting. This area is used by ESP-IDF to store key-value pairs. I wonder if micropython provides functions to read and write this partition. It would be great if it does.
A phy_init partition stores some calibration data. Here is the info on it. Search phy_init, the last hit: https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/partition-tables.html
There is a factory app partition that starts at 0x10000 with the length of 1MB-64KB, the default starting location for ESP-IDF, where the first 64KB of flash is used as nvs and phy_init data
The last 2MB is used as a file partition with vfs.

## What are flashed to a device with the deploy command:

bootloader      is flashed to 0x1000. It's compiled inside a bootloader subfolder in the build folder.
partition table is flashed to 0x8000. It's compiled inside a partition table subfolder in the build folder.
micropython.bin is flashed to 0x10000. See partition table.

If you want to keep your existing mp file system but just want to update mp firmware, flash the micropython.bin at 0x10000 like a regular ESP-IDF project. If you want to erase everything, you must either flash a 4MB image you saved earlier or flash partition table and bootloader with micropython.bin:

esptool.py esp32 -p /dev/ttyUSB0 -b 460800 --before=default_reset --after=hard_reset write_flash --flash_mode dio --flash_freq 40m --flash_size 4MB 0x1000 bootloader/bootloader.bin 0x10000 micropython.bin 0x8000 partition_table/partition-table.bin

## Make and deploy command (incomplete with ...):

make deploy has the following commands

cd /home/zliu/Documents/Projects/liudr/micropython/ports/esp32/build-GENERIC/esp-idf/esptool_py && /home/...n_table/partition-table.bin /home/zliu/Documents/Projects/liudr/micropython/ports/esp32/build-GENERIC/micropython.bin

cd /home/zliu/Documents/Projects/esp/esp-idf/components/esptool_py && /usr/bin/cmake -D IDF_PATH="/home/z...n/ports/esp32/build-GENERIC" -P /home/zliu/Documents/Projects/esp/esp-idf/components/esptool_py/run_serial_tool.cmake


## Update Network Host Max Len:

MICROPY_PY_NETWORK_HOSTNAME_MAX_LEN is defined as 16 in modnetwork.h if it isn't defined with #ifndef. Then a global variable is defined:
extern char mod_network_hostname[MICROPY_PY_NETWORK_HOSTNAME_MAX_LEN];

In modnetwork.c there is a snippet that determines whether the input of host name is too long. Interesting call mp_raise_ValueError(NULL).
        if (len >= MICROPY_PY_NETWORK_HOSTNAME_MAX_LEN) {
            mp_raise_ValueError(NULL);
        }

## Using W5500 in MP notes

>>> spi=machine.SPI(1,sck=machine.Pin(5),mosi=machine.Pin(18),miso=machine.Pin(19))
>>> iface=network.LAN(phy_type=network.PHY_W5500,phy_addr=1,spi=spi,cs=machine.Pin(21),int=machine.Pin(12))
>>> iface.isconnected()
False
>>> iface.active(True)
True
>>> iface.isconnected()
True
>>> iface.ifconfig()
('0.0.0.0', '0.0.0.0', '0.0.0.0', '0.0.0.0')

## mp 1.20 using native decorator in compiled code issue

Fist test performed on 6/7/23. Flashed a 4MB image with my dev branch of ethernet-enabled mp 1.20 and added 1.20mp mpy files. Encountered error as below. Same error if I erase flash and flash a 1.20 release version bin with thonny install firmware feature.

I then uploaded ESP32.py to board and it started working normally. So the ESP32.mpy may have issues with compilation, such as the native decorator?

The problem seems to stem from a dictionary item comparison with a string defined in common.mpy

ets Jul 29 2019 12:21:46

rst:0xc (SW_CPU_RESET),boot:0x13 (SPI_FAST_FLASH_BOOT)
configsip: 0, SPIWP:0xee
clk_drv:0x00,q_drv:0x00,d_drv:0x00,cs0_drv:0x00,hd_drv:0x00,wp_drv:0x00
mode:DIO, clock div:2
load:0x3fff0030,len:4656
load:0x40078000,len:13284
ho 0 tail 12 room 4
load:0x40080400,len:3712
entry 0x4008064c
Found custom routines
Using pinnacle.conf

Using saved config...

Guru Meditation Error: Core  1 panic'ed (LoadStoreAlignment). Exception was unhandled.

Core  1 register dump:
PC      : 0x4009e5fc  PS      : 0x00060d30  A0      : 0x4009ea36  A1      : 0x3ffccd10  
A2      : 0x3f81e4a0  A3      : 0x00000001  A4      : 0x4009e5fc  A5      : 0x3f81a5f8  
A6      : 0x3f81b6f0  A7      : 0x3f4171f4  A8      : 0x8009ea4c  A9      : 0x3ffccd00  
A10     : 0x00000000  A11     : 0x3f825530  A12     : 0x00000001  A13     : 0x3ffccdf0  
A14     : 0x3ffccd3c  A15     : 0x3ffccdf0  SAR     : 0x00000013  EXCCAUSE: 0x00000009  
EXCVADDR: 0x4009ea36  LBEG    : 0x40094910  LEND    : 0x4009492c  LCOUNT  : 0xffffffff  

Backtrace:0x4009e5f9:0x3ffccd10 0x4009ea33:0x3ffcce00 0x400e30f2:0x3ffcce20 0x40085b59:0x3ffcce40 0x400dccec:0x3ffccee0 0x400e30f2:0x3ffccf10 0x400e311a:0x3ffccf30 0x400fead2:0x3ffccf50 0x400feb59:0x3ffccfe0 0x400fee7b:0x3ffcd010 0x400e32c0:0x3ffcd0f0 0x40085e8d:0x3ffcd130 0x400dccec:0x3ffcd1d0 0x400e30f2:0x3ffcd220 0x400e311a:0x3ffcd240 0x400effe2:0x3ffcd260 0x400f03c5:0x3ffcd2f0 0x400f043a:0x3ffcd310 0x400d6395:0x3ffcd330


ELF file SHA256: 5985f869e1307303

Rebooting...

Error types: LoadStoreError, LoadProhibited, IllegalInstruction
