library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;

package RV32M is

    -- RV32M Standard Extension Set functions
    constant FUNCT3_MUL    : WORK.RV32I.t_FUNCT3 := "000";
constant FUNCT3_MULH   : WORK.RV32I.t_FUNCT3 := "001";
constant FUNCT3_MULHSU : WORK.RV32I.t_FUNCT3 := "010";
constant FUNCT3_MULHU  : WORK.RV32I.t_FUNCT3 := "011";
constant FUNCT3_DIV    : WORK.RV32I.t_FUNCT3 := "100";
constant FUNCT3_DIVU   : WORK.RV32I.t_FUNCT3 := "101";
constant FUNCT3_REM    : WORK.RV32I.t_FUNCT3 := "110";
constant FUNCT3_REMU   : WORK.RV32I.t_FUNCT3 := "111";

constant FUNCT7_MUL    : WORK.RV32I.t_FUNCT7 := "0000001";
constant FUNCT7_MULH   : WORK.RV32I.t_FUNCT7 := "0000001";
constant FUNCT7_MULHSU : WORK.RV32I.t_FUNCT7 := "0000001";
constant FUNCT7_MULHU  : WORK.RV32I.t_FUNCT7 := "0000001";
constant FUNCT7_DIV    : WORK.RV32I.t_FUNCT7 := "0000001";
constant FUNCT7_DIVU   : WORK.RV32I.t_FUNCT7 := "0000001";
constant FUNCT7_REM    : WORK.RV32I.t_FUNCT7 := "0000001";
constant FUNCT7_REMU   : WORK.RV32I.t_FUNCT7 := "0000001";

end package;
