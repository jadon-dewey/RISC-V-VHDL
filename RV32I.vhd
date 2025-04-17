library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

library WORK;

--! Para a topologia, um conjunto de registros foi criado para definir o fluxo de
--! dados em alto nï¿½vel. Isso possibilita simplificar a implementaï¿½ï¿½o de pipelining
--! e manter o cï¿½digo limpo. A partir dos seguintes registros ï¿½ possï¿½vel declarar
--! todos os pontos de controle e de dados de todo o fluxo de execuï¿½ï¿½o da arquitetura.
--! Alï¿½m disso, tambï¿½m sï¿½o especificados valores que caracterizem o comportamento
--! ocioso da arquitetura.
package RV32I is

     --! Largura do vetor de dados
    subtype XLEN_RANGE        is natural range 31 downto  0;
    --! Largura do vetor de programa
    subtype INSTRUCTION_RANGE is natural range 31 downto  0;
    --! Largura do vetor de seleï¿½ï¿½o de funï¿½ï¿½o
    subtype FUNCT3_RANGE      is natural range 14 downto 12;
    --! Largura do vetor de seleï¿½ï¿½o de funï¿½ï¿½o
    subtype FUNCT7_RANGE      is natural range 31 downto 25;
    --! Largura do vetor de opcode completo
    subtype OPCODE_FULL_RANGE is natural range  6 downto  0;
    --! Largura do vetor de opcode truncado
    subtype OPCODE_RANGE      is natural range  6 downto  2;
    --! Largura do vetor de seleï¿½ï¿½o de registrador
    subtype REGISTER_RANGE    is natural range  4 downto  0;
    
    --! Vetor de dados
    subtype t_DATA        is std_logic_vector(XLEN_RANGE);
    --! Vetor de programa
    subtype t_PROGRAM     is std_logic_vector(INSTRUCTION_RANGE);
    --! Vetor de seleï¿½ï¿½o de funï¿½ï¿½o
    subtype t_FUNCT3      is std_logic_vector(FUNCT3_RANGE);
    --! Vetor de seleï¿½ï¿½o de funï¿½ï¿½o
    subtype t_FUNCT7      is std_logic_vector(FUNCT7_RANGE);
    --! Vetor de opcode completo
    subtype t_OPCODE_FULL is std_logic_vector(OPCODE_FULL_RANGE);
    --! Vetor de opcode truncado
    subtype t_OPCODE      is std_logic_vector(OPCODE_RANGE);
    --! Vetor de seleï¿½ï¿½o de registrador
    subtype t_REGISTER    is std_logic_vector(REGISTER_RANGE);

    --! Enumerador de tipos de instruï¿½ï¿½o
    type t_INSTRUCTION_TYPE is (
        --! Instruï¿½ï¿½o tipo R
        INSTRUCTION_R_TYPE,
        --! Instruï¿½ï¿½o tipo I
        INSTRUCTION_I_TYPE,
        --! Instruï¿½ï¿½o tipo S
        INSTRUCTION_S_TYPE,
        --! Instruï¿½ï¿½o tipo B
        INSTRUCTION_B_TYPE,
        --! Instruï¿½ï¿½o tipo U
        INSTRUCTION_U_TYPE,
        --! Instruï¿½ï¿½o tipo J
        INSTRUCTION_J_TYPE
    );

    --! Atributos decodificï¿½veis de um vetor de instruï¿½ï¿½o
    type t_INSTRUCTION is record
        --! Vetor de seleï¿½ï¿½o de funï¿½ï¿½o
        funct_3            : t_FUNCT3;
        --! Vetor de seleï¿½ï¿½o de funï¿½ï¿½o
        funct_7            : t_FUNCT7;
        --! Vetor de seleï¿½ï¿½o de dados
        select_source_2    : t_REGISTER;
        --! Vetor de seleï¿½ï¿½o de dados
        select_source_1    : t_REGISTER;
        --! Vetor de seleï¿½ï¿½o de dados
        select_destination : t_REGISTER;
        --! Vetor de imediato tipo I
        immediate_i        : t_DATA;
        --! Vetor de imediato tipo S
        immediate_s        : t_DATA;
        --! Vetor de imediato tipo B
        immediate_b        : t_DATA;
        --! Vetor de imediato tipo U
        immediate_u        : t_DATA;
        --! Vetor de imediato tipo J
        immediate_j        : t_DATA;
        --! Seletor de shift
        shamt              : std_logic_vector(4 downto 0);
        --! Vetor de Opcode
        opcode             : t_OPCODE;
        --! Tipo de instruï¿½ï¿½o
        encoding           : t_INSTRUCTION_TYPE;
    end record;

    --! Tamanho do vetor de dados
    constant XLEN              : natural := 32;
    --! Tamanho do vetor de instruï¿½ï¿½o
    constant INSTRUCTION_WIDTH : natural := 32;
    --! Tamanho do vetor de seleï¿½ï¿½o de funï¿½ï¿½o
    constant FUNCT3_WIDTH      : natural :=  3;
    --! Tamanho do vetor de seleï¿½ï¿½o de funï¿½ï¿½o
    constant FUNCT7_WIDTH      : natural :=  7;
    --! Tamanho do vetor de opcode completo
    constant OPCODE_FULL_WIDTH : natural :=  7;
    --! Tamanho do vetor de opcode truncado
    constant OPCODE_WIDTH      : natural :=  5;
    --! Tamanho do vetor de seleï¿½ï¿½o de registrador
    constant REGISTER_WIDTH    : natural :=  5;

	 -- RV32I Base Instruction Set opcodes
	constant OPCODE_FULL_OP     : t_OPCODE_FULL := "0110011"; -- X"33"
	constant OPCODE_FULL_OP_IMM : t_OPCODE_FULL := "0010011"; -- X"13"
	constant OPCODE_FULL_JALR   : t_OPCODE_FULL := "1100111"; -- X"67"
	constant OPCODE_FULL_SYNCH  : t_OPCODE_FULL := "0001111"; -- X"0F"
	constant OPCODE_FULL_SYSTEM : t_OPCODE_FULL := "1110011"; -- X"73"
	constant OPCODE_FULL_STORE  : t_OPCODE_FULL := "0100011"; -- X"23"
	constant OPCODE_FULL_LOAD   : t_OPCODE_FULL := "0000011"; -- X"03"
	constant OPCODE_FULL_BRANCH : t_OPCODE_FULL := "1100011"; -- X"63"
	constant OPCODE_FULL_LUI    : t_OPCODE_FULL := "0110111"; -- X"37"
	constant OPCODE_FULL_AUIPC  : t_OPCODE_FULL := "0010111"; -- X"17"
	constant OPCODE_FULL_JAL    : t_OPCODE_FULL := "1101111"; -- X"6F"


		 -- RV32I Base Instruction Set opcodes (ignored 2 LSB)
	constant OPCODE_OP     : t_OPCODE := "01100"; -- X"0C"
	constant OPCODE_OP_M   : t_OPCODE := "01100"; -- X"0C"
	constant OPCODE_OP_IMM : t_OPCODE := "00100"; -- X"04"
	constant OPCODE_JALR   : t_OPCODE := "11001"; -- X"19"
	constant OPCODE_SYNCH  : t_OPCODE := "00011"; -- X"03"
	constant OPCODE_SYSTEM : t_OPCODE := "11100"; -- X"1C"
	constant OPCODE_STORE  : t_OPCODE := "01000"; -- X"08"
	constant OPCODE_LOAD   : t_OPCODE := "00000"; -- X"00"
	
    constant OPCODE_BRANCH : t_OPCODE := "11000"; -- X"18"
    constant OPCODE_LUI    : t_OPCODE := "01101"; -- X"0D"
    constant OPCODE_AUIPC  : t_OPCODE := "00101"; -- X"05"
    constant OPCODE_JAL    : t_OPCODE := "11011"; -- X"1B"

    constant FUNCT3_JALR   : t_FUNCT3 := "000";
    constant FUNCT3_BEQ    : t_FUNCT3 := "000";
    constant FUNCT3_BNE    : t_FUNCT3 := "001";
    constant FUNCT3_BLT    : t_FUNCT3 := "100";
    constant FUNCT3_BGE    : t_FUNCT3 := "101";
    constant FUNCT3_BLTU   : t_FUNCT3 := "110";
    constant FUNCT3_BGEU   : t_FUNCT3 := "111";
    constant FUNCT3_LB     : t_FUNCT3 := "000";
    constant FUNCT3_LH     : t_FUNCT3 := "001";
    constant FUNCT3_LW     : t_FUNCT3 := "010";
    constant FUNCT3_LBU    : t_FUNCT3 := "100";
    constant FUNCT3_LHU    : t_FUNCT3 := "101";
    constant FUNCT3_SB     : t_FUNCT3 := "000";
    constant FUNCT3_SH     : t_FUNCT3 := "001";
    constant FUNCT3_SW     : t_FUNCT3 := "010";
    --! Seletor de funï¿½ï¿½o da instruï¿½ï¿½o ADDI
    constant FUNCT3_ADDI   : t_FUNCT3 := "000";
    constant FUNCT3_SLTI   : t_FUNCT3 := "010";
    constant FUNCT3_SLTIU  : t_FUNCT3 := "011";
    constant FUNCT3_XORI   : t_FUNCT3 := "100";
    constant FUNCT3_ORI    : t_FUNCT3 := "110";
    constant FUNCT3_ANDI   : t_FUNCT3 := "111";
    constant FUNCT3_SLLI   : t_FUNCT3 := "001";
    constant FUNCT3_SRLI   : t_FUNCT3 := "101";
    constant FUNCT3_SRAI   : t_FUNCT3 := "101";
    constant FUNCT3_ADD    : t_FUNCT3 := "000";
    constant FUNCT3_SUB    : t_FUNCT3 := "000";
    constant FUNCT3_SLL    : t_FUNCT3 := "001";
    constant FUNCT3_SLT    : t_FUNCT3 := "010";
    constant FUNCT3_SLTU   : t_FUNCT3 := "011";
    constant FUNCT3_XOR    : t_FUNCT3 := "100";
    constant FUNCT3_SRL    : t_FUNCT3 := "101";
    constant FUNCT3_SRA    : t_FUNCT3 := "101";
    constant FUNCT3_OR     : t_FUNCT3 := "110";
    constant FUNCT3_AND    : t_FUNCT3 := "111";


        --! Seletor de função da instrução FENCE
    constant FUNCT3_FENCE  : t_FUNCT3 := "000";
    --! Seletor de função da instrução ECALL
    constant FUNCT3_ECALL  : t_FUNCT3 := "000";
    --! Seletor de função da instrução EBREAK
    constant FUNCT3_EBREAK : t_FUNCT3 := "000";

    --! Seletor de função da instrução SLLI
    constant FUNCT7_SLLI : t_FUNCT7 := "0000000";
    --! Seletor de função da instrução SRLI
    constant FUNCT7_SRLI : t_FUNCT7 := "0000000";
    --! Seletor de função da instrução SRAI
    constant FUNCT7_SRAI : t_FUNCT7 := "0100000";
    --! Seletor de função da instrução ADD
    constant FUNCT7_ADD  : t_FUNCT7 := "0000000";
    --! Seletor de função da instrução SUB
    constant FUNCT7_SUB  : t_FUNCT7 := "0100000";
        --! Seletor de função da instrução SLL
    constant FUNCT7_SLL  : t_FUNCT7 := "0000000";
    --! Seletor de função da instrução SLT
    constant FUNCT7_SLT  : t_FUNCT7 := "0000000";
    --! Seletor de função da instrução SLTU
    constant FUNCT7_SLTU : t_FUNCT7 := "0000000";
    --! Seletor de função da instrução XOR
    constant FUNCT7_XOR  : t_FUNCT7 := "0000000";
    --! Seletor de função da instrução SRL
    constant FUNCT7_SRL  : t_FUNCT7 := "0000000";
    --! Seletor de função da instrução SRA
    constant FUNCT7_SRA  : t_FUNCT7 := "0100000";
    --! Seletor de função da instrução OR
    constant FUNCT7_OR   : t_FUNCT7 := "0000000";
    --! Seletor de função da instrução AND
    constant FUNCT7_AND  : t_FUNCT7 := "0000000";

    --! Vetor de instrução nula (NOP)
    constant NULL_INSTRUCTION : t_PROGRAM :=
        "00000000000000000" & FUNCT3_ADDI & "00000" & OPCODE_FULL_OP_IMM;
    --! Decodifica um vetor de instruï¿½ï¿½o para um vetor de imediato do tipo I
    
    function to_immediate_i(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA;

    --! Decodifica um vetor de instruï¿½ï¿½o para um vetor de imediato do tipo S
    function to_immediate_s(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA;

    --! Decodifica um vetor de instruï¿½ï¿½o para um vetor de imediato do tipo B
    function to_immediate_b(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA;

    --! Decodifica um vetor de instruï¿½ï¿½o para um vetor de imediato do tipo U
    function to_immediate_u(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA;

    --! Decodifica um vetor de instruï¿½ï¿½o para um vetor de imediato do tipo J
    function to_immediate_j(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA;

    --! Decodifica um vetor de opcode truncado para o tipo de instruï¿½ï¿½o
    function to_instruction_type(
        in_vec : t_OPCODE
    ) return t_INSTRUCTION_TYPE;

    --! Decodifica um vetor de instruï¿½ï¿½o para um record t_INSTRUCTION
    function to_instruction(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_INSTRUCTION;

end package;

package body RV32I is

    function to_immediate_i(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA is
        variable out_vec : t_DATA;
    begin
        out_vec(31 downto 11) := (others => in_vec(31));
        out_vec(10 downto  0) := in_vec(30 downto 20);

        return out_vec;
    end function;

    function to_immediate_s(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA is
        variable out_vec : t_DATA;
    begin
        out_vec(31 downto 11) := (others => in_vec(31));
        out_vec(10 downto  0) := in_vec(30 downto 25) & in_vec(11 downto 7);

        return out_vec;
    end function;

    function to_immediate_b(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA is
        variable out_vec : t_DATA;
    begin
        out_vec(31 downto 12) := (others => in_vec(31));
        out_vec(11 downto  0) := in_vec(7) & in_vec(30 downto 25) & in_vec(11 downto 8) & '0';

        return out_vec;
    end function;

    function to_immediate_u(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA is
        variable out_vec : t_DATA;
    begin
        out_vec(31 downto  12) := in_vec(31 downto 12);
        out_vec(11 downto  0)  := (others => '0');

        return out_vec;
    end function;

    function to_immediate_j(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA is
        variable out_vec : t_DATA;
    begin
        out_vec(31 downto 21) := (others => in_vec(31));
        out_vec(20 downto  0) := in_vec(31) & in_vec(19 downto 12) & in_vec(20) & in_vec(30 downto 21) & '0';

        return out_vec;
    end function;

    function to_instruction_type(
        in_vec : t_OPCODE
    ) return t_INSTRUCTION_TYPE is
        -- No variables
    begin
        case in_vec is
            when
                OPCODE_OP =>
                return INSTRUCTION_R_TYPE;
            when
                OPCODE_JALR   |
                OPCODE_LOAD   |
                OPCODE_OP_IMM |
                OPCODE_SYNCH  |
                OPCODE_SYSTEM =>
                return INSTRUCTION_I_TYPE;
            when
                OPCODE_STORE =>
                return INSTRUCTION_S_TYPE;
            when
                OPCODE_BRANCH =>
                return INSTRUCTION_B_TYPE;
            when
                OPCODE_LUI   |
                OPCODE_AUIPC =>
                return INSTRUCTION_U_TYPE;
            when
                OPCODE_JAL =>
                return INSTRUCTION_J_TYPE;
            when
                others =>
                return INSTRUCTION_R_TYPE;
        end case;
    end function;

    function to_instruction(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_INSTRUCTION is
        variable out_vec : t_INSTRUCTION;
    begin
        out_vec.funct_3            := in_vec(FUNCT3_RANGE);
        out_vec.funct_7            := in_vec(FUNCT7_RANGE);
        out_vec.select_source_2    := in_vec(24 downto 20);
        out_vec.select_source_1    := in_vec(19 downto 15);
        out_vec.select_destination := in_vec(11 downto  7);
        out_vec.immediate_i        := to_immediate_i(in_vec);
        out_vec.immediate_s        := to_immediate_s(in_vec);
        out_vec.immediate_b        := to_immediate_b(in_vec);
        out_vec.immediate_u        := to_immediate_u(in_vec);
        out_vec.immediate_j        := to_immediate_j(in_vec);
        out_vec.shamt              := in_vec(24 downto 20);
        out_vec.opcode             := in_vec(OPCODE_RANGE);
        out_vec.encoding           := to_instruction_type(out_vec.opcode);

        return out_vec;
    end function;

end package body;