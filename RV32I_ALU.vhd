library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;
use WORK.GENERICS.ALL;

entity RV32I_ALU is

    generic (
        DATA_WIDTH : natural := WORK.RV32I.XLEN
    );

    port (
        select_function : in  std_logic_vector(3 downto 0); -- ALU Function Selector
        source_1        : in  std_logic_vector((DATA_WIDTH - 1) downto 0); -- First Operand
        source_2        : in  std_logic_vector((DATA_WIDTH - 1) downto 0); -- Second Operand
        clock           : in  std_logic;  -- Clock for Multiplier
        enable          : in  std_logic;  -- Enable Signal for Multiplier
        overflow        : out std_logic;  -- Overflow Detection
        destination     : out std_logic_vector((DATA_WIDTH - 1) downto 0) -- Final ALU Result
    );

end entity;

architecture RTL of RV32I_ALU is

    -- ALU Internal Signals
    signal result_HI       : std_logic_vector(31 downto 0);  -- Upper 32 Bits of Multiplication
    signal result_LO       : std_logic_vector(31 downto 0);  -- Lower 32 Bits of Multiplication
    signal is_mul_op       : std_logic;                      -- Flag to detect multiply instructions

    -- Regular ALU Operation Signals
    signal alu_result      : std_logic_vector(31 downto 0);
    signal flag_subtract   : std_logic;
    signal source_2_aux    : std_logic_vector((DATA_WIDTH - 1) downto 0);

begin

    -- Detect Multiply Operations (MUL, MULH, MULHSU, MULHU)
    is_mul_op <= '1' when select_function(3 downto 2) = "11" else '0';

    -- Instantiate the Multiplication Unit
    MULTIPLIER_UNIT: entity WORK.RV32M_MULTIPLIER
        port map (
            clock       => clock,
            enable      => enable,
            select_fun  => select_function(1 downto 0),  -- Determine the type of multiplication
            input_A     => source_1,
            input_B     => source_2,
            result_LO   => result_LO,
            result_HI   => result_HI
        );

    -- Default ALU Operations (Addition, Subtraction, Logical, Shift)
    flag_subtract <= select_function(3) AND NOT(select_function(2));  -- Detect SUB operation
    source_2_aux  <= source_2 XOR (DATA_WIDTH - 1 downto 0 => flag_subtract);
    alu_result    <= source_1 + source_2_aux + flag_subtract; -- Addition/Subtraction

    -- Final ALU Output Multiplexer
    process(select_function, alu_result, result_LO, result_HI, is_mul_op)
    begin
        if is_mul_op = '1' then
            case select_function(1 downto 0) is
                when "00" => destination <= result_LO; -- MUL (Lower 32-bits)
                when others => destination <= result_HI; -- MULH, MULHSU, MULHU (Upper 32-bits)
            end case;
        else
            destination <= alu_result;  -- Regular ALU operation
        end if;
    end process;

end architecture;
