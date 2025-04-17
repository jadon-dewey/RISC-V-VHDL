library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library WORK;

entity CPU_STAGE_EX is
    generic (
        GENERATE_REGISTERS : boolean := TRUE
    );
    port (
        clock           : in  std_logic;
        clear           : in  std_logic;
        enable          : in  std_logic;
        source          : in  WORK.CPU.t_SIGNALS_ID_EX;
        forward         : in  WORK.CPU.t_FORWARD_EXECUTION;
        select_source_1 : out WORK.CPU.t_REGISTER;
        select_source_2 : out WORK.CPU.t_REGISTER;
        destination     : out WORK.CPU.t_SIGNALS_EX_MEM
    );
end entity;

architecture RV32I of CPU_STAGE_EX is

    signal source_0              : WORK.CPU.t_SIGNALS_ID_EX := WORK.CPU.NULL_SIGNALS_ID_EX;
    signal select_function       : WORK.CPU.t_FUNCTION;
    signal data_source_1         : WORK.CPU.t_DATA;
    signal data_source_2         : WORK.CPU.t_DATA;

    -- [ADDED] ALU output and multiplier output
    signal data_alu              : WORK.CPU.t_DATA;  -- ALU result
    signal data_multiplication   : WORK.CPU.t_DATA;  -- Multiplier result

begin

    -- Handling pipeline register update
    PIPELINE : if GENERATE_REGISTERS = TRUE generate
        UPDATE : process(clock)
        begin
            if rising_edge(clock) then
                if clear = '1' then
                    source_0 <= WORK.CPU.NULL_SIGNALS_ID_EX;
                elsif enable = '1' then
                    source_0 <= source;
                end if;
            end if;
        end process;
    else generate
        source_0 <= source;
    end generate;

    -- Output control signals
    select_source_1 <= source_0.select_source_1;
    select_source_2 <= source_0.select_source_2;

    destination.control_mem        <= source_0.control_mem;
    destination.control_wb         <= source_0.control_wb;
    destination.data_source_2      <= data_source_2;
    destination.select_destination <= source_0.select_destination;
    destination.funct_3            <= source_0.funct_3;

    -- [ADDED] Forward multiplier result
    destination.data_multiplication <= data_multiplication;

    -- Forwarding multiplexers
    MUX_FORWARD_SOURCE_1 : entity WORK.GENERIC_MUX_4X1
        generic map (
            DATA_WIDTH => WORK.RV32I.XLEN
        )
        port map (
            selector    => forward.select_source_1,
            source_1    => source_0.data_source_1,
            source_2    => forward.source_wb,
            source_3    => forward.source_mem,
            source_4    => (others => '0'),
            destination => data_source_1
        );

    MUX_FORWARD_SOURCE_2 : entity WORK.GENERIC_MUX_4X1
        generic map (
            DATA_WIDTH => WORK.RV32I.XLEN
        )
        port map (
            selector    => forward.select_source_2,
            source_1    => source_0.data_source_2,
            source_2    => forward.source_wb,
            source_3    => forward.source_mem,
            source_4    => (others => '0'),
            destination => data_source_2
        );

    -- ALU controller
    MODULE_EXECUTION_UNIT_CONTROLLER : entity WORK.MODULE_EXECUTION_UNIT_CONTROLLER
        port map (
            opcode      => source_0.opcode,
            funct_3     => source_0.funct_3,
            funct_7     => source_0.funct_7,
            destination => select_function
        );

    -- ALU logic
    MODULE_EXECUTION_UNIT : entity WORK.MODULE_EXECUTION_UNIT
        port map (
            select_source_1 => source_0.control_ex.select_source_1,
            select_source_2 => source_0.control_ex.select_source_2,
            select_function => select_function,
            address_program => source_0.address_program,
            source_1        => data_source_1,
            source_2        => data_source_2,
            immediate       => source_0.data_immediate,
            destination     => data_alu,  -- [MODIFIED]
            overflow        => open
        );

    -- [ADDED] Multiplier unit
    RV32M_MULTIPLIER : entity WORK.RV32M_MULTIPLIER
        port map (
            clock      => clock,
            enable     => source_0.enable_multiplier,
            select_fun => "00",  -- Regular MUL
            input_A    => data_source_1,
            input_B    => data_source_2,
            result_LO  => data_multiplication,
            result_HI  => open
        );

    -- [ADDED] Final result write-back mux
    destination.data_destination <= data_multiplication when source_0.enable_multiplier = '1'
                                   else data_alu;

end architecture;