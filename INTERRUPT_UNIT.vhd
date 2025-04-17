library IEEE; -- Declaring IEEE libray
use IEEE.STD_LOGIC_1164.ALL; -- Declaring std_logic for signal declaration
use IEEE.NUMERIC_STD.ALL; -- Declaring numeric std if needed in the Interruption unit

library WORK; -- Further declarations to integrate with the RISC-V structure

entity INTERRUPT_UNIT is -- declare output and input signals

    port (
        CLOCK          : in std_logic                    := '0'; -- Clock counter is from the CPU system
        reset_n        : in  std_logic; -- Low-active signal
        -- Interrupt enable signals
        mie            : in  std_logic;   -- Global interrupt enable
        msie           : in  std_logic;   -- Software interrupt enable
        mtie           : in  std_logic;   -- Timer interrupt enable
        meie           : in  std_logic;   -- External interrupt enable
        -- Interrupt pending signals (inputs)
        msip           : in  std_logic;   -- Software interrupt pending
        mtip           : in  std_logic;   -- Timer interrupt pending
        meip           : in  std_logic;   -- External interrupt pending
        -- Acknowledge signal from the CPU
        acknowledge    : in  std_logic;
        -- Vector base address from mtvec register
        mtvec_base     : in  std_logic_vector(31 downto 0);  -- MTVEC base address
        vectored_mode  : in  std_logic;   -- Indicates if vectored mode is enabled
        -- Test signals
        interrupt_ack : out std_logic;    -- Interrupt signal after acknowledgement
        -- Output signal to the core
        interrupt_out      : out std_logic;                      -- Interrupt signal to the core
        interrupt_address  : out std_logic_vector(31 downto 0);   -- Address to jump to
        -- Mask control
        mask_write_enable            : in  std_logic;
        mask_write_data              : in  std_logic_vector(2 downto 0)
    );

end entity;

