library IEEE; -- Declaring IEEE libray
use IEEE.STD_LOGIC_1164.ALL; -- Declaring std_logic for signal declaration
use IEEE.NUMERIC_STD.ALL; -- Declaring numeric std if needed in the Interruption unit

library WORK; -- Further declarations to integrate with the RISC-V structure

entity TOP_LEVEL is -- declare output and input signals

    port (
        CLOCK           : in  std_logic                    := '0'; -- Clock counter is from the CPU system
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
        interrupt_address  : out std_logic_vector(31 downto 0)   -- Address to jump to
    );

end entity;

architecture RTL of TOP_LEVEL is -- declare internal architecture of the interrupt unit (internal signals and constants)

    -- Number of interrupt sources (Software, CPU Timer, External)
    constant N : integer := 3;

    -- Array for interrupt pending signals
    signal interrupt_pending_signals : std_logic_vector(N-1 downto 0);

    -- Interrupt enable signals array
    signal interrupt_enable_signals : std_logic_vector(N-1 downto 0);

    -- Highest priority index
    signal highest_priority_index : integer range 0 to N-1 := 0;

    -- Interrupt valid flag
    signal interrupt_valid : std_logic := '0';

    -- Interrupt causes array
    type interrupt_cause_array is array(0 to N-1) of unsigned(31 downto 0);
    constant interrupt_causes : interrupt_cause_array := (
        0 => to_unsigned(3, 32),  -- Software Interrupt
        1 => to_unsigned(7, 32),  -- Timer Interrupt
        2 => to_unsigned(11, 32)  -- External Interrupt
    );

    -- Define the custom array type for interrupt pending counts
    type interrupt_pending_array is array (0 to N-1) of unsigned(3 downto 0);

    -- Interrupt pending counters
    signal interrupt_pending_counts : interrupt_pending_array := (others => (others => '0'));

    -- Internal signals
    signal interrupt_cause : unsigned(31 downto 0) := (others => '0');

    -- Internal signal to hold the value of interrupt out
    signal interrupt_out_internal : std_logic := '0';

    -- Internal signal to hold the value of interrupt out after acknowledgement
    signal interrupt_out_acknowledgement : std_logic := '0';

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
        begin
            if reset_n = '0' then -- The unit resets at reset_n = 0
                interrupt_out_internal    <= '0'; -- reset the interrupt_out_internal signal to track the interrupt signal throughout the logic
                interrupt_address <= (others => '0'); -- reset the interrupt address
                interrupt_cause   <= (others => '0'); -- reset the interrupt cause signal
                interrupt_valid   <= '0'; -- reset the interrupt valid signal
                interrupt_pending_counts <= (others => (others => '0')); -- reset the interrupt pending counts signal
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
                if acknowledge = '1' and interrupt_out_internal = '1' then -- If the CPU has acknowledged the signal and the is an interrupt_signal
                -- being sent to the CPU, then this logic should follow
                    -- If the interrupt was acknowledged by the CPU, then the amount of pending interrupts should go down
                    interrupt_pending_counts(highest_priority_index) <= interrupt_pending_counts(highest_priority_index) - 1;
                    -- Deassert interrupt_out since the interrupt was processed (as shown with the acknowledge signal)
                    interrupt_out_internal <= '0';
                    -- Track whether the interrupt_out signal is deasserted after acknowledgement for testing purposes
                    interrupt_out_acknowledgement <= '0';
                    -- Deassert/Reset the internal interrupt_valid signal
                    interrupt_valid <= '0';
    
                    report "Debug: Acknowledge received, interrupt_out_internal deasserted";
                    --report "Debug: Pending count for index " & integer'image(highest_priority_index) &
                       --" decremented to " & integer'image(to_integer(interrupt_pending_counts(highest_priority_index)));
    
                end if;
                
                -- Handle acknowledge signal after the interrupt passes
                if acknowledge = '0' then
                    interrupt_out_internal <= '0'; -- Ensures interrupt_out_internal remains zero after the interrupt passes
                end if;
                
                -- Priority encoder to find the highest priority pending interrupt
                interrupt_valid <= '0'; -- Reset interrupt_valid
                for idx in 0 to N-1 loop -- Checks for each of the three different types of interrupts
                    if interrupt_enable_signals(idx) = '1' and interrupt_pending_counts(idx) > 0 then
                        highest_priority_index <= idx; -- the highest priority index should be the smallest index,
                        -- this sets which interrupt should be processed next
                        interrupt_valid <= '1'; -- asserts that the interrupt is valid

                        report "Debug: Interrupt valid, highest_priority_index = " & integer'image(idx);
    
                        exit;  -- Highest priority interrupt found
                    end if;
                end loop;
                
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
