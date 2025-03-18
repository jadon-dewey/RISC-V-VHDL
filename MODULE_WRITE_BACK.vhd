library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library WORK;

entity MODULE_WRITE_BACK is

    generic (
        DATA_WIDTH : natural := WORK.RV32I.XLEN
    );

    port (
        selector         : in  std_logic_vector(1 downto 0); -- Updated to 2-bit selector
        source_execution : in  std_logic_vector((DATA_WIDTH - 1) downto 0);
        source_memory    : in  std_logic_vector((DATA_WIDTH - 1) downto 0);
        source_multiplication : in std_logic_vector((DATA_WIDTH - 1) downto 0); -- New input for multiplication results
        destination      : out std_logic_vector((DATA_WIDTH - 1) downto 0)
    );

end entity;

architecture RV32I of MODULE_WRITE_BACK is

    -- No additional signals needed

begin

    -- **Write-Back Multiplexer**
    MUX_SOURCE : entity WORK.GENERIC_MUX_4X1 -- Updated from 2X1 to 4X1
        generic map (
            DATA_WIDTH => WORK.RV32I.XLEN
        )
        port map (
            selector    => selector,
            source_1    => source_execution,     -- ALU result
            source_2    => source_memory,        -- Memory load result
            source_3    => source_multiplication, -- Multiplication result
            source_4    => (others => '0'),      -- Default case (unused)
            destination => destination
        );

end architecture;
