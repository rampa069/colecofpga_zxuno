-------------------------------------------------------------------------------
--
-- ColecoFPGA project
--
-- Copyright (c) 2006, Arnim Laeuger (arnim.laeuger@gmx.net)
-- Copyright (c) 2016, Fabio Belavenuto (belavenuto@gmail.com)
-- Copyright (c) 2022, Ramon Martinez (rampa@encomix.org) (SGM module)
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity colecovision is
	generic (
		num_maq_g		: integer := 0;
		compat_rgb_g	: integer := 0
	);
	port (
		clock_i			: in  std_logic;
		clk_en_10m7_i	: in  std_logic;
		clk_en_5m37_i	: in  std_logic;
		clk_en_3m58_p_i: in  std_logic;
		clk_en_3m58_n_i: in  std_logic;
		reset_i			: in  std_logic;			-- Reset, tbem acionado quando por_n_i for 0
		por_n_i			: in  std_logic;			-- Power-on Reset
		-- Controller Interface ---------------------------------------------------
		ctrl_p1_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p2_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p3_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p4_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p5_o		: out std_logic_vector( 1 downto 0);
		ctrl_p6_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p7_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p8_o		: out std_logic_vector( 1 downto 0);
		ctrl_p9_i		: in  std_logic_vector( 1 downto 0);
		-- CPU RAM Interface ------------------------------------------------------
		ram_addr_o		: out std_logic_vector(18 downto 0);	-- 512K
		ram_ce_o			: out std_logic;
		ram_oe_o			: out std_logic;
		ram_we_o			: out std_logic;
		ram_data_i		: in  std_logic_vector( 7 downto 0);
		ram_data_o		: out std_logic_vector( 7 downto 0);
		-- Video RAM Interface ----------------------------------------------------
		vram_addr_o		: out std_logic_vector(13 downto 0);	-- 16K
		vram_ce_o		: out std_logic;
		vram_oe_o		: out std_logic;
		vram_we_o		: out std_logic;
		vram_data_i		: in  std_logic_vector( 7 downto 0);
		vram_data_o		: out std_logic_vector( 7 downto 0);
		-- Cartridge ROM Interface ------------------------------------------------
		cart_addr_o		: out std_logic_vector(14 downto 0);	-- 32K
		cart_data_i		: in  std_logic_vector( 7 downto 0);
		cart_oe_n_o		: out std_logic;
		cart_en_80_n_o	: out std_logic;
		cart_en_a0_n_o	: out std_logic;
		cart_en_c0_n_o	: out std_logic;
		cart_en_e0_n_o	: out std_logic;
		-- Audio Interface --------------------------------------------------------
		audio_o			: out unsigned(13 downto 0);
		audio_signed_o	: out signed(13 downto 0);
		-- RGB Video Interface ----------------------------------------------------
		col_o				: out std_logic_vector( 3 downto 0);
		cnt_hor_o		: out std_logic_vector( 8 downto 0);
		cnt_ver_o		: out std_logic_vector( 7 downto 0);
		rgb_r_o			: out std_logic_vector( 7 downto 0);
		rgb_g_o			: out std_logic_vector( 7 downto 0);
		rgb_b_o			: out std_logic_vector( 7 downto 0);
		hsync_n_o		: out std_logic;
		vsync_n_o		: out std_logic;
		comp_sync_n_o	: out std_logic;
		-- SPI
		spi_miso_i		: in  std_logic;
		spi_mosi_o		: out std_logic;
		spi_sclk_o		: out std_logic;
		spi_cs_n_o		: out std_logic;
		sd_cd_n_i		: in  std_logic;
		-- DEBUG
		D_cpu_addr		: out std_logic_vector(15 downto 0)
	);

end entity;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

