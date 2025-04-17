library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;

entity CPU_TOP_LEVEL is
    generic (
         QUARTUS_MEMORY : boolean := FALSE
    );

    port (
        clock           : in  std_logic := '0';
        clear           : in  std_logic := '0';
        enable          : in  std_logic := '1';
        memory_read     : out std_logic;
        memory_write    : out std_logic;
        data_program    : in  WORK.RV32I.t_PROGRAM := WORK.RV32I.NULL_INSTRUCTION;
        data_memory_in  : in  WORK.CPU.t_DATA := (others => '0');
        data_memory_out : out WORK.CPU.t_DATA;
        address_program : out WORK.CPU.t_DATA;
        address_memory  : out WORK.CPU.t_DATA;
        interrupt_req   : in  std_logic;
        interrupt_addr  : in  std_logic_vector(31 downto 0);
        acknowledge     : out std_logic;
        mret            : in  std_logic
    );
end entity;

architecture RV32I of CPU_TOP_LEVEL is

    signal control_if                  : WORK.CPU.t_CONTROL_IF := WORK.CPU.NULL_CONTROL_IF;
    signal signals_if_id               : WORK.CPU.t_SIGNALS_IF_ID;
    signal signals_id_ex               : WORK.CPU.t_SIGNALS_ID_EX;
    signal signals_ex_mem              : WORK.CPU.t_SIGNALS_EX_MEM;
    signal signals_mem_wb              : WORK.CPU.t_SIGNALS_MEM_WB;
    signal stage_id_address_jump       : WORK.RV32I.t_DATA;
    signal stage_id_forward_branch     : WORK.CPU.t_FORWARD_BRANCH;
    signal stage_ex_forward_execution  : WORK.CPU.t_FORWARD_EXECUTION;
    signal stage_ex_select_source_1    : WORK.RV32I.t_REGISTER;
    signal stage_ex_select_source_2    : WORK.RV32I.t_REGISTER;
    signal stage_mem_control_memory    : WORK.CPU.t_CONTROL_MEM;
    signal stage_wb_enable_destination : std_logic;
    signal stage_wb_select_destination : WORK.RV32I.t_REGISTER;
    signal stage_wb_data_destination   : WORK.RV32I.t_DATA;
    signal flag_stall                  : std_logic;
    signal flag_hazzard                : std_logic;
    signal flush_pipeline              : std_logic;

    -- Interrupt handling
    signal acknowledge_internal        : std_logic;
    signal old_interrupt_req           : std_logic;
    signal intr_pending                : std_logic;

    -- Multiplier propagation signals
    signal stage_ex_data_multiplication   : WORK.CPU.t_DATA;
    signal stage_mem_data_multiplication  : WORK.CPU.t_DATA;
    signal stage_wb_data_multiplication   : WORK.CPU.t_DATA;
    signal stage_ex_enable_multiplier     : std_logic;
    signal stage_mem_enable_multiplier    : std_logic;
    signal stage_wb_enable_multiplier     : std_logic;

