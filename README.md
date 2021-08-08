# CYC1000 Remote System Upgrade

This repository contains a source code of the CYC1000 Remote System Upgrade project.
The goal is to show possible ways to update the FPGA bitstream (Intel/Altera), which is stored on attached flash memory.
The first implementation allows remote bitstream updates via the UART interface.

* Development board [CYC1000](https://shop.trenz-electronic.de/en/Products/Trenz-Electronic/CYC1000-Intel-Cyclone-10/), [documentation](https://www.trenz-electronic.de/fileadmin/docs/Trenz_Electronic/Modules_and_Module_Carriers/2.5x6.15/TEI0003/REV02/Documents/CYC1000%20User%20Guide.pdf), [driver](https://shop.trenz-electronic.de/en/TEI0003-02-CYC1000-with-Cyclone-10-FPGA-8-MByte-SDRAM?path=Trenz_Electronic/Modules_and_Module_Carriers/2.5x6.15/TEI0003/Driver/Arrow_USB_Programmer)
* Languages - VHDL, Python

The project is using the following open-source codes:

- https://github.com/jakubcabal/uart-for-fpga - The UART controller and UART2WB bridge.

To clone the repository, run:

```bash
git clone --recursive git@github.com:jakubcabal/cyc1000-rsu.git
```

## FPGA design

### TODO list

- [x] Write bitstream (.rbf) to flash memory via UART interface
- [x] Support for UART command to reboot FPGA
- [ ] Support for multiple bitsreams
- [ ] Write bitstream (.rbf) to flash memory via Ethernet

### Remote update bitstream

The initial design with this Remote System Upgrade (RSU) logic must be loaded into the FPGA (flash memory) in the usual way using Quartus.
Then it is possible to load new bitstream (.rbf) using the following Python script, which can be found in the `sw` directory.

```bash
python .\update_bitstream.py ..\rtl\synth\FPGA.rbf
```

The .rbf file can be obtained by conversion from a .sof file.
Or you can set Quartus to generate an .rbf file already in the assembler stage at the same time as the .sof file.
In order to continue to use this method of updating the bitstream, the new bitstream must also contain RSU logic.

> On Windows 10, bitstream writing via the UART interface was very slow (~ 15 minutes), the solution was to change the Latency Timer setting to 1 ms. (Device manager -> Ports -> COM1 -> Advanced). Now writing takes about 2 minutes.

### Top level diagram
```
          +----+----+
UART <----| UART2WB |
PORT ---->| MASTER  |
          +---------+
               ↕
       +=======+========+===============+ WISHBONE BUS
       ↕                ↕               ↕
 +-----+-----+    +-----+-----+    +----+----+
 | ASMI2 IP  |    | Remote    |    | SYSTEM  |
 |           |    | Update IP |    | MODULE  |
 +-----------+    +-----------+    +---------+
       ↕
     FLASH
```

### Main modules description

* UART2WB MASTER - Transmits the Wishbone requests and responses via UART interface (Wishbone master).
* SYSTEM MODULE - Basic system control and status registers (version, debug space etc.).
* ASMI2 IP - The ASMI Parallel II Intel FPGA IP provides access to the configuration devices (EPCQ), [IP User Guide](https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/ug/ug-asmi2.pdf).
* Remote Update IP - The Remote Update Intel FPGA IP core implements a device reconfiguration, [IP User Guide](https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/ug/ug_altremote.pdf).

## License
The project is available under the MIT license (MIT). Please read [LICENSE file](LICENSE).
