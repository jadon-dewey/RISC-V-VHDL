library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;

entity CPU_STAGE_IF is

    port (
        clock           : in  std_logic;
        clear           : in  std_logic;
        enable          : in  std_logic;
        source          : in  WORK.CPU.t_CONTROL_IF;
        address_jump    : in  WORK.CPU.t_DATA;
        address_program : out WORK.CPU.t_DATA;
        -- New ports for interrupt handling integration
        interrupt_req   : in  std_logic;
        interrupt_addr  : in  WORK.RV32I.t_DATA;
        mret            : in  std_logic
    );

end entity;

architecture RV32I of CPU_STAGE_IF is

    -- Internal signal that will be the input to the program counter
    signal next_address : WORK.CPU.t_DATA;

    -- Component declaration for the GENERIC_MUX_2X1
    component GENERIC_MUX_2X1 is
        generic (
            DATA_WIDTH : natural := 8
        );
        port (
            selector    : in  std_logic;
            source_1    : in  std_logic_vector((DATA_WIDTH - 1) downto 0);
            source_2    : in  std_logic_vector((DATA_WIDTH - 1) downto 0);
            destination : out std_logic_vector((DATA_WIDTH - 1) downto 0)
        );
    end component;

begin

    -- Instantiate the 2x1 multiplexer to select between address_jump and interrupt_addr.
    MUX_IF : GENERIC_MUX_2X1
        generic map (
            DATA_WIDTH => WORK.CPU.t_DATA'length  -- Assumes WORK.CPU.t_DATA and WORK.RV32I.t_DATA have the same width.
        )
        port map (
            selector    => interrupt_req,    -- If '1', selects interrupt_addr.
            source_1    => address_jump,     -- Selected when interrupt_req = '0'.
            source_2    => interrupt_addr,   -- Selected when interrupt_req = '1'.
            destination => next_address
        );

    PROGRAM_COUNTER : entity WORK.MODULE_PROGRAM_COUNTER(RV32I)
        port map (
            clock        => clock,
            clear        => clear,
            enable       => enable, -- AND NOT(source.enable_stall),
            selector     => source.select_source,
            -- The source now comes from the next address signal instead of just the address jump
            source       => next_address,
            destination  => address_program,
            -- Connecting the appropriate ports for PC saving
            interrupt_req   => interrupt_req,    -- connect appropriate signal
            interrupt_addr  => interrupt_addr,   -- connect appropriate signal
            mret            => mret              -- connect return-from-interrupt signal
        );

end architecture;