begin

    signals_if_id.data_instruction <= data_program;
    address_program <= signals_if_id.address_program;
    memory_read     <= stage_mem_control_memory.enable_read;
    memory_write    <= stage_mem_control_memory.enable_write;

    stage_id_forward_branch.source_mem <= signals_mem_wb.data_destination;
    stage_ex_forward_execution.source_mem <= signals_mem_wb.data_destination;
    stage_ex_forward_execution.source_wb  <= stage_wb_data_destination;

    INSTRUCTION_FETCH : entity WORK.CPU_STAGE_IF
        port map (
            clock           => clock,
            clear           => clear,
            enable          => NOT (flag_hazzard OR (flag_stall AND control_if.enable_stall)),
            source          => control_if,
            address_jump    => stage_id_address_jump,
            address_program => signals_if_id.address_program,
            interrupt_req   => interrupt_req,
            interrupt_addr  => interrupt_addr,
            mret            => mret
        );

    INSTRUCTION_DECODE : entity WORK.CPU_STAGE_ID
        generic map (
            QUARTUS_MEMORY => QUARTUS_MEMORY
        )
        port map (
            clock                => clock,
            clear                => NOT flag_stall OR flush_pipeline,
            enable               => NOT (flag_hazzard OR (flag_stall AND control_if.enable_stall)),
            enable_destination   => stage_wb_enable_destination,
            select_destination   => stage_wb_select_destination,
            data_destination     => stage_wb_data_destination,
            forward              => stage_id_forward_branch,
            source               => signals_if_id,
            address_jump         => stage_id_address_jump,
            control_if           => control_if,
            signals_ex           => signals_id_ex
        );

    EXECUTE : entity WORK.CPU_STAGE_EX
        port map (
            clock           => clock,
            clear           => clear OR flush_pipeline OR (flag_hazzard OR (flag_stall AND control_if.enable_stall)),
            enable          => enable,
            forward         => stage_ex_forward_execution,
            source          => signals_id_ex,
            select_source_1 => stage_ex_select_source_1,
            select_source_2 => stage_ex_select_source_2,
            destination     => signals_ex_mem
        );

    -- Multiplier propagation from EX
    stage_ex_data_multiplication <= signals_ex_mem.data_multiplication;
    stage_ex_enable_multiplier   <= signals_id_ex.enable_multiplier;

    MEMORY_ACCESS : entity WORK.CPU_STAGE_MEM
        port map (
            clock           => clock,
            clear           => clear OR flush_pipeline,
            enable          => enable,
            source          => signals_ex_mem,
            data_memory_in  => data_memory_in,
            control_memory  => stage_mem_control_memory,
            address_memory  => address_memory,
            data_memory_out => data_memory_out,
            destination     => signals_mem_wb
        );

    stage_mem_data_multiplication <= signals_ex_mem.data_multiplication;
    stage_mem_enable_multiplier   <= signals_ex_mem.control_wb.enable_multiplier;

    WRITE_BACK : entity WORK.CPU_STAGE_WB
        port map (
            clock              => clock,
            clear              => clear OR flush_pipeline,
            enable             => enable,
            enable_destination => stage_wb_enable_destination,
            select_destination => stage_wb_select_destination,
            source             => signals_mem_wb,
            destination        => stage_wb_data_destination
        );

    stage_wb_data_multiplication <= signals_mem_wb.data_multiplication;
    stage_wb_enable_multiplier   <= signals_mem_wb.control_wb.enable_multiplier;

    BRANCH_FORWARDING_UNIT : entity WORK.CPU_BRANCH_FORWARDING_UNIT
        port map (
            stage_id_select_source_1     => signals_id_ex.select_source_1,
            stage_id_select_source_2     => signals_id_ex.select_source_2,
            stage_mem_enable_destination => signals_mem_wb.control_wb.enable_destination,
            stage_mem_select_destination => signals_mem_wb.select_destination,
            select_source_1              => stage_id_forward_branch.select_source_1,
            select_source_2              => stage_id_forward_branch.select_source_2
        );

    EXECUTION_FORWARDING_UNIT : entity WORK.CPU_EXECUTION_FORWARDING_UNIT(RV32I)
        port map (
            stage_ex_select_source_1     => stage_ex_select_source_1,
            stage_ex_select_source_2     => stage_ex_select_source_2,
            stage_mem_enable_destination => signals_mem_wb.control_wb.enable_destination,
            stage_mem_select_destination => signals_mem_wb.select_destination,
            stage_wb_enable_destination  => stage_wb_enable_destination,
            stage_wb_select_destination  => stage_wb_select_destination,
            select_source_1              => stage_ex_forward_execution.select_source_1,
            select_source_2              => stage_ex_forward_execution.select_source_2
        );

    CONTROL_HAZZARD_UNIT : entity WORK.CPU_HAZZARD_CONTROL_UNIT
        port map (
            clock                         => clock,
            stage_id_select_source_1     => signals_id_ex.select_source_1,
            stage_id_select_source_2     => signals_id_ex.select_source_2,
            stage_ex_enable_read         => signals_ex_mem.control_mem.enable_read,
            stage_ex_enable_destination  => signals_ex_mem.control_wb.enable_destination,
            stage_ex_select_destination  => signals_ex_mem.select_destination,
            stage_mem_enable_read        => stage_mem_control_memory.enable_read,
            stage_mem_select_destination => signals_mem_wb.select_destination,
            stall_branch                 => flag_stall,
            destination                  => flag_hazzard,
            interrupt_req                => interrupt_req,
            flush_pipeline               => flush_pipeline
        );

    -- Edge detection and acknowledge pulse for interrupt
    process(clock, clear)
    begin
        if clear = '1' then
            old_interrupt_req <= '0';
        elsif rising_edge(clock) then
            old_interrupt_req <= interrupt_req;
        end if;
    end process;

    process(clock, clear)
    begin
        if clear = '1' then
            intr_pending         <= '0';
            acknowledge_internal <= '0';
        elsif rising_edge(clock) then
            acknowledge_internal <= '0';
            if (intr_pending = '0') and (old_interrupt_req = '0') and (interrupt_req = '1') then
                intr_pending <= '1';
            end if;
            if (intr_pending = '1') and (address_program = interrupt_addr) then
                acknowledge_internal <= '1';
                intr_pending         <= '0';
            end if;
        end if;
    end process;

    acknowledge <= acknowledge_internal;

end architecture;
