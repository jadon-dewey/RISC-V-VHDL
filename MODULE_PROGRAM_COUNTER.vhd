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
        selector      : in  std_logic;  -- '0': normal PC+4, '1': branch target (source)
        source        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        destination   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        -- New ports for interrupt handling:
        interrupt_req : in  std_logic;
        interrupt_addr: in  std_logic_vector(DATA_WIDTH-1 downto 0);
        mret          : in  std_logic
    );
end entity;

architecture RV32I of MODULE_PROGRAM_COUNTER is

    signal count_current   : WORK.RV32I.t_DATA;  -- Current PC value
    signal count_increment : WORK.RV32I.t_DATA;  -- PC + 4
    signal normal_pc       : WORK.RV32I.t_DATA;  -- Normal next PC (without interrupt override)
    signal final_pc_input  : WORK.RV32I.t_DATA;  -- Final next PC value
    signal mepc            : WORK.RV32I.t_DATA := (others => '0'); -- Minimal context saving
    -- signal effective_enable_bool : boolean; -- Boolean variable for compute the signal value
    -- signal effective_enable : std_logic; -- Effective enable signal to stall the PC when an interrupt is asserted

begin

    -- Drive the output with the current PC
    destination <= count_current;
    
    -- Calculate the normal PC value:
    normal_pc <= count_increment when selector = '0' else source;

    -- Final selection: if mret, restore PC from mepc; if interrupt, use interrupt_addr; otherwise, use normal_pc.
    final_pc_input <= mepc           when mret = '1' else
                      interrupt_addr when interrupt_req = '1' else
                      normal_pc;

    -- Compute the effective enable signal: enable signal must be asserted; if interrupt_req is asserted, then don't increment the PC
    -- effective_enable_bool <= (enable = '1') and not (count_current = interrupt_addr);
    -- effective_enable <= '1' when effective_enable_bool else '0';

    -- Update the PC register:
    COUNT_REGISTER : entity WORK.GENERIC_REGISTER
        generic map ( DATA_WIDTH => WORK.RV32I.XLEN )
        port map (
            clock       => clock,
            clear       => clear,
            enable      => enable,
            source      => final_pc_input,
            destination => count_current
        );

    
    -- Adder to increment the PC by 4:
    COUNT_ADDER : entity WORK.GENERIC_ADDER
        generic map (
            DATA_WIDTH       => WORK.RV32I.XLEN,
            DEFAULT_SOURCE_2 => 4
        )
        port map (
            source_1    => count_current,
            destination => count_increment
        );

    -- Context saving process: save the current PC when an interrupt is asserted.
    process(clock)
    begin
        if rising_edge(clock) then
            if clear = '1' then
                mepc <= (others => '0');
            elsif interrupt_req = '1' and not (count_current = interrupt_addr) then
                mepc <= count_current;
            end if;
        end if;
    end process;

end architecture;