architecture RTL of INTERRUPT_UNIT is -- declare internal architecture of the interrupt unit (internal signals and constants)

    -- Number of interrupt sources (Software, CPU Timer, External)
    constant NUM_INTERRUPTS : integer := 3;

    -- Number of groups used in the group priority code
    constant NUM_GROUPS     : integer := 2;

    -- Grouping: Group 0 contains msip and mtip; Group 1 contains meip.
    type Interrupt_Group_Array is array (0 to NUM_INTERRUPTS-1) of integer range 0 to NUM_GROUPS-1;
    constant interrupt_group : Interrupt_Group_Array := (
        0, -- msip
        0, --mtip
        1  -- meip
    );

    type integer_vector is array (natural range <>) of integer;

    -- Group priorities (0 is highest)
    constant Group_Priority  : integer_vector(0 to NUM_GROUPS-1) := (0, 1);

    -- Array for interrupt pending signals
    signal interrupt_pending_signals : std_logic_vector(NUM_INTERRUPTS-1 downto 0);

    -- Interrupt enable signals array
    signal interrupt_enable_signals : std_logic_vector(NUM_INTERRUPTS-1 downto 0);

    -- Highest priority index
    signal highest_priority_index : integer range 0 to NUM_INTERRUPTS-1 := 0;

    -- Interrupt valid flag
    signal interrupt_valid : std_logic := '0';

    -- Interrupt causes array
    type interrupt_cause_array is array(0 to NUM_INTERRUPTS-1) of unsigned(31 downto 0);
    constant interrupt_causes : interrupt_cause_array := (
        0 => to_unsigned(3, 32),  -- Software Interrupt
        1 => to_unsigned(7, 32),  -- Timer Interrupt
        2 => to_unsigned(11, 32)  -- External Interrupt
    );

    -- Define the custom array type for interrupt pending counts
    type interrupt_pending_array is array (0 to NUM_INTERRUPTS-1) of unsigned(3 downto 0);

    -- Interrupt pending counters
    signal interrupt_pending_counts : interrupt_pending_array := (others => (others => '0'));

    -- Internal signals
    signal interrupt_cause : unsigned(31 downto 0) := (others => '0');

    -- Internal signal to hold the value of interrupt out
    signal interrupt_out_internal : std_logic := '0';

    -- Internal signal to hold the value of interrupt out after acknowledgement
    signal interrupt_out_acknowledgement : std_logic := '0';

    -- Internal signal to hold the masked interrupt
    signal interrupt_mask : std_logic_vector(NUM_INTERRUPTS-1 downto 0);

    -- Internal signal to store the last serviced index per group
    signal last_serviced_index_per_group : integer_vector(0 to NUM_GROUPS-1);

    -- Signals of previous pending signals, this is for edge-detection
    signal msip_prev : std_logic := '0'; -- Previous software pending signal
    signal mtip_prev : std_logic := '0'; -- Previous timer pending signal
    signal meip_prev : std_logic := '0'; -- Previous external pending signal

    begin

        -- Map interrupt pending and enable signals to arrays
        interrupt_pending_signals(0) <= msip; -- Update software pending
        interrupt_pending_signals(1) <= mtip; -- Update timer pending
        interrupt_pending_signals(2) <= meip; -- Update external pending
    
        interrupt_enable_signals(0) <= msie; -- Update software enabled
        interrupt_enable_signals(1) <= mtie; -- Update timer enabled
        interrupt_enable_signals(2) <= meie; -- Update external enabled
    
        -- Interrupt handling process
        process (CLOCK, reset_n) -- iterated for every clock cycle
            -- Variables used for computing the two-level priority decision.
            variable group_found: boolean;
            variable selected_group: integer range 0 to NUM_GROUPS-1;
            variable idx: integer;
            variable new_highest_priority_index: integer;
            variable new_interrupt_valid: std_logic;
        begin
            if reset_n = '0' then -- The unit resets at reset_n = 0
                interrupt_out_internal    <= '0'; -- reset the interrupt_out_internal signal to track the interrupt signal throughout the logic
                interrupt_address <= (others => '0'); -- reset the interrupt address
                interrupt_cause   <= (others => '0'); -- reset the interrupt cause signal
                interrupt_valid   <= '0'; -- reset the interrupt valid signal
                interrupt_pending_counts <= (others => (others => '0')); -- reset the interrupt pending counts signal
                interrupt_mask <= (others => '0');  -- No interrupts masked by default
                last_serviced_index_per_group <= (others => -1); -- Initialize the last serviced index per group
                -- Reset previous states for edge detection
                msip_prev                 <= '0';  -- Reset previous state of software interrupt
                mtip_prev                 <= '0';  -- Reset previous state of cpu-timer interrupt
                meip_prev                 <= '0';  -- Reset previous state of external interrupt
            elsif rising_edge(CLOCK) then
                -- Edge detection for interrupt inputs (the interruption unit detects for rising-edge, so the unit checks whether each signal
                -- was previously 0)
                if (msip = '1' and msip_prev = '0') then
                    interrupt_pending_counts(0) <= interrupt_pending_counts(0) + 1; -- Increment the amount of pending software interrupts
                end if;
                if (mtip = '1' and mtip_prev = '0') then
                    interrupt_pending_counts(1) <= interrupt_pending_counts(1) + 1; -- Increment the amount of pending timer interrupts
                end if;
                if (meip = '1' and meip_prev = '0') then
                    interrupt_pending_counts(2) <= interrupt_pending_counts(2) + 1; -- Increment the amount of pending external interrupts
                end if;
                
                -- Update the prev signals for the next clock cycle. 
                -- This is to track the value of each signal coming from the register in the previous cycle 
                msip_prev <= msip; -- Tracking for software interrupts
                mtip_prev <= mtip; -- Tracking for timer interrupts
                meip_prev <= meip; -- Tracking for external interrupts

                -- Handle acknowledge signal
                if acknowledge = '1' and interrupt_out_internal = '1' then
                    interrupt_pending_counts(highest_priority_index) <= interrupt_pending_counts(highest_priority_index) - 1;
                    last_serviced_index_per_group(interrupt_group(highest_priority_index)) <= highest_priority_index;
                    report "Debug: Acknowledge received";
                    -- Deassert the internal interrupt signal if acknowledged
                    -- interrupt_out_internal <= '0';
                    -- interrupt_valid <= '0';
                end if;

                -- Interrupt Mask Update Process
                if mask_write_enable = '1' then
                -- Update the interrupt_mask signal with mask_write_data
                    interrupt_mask <= mask_write_data; -- mask_write_data contains data on which interrupt is masked
                end if;
                
                -- Two-Level Priority Encoder
                -- First level: Determine if any interrupt is pending in the highest-priority group.
                group_found := false; -- Intially group_found as false
                selected_group := 0; -- Initially set group 0
                new_interrupt_valid := '0'; --Set the valid signal to '0' as the defaultSS
                new_highest_priority_index := 0;
                for priority_level in 0 to NUM_GROUPS - 1 loop -- Iterate through the priority level (0 being the most priority)
                    for group_index in 0 to NUM_GROUPS - 1 loop -- Iterate through the groups based on priority level
                        if Group_Priority(group_index) = priority_level then
                            for i in 0 to NUM_INTERRUPTS - 1 loop
                                if (interrupt_group(i) = group_index) and 
                                    ((i = 0 and msie = '1') or (i = 1 and mtie = '1') or (i = 2 and meie = '1')) and 
                                    (interrupt_pending_counts(i) > 0) and 
                                    (interrupt_mask(i) = '0') then
                                    group_found := true;
                                    selected_group := group_index;
                                    exit;
                                end if;
                            end loop;
                            if group_found then
                                exit;
                            end if;
                        end if;
                    end loop;
                    if group_found then
                        exit;
                    end if;
                end loop;

                -- Second level: Within the selected group, perform round-robin selection.
                if group_found then
                    for offset in 1 to NUM_INTERRUPTS loop
                        idx := (last_serviced_index_per_group(selected_group) + offset) mod NUM_INTERRUPTS;
                        if interrupt_group(idx) = selected_group then
                            if ((idx = 0 and msie = '1') or (idx = 1 and mtie = '1') or (idx = 2 and meie = '1')) and 
                                (interrupt_pending_counts(idx) > 0) and 
                                (interrupt_mask(idx) = '0') then
                                new_highest_priority_index := idx;
                                new_interrupt_valid := '1';
                                exit;
                            end if;
                        end if;
                    end loop;
                end if;
                highest_priority_index <= new_highest_priority_index;
                interrupt_valid <= new_interrupt_valid;

                -- Generate interrupt signals
                -- Checks if the global interrupt enable (mie) is set and the interrupt is valid
                if mie = '1' and interrupt_valid = '1' then
                    -- Assert the interrupt_out_internal signal
                    interrupt_out_internal <= '1';
                    -- Record the cause of the interrupt, selecting from the highest priority interrupt
                    interrupt_cause <= interrupt_causes(highest_priority_index);
    
                    report "Debug: interrupt_out_internal asserted";
    
                    -- Check if vectored mode is enabled
                    if vectored_mode = '1' then
                    -- Calculate the interrupt vector address by adding the interrupt cause
                    -- (shifted left by 2 for byte alignment) to the base address in mtvec_base
                        interrupt_address <= std_logic_vector(
                            unsigned(mtvec_base) + (interrupt_cause sll 2)
                        );
                    else
                        -- In non-vectored mode, use the base address in mtvec_base as the interrupt address
                        interrupt_address <= mtvec_base;
                    end if;
                else
                    -- Deassert the internal interrupt signal if conditions are not met
                    interrupt_out_internal <= '0';
                    -- Clear the interrupt_address signal
                    interrupt_address <= (others => '0');
                    -- Clear the interrupt_cause signal
                    interrupt_cause <= (others => '0');
    
                    report "Debug: interrupt_out_internal deasserted";
                end if;
            end if;
        end process;
    
        -- Update the signals at the end
        interrupt_out <= interrupt_out_internal; -- Could not update the output signal during the process, so need to update interrupt_out with
        -- an internal signal at the end of the code
        interrupt_ack <= interrupt_out_acknowledgement; -- For testing purposes in the testbench
    end architecture;