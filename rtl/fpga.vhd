--------------------------------------------------------------------------------
-- PROJECT: CYC1000 RSU
--------------------------------------------------------------------------------
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License, please read LICENSE file
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FPGA is
    Generic(
        SDRAM_CTRL_SEL : natural := 0
    );
    Port (
        -- System clock and reset button
        CLK_12M     : in    std_logic;
        RST_BTN_N   : in    std_logic;
        -- UART interface
        UART_RXD    : in    std_logic;
        UART_TXD    : out   std_logic;
        -- LED output
        LED_OUT     : out   std_logic_vector(8-1 downto 0) := (others => '0')
    );
end entity;

architecture FULL of FPGA is

    constant WB_BASE_PORTS  : natural := 4;  -- system, rsu, asmi_csr, asmi_mem
    constant WB_BASE_OFFSET : natural := 14;

    signal rst_btn                         : std_logic;
    signal clk                             : std_logic;
    signal rst                             : std_logic;
    signal rst_n                           : std_logic;

    signal wb_master_cyc                   : std_logic;
    signal wb_master_stb                   : std_logic;
    signal wb_master_we                    : std_logic;
    signal wb_master_addr                  : std_logic_vector(15 downto 0);
    signal wb_master_dout                  : std_logic_vector(31 downto 0);
    signal wb_master_stall                 : std_logic;
    signal wb_master_ack                   : std_logic;
    signal wb_master_din                   : std_logic_vector(31 downto 0);

    signal wb_mbs_cyc                      : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_stb                      : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_we                       : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_addr                     : std_logic_vector(WB_BASE_PORTS*16-1 downto 0);
    signal wb_mbs_din                      : std_logic_vector(WB_BASE_PORTS*32-1 downto 0);
    signal wb_mbs_stall                    : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_ack                      : std_logic_vector(WB_BASE_PORTS-1 downto 0);
    signal wb_mbs_dout                     : std_logic_vector(WB_BASE_PORTS*32-1 downto 0);

    signal asmi_mem_avl_csr_addr           : std_logic_vector(18 downto 0);
    signal asmi_mem_avl_csr_write          : std_logic;
    signal asmi_mem_avl_csr_read           : std_logic;
    signal asmi_mem_avl_csr_readdatavalid  : std_logic;
    signal asmi_mem_avl_csr_readdata       : std_logic_vector(31 downto 0);
    signal asmi_mem_avl_csr_writedata      : std_logic_vector(31 downto 0);

    signal asmi_csr_avl_csr_write          : std_logic;
    signal asmi_csr_avl_csr_read           : std_logic;
    signal asmi_csr_avl_csr_readdatavalid  : std_logic;

    signal rsu_avl_csr_write               : std_logic;
    signal rsu_avl_csr_read                : std_logic;
    signal rsu_avl_csr_readdatavalid       : std_logic;

    component asmi_p2 is
        port (
            clk_clk               : in  std_logic                     := 'X';             -- clk
            reset_reset_n         : in  std_logic                     := 'X';             -- reset_n
            avl_csr_address       : in  std_logic_vector(5 downto 0)  := (others => 'X'); -- address
            avl_csr_read          : in  std_logic                     := 'X';             -- read
            avl_csr_readdata      : out std_logic_vector(31 downto 0);                    -- readdata
            avl_csr_write         : in  std_logic                     := 'X';             -- write
            avl_csr_writedata     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
            avl_csr_waitrequest   : out std_logic;                                        -- waitrequest
            avl_csr_readdatavalid : out std_logic;                                        -- readdatavalid
            avl_mem_write         : in  std_logic                     := 'X';             -- write
            avl_mem_burstcount    : in  std_logic_vector(6 downto 0)  := (others => 'X'); -- burstcount
            avl_mem_waitrequest   : out std_logic;                                        -- waitrequest
            avl_mem_read          : in  std_logic                     := 'X';             -- read
            avl_mem_address       : in  std_logic_vector(18 downto 0) := (others => 'X'); -- address
            avl_mem_writedata     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
            avl_mem_readdata      : out std_logic_vector(31 downto 0);                    -- readdata
            avl_mem_readdatavalid : out std_logic;                                        -- readdatavalid
            avl_mem_byteenable    : in  std_logic_vector(3 downto 0)  := (others => 'X')  -- byteenable
        );
    end component asmi_p2;

    component remote_update is
        port (
            clock                 : in  std_logic                     := 'X';             -- clk
            reset                 : in  std_logic                     := 'X';             -- reset
            avl_csr_write         : in  std_logic                     := 'X';             -- write
            avl_csr_read          : in  std_logic                     := 'X';             -- read
            avl_csr_writedata     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
            avl_csr_readdata      : out std_logic_vector(31 downto 0);                    -- readdata
            avl_csr_readdatavalid : out std_logic;                                        -- readdatavalid
            avl_csr_waitrequest   : out std_logic;                                        -- waitrequest
            avl_csr_address       : in  std_logic_vector(4 downto 0)  := (others => 'X')  -- address
        );
    end component remote_update;

