library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;
use WORK.GENERICS.ALL;

entity CPU_HAZZARD_CONTROL_UNIT is
    port (
        CLOCK                          : in  std_logic := '0';
        stage_id_select_source_1      : in  WORK.CPU.t_REGISTER;
        stage_id_select_source_2      : in  WORK.CPU.t_REGISTER;
        stage_ex_enable_read          : in  std_logic;
        stage_ex_enable_destination   : in  std_logic;
        stage_ex_select_destination   : in  WORK.CPU.t_REGISTER;
        stage_mem_enable_read         : in  std_logic;
        stage_mem_select_destination  : in  WORK.CPU.t_REGISTER;
        stall_branch                  : out std_logic;
        destination                   : out std_logic;
        interrupt_req                 : in  std_logic;
        flush_pipeline                : out std_logic
    );
end entity;

architecture RTL of CPU_HAZZARD_CONTROL_UNIT is

    -- Rising-edge detector signal
    signal interrupt_req_edge : std_logic;

    -- Edge detector component declaration
    component GENERIC_EDGE_DETECTOR is
        port (
            clock  : in  std_logic;
            source : in  std_logic := 'X';
            pulse  : out std_logic
        );
    end component;

begin

    -- Rising edge detector instantiation for interrupt_req
    EDGE_DETECTOR_INST: entity WORK.GENERIC_EDGE_DETECTOR(RISING_DETECTOR)
        port map (
            clock  => CLOCK,
            source => interrupt_req,
            pulse  => interrupt_req_edge
        );

    -- Stall logic
    stall_branch <= (
                        (
                            is_equal_dynamic(stage_id_select_source_1, stage_ex_select_destination) OR
                            is_equal_dynamic(stage_id_select_source_2, stage_ex_select_destination)
                        ) AND
                        NOT(is_equal_dynamic(stage_ex_select_destination, 5X"0")) AND
                        stage_ex_enable_destination
                    ) OR
                    (
                        (
                            is_equal_dynamic(stage_id_select_source_1, stage_mem_select_destination) OR
                            is_equal_dynamic(stage_id_select_source_2, stage_mem_select_destination)
                        ) AND
                        NOT(is_equal_dynamic(stage_mem_select_destination, 5X"0")) AND
                        stage_mem_enable_read
                    );

    -- Forwarding logic
    destination <= (
                        is_equal_dynamic(stage_id_select_source_1, stage_ex_select_destination) OR
                        is_equal_dynamic(stage_id_select_source_2, stage_ex_select_destination)
                   ) AND
                   NOT(is_equal_dynamic(stage_ex_select_destination, 5X"0")) AND
                   stage_ex_enable_read;

    -- Interrupt flush logic
    flush_pipeline <= interrupt_req_edge;

end architecture;