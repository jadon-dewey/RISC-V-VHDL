library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library WORK;
use WORK.GENERICS.ALL;

entity MODULE_CONTROL_UNIT is

    generic (
        DATA_WIDTH        : natural := WORK.RV32I.XLEN;
        INSTRUCTION_WIDTH : natural := WORK.RV32I.INSTRUCTION_WIDTH
    );

    port (
        clear       : in  std_logic;
        instruction : in  std_logic_vector((INSTRUCTION_WIDTH - 1) downto 0);
        immediate   : out std_logic_vector((DATA_WIDTH - 1) downto 0);
        control_id  : out WORK.CPU.t_CONTROL_ID := WORK.CPU.NULL_CONTROL_ID;
        control_ex  : out WORK.CPU.t_CONTROL_EX := WORK.CPU.NULL_CONTROL_EX;
        control_mem : out WORK.CPU.t_CONTROL_MEM := WORK.CPU.NULL_CONTROL_MEM;
        control_wb  : out WORK.CPU.t_CONTROL_WB := WORK.CPU.NULL_CONTROL_WB;
        enable_multiplier : out std_logic  -- NEW: Enable multiplier when needed
    );

end entity;

architecture RV32I of MODULE_CONTROL_UNIT is

    alias opcode   is instruction(WORK.RV32I.OPCODE_RANGE);
    alias funct3   is instruction(WORK.RV32I.FUNCT3_RANGE);
    alias funct7   is instruction(WORK.RV32I.FUNCT7_RANGE);

    signal is_mul    : std_logic;
    signal is_mulh   : std_logic;
    signal is_mulhsu : std_logic;
    signal is_mulhu  : std_logic;

begin

    -- **Detect Multiplication Instructions**
    is_mul    <= '1' when (opcode = WORK.RV32I.OPCODE_OP and funct7 = WORK.RV32M.FUNCT7_MUL    and funct3 = WORK.RV32M.FUNCT3_MUL)    else '0';
    is_mulh   <= '1' when (opcode = WORK.RV32I.OPCODE_OP and funct7 = WORK.RV32M.FUNCT7_MULH   and funct3 = WORK.RV32M.FUNCT3_MULH)   else '0';
    is_mulhsu <= '1' when (opcode = WORK.RV32I.OPCODE_OP and funct7 = WORK.RV32M.FUNCT7_MULHSU and funct3 = WORK.RV32M.FUNCT3_MULHSU) else '0';
    is_mulhu  <= '1' when (opcode = WORK.RV32I.OPCODE_OP and funct7 = WORK.RV32M.FUNCT7_MULHU  and funct3 = WORK.RV32M.FUNCT3_MULHU)  else '0';

    -- **Enable Multiplier Unit Only for MUL Instructions**
    enable_multiplier <= is_mul OR is_mulh OR is_mulhsu OR is_mulhu;

    -- **Send the Correct ALU Function Code**
    control_ex.select_function <= std_logic_vector'("11" & funct3) 
        when (is_mul = '1' OR is_mulh = '1' OR is_mulhsu = '1' OR is_mulhu = '1') 
        else std_logic_vector'("0" & funct3);

    -- **Instruction Decode Stage Control Signals**
    control_id.enable_branch <= '1' when (opcode = WORK.RV32I.OPCODE_BRANCH) else '0';
    control_id.enable_jump   <= '1' when (opcode = WORK.RV32I.OPCODE_JAL OR opcode = WORK.RV32I.OPCODE_JALR) else '0';

    -- **Execution Stage Control Signals**
    control_ex.select_source_1(0) <= '1' when (opcode = WORK.RV32I.OPCODE_JAL OR opcode = WORK.RV32I.OPCODE_JALR OR opcode = WORK.RV32I.OPCODE_AUIPC) else '0';
    control_ex.select_source_1(1) <= '1' when (opcode = WORK.RV32I.OPCODE_LUI) else '0';

    -- **Memory Access Stage Control Signals**
    control_mem.enable_read  <= '1' when (opcode = WORK.RV32I.OPCODE_LOAD) else '0';
    control_mem.enable_write <= '1' when (opcode = WORK.RV32I.OPCODE_STORE) else '0';

    -- **Write Back Stage Control Signals**
    control_wb.enable_destination <= '1' 
        when (opcode = WORK.RV32I.OPCODE_OP OR 
              opcode = WORK.RV32I.OPCODE_OP_IMM OR 
              (is_mul = '1') OR (is_mulh = '1') OR (is_mulhsu = '1') OR (is_mulhu = '1'))
        else '0';

    control_wb.select_destination <= '1' when (opcode = WORK.RV32I.OPCODE_LOAD) else '0';

    -- **Immediate Generation Logic**
    immediate(31) <= instruction(31);

    -- Keep the existing immediate generation logic...

end architecture;
