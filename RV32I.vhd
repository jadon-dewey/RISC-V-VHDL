library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

library WORK;

--! Para a topologia, um conjunto de registros foi criado para definir o fluxo de
--! dados em alto nível. Isso possibilita simplificar a implementação de pipelining
--! e manter o código limpo. A partir dos seguintes registros é possível declarar
--! todos os pontos de controle e de dados de todo o fluxo de execução da arquitetura.
--! Além disso, também são especificados valores que caracterizem o comportamento
--! ocioso da arquitetura.
package RV32I is

     --! Largura do vetor de dados
    subtype XLEN_RANGE        is natural range 31 downto  0;
    --! Largura do vetor de programa
    subtype INSTRUCTION_RANGE is natural range 31 downto  0;
    --! Largura do vetor de seleção de função
    subtype FUNCT3_RANGE      is natural range 14 downto 12;
    --! Largura do vetor de seleção de função
    subtype FUNCT7_RANGE      is natural range 31 downto 25;
    --! Largura do vetor de opcode completo
    subtype OPCODE_FULL_RANGE is natural range  6 downto  0;
    --! Largura do vetor de opcode truncado
    subtype OPCODE_RANGE      is natural range  6 downto  2;
    --! Largura do vetor de seleção de registrador
    subtype REGISTER_RANGE    is natural range  4 downto  0;
    
    --! Vetor de dados
    subtype t_DATA        is std_logic_vector(XLEN_RANGE);
    --! Vetor de programa
    subtype t_PROGRAM     is std_logic_vector(INSTRUCTION_RANGE);
    --! Vetor de seleção de função
    subtype t_FUNCT3      is std_logic_vector(FUNCT3_RANGE);
    --! Vetor de seleção de função
    subtype t_FUNCT7      is std_logic_vector(FUNCT7_RANGE);
    --! Vetor de opcode completo
    subtype t_OPCODE_FULL is std_logic_vector(OPCODE_FULL_RANGE);
    --! Vetor de opcode truncado
    subtype t_OPCODE      is std_logic_vector(OPCODE_RANGE);
    --! Vetor de seleção de registrador
    subtype t_REGISTER    is std_logic_vector(REGISTER_RANGE);

    --! Enumerador de tipos de instrução
    type t_INSTRUCTION_TYPE is (
        --! Instrução tipo R
        INSTRUCTION_R_TYPE,
        --! Instrução tipo I
        INSTRUCTION_I_TYPE,
        --! Instrução tipo S
        INSTRUCTION_S_TYPE,
        --! Instrução tipo B
        INSTRUCTION_B_TYPE,
        --! Instrução tipo U
        INSTRUCTION_U_TYPE,
        --! Instrução tipo J
        INSTRUCTION_J_TYPE
    );

    --! Atributos decodificáveis de um vetor de instrução
    type t_INSTRUCTION is record
        --! Vetor de seleção de função
        funct_3            : t_FUNCT3;
        --! Vetor de seleção de função
        funct_7            : t_FUNCT7;
        --! Vetor de seleção de dados
        select_source_2    : t_REGISTER;
        --! Vetor de seleção de dados
        select_source_1    : t_REGISTER;
        --! Vetor de seleção de dados
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
        --! Tipo de instrução
        encoding           : t_INSTRUCTION_TYPE;
    end record;

    --! Tamanho do vetor de dados
    constant XLEN              : natural := 32;
    --! Tamanho do vetor de instrução
    constant INSTRUCTION_WIDTH : natural := 32;
    --! Tamanho do vetor de seleção de função
    constant FUNCT3_WIDTH      : natural :=  3;
    --! Tamanho do vetor de seleção de função
    constant FUNCT7_WIDTH      : natural :=  7;
    --! Tamanho do vetor de opcode completo
    constant OPCODE_FULL_WIDTH : natural :=  7;
    --! Tamanho do vetor de opcode truncado
    constant OPCODE_WIDTH      : natural :=  5;
    --! Tamanho do vetor de seleção de registrador
    constant REGISTER_WIDTH    : natural :=  5;

    -- RV32I Base Instruction Set opcodes

    -- RV32I Base Instruction Set opcodes (Full opcodes: 7 bits)
    constant OPCODE_FULL_OP     : t_OPCODE_FULL := "0110011";  -- 0x33
    constant OPCODE_FULL_OP_IMM : t_OPCODE_FULL := "0010011";  -- 0x13
    constant OPCODE_FULL_JALR   : t_OPCODE_FULL := "1100111";  -- 0x67
    constant OPCODE_FULL_SYNCH  : t_OPCODE_FULL := "0001111";  -- 0x0F
    constant OPCODE_FULL_SYSTEM : t_OPCODE_FULL := "1110011";  -- 0x73
    constant OPCODE_FULL_STORE  : t_OPCODE_FULL := "0100011";  -- 0x23
    constant OPCODE_FULL_LOAD   : t_OPCODE_FULL := "0000011";  -- 0x03
    constant OPCODE_FULL_BRANCH : t_OPCODE_FULL := "1100011";  -- 0x63
    constant OPCODE_FULL_LUI    : t_OPCODE_FULL := "0110111";  -- 0x37
    constant OPCODE_FULL_AUIPC  : t_OPCODE_FULL := "0010111";  -- 0x17
    constant OPCODE_FULL_JAL    : t_OPCODE_FULL := "1101111";  -- 0x6F

    -- Truncated opcodes (ignoring the 2 LSB) for various instruction types (5 bits)
    constant OPCODE_OP     : t_OPCODE := "01100";  -- 0x0C
    constant OPCODE_OP_IMM : t_OPCODE := "00100";  -- 0x04
    constant OPCODE_JALR   : t_OPCODE := "11001";  -- 0x19
    constant OPCODE_SYNCH  : t_OPCODE := "00011";  -- 0x03
    constant OPCODE_SYSTEM : t_OPCODE := "11100";  -- 0x1C
    constant OPCODE_STORE  : t_OPCODE := "01000";  -- 0x08
    constant OPCODE_LOAD   : t_OPCODE := "00000";  -- 0x00
    constant OPCODE_BRANCH : t_OPCODE := "11000";  -- 0x18
    constant OPCODE_LUI    : t_OPCODE := "01101";  -- 0x0D
    constant OPCODE_AUIPC  : t_OPCODE := "00101";  -- 0x05
    constant OPCODE_JAL    : t_OPCODE := "11011";  -- 0x1B

    -- RV32I Base Instruction Set function selectors (FUNCT3: 3 bits)
    constant FUNCT3_JALR   : t_FUNCT3 := "000";  -- 0x0
    constant FUNCT3_BEQ    : t_FUNCT3 := "000";  -- 0x0
    constant FUNCT3_BNE    : t_FUNCT3 := "001";  -- 0x1
    constant FUNCT3_BLT    : t_FUNCT3 := "100";  -- 0x4
    constant FUNCT3_BGE    : t_FUNCT3 := "101";  -- 0x5
    constant FUNCT3_BLTU   : t_FUNCT3 := "110";  -- 0x6
    constant FUNCT3_BGEU   : t_FUNCT3 := "111";  -- 0x7
    constant FUNCT3_LB     : t_FUNCT3 := "000";  -- 0x0
    constant FUNCT3_LH     : t_FUNCT3 := "001";  -- 0x1
    constant FUNCT3_LW     : t_FUNCT3 := "010";  -- 0x2
    constant FUNCT3_LBU    : t_FUNCT3 := "100";  -- 0x4
    constant FUNCT3_LHU    : t_FUNCT3 := "101";  -- 0x5
    constant FUNCT3_SB     : t_FUNCT3 := "000";  -- 0x0
    constant FUNCT3_SH     : t_FUNCT3 := "001";  -- 0x1
    constant FUNCT3_SW     : t_FUNCT3 := "010";  -- 0x2
    constant FUNCT3_ADDI   : t_FUNCT3 := "000";  -- 0x0
    constant FUNCT3_SLTI   : t_FUNCT3 := "010";  -- 0x2
    constant FUNCT3_SLTIU  : t_FUNCT3 := "011";  -- 0x3
    constant FUNCT3_XORI   : t_FUNCT3 := "100";  -- 0x4
    constant FUNCT3_ORI    : t_FUNCT3 := "110";  -- 0x6
    constant FUNCT3_ANDI   : t_FUNCT3 := "111";  -- 0x7
    constant FUNCT3_SLLI   : t_FUNCT3 := "001";  -- 0x1
    constant FUNCT3_SRLI   : t_FUNCT3 := "101";  -- 0x5
    constant FUNCT3_SRAI   : t_FUNCT3 := "101";  -- 0x5
    constant FUNCT3_ADD    : t_FUNCT3 := "000";  -- 0x0
    constant FUNCT3_SUB    : t_FUNCT3 := "000";  -- 0x0
    constant FUNCT3_SLL    : t_FUNCT3 := "001";  -- 0x1
    constant FUNCT3_SLT    : t_FUNCT3 := "010";  -- 0x2
    constant FUNCT3_SLTU   : t_FUNCT3 := "011";  -- 0x3
    constant FUNCT3_XOR    : t_FUNCT3 := "100";  -- 0x4
    constant FUNCT3_SRL    : t_FUNCT3 := "101";  -- 0x5
    constant FUNCT3_SRA    : t_FUNCT3 := "101";  -- 0x5
    constant FUNCT3_OR     : t_FUNCT3 := "110";  -- 0x6
    constant FUNCT3_AND    : t_FUNCT3 := "111";  -- 0x7
    constant FUNCT3_FENCE  : t_FUNCT3 := "000";  -- 0x0
    constant FUNCT3_ECALL  : t_FUNCT3 := "000";  -- 0x0
    constant FUNCT3_EBREAK : t_FUNCT3 := "000";  -- 0x0

    -- RV32I Base Instruction Set function selectors for FUNCT7 (7 bits)
    constant FUNCT7_SLLI : t_FUNCT7 := "0000000";  -- 0x00
    constant FUNCT7_SRLI : t_FUNCT7 := "0000000";  -- 0x00
    constant FUNCT7_SRAI : t_FUNCT7 := "0100000";  -- 0x20
    constant FUNCT7_ADD  : t_FUNCT7 := "0000000";  -- 0x00
    constant FUNCT7_SUB  : t_FUNCT7 := "0100000";  -- 0x20
    constant FUNCT7_SLL  : t_FUNCT7 := "0000000";  -- 0x00
    constant FUNCT7_SLT  : t_FUNCT7 := "0000000";  -- 0x00
    constant FUNCT7_SLTU : t_FUNCT7 := "0000000";  -- 0x00
    constant FUNCT7_XOR  : t_FUNCT7 := "0000000";  -- 0x00
    constant FUNCT7_SRL  : t_FUNCT7 := "0000000";  -- 0x00
    constant FUNCT7_SRA  : t_FUNCT7 := "0100000";  -- 0x20
    constant FUNCT7_OR   : t_FUNCT7 := "0000000";  -- 0x00
    constant FUNCT7_AND  : t_FUNCT7 := "0000000";  -- 0x00

    -- Null instruction (NOP) defined as a 32-bit vector:
    -- 17 bits of zeros, 3 bits for FUNCT3_ADDI, 5 bits of zeros, and 7 bits for OPCODE_FULL_OP_IMM.
    constant NULL_INSTRUCTION : t_PROGRAM :=
        "00000000000000000" &  -- 17-bit zero vector
        FUNCT3_ADDI &           -- 3-bit function selector for ADDI (should be "000")
        "00000" &               -- 5-bit zero vector
        OPCODE_FULL_OP_IMM;      -- 7-bit full opcode for OP_IMM (should be "0010011")

    --! Decodifica um vetor de instrução para um vetor de imediato do tipo I
    function to_immediate_i(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA;

    --! Decodifica um vetor de instrução para um vetor de imediato do tipo S
    function to_immediate_s(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA;

    --! Decodifica um vetor de instrução para um vetor de imediato do tipo B
    function to_immediate_b(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA;

    --! Decodifica um vetor de instrução para um vetor de imediato do tipo U
    function to_immediate_u(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA;

    --! Decodifica um vetor de instrução para um vetor de imediato do tipo J
    function to_immediate_j(
        in_vec : std_logic_vector(INSTRUCTION_RANGE)
    ) return t_DATA;

    --! Decodifica um vetor de opcode truncado para o tipo de instrução
    function to_instruction_type(
        in_vec : t_OPCODE
    ) return t_INSTRUCTION_TYPE;

    --! Decodifica um vetor de instrução para um record t_INSTRUCTION
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
