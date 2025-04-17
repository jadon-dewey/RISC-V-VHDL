library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library WORK;

entity MODULE_WRITE_BACK is
    generic (
        DATA_WIDTH : natural := WORK.RV32I.XLEN
    );
    port (
        selector              : in  std_logic_vector(1 downto 0);  -- [MODIFIED] 2-bit selector
        source_execution      : in  std_logic_vector((DATA_WIDTH - 1) downto 0);
        source_memory         : in  std_logic_vector((DATA_WIDTH - 1) downto 0);
        source_multiplication : in  std_logic_vector((DATA_WIDTH - 1) downto 0); -- [ADDED]
        destination           : out std_logic_vector((DATA_WIDTH - 1) downto 0)
    );
end entity;

architecture RV32I of MODULE_WRITE_BACK is
begin

    -- [MODIFIED] Changed from 2X1 to 4X1 mux to support multiplier path
    MUX_SOURCE : entity WORK.GENERIC_MUX_4X1
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            selector    => selector,
            source_1    => source_execution,
            source_2    => source_memory,
            source_3    => source_multiplication,
            source_4    => (others => '0'),  -- fallback/default
            destination => destination
        );

end architecture;