architecture Behavior of colecovision is

   component ym2149_audio
   generic                 -- Non-custom PSG address mask is 0000.
      ( ADDRESS_G          : std_logic_vector(3 downto 0) := x"0"
   );
   port
      ( clk_i              : in     std_logic -- system clock
      ; en_clk_psg_i       : in     std_logic -- PSG clock enable
      ; sel_n_i            : in     std_logic -- divide select, 0=clock-enable/2
      ; reset_n_i          : in     std_logic -- active low
      ; bc_i               : in     std_logic -- bus control
      ; bdir_i             : in     std_logic -- bus direction
      ; data_i             : in     std_logic_vector(7 downto 0)
      ; data_r_o           : out    std_logic_vector(7 downto 0) -- registered output data
      ; ch_a_o             : out    unsigned(11 downto 0)
      ; ch_b_o             : out    unsigned(11 downto 0)
      ; ch_c_o             : out    unsigned(11 downto 0)
      ; mix_audio_o        : out    unsigned(13 downto 0)
      ; pcm14s_o           : out    unsigned(13 downto 0)
   );
   end component;

   component sn76489_audio
   generic                 -- 0 = normal I/O, 32 clocks per write
                           -- 1 = fast I/O, around 2 clocks per write
      ( FAST_IO_G          : std_logic := '0'

                           -- Minimum allowable period count (see comments further
                           -- down for more information), recommended:
                           --  6  18643.46Hz First audible count.
                           -- 17   6580.04Hz Counts at 16 are known to be used for
                           --                amplitude-modulation.
      ; MIN_PERIOD_CNT_G   : integer := 6
   );
   port
      ( clk_i              : in     std_logic -- System clock
      ; en_clk_psg_i       : in     std_logic -- PSG clock enable
      ; ce_n_i             : in     std_logic -- chip enable, active low
      ; wr_n_i             : in     std_logic -- write enable, active low
      ; ready_o            : out    std_logic -- low during I/O operations
      ; data_i             : in     std_logic_vector(7 downto 0)
      ; ch_a_o             : out    unsigned(11 downto 0)
      ; ch_b_o             : out    unsigned(11 downto 0)
      ; ch_c_o             : out    unsigned(11 downto 0)
      ; noise_o            : out    unsigned(11 downto 0)
      ; mix_audio_o        : out    unsigned(13 downto 0)
      ; pcm14s_o           : out    unsigned(13 downto 0)
   );
   end component;
	
	COMPONENT T80pa
	PORT(
		RESET_n : IN std_logic;
		CLK : IN std_logic;
		CEN_p : IN std_logic;
		CEN_n : IN std_logic;
		WAIT_n : IN std_logic;
		INT_n : IN std_logic;
		NMI_n : IN std_logic;
		BUSRQ_n : IN std_logic;
		OUT0 : IN std_logic;
		DI : IN std_logic_vector(7 downto 0);
		R800_mode : IN std_logic;
		DIRSet : IN std_logic;
		DIR : IN std_logic_vector(211 downto 0);          
		M1_n : OUT std_logic;
		MREQ_n : OUT std_logic;
		IORQ_n : OUT std_logic;
		RD_n : OUT std_logic;
		WR_n : OUT std_logic;
		RFSH_n : OUT std_logic;
		HALT_n : OUT std_logic;
		BUSAK_n : OUT std_logic;
		A : OUT std_logic_vector(15 downto 0);
		DO : OUT std_logic_vector(7 downto 0);
		REG : OUT std_logic_vector(211 downto 0)
		);
	END COMPONENT;

	-- Reset
	signal reset_n_s			: std_logic;

	-- CPU signals
	signal clk_en_cpu_s		: std_logic;
	signal nmi_n_s				: std_logic;
	signal iorq_n_s			: std_logic;
	signal m1_n_s           : std_logic;
	signal m1_wait_q        : std_logic;
	signal rd_n_s				: std_logic;
	signal wr_n_s				: std_logic;
	signal wait_n_s         : std_logic;
	signal int_n_s          : std_logic;
	signal mreq_n_s			: std_logic;
	signal rfsh_n_s			: std_logic;
	signal cpu_addr_s			: std_logic_vector(15 downto 0);
	signal d_to_cpu_s			: std_logic_vector( 7 downto 0);
	signal d_from_cpu_s		: std_logic_vector( 7 downto 0);

	-- Address Decoder
	signal mem_access_s		: std_logic;
	signal io_access_s		: std_logic;
	signal io_read_s			: std_logic;
	signal io_write_s			: std_logic;
	signal bios_en_s        : std_logic;
	signal cart_page_s      : std_logic_vector(3 downto 0) := "0000";
	signal cart_totpage_s   : std_logic_vector(3 downto 0);
	signal cart_actpage_s   : std_logic_vector(3 downto 0);
	signal cart_actpage_cs_s: std_logic;
	signal cart_totpage_cs_s: std_logic;
	signal megacart_en_s    : std_logic;
	signal megacart_page_s  : std_logic_vector(3 downto 0);

	-- machine id
	signal machine_id_cs_s	: std_logic;
	constant machine_id_c	: std_logic_vector(7 downto 0)		:= std_logic_vector(to_unsigned(num_maq_g, 8));

	-- Config port
	signal cfg_port_cs_s		: std_logic;
	signal cfg_page_cs_s		: std_logic;
	signal cfg_page_r			: std_logic_vector(7 downto 0);

	-- BIOS
	signal loader_ce_s		: std_logic;
	signal d_from_loader_s	: std_logic_vector( 7 downto 0);
	signal loader_q			: std_logic;
	signal multcart_q			: std_logic;
	signal bios_ce_s			: std_logic;
	signal bios_oe_s			: std_logic;
	signal bios_we_s			: std_logic;

	-- RAM
	signal ram_ce_s			: std_logic;

	-- VDP18 signal
	signal d_from_vdp_s		: std_logic_vector( 7 downto 0);
	signal vdp_r_n_s			: std_logic;
	signal vdp_w_n_s			: std_logic;

	-- SN76489 signal
	signal psg_a_audio_s    : signed( 13 downto 0);
	signal psg_a_audio_u2   : unsigned( 13 downto 0);
	signal psg_a_audio_u    : unsigned( 13 downto 0);
	signal psg_ready_s      : std_logic;
	signal psg_we_n_s			: std_logic;


	 -- AY-8910 signal
	signal ay_d_s           : std_logic_vector( 7 downto 0);
	signal ay_ch_a_s        : unsigned( 11 downto 0);
	signal ay_ch_b_s        : unsigned( 11 downto 0);
	signal ay_ch_c_s        : unsigned( 11 downto 0);
    signal psg_b_audio_s    : signed( 13 downto 0);
	signal psg_b_audio_u2   : unsigned( 13 downto 0);
	signal psg_b_audio_u    : unsigned( 13 downto 0);
	signal ay_addr_we_n_s   : std_logic;
	signal ay_addr_rd_n_s   : std_logic;
	signal ay_data_rd_n_s   : std_logic;
	signal ay_data_we_n_s   : std_logic;
	
   signal bdir_s           : std_logic;
   signal bc_s             : std_logic;
   

	-- Controller signals
	signal d_from_ctrl_s    : std_logic_vector( 7 downto 0);
	signal ctrl_r_n_s       : std_logic;
	signal ctrl_en_key_n_s	: std_logic;
	signal ctrl_en_joy_n_s	: std_logic;

	-- SPI
	signal d_from_spi_s		: std_logic_vector( 7 downto 0);
	signal spi_cs_s			: std_logic;
	signal spi_wr_s			: std_logic;
	signal spi_rd_s			: std_logic;

	-- Cartridge
	signal ext_cart_en_q		: std_logic;
	signal cart_en_80_n_s	: std_logic;
	signal cart_en_a0_n_s	: std_logic;
	signal cart_en_c0_n_s	: std_logic;
	signal cart_en_e0_n_s	: std_logic;
	signal ext_cart_ce_s		: std_logic;
	signal cart_ce_s			: std_logic;
	signal cart_oe_s			: std_logic;
	signal cart_we_s			: std_logic;

