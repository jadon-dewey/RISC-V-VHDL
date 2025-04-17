library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TOP_LEVEL_INTERRUPT_TEST is
    port (
        CLOCK     : in  std_logic;                      -- System clock
        SW        : in  std_logic_vector(2 downto 0);   -- {meip, mtip, msip}
        BUTTON    : in  std_logic;                      -- Used to simulate mret / acknowledge
        LED       : out std_logic_vector(7 downto 0)    -- Output status indicators
    );
end entity;

architecture RTL of TOP_LEVEL_INTERRUPT_TEST is

    -- Internal signals for the interrupt unit
    signal meip, mtip, msip       : std_logic;
    signal interrupt_req          : std_logic;
    signal interrupt_address      : std_logic_vector(31 downto 0);
    signal acknowledge            : std_logic;

begin

    ------------------------------------------------------------------------------
    -- Assign input switches to individual interrupt lines
    ------------------------------------------------------------------------------
    meip <= SW(2);     -- External interrupt
    mtip <= SW(1);     -- Timer interrupt
    msip <= SW(0);     -- Software interrupt

    ------------------------------------------------------------------------------
    -- Assign button press to simulate mret / acknowledge
    ------------------------------------------------------------------------------
    acknowledge <= BUTTON;


    ------------------------------------------------------------------------
    -- Instantiate the INTERRUPT_UNIT
    ------------------------------------------------------------------------
    Interrupt_Unit_inst : entity WORK.INTERRUPT_UNIT
        port map (
            CLOCK             => clock_processor,
            reset_n           => not CLEAR,       -- If CLEAR='1' resets logic. Adjust if needed.
            mie               => mie,
            msie              => msie,
            mtie              => mtie,
            meie              => meie,
            msip              => msip,
            mtip              => mtip,
            meip              => meip,
            acknowledge       => interrupt_ack_int,
            mtvec_base        => mtvec_base,
            vectored_mode     => vectored_mode,
            interrupt_ack     => open,
            interrupt_out     => interrupt_req_int,
            interrupt_address => interrupt_addr_int,
            mask_write_enable => mask_write_enable,
            mask_write_data   => mask_write_data
        );

        ------------------------------------------------------------------------------
        -- Map internal signals to LEDs for observation
        ------------------------------------------------------------------------------
        LED(0) <= interrupt_req;               -- Interrupt active
        LED(1) <= acknowledge;                 -- Acknowledge pressed
        LED(2) <= meip;                        -- External interrupt line
        LED(3) <= mtip;                        -- Timer interrupt line
        LED(4) <= msip;                        -- Software interrupt line
        LED(7 downto 5) <= interrupt_address(2 downto 0);  -- LSB of interrupt address for debug

end architecture RTL;