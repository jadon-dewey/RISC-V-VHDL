library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MODULE_REGISTER_FILE is
    Port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        reg_write   : in  std_logic;
        read_reg1   : in  std_logic_vector(4 downto 0);
        read_reg2   : in  std_logic_vector(4 downto 0);
        write_reg   : in  std_logic_vector(4 downto 0);
        write_data  : in  std_logic_vector(31 downto 0);
        read_data1  : out std_logic_vector(31 downto 0);
        read_data2  : out std_logic_vector(31 downto 0)
    );
end MODULE_REGISTER_FILE;   

architecture RTL of MODULE_REGISTER_FILE is

    -- Define register file: 32 registers, each 32 bits
    type reg_file_type is array (0 to 31) of std_logic_vector(31 downto 0);
    signal registers : reg_file_type := (others => (others => '0'));

begin

    -- Write process
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                registers <= (others => (others => '0'));
            elsif reg_write = '1' and write_reg /= "00000" then
                registers(to_integer(unsigned(write_reg))) <= write_data;
            end if;
        end if;
    end process;

    -- Read ports
    read_data1 <= registers(to_integer(unsigned(read_reg1)));
    read_data2 <= registers(to_integer(unsigned(read_reg2)));

end RTL;