begin

    clk <= CLK_12M;
    rst_btn <= not RST_BTN_N;

    rst_sync_i : entity work.RST_SYNC
    port map (
        CLK        => CLK_12M,
        ASYNC_RST  => rst_btn,
        SYNCED_RST => rst
    );

    rst_n <= not rst;

    uart2wbm_i : entity work.UART2WBM
    generic map (
        CLK_FREQ  => 12e6,
        BAUD_RATE => 9600
    )
    port map (
        CLK      => clk,
        RST      => rst,
        -- UART INTERFACE
        UART_TXD => UART_TXD,
        UART_RXD => UART_RXD,
        -- WISHBONE MASTER INTERFACE
        WB_CYC   => wb_master_cyc,
        WB_STB   => wb_master_stb,
        WB_WE    => wb_master_we,
        WB_ADDR  => wb_master_addr,
        WB_DOUT  => wb_master_dout,
        WB_STALL => wb_master_stall,
        WB_ACK   => wb_master_ack,
        WB_DIN   => wb_master_din
    );

    wb_splitter_base_i : entity work.WB_SPLITTER
    generic map (
        MASTER_PORTS => WB_BASE_PORTS,
        ADDR_OFFSET  => WB_BASE_OFFSET
    )
    port map (
        CLK        => clk,
        RST        => rst,

        WB_S_CYC   => wb_master_cyc,
        WB_S_STB   => wb_master_stb,
        WB_S_WE    => wb_master_we,
        WB_S_ADDR  => wb_master_addr,
        WB_S_DIN   => wb_master_dout,
        WB_S_STALL => wb_master_stall,
        WB_S_ACK   => wb_master_ack,
        WB_S_DOUT  => wb_master_din,

        WB_M_CYC   => wb_mbs_cyc,
        WB_M_STB   => wb_mbs_stb,
        WB_M_WE    => wb_mbs_we,
        WB_M_ADDR  => wb_mbs_addr,
        WB_M_DOUT  => wb_mbs_dout,
        WB_M_STALL => wb_mbs_stall,
        WB_M_ACK   => wb_mbs_ack,
        WB_M_DIN   => wb_mbs_din
    );

    sys_module_i : entity work.SYS_MODULE
    port map (
        -- CLOCK AND RESET
        CLK      => clk,
        RST      => rst,

        -- WISHBONE SLAVE INTERFACE
        WB_CYC   => wb_mbs_cyc(0),
        WB_STB   => wb_mbs_stb(0),
        WB_WE    => wb_mbs_we(0),
        WB_ADDR  => wb_mbs_addr((0+1)*16-1 downto 0*16),
        WB_DIN   => wb_mbs_dout((0+1)*32-1 downto 0*32),
        WB_STALL => wb_mbs_stall(0),
        WB_ACK   => wb_mbs_ack(0),
        WB_DOUT  => wb_mbs_din((0+1)*32-1 downto 0*32)
    );

    --rsu_avl_csr_addr  <= wb_mbs_addr(1*16+5-1 downto 1*16);
    rsu_avl_csr_write <= wb_mbs_stb(1) and wb_mbs_we(1);
    rsu_avl_csr_read  <= wb_mbs_stb(1) and not wb_mbs_we(1);
    wb_mbs_ack(1) <= rsu_avl_csr_readdatavalid or (rsu_avl_csr_write and not wb_mbs_stall(1));

    rsu_i : component remote_update
    port map (
        clock                 => clk,                 --   clock.clk
        reset                 => rst,                 --   reset.reset
        avl_csr_write         => rsu_avl_csr_write,         -- avl_csr.write
        avl_csr_read          => rsu_avl_csr_read,          --        .read
        avl_csr_writedata     => wb_mbs_dout((1+1)*32-1 downto 1*32),     --        .writedata
        avl_csr_readdata      => wb_mbs_din((1+1)*32-1 downto 1*32),      --        .readdata
        avl_csr_readdatavalid => rsu_avl_csr_readdatavalid, --        .readdatavalid
        avl_csr_waitrequest   => wb_mbs_stall(1),   --        .waitrequest
        avl_csr_address       => wb_mbs_addr(1*16+5-1 downto 1*16)        --        .address
    );

    --asmi_csr_avl_csr_addr  <= wb_mbs_addr(2*16+8-1 downto 2*16+2);
    asmi_csr_avl_csr_write <= wb_mbs_stb(2) and wb_mbs_we(2);
    asmi_csr_avl_csr_read  <= wb_mbs_stb(2) and not wb_mbs_we(2);
    wb_mbs_ack(2) <= asmi_csr_avl_csr_readdatavalid or (asmi_csr_avl_csr_write and not wb_mbs_stall(2));

    asmi_mem_avl_csr_addr  <= "00000" & wb_mbs_addr(3*16+14-1 downto 3*16);
    asmi_mem_avl_csr_write <= wb_mbs_stb(3) and wb_mbs_we(3);
    asmi_mem_avl_csr_read  <= wb_mbs_stb(3) and not wb_mbs_we(3);
    
    wb_mbs_ack(3) <= asmi_mem_avl_csr_readdatavalid or (asmi_mem_avl_csr_write and not wb_mbs_stall(3));

    data_reverse_g : for i in 0 to 31 generate
        wb_mbs_din(3*32+i) <= asmi_mem_avl_csr_readdata(31-i);
        asmi_mem_avl_csr_writedata(31-i) <= wb_mbs_dout(3*32+1);
    end generate;

    asmi_i : component asmi_p2
    port map (
        clk_clk               => clk,         --     clk.clk
        reset_reset_n         => rst_n,         --   reset.reset_n
        avl_csr_address       => wb_mbs_addr(2*16+6-1 downto 2*16),       -- avl_csr.address
        avl_csr_read          => asmi_csr_avl_csr_read,          --        .read
        avl_csr_readdata      => wb_mbs_din((2+1)*32-1 downto 2*32),      --        .readdata
        avl_csr_write         => asmi_csr_avl_csr_write,         --        .write
        avl_csr_writedata     => wb_mbs_dout((2+1)*32-1 downto 2*32),     --        .writedata
        avl_csr_waitrequest   => wb_mbs_stall(2),   --        .waitrequest
        avl_csr_readdatavalid => asmi_csr_avl_csr_readdatavalid, --        .readdatavalid
        avl_mem_write         => asmi_mem_avl_csr_write,         -- avl_mem.write
        avl_mem_burstcount    => "0000001",    --        .burstcount
        avl_mem_waitrequest   => wb_mbs_stall(3),   --        .waitrequest
        avl_mem_read          => asmi_mem_avl_csr_read,          --        .read
        avl_mem_address       => asmi_mem_avl_csr_addr,       --        .address
        avl_mem_writedata     => asmi_mem_avl_csr_writedata,     --        .writedata
        avl_mem_readdata      => asmi_mem_avl_csr_readdata,      --        .readdata
        avl_mem_readdatavalid => asmi_mem_avl_csr_readdatavalid, --        .readdatavalid
        avl_mem_byteenable    => (others => '1')     --        .byteenable
    );

end architecture;
