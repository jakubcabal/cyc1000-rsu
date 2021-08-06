#!/usr/bin/python
#-------------------------------------------------------------------------------
# PROJECT: CYC1000 RSU
#-------------------------------------------------------------------------------
# AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
# LICENSE: The MIT License, please read LICENSE file
#-------------------------------------------------------------------------------

import sys
# Sys path allows access to python files in directory with UART submodule. 
sys.path.append('../rtl/comp/uart-for-fpga/examples/uart2wb/sw/')

from wishbone import wishbone

wb = wishbone("COM1") # on Linux use "/dev/ttyUSB0"

rd = 0xDEADDEAD

if len(sys.argv) == 3:
    arg1 = int(sys.argv[1],0)
    arg2 = int(sys.argv[2],0)
    print("Write 0x%02X to 0x%02X" % (arg2, arg1))
    wb.write(arg1,arg2)
elif len(sys.argv) == 2:
    arg1 = int(sys.argv[1],0)
    print("Read from 0x%02X" % arg1)
    rd = wb.read(arg1)
    print("0x%02X" % rd)
else:
    print("Argument error!")
    print("Help: csr.py addr data")

wb.close()
