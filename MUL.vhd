-- MULTIPLICATION UNIT (MUL.vhd)
-- Implements a pipelined 32x32 bit signed multiplication unit
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MUL is
    port (
        clk       : in std_logic;
        rst       : in std_logic;
        start     : in std_logic;
        a, b      : in std_logic_vector(31 downto 0);
        result    : out std_logic_vector(31 downto 0);
        done      : out std_logic
    );
end entity;

architecture Behavioral of MUL is
    signal a_reg, b_reg, p_reg : signed(31 downto 0) := (others => '0');
    signal step : integer := 0;
    signal active : std_logic := '0';

begin
    process(clk, rst)
    begin
        if rst = '1' then
            step <= 0;
            active <= '0';
            result <= (others => '0');
            done <= '0';
        elsif rising_edge(clk) then
            if start = '1' then
                a_reg <= signed(a);
                b_reg <= signed(b);
                p_reg <= (others => '0');
                step <= 0;
                active <= '1';
                done <= '0';
            elsif active = '1' then
                if step < 5 then -- Pipeline steps
                    p_reg <= a_reg * b_reg;
                    step <= step + 1;
                else
                    result <= std_logic_vector(p_reg);
                    done <= '1';
                    active <= '0';
                end if;
            end if;
        end if;
    end process;
end Behavioral;

-- INTEGRATE INTO CPU EXECUTION STAGE (CPU_STAGE_EX.vhd)
architecture Behavioral of CPU_STAGE_EX is
    signal mul_start, mul_done : std_logic;
    signal mul_result : std_logic_vector(31 downto 0);
    signal executing_mul : std_logic := '0';

begin
    -- Instantiate MUL unit
    MUL_UNIT: entity work.MUL
        port map (
            clk     => clk,
            rst     => rst,
            start   => mul_start,
            a       => src1,
            b       => src2,
            result  => mul_result,
            done    => mul_done
        );
    
    process(clk, rst)
    begin
        if rst = '1' then
            executing_mul <= '0';
        elsif rising_edge(clk) then
            if opcode = "0110011" and funct7 = "0000001" and funct3 = "000" then -- MUL instruction
                mul_start <= '1';
                executing_mul <= '1';
            elsif mul_done = '1' then
                result <= mul_result;
                executing_mul <= '0';
            end if;
        end if;
    end process;
end Behavioral;

-- UPDATE INSTRUCTION DECODER (CPU_STAGE_ID.vhd)
process(instr)
begin
    case instr(6 downto 0) is
        when "0110011" => -- R-type ALU operations
            case instr(31 downto 25) is
                when "0000001" => -- MUL Variant
                    case instr(14 downto 12) is
                        when "000" => alu_op <= "MUL";
                        when others => alu_op <= "NOP";
                    end case;
                when others => alu_op <= "NOP";
            end case;
        when others => alu_op <= "NOP";
    end case;
end process;
