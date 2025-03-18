library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;

entity RV32M_MULTIPLIER is
    port (
        clock       : in  std_logic;                     -- Clock Signal
        enable      : in  std_logic;                     -- Enable Signal
        select_fun  : in  std_logic_vector(1 downto 0);  -- Selects between MUL, MULH, MULHSU, MULHU
        input_A     : in  std_logic_vector(31 downto 0); -- First Operand
        input_B     : in  std_logic_vector(31 downto 0); -- Second Operand
        result_LO   : out std_logic_vector(31 downto 0); -- Lower 32 Bits of Result
        result_HI   : out std_logic_vector(31 downto 0)  -- Upper 32 Bits of Result
    );
end entity;

architecture RTL of RV32M_MULTIPLIER is

    signal operand_A, operand_B  : signed(32 downto 0);
    signal product               : signed(63 downto 0);

begin

    process(clock)
    begin
        if rising_edge(clock) then
            if enable = '1' then
                -- Sign Extension Based on Function Type
                if select_fun = "00" then  -- MUL (Signed × Signed)
                    operand_A <= signed('0' & input_A);
                    operand_B <= signed('0' & input_B);
                elsif select_fun = "01" then -- MULH (Signed × Signed, Upper Bits)
                    operand_A <= signed('0' & input_A);
                    operand_B <= signed('0' & input_B);
                elsif select_fun = "10" then -- MULHSU (Signed × Unsigned)
                    operand_A <= signed('0' & input_A);
                    operand_B <= signed('0' & std_logic_vector(to_unsigned(to_integer(unsigned(input_B)), 33)));
                else -- MULHU (Unsigned × Unsigned)
                    operand_A <= signed('0' & std_logic_vector(to_unsigned(to_integer(unsigned(input_A)), 33)));
                    operand_B <= signed('0' & std_logic_vector(to_unsigned(to_integer(unsigned(input_B)), 33)));
                end if;

                -- Perform Multiplication
                product <= operand_A * operand_B;

                -- Extract Lower and Upper 32 Bits
                result_LO <= std_logic_vector(product(31 downto 0));
                result_HI <= std_logic_vector(product(63 downto 32));
            end if;
        end if;
    end process;

end architecture;