begin

--	-- CPU
--	cpu: entity work.T80a
--	generic map (
--				Mode => 0
--	)
--	port map (
--		clock_i		=> clock_i,
--		clock_en_i	=> clk_en_cpu_s,
--		reset_n_i	=> reset_n_s,
--		address_o	=> cpu_addr_s,
--		data_i		=> d_to_cpu_s,
--		data_o		=> d_from_cpu_s,
--		wait_n_i		=> '1',
--		int_n_i		=> '1',
--		nmi_n_i		=> nmi_n_s,
--		m1_n_o		=> m1_n_s,
--		mreq_n_o		=> mreq_n_s,
--		iorq_n_o		=> iorq_n_s,
--		rd_n_o		=> rd_n_s,
--		wr_n_o		=> wr_n_s,
--		refresh_n_o	=> rfsh_n_s,
--		halt_n_o		=> open,
--		busrq_n_i	=> '1',
--		busak_n_o	=> open
--	);

 -----------------------------------------------------------------------------
  -- T80 CPU
  -----------------------------------------------------------------------------
  cpu : entity work.T80pa
    generic map (
      Mode       => 0
    )
    port map(
      RESET_n    => reset_n_s,
      CLK        => clock_i,
      CEN_p      => clk_en_3m58_p_i,
      CEN_n      => clk_en_3m58_n_i,
      WAIT_n     => wait_n_s,
      INT_n      => int_n_s,
      NMI_n      => nmi_n_s,
      BUSRQ_n    => '1',
      M1_n       => m1_n_s,
      MREQ_n     => mreq_n_s,
      IORQ_n     => iorq_n_s,
      RD_n       => rd_n_s,
      WR_n       => wr_n_s,
      RFSH_n     => rfsh_n_s,
      HALT_n     => open,
      BUSAK_n    => open,
      A          => cpu_addr_s,
      DI         => d_to_cpu_s,
      DO         => d_from_cpu_s
    );

	-- Loader
	lr: entity work.loaderrom
	port map (
		clk		=> clock_i,
		addr		=> cpu_addr_s(12 downto 0),
		data		=> d_from_loader_s
	);

	-----------------------------------------------------------------------------
	-- TMS9928A Video Display Processor
	-----------------------------------------------------------------------------
	vdp18_b : entity work.vdp18_core
	generic map (
		compat_rgb_g	=> compat_rgb_g
	)
	port map (
		clk_i			   => clock_i,
		clk_en_10m7_i	=> clk_en_10m7_i,
--		clk_en_5m37_i	=> clk_en_5m37_i,
		reset_n_i		=> por_n_i,
		csr_n_i			=> vdp_r_n_s,
		csw_n_i			=> vdp_w_n_s,
		mode_i			=> cpu_addr_s(0),
		int_n_o			=> nmi_n_s,
		cd_i				=> d_from_cpu_s,
		cd_o				=> d_from_vdp_s,
		vram_ce_o		=> vram_ce_o,
		vram_oe_o		=> vram_oe_o,
		vram_we_o		=> vram_we_o,
		vram_a_o			=> vram_addr_o,
		vram_d_o			=> vram_data_o,
		vram_d_i			=> vram_data_i,
		--
		col_o				=> col_o,
		cnt_hor_o		=> cnt_hor_o,
		cnt_ver_o		=> cnt_ver_o,
		rgb_r_o			=> rgb_r_o,
		rgb_g_o			=> rgb_g_o,
		rgb_b_o			=> rgb_b_o,
		hsync_n_o		=> hsync_n_o,
		vsync_n_o		=> vsync_n_o,
		comp_sync_n_o	=> comp_sync_n_o
	);


    -----------------------------------------------------------------------------
	-- YM2149 Programmable Sound Generator
	-----------------------------------------------------------------------------
   bdir_s <= not ay_addr_we_n_s or not ay_data_we_n_s;
   bc_s   <= not ay_addr_we_n_s or not ay_data_rd_n_s;
   psg_b_audio_s <= signed(psg_b_audio_u2);
   
	psg_a: ym2149_audio
    port map (
		clk_i       => clock_i,
		en_clk_psg_i=> clk_en_3m58_p_i,
		reset_n_i   => reset_n_s,
		bdir_i      => bdir_s,--not ay_addr_we_n_s or not ay_data_we_n_s,
		bc_i        => bc_s, --not ay_addr_we_n_s or not ay_data_rd_n_s,
		data_i      => d_from_cpu_s,
		data_r_o    => ay_d_s,
		ch_a_o      => ay_ch_a_s,
		ch_b_o      => ay_ch_b_s,
		ch_c_o      => ay_ch_c_s,
		mix_audio_o => psg_b_audio_u,
		pcm14s_o    => psg_b_audio_u2,
		sel_n_i     => '0'
    );

	-----------------------------------------------------------------------------
	-- SN76489 Programmable Sound Generator
	-----------------------------------------------------------------------------
	psg_a_audio_s <= signed(psg_a_audio_u2);
   
	psg_b : sn76489_audio
    generic map (
    	FAST_IO_G          => '0',
		MIN_PERIOD_CNT_G   => 17
    )port map (
		clk_i		=> clock_i,
		en_clk_psg_i=> clk_en_3m58_p_i,
		--res_n_i		=> reset_n_s,
		ce_n_i		=> psg_we_n_s,
		wr_n_i		=> psg_we_n_s,
		ready_o		=> psg_ready_s,
		data_i		=> d_from_cpu_s,
		mix_audio_o => psg_a_audio_u,
		pcm14s_o    => psg_a_audio_u2
	);

	audio_o			<= psg_a_audio_u + psg_b_audio_u;
	audio_signed_o	<= psg_a_audio_s + psg_b_audio_s;

	-----------------------------------------------------------------------------
	-- Controller ports
	-----------------------------------------------------------------------------
	ctrl_b : entity work.cv_ctrl
	port map (
		clk_i				   => clock_i,
		clk_en_3m58_i		=> clk_en_3m58_p_i,
		reset_n_i			=> reset_n_s,
		ctrl_en_key_n_i	=> ctrl_en_key_n_s,
		ctrl_en_joy_n_i	=> ctrl_en_joy_n_s,
		a1_i					=> cpu_addr_s(1),
		ctrl_p1_i			=> ctrl_p1_i,
		ctrl_p2_i			=> ctrl_p2_i,
		ctrl_p3_i			=> ctrl_p3_i,
		ctrl_p4_i			=> ctrl_p4_i,
		ctrl_p5_o			=> ctrl_p5_o,
		ctrl_p6_i			=> ctrl_p6_i,
		ctrl_p7_i			=> ctrl_p7_i,
		ctrl_p8_o			=> ctrl_p8_o,
		ctrl_p9_i			=> ctrl_p9_i,
		d_o					=> d_from_ctrl_s,
		int_n_o           => int_n_s
	);

	-- SPI
	sd: entity work.spi
	port map (
		clock_i			=> clk_en_3m58_p_i,
		reset_i			=> reset_i,
		addr_i			=> cpu_addr_s(0),
		cs_i				=> spi_cs_s,
		wr_i				=> spi_wr_s,
		rd_i				=> spi_rd_s,
		data_i			=> d_from_cpu_s,
		data_o			=> d_from_spi_s,
		-- SD card interface
		spi_cs_o			=> spi_cs_n_o,
		spi_sclk_o		=> spi_sclk_o,
		spi_mosi_o		=> spi_mosi_o,
		spi_miso_i		=> spi_miso_i,
		sd_cd_n_i		=> sd_cd_n_i
	);

	spi_wr_s		<= not wr_n_s;
	spi_rd_s		<= not rd_n_s;

	-- Glue
	reset_n_s		<= not reset_i;
   wait_n_s  <= psg_ready_s and not m1_wait_q;

	-----------------------------------------------------------------------------
	-- Process m1_wait
	--
	-- Purpose:
	--   Implements flip-flop U8A which asserts a wait states controlled by M1.
	--

	m1_wait: process (clock_i, reset_n_s, m1_n_s)
	begin
    if reset_n_s = '0' or m1_n_s = '1' then
      m1_wait_q   <= '0';
    elsif clock_i'event and clock_i = '1' then
      if clk_en_3m58_p_i = '1' then
        m1_wait_q <= not m1_wait_q;
      end if;
    end if;
	end process m1_wait;

 

	-----------------------------------------------------------------------------
	-- Misc outputs
	-----------------------------------------------------------------------------
	loader_ce_s		<= not rd_n_s and bios_ce_s	when loader_q = '1'	else '0';
	bios_we_s		<= not wr_n_s and bios_ce_s	when loader_q = '1'	else '0';
	bios_oe_s		<= not rd_n_s and bios_ce_s;

	cart_ce_s		<= not (cart_en_80_n_s and cart_en_A0_n_s and cart_en_C0_n_s and cart_en_E0_n_s) and not ext_cart_en_q;
	ext_cart_ce_s	<= not (cart_en_80_n_s and cart_en_A0_n_s and cart_en_C0_n_s and cart_en_E0_n_s) and     ext_cart_en_q;
	cart_oe_s		<= (not rd_n_s) and cart_ce_s;
	--cart_we_s		<= (not wr_n_s) and cart_ce_s		when multcart_q = '1'	else '0';
   cart_we_s		<= mem_access_s and (not wr_n_s)  when multcart_q = '1'	else '0'; 
	-- RAM map
	--											         1111111
	--											         65432109876543210
	-- 00000 - 01FFF = BIOS (8K)				   0000xxxxxxxxxxxxx
	-- 02000 - 07FFF = RAM  (24K)			      00xxxxxxxxxxxxxxx
	-- 08000 - 0FFFF = Multicart (32K)			01xxxxxxxxxxxxxxx
	-- 10000 - 17FFF = Cartridge (32K)			10xxxxxxxxxxxxxxx
	--
	ram_addr_o		<=
		"000000"    & cpu_addr_s(12 downto 0)	when bios_ce_s = '1'											            else
		"0001"      & cpu_addr_s(14 downto 0)	when ram_ce_s =  '1'												         else	-- 32K linear RAM
		"0010"      & cpu_addr_s(14 downto 0)	when cart_ce_s = '1' and loader_q = '1'							   else
		"0010"      & cpu_addr_s(14 downto 0)	when cart_ce_s = '1' and multcart_q = '1' and cart_oe_s = '1'	else
		'1'& cart_actpage_s  & cpu_addr_s(13 downto 0)	when cart_we_s = '1'  else 
		'1'& cart_page_s     & cpu_addr_s(13 downto 0)	when cart_ce_s = '1' and multcart_q = '0' else
		(others => '0');

	ram_data_o		<= d_from_cpu_s;
	ram_ce_o			<= ram_ce_s or bios_ce_s or cart_ce_s;
	ram_we_o			<= (not wr_n_s and ram_ce_s) or bios_we_s or cart_we_s;
	ram_oe_o			<= (not rd_n_s and ram_ce_s) or bios_oe_s or cart_oe_s;
   

	cart_addr_o		<= cpu_addr_s(14 downto 0);
	cart_oe_n_o		<= not cart_oe_s;
	cart_en_80_n_o	<= cart_en_80_n_s or rd_n_s	when ext_cart_en_q = '1'	else '1';
	cart_en_a0_n_o	<= cart_en_A0_n_s or rd_n_s	when ext_cart_en_q = '1'	else '1';
	cart_en_c0_n_o	<= cart_en_C0_n_s or rd_n_s	when ext_cart_en_q = '1'	else '1';
	cart_en_e0_n_o	<= cart_en_E0_n_s or rd_n_s	when ext_cart_en_q = '1'	else '1';

	-- Address decoding
	mem_access_s	<= '1'	when mreq_n_s = '0' and rfsh_n_s = '1'							else '0';
	io_access_s		<= '1'	when iorq_n_s = '0' and m1_n_s = '1'							else '0';
	io_read_s		<= '1'	when iorq_n_s = '0' and m1_n_s = '1' and rd_n_s = '0'		else '0';
	io_write_s		<= '1'	when iorq_n_s = '0' and m1_n_s = '1' and wr_n_s = '0'		else '0';

