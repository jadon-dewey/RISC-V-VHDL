library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library WORK;

entity MODULE_PROGRAM_COUNTER is
    generic (
        DATA_WIDTH : natural := WORK.RV32I.XLEN
    );
    port (
        clock         : in  std_logic;
        clear         : in  std_logic;
        enable        : in  std_logic;
        selector      : in  std_logic;  -- '0': normal PC+4, '1': branch/jump target
        source        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        destination   : out std_logic_vector(DATA_WIDTH-1 downto 0);

        -- Interrupt-related ports
        interrupt_req  : in  std_logic;
        interrupt_addr : in  std_logic_vector(DATA_WIDTH-1 downto 0);

        -- No external mret anymore; replaced by internal logic
        mret           : in  std_logic := '0' -- Optional / unused now
    );
end entity;

architecture RV32I of MODULE_PROGRAM_COUNTER is

    -- Internal PC state
    signal count_current    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal count_increment  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal normal_pc        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal final_pc_input   : std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Context saving
    signal mepc             : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    -- Internal FSM flags
    signal interrupt_active : std_logic := '0'; -- Indicates ISR is being handled
    signal mret_internal    : std_logic := '0'; -- Asserts one cycle when returning from interrupt

begin
    
    -- PC + 4 calculation
    COUNT_ADDER : entity WORK.GENERIC_ADDER
        generic map (
            DATA_WIDTH       => DATA_WIDTH,
            DEFAULT_SOURCE_2 => 4
        )
        port map (
            source_1    => count_current,
            destination => count_increment
        );

    -- Drive output port
    destination <= count_current;
    
    -- Normal PC: either PC+4 or jump/branch target
    normal_pc <= count_increment when selector = '0' else source;

    -- Final PC input: prioritized mux structure
    final_pc_input <= mepc           when mret_internal = '1' else
                      interrupt_addr when interrupt_req = '1' else
                      normal_pc;

    
    -- PC register (updates with selected input)
    COUNT_REGISTER : entity WORK.GENERIC_REGISTER
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clock       => clock,
            clear       => clear,
            enable      => enable,
            source      => final_pc_input,
            destination => count_current
        );

    -- Context-saving + internal mret signal logic
    process(clock)
    begin
        if rising_edge(clock) then
            if clear = '1' then -- Clear logic
                mepc             <= (others => '0');
                interrupt_active <= '0';
                mret_internal    <= '0';

            -- Save PC when interrupt is first detected (edge detector on interrupt request signal)
            elsif interrupt_req = '1' and interrupt_active = '0' then
                mepc             <= count_current;
                interrupt_active <= '1';
                mret_internal    <= '0';

            -- Return from interrupt: trigger PC restore on deassertion
            elsif interrupt_req = '0' and interrupt_active = '1' then
                interrupt_active <= '0';
                mret_internal    <= '1'; -- Will select mepc for 1 cycle

            else
                mret_internal <= '0'; -- Reset after one cycle
            end if;
        end if;
    end process;

end architecture;