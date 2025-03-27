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
    signal source_0        : WORK.CPU.t_SIGNALS_ID_EX := WORK.CPU.NULL_SIGNALS_ID_EX;
    signal select_function : WORK.CPU.t_FUNCTION;
    signal data_source_1   : WORK.CPU.t_DATA;
    signal data_source_2   : WORK.CPU.t_DATA;

begin
    -- Handling the clear and enable signals properly
    PIPELINE : if GENERATE_REGISTERS = TRUE generate
        UPDATE : process(clock)
        begin
            if rising_edge(clock) then
                if clear = '1' then
                    source_0 <= WORK.CPU.NULL_SIGNALS_ID_EX;  -- Reset source_0 if clear is active
                elsif enable = '1' then
                    source_0 <= source;  -- Update source_0 if enabled
                end if;
            end if;
        end process;
    else generate
        source_0 <= source;  -- Direct assignment when registers are not generated
    end generate;

    -- Signal mappings
    select_source_1 <= source_0.select_source_1;
    select_source_2 <= source_0.select_source_2;
    destination.control_mem        <= source_0.control_mem;
    destination.control_wb         <= source_0.control_wb;
    destination.data_source_2      <= data_source_2;
    destination.select_destination <= source_0.select_destination;
    destination.funct_3            <= source_0.funct_3;

    -- Multiplexer for forwarding logic
    MUX_FORWARD_SOURCE_1 : entity WORK.GENERIC_MUX_4X1
        generic map (
            DATA_WIDTH => WORK.RV32I.XLEN
        )
        port map (
            selector    => forward.select_source_1,
            source_1    => source_0.data_source_1,
            source_3    => forward.source_mem,
            source_2    => forward.source_wb,
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
            source_3    => forward.source_mem,
            source_2    => forward.source_wb,
            source_4    => (others => '0'),
            destination => data_source_2
        );

    -- Execution unit controllers
    MODULE_EXECUTION_UNIT_CONTROLLER : entity WORK.MODULE_EXECUTION_UNIT_CONTROLLER(RV32I)
        port map (
            opcode      => source_0.opcode,
            funct_3     => source_0.funct_3,
            funct_7     => source_0.funct_7,
            destination => select_function
        );

    MODULE_EXECUTION_UNIT : entity WORK.MODULE_EXECUTION_UNIT(RV32I)
        port map (
            clock           => clock,
            enable          => enable,
            select_source_1 => source_0.control_ex.select_source_1,
            select_source_2 => source_0.control_ex.select_source_2,
            select_function => select_function,
            address_program => source_0.address_program,
            source_1        => data_source_1,
            source_2        => data_source_2,
            immediate       => source_0.data_immediate,
            destination     => destination.data_destination,
            overflow        => open  -- Connect to a signal if overflow needs to be monitored
        );

end architecture;