---------------------------------------------------------
 sgm: process (reset_n_s, clock_i)
  begin
        if reset_n_s = '0' then  
		    bios_en_s <= '1';
			 megacart_page_s <= "0000";
        elsif rising_edge( clock_i )
		    then if io_write_s = '1' and cpu_addr_s(7 downto 0) = x"7f"
            then
                bios_en_s <= d_from_cpu_s(1);
            end if;
		  
		  if megacart_en_s = '1'  and mem_access_s ='1' and rd_n_s = '0' and cpu_addr_s(15 downto 6) = x"FF"&"11"
            then
               megacart_page_s <= cpu_addr_s(3 downto 0) and cart_totpage_s;
            end if;
        end if;
 end process sgm;
---------------------------------------------------------

 megacart: process (clock_i)  
 begin

    if (cart_totpage_s = "0011" or      --  64k
        cart_totpage_s = "0111" or      -- 128k
        cart_totpage_s = "1111") then   -- 256k
        megacart_en_s <= '1';
    else
        megacart_en_s <= '0';
    end if;
	    
	 case cpu_addr_s(15 downto 14) is
        when "10" =>
            if megacart_en_s = '1' then
                cart_page_s <= cart_totpage_s; 
            else
                cart_page_s <= "0000";
            end if;
        when "11" =>
            if megacart_en_s = '1' then
                cart_page_s <= megacart_page_s;
            else
                cart_page_s <= "0001";
            end if;
        when others =>
            cart_page_s     <= "0000";
    end case;
