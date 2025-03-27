library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;

entity CPU_TOP_LEVEL is
    generic (
        QUARTUS_MEMORY : boolean := FALSE
    );
    port (
        clock           : in  std_logic;
        clear           : in  std_logic;
        enable          : in  std_logic;
        memory_read     : out std_logic;
        memory_write    : out std_logic;
        data_program    : in  std_logic_vector((WORK.RV32I.XLEN - 1) downto 0);
        data_memory_in  : in  std_logic_vector((WORK.RV32I.XLEN - 1) downto 0);
        data_memory_out : out std_logic_vector((WORK.RV32I.XLEN - 1) downto 0);
        address_program : out std_logic_vector((WORK.RV32I.XLEN - 1) downto 0);
        address_memory  : out std_logic_vector((WORK.RV32I.XLEN - 1) downto 0)
    );
end entity;

architecture RV32I of CPU_TOP_LEVEL is

    -- Control Signals
    signal control_wb : WORK.CPU.t_CONTROL_WB;

    -- Data Signals
    signal alu_result            : std_logic_vector((WORK.RV32I.XLEN - 1) downto 0);
    signal memory_result         : std_logic_vector((WORK.RV32I.XLEN - 1) downto 0);
    signal multiplication_result : std_logic_vector((WORK.RV32I.XLEN - 1) downto 0);
    signal writeback_result      : std_logic_vector((WORK.RV32I.XLEN - 1) downto 0);

    -- Operands
    signal operand_1 : std_logic_vector((WORK.RV32I.XLEN - 1) downto 0);
    signal operand_2 : std_logic_vector((WORK.RV32I.XLEN - 1) downto 0);

    -- Multiplication control
    signal multiplication_enable : std_logic;

begin

    -- Execution Unit
    EXECUTION_UNIT : entity WORK.MODULE_EXECUTION_UNIT
        generic map (
            FUNCTION_WIDTH => 4,
            DATA_WIDTH     => WORK.RV32I.XLEN
        )
        port map (
            clock           => clock,
            enable          => enable,
            select_source_1 => (others => '0'),
            select_source_2 => (others => '0'),
            select_function => (others => '0'),
            address_program => address_program,
            source_1        => operand_1,
            source_2        => operand_2,
            immediate       => data_program,
            overflow        => open,
            destination     => alu_result
        );

    -- Multiplier Unit
    MULTIPLICATION_UNIT : entity WORK.RV32M_MULTIPLIER
        port map (
            clock        => clock,
            enable       => multiplication_enable,
            select_fun   => "00",  -- MUL
            input_A      => operand_1,
            input_B      => operand_2,
            result_LO    => multiplication_result,
            result_HI    => open
        );

    -- Write-Back Unit
    WRITE_BACK : entity WORK.MODULE_WRITE_BACK
        generic map (
            DATA_WIDTH => WORK.RV32I.XLEN
        )
        port map (
            selector              => control_wb.select_destination & multiplication_enable,
            source_execution      => alu_result,
            source_memory         => memory_result,
            source_multiplication => multiplication_result,
            destination           => writeback_result
        );

end architecture;