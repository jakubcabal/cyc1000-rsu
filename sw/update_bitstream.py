#!/usr/bin/python
#-------------------------------------------------------------------------------
# PROJECT: CYC1000 RSU
#-------------------------------------------------------------------------------
# AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

import sys
import math
# Sys path allows access to python files in directory with UART submodule. 

sys.path.append('../rtl/comp/uart-for-fpga/examples/uart2wb/sw/')

from wishbone import wishbone

if len(sys.argv) == 2:
    rbf_file_path = sys.argv[1]
    print("Start of update factory bitstream with this file:", rbf_file_path)
else:
    print("Argument error!")
    print("Help: update_bitstream.py rbf_file_path")
    exit()

with open(rbf_file_path, 'rb') as f:
    rbf_raw = f.read()

rbf_list = []
rbf_raw_len = len(rbf_raw)
rbf_raw_dw = math.ceil(len(rbf_raw)/4)
rbf_raw_mod = (len(rbf_raw) % 4)
#print(rbf_raw_len)
#print(rbf_raw_dw)
#print(rbf_raw_mod)

if rbf_raw_mod > 0:
    for i in range(0, rbf_raw_mod):
        rbf_raw += b'\xff'

for i in range(0, len(rbf_raw)-3, 4):
    rbf_list.append(int.from_bytes([rbf_raw[i],rbf_raw[i+1],rbf_raw[i+2],rbf_raw[i+3]], "big"))
    #print("0x%08X" % rbf_list[-1])

wb = wishbone("COM1",115200,32) # on Linux use "/dev/ttyUSB0"
# write enable
wb.write(0x80000000,0x1)
# read wr status
wb.read(0x80000002)
# erase all flash
wb.write(0x80000011,0x1)
# read wr status
wb.read(0x80000002)

percent = len(rbf_list)/100
# write new bitstream to flash per dwords
print("Writing a new bitstream to flash memory, percentage status:")
for i in range(0, len(rbf_list)):
    addr = 0xC0000000 + i
    wb.write(addr,rbf_list[i])
    if i % 100 == 0:
        state = i/percent
        sys.stdout.write("\r%0.2f"%state+"%")
        sys.stdout.flush()
sys.stdout.write("\r100.00%")
sys.stdout.flush()
print("\nWriting to flash memory is completed.")

# reboot FPGA
wb.write(0x4000001D,0x1)
print("Reboot FPGA requested...")

wb.close()
