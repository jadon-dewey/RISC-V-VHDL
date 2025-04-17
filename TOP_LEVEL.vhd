library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;

entity TOP_LEVEL is
    generic (
        PROGRAM_FILE   : string := "/root/workspace/data/mif/blink.mif";
        DEMONSTRATION  : boolean := FALSE;
        QUARTUS_MEMORY : boolean := FALSE
    );
    port (
        -- Existing ports
        CLOCK           : in  std_logic := '0';
        LEDR            : out std_logic_vector(0 downto 0) := (others => '0');

        -- New top-level ports for testing:
        CLEAR           : in  std_logic := '0';  -- CPU reset (active-high in this example)

        -- Outputs to observe in the testbench:
        ACKNOWLEDGE     : out std_logic;
        INTERRUPT_REQ   : out std_logic;
        INTERRUPT_ADDR  : out std_logic_vector(31 downto 0);
        ADDRESS_PROGRAM : out std_logic_vector(31 downto 0);

        -- Interrupt signals driven/observed by your testbench or external hardware (button, etc.):
        HW_INT_PENDING  : in  std_logic := '0';
        HW_INT_ENABLE   : in  std_logic := '0';
        MRET            : in  std_logic := '0'
    );
end entity;

architecture RTL of TOP_LEVEL is

    ------------------------------------------------------------------------
    -- Internal signals and memory interface
    ------------------------------------------------------------------------
    signal data_program        : WORK.RV32I.t_PROGRAM;
    signal data_memory_in      : WORK.RV32I.t_DATA;
    signal data_memory_out     : WORK.RV32I.t_DATA;
    signal enable_memory_read  : std_logic;
    signal enable_memory_write : std_logic;
    signal address_program_int : WORK.RV32I.t_DATA;  -- Internal PC signal
    signal address_memory      : WORK.RV32I.t_DATA;
    signal clock_processor     : std_logic := '0';

    ------------------------------------------------------------------------
    -- Interrupt-related internal signals
    ------------------------------------------------------------------------
    signal interrupt_req_int   : std_logic;
    signal interrupt_addr_int  : std_logic_vector(31 downto 0);
    signal interrupt_ack_int   : std_logic;
    signal mret_signal         : std_logic;

    -- For the interrupt unit's control signals (kept constant or expanded as needed):
    signal mie         : std_logic := '1';  
    signal msie        : std_logic := '1';  
    signal mtie        : std_logic := '1';  
    signal meie        : std_logic := '1';  

    signal msip        : std_logic := '0';
    signal mtip        : std_logic := '0';
    signal meip        : std_logic := '0';

    signal mtvec_base    : std_logic_vector(31 downto 0) := (others => '0');
    signal vectored_mode : std_logic := '1';

    signal mask_write_enable : std_logic := '0';
    signal mask_write_data   : std_logic_vector(2 downto 0) := (others => '0');

begin
    ------------------------------------------------------------------------
    -- Map the new top-level ports into internal signals
    ------------------------------------------------------------------------
    -- Drive CPU interrupt signals from top-level pins
    mret_signal        <= MRET;

    -- Expose CPU acknowledge and program address on top-level outputs
    ACKNOWLEDGE        <= interrupt_ack_int;
    ADDRESS_PROGRAM    <= address_program_int;
    INTERRUPT_ADDR     <= interrupt_addr_int;
    INTERRUPT_REQ      <= interrupt_req_int;

    -- Map the hardware interrupt pending/enable to meie / meip
    meip <= HW_INT_PENDING;
    meie <= HW_INT_ENABLE;

    ------------------------------------------------------------------------
    -- Instantiate ROM
    ------------------------------------------------------------------------
    ROM : entity WORK.GENERIC_ROM
        generic map (
            DATA_WIDTH    => WORK.RV32I.XLEN,
            ADDRESS_WIDTH => WORK.RV32I.XLEN,
            INIT_FILE     => PROGRAM_FILE
        )
        port map (
            clock       => clock_processor,
            address     => std_logic_vector(address_program_int),
            destination => data_program
        );

    ------------------------------------------------------------------------
    -- Instantiate RAM
    ------------------------------------------------------------------------
    RAM : entity WORK.GENERIC_RAM
        generic map (
            DATA_WIDTH    => WORK.RV32I.XLEN,
            ADDRESS_WIDTH => WORK.RV32I.XLEN
        )
        port map (
            clock        => clock_processor,
            enable       => '1',
            enable_read  => enable_memory_read,
            enable_write => enable_memory_write,
            address      => address_memory,
            source       => data_memory_out,
            destination  => data_memory_in
        );

    ------------------------------------------------------------------------
    -- Instantiate the CPU with interrupt signals
    ------------------------------------------------------------------------
    CPU : entity WORK.CPU_TOP_LEVEL(RV32I)
        generic map (
            QUARTUS_MEMORY => QUARTUS_MEMORY
        )
        port map (
            clock           => clock_processor,
            clear           => CLEAR,     -- Driven from top-level port
            enable          => '1',
            memory_read     => enable_memory_read,
            memory_write    => enable_memory_write,
            data_program    => data_program,
            data_memory_in  => data_memory_in,
            data_memory_out => data_memory_out,
            address_program => address_program_int,
            address_memory  => address_memory,

            -- Interrupt integration:
            interrupt_req   => interrupt_req_int,
            interrupt_addr  => interrupt_addr_int,
            acknowledge     => interrupt_ack_int,
            mret            => mret_signal
        );

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

    ------------------------------------------------------------------------
    -- Register for LED
    ------------------------------------------------------------------------
    UPDATE_LED : entity WORK.GENERIC_REGISTER
        generic map (
            DATA_WIDTH => 1
        )
        port map (
            clock        => clock_processor,
            clear        => '0',
            enable       => enable_memory_write 
                AND WORK.GENERICS.is_equal_dynamic(address_memory, 32X"0080"),
            source       => data_memory_out(0 downto 0),
            destination  => LEDR(0 downto 0)
        );

    ------------------------------------------------------------------------
    -- Clock generation for demonstration mode
    ------------------------------------------------------------------------
    CLOCK_DEMONSTRATION : if DEMONSTRATION = TRUE generate
        low_freq : entity WORK.GENERIC_LOW_FREQ
            generic map (n => 100000000)
            port map (
                clock     => CLOCK,
                clock_out => clock_processor
            );
    end generate;
    -- Otherwise, directly pass top-level CLOCK into CPU
    CLOCK_BYPASS : if DEMONSTRATION = FALSE generate
        clock_processor <= CLOCK;
    end generate;

end architecture RTL;