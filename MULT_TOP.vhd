library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MULT_TOP is
    port (
        clock        : in  std_logic;
        en           : in  std_logic;
        input_A      : in  std_logic_vector(15 downto 0);  -- from SW[15:0]
        input_B      : in  std_logic_vector(15 downto 0);  -- from SW[31:16]
        final_result : out std_logic_vector(31 downto 0)   -- to LEDR[31:0] or similar
    );
end entity;

architecture RTL of MULT_TOP is

    -- Declare the multiplier component
    component RV32M_MULTIPLIER
        port (
            clock       : in  std_logic;
            enable      : in  std_logic;
            select_fun  : in  std_logic_vector(1 downto 0);
            input_A     : in  std_logic_vector(31 downto 0);
            input_B     : in  std_logic_vector(31 downto 0);
            result_LO   : out std_logic_vector(31 downto 0);
            result_HI   : out std_logic_vector(31 downto 0)
        );
    end component;

    signal a_ext : std_logic_vector(31 downto 0);
    signal b_ext : std_logic_vector(31 downto 0);  -- now hardcoded

begin

    -- Sign-extend input_A from switches
    a_ext <= (15 downto 0 => input_A(15)) & input_A;

    -- Hardcode input_B to value 5
    b_ext <= x"00000005";

    -- Instantiate the multiplier
    DUT: RV32M_MULTIPLIER
        port map (
            clock       => clock,
            enable      => en,
            select_fun  => "00",
            input_A     => a_ext,
            input_B     => b_ext,
            result_LO   => final_result,
            result_HI   => open
        );

end architecture;