end process megacart;
---------------------------------------------------------

	-- memory
	bios_ce_s		<= '1'	when bios_en_s = '1' and mem_access_s = '1' and cpu_addr_s(15 downto 13)   = "000"		else '0';	-- BIOS         => 0000 to 1FFF
	ram_ce_s		   <= '1'	when mem_access_s = '1' and ((cpu_addr_s(15 downto 13) = "000" and bios_en_s ='0')
																    or (cpu_addr_s(15 downto 13) = "001")
	                                                 or (cpu_addr_s(15 downto 13) = "010")
					                                     or (cpu_addr_s(15 downto 13) = "011"))	else '0';   -- RAM          => 0000 to 7FFF

	cart_en_80_n_s	<= '0'	when mem_access_s = '1' and cpu_addr_s(15 downto 13) = "100"		else '1';	-- Cartridge 80 => 8000 to 9FFF
	cart_en_a0_n_s	<= '0'	when mem_access_s = '1' and cpu_addr_s(15 downto 13) = "101"		else '1';	-- Cartridge A0 => A000 to BFFF
	cart_en_c0_n_s	<= '0'	when mem_access_s = '1' and cpu_addr_s(15 downto 13) = "110"		else '1';	-- Cartridge C0 => C000 to DFFF
	cart_en_e0_n_s	<= '0'	when mem_access_s = '1' and cpu_addr_s(15 downto 13) = "111"		else '1';	-- Cartridge E0 => E000 to FFFF

	-- I/O
	spi_cs_s				<= '1'	when io_access_s = '1' and cpu_addr_s(7 downto 1) = "0100000"	else '0';	-- SPI (R/W)          => 40 to 41
	cfg_port_cs_s		<= '1'	when io_write_s  = '1' and cpu_addr_s(7 downto 0) = X"42"		else '0';	-- Config Port        => 42
	machine_id_cs_s	<= '1'	when io_read_s   = '1' and cpu_addr_s(7 downto 0) = X"43"		else '0';	-- Machine ID read    => 43
	cfg_page_cs_s		<= '1'	when io_access_s = '1' and cpu_addr_s(7 downto 0) = X"44"		else '0';	-- Page port          => 44
	cart_actpage_cs_s	<= '1'	when io_access_s = '1' and cpu_addr_s(7 downto 0) = X"45"		else '0';	-- Cart page port     => 45
	cart_totpage_cs_s	<= '1'	when io_access_s = '1' and cpu_addr_s(7 downto 0) = X"46"		else '0';	-- Cart page port     => 46
	ctrl_en_key_n_s	<= '0'	when io_write_s  = '1' and cpu_addr_s(7 downto 5) = "100"		else '1';	-- Controller key set => 80 to 9F
	vdp_w_n_s			<= '0'	when io_write_s  = '1' and cpu_addr_s(7 downto 5) = "101"		else '1';	-- VDP write          => A0 to BF
	vdp_r_n_s			<= '0'	when io_read_s   = '1' and cpu_addr_s(7 downto 5) = "101"		else '1';	-- VDP read           => A0 to BF
	ctrl_en_joy_n_s	<= '0'	when io_write_s  = '1' and cpu_addr_s(7 downto 5) = "110"		else '1';	-- Controller joy set => C0 to DF
	psg_we_n_s			<= '0'	when io_write_s  = '1' and cpu_addr_s(7 downto 5) = "111"		else '1';	-- PSG write          => E0 to FF
	ay_addr_we_n_s		<= '0'	when io_write_s  = '1' and cpu_addr_s(7 downto 0) = x"50"		else '1';	-- AY addr write       
	ay_data_we_n_s		<= '0'	when io_write_s  = '1' and cpu_addr_s(7 downto 0) = x"51"		else '1';	-- AY data write       
	ay_data_rd_n_s		<= '0'	when io_read_s   = '1' and cpu_addr_s(7 downto 0) = x"52"		else '1';	-- AY data read       
	ctrl_r_n_s			<= '0'	when io_read_s   = '1' and cpu_addr_s(7 downto 5) = "111"		else '1';	-- Controller read    => E0 to FF

	-- Write I/O port 42
	process (por_n_i, reset_i, clock_i)
	begin
		if por_n_i = '0' then
			ext_cart_en_q	<= '1';
			multcart_q <= '1';
			loader_q	  <= '1';
		elsif reset_i = '1' then
			multcart_q <= '1';
		elsif rising_edge(clock_i) then
			if clk_en_3m58_p_i = '1' and cfg_port_cs_s = '1' then
				ext_cart_en_q	<= d_from_cpu_s(2);
				multcart_q <= d_from_cpu_s(1);
				loader_q	  <= d_from_cpu_s(0);
			end if;
		end if;
	end process;
	
   -- Write I/O port 44
	process (por_n_i, clock_i)
	begin
		if por_n_i = '0' then
			cfg_page_r <= (others => '0');
		elsif rising_edge(clock_i) then
			if clk_en_3m58_p_i = '1' and cfg_page_cs_s = '1' and wr_n_s = '0' then
				cfg_page_r <= d_from_cpu_s;
			end if;
		end if;
	end process;
	
   -- Write I/O port 45
	process (por_n_i, clock_i)
	begin
		if por_n_i = '0' then
			cart_actpage_s <= (others => '0');
		elsif rising_edge(clock_i) then
			if clk_en_3m58_p_i = '1' and cart_actpage_cs_s = '1' and wr_n_s = '0' then
				cart_actpage_s <= d_from_cpu_s (3 downto 0);
			end if;
		end if;
	end process;

  -- Write I/O port 46
	process (por_n_i, clock_i)
	begin
		if por_n_i = '0' then
			cart_totpage_s <= (others => '0');
		elsif rising_edge(clock_i) then
			if clk_en_3m58_p_i = '1' and cart_totpage_cs_s = '1' and wr_n_s = '0' then
				cart_totpage_s <= d_from_cpu_s (3 downto 0);
			end if;
		end if;
	end process;


	-- MUX data CPU
	d_to_cpu_s	<=	-- Memory
						d_from_loader_s				when loader_ce_s = '1'		 else
						ram_data_i						when bios_ce_s = '1'		    else
						ram_data_i						when ram_ce_s  = '1'		    else
						ram_data_i						when cart_ce_s = '1'		    else
						cart_data_i						when ext_cart_ce_s = '1'	 else
						-- I/O
						d_from_vdp_s					when vdp_r_n_s = '0'		    else
						d_from_ctrl_s					when ctrl_r_n_s = '0'		 else
						d_from_spi_s					when spi_cs_s = '1'			 else
						ay_d_s                     when ay_data_rd_n_s  ='0'   else
						machine_id_c					when machine_id_cs_s = '1'	 else
						cfg_page_r						when cfg_page_cs_s = '1'	 else
						"0000"& cart_totpage_s     when cart_totpage_cs_s ='1' else
						"0000"& cart_actpage_s     when cart_actpage_cs_s ='1' else
						(others => '1');

	-- Debug
	D_cpu_addr	<= cpu_addr_s;
	

end architecture;
