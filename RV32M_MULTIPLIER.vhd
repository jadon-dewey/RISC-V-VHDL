library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library WORK;

entity RV32M_MULTIPLIER is
    port (
        clock       : in  std_logic := '0';
        enable      : in  std_logic;
        select_fun  : in  std_logic_vector(1 downto 0); -- not used
        input_A     : in  std_logic_vector(31 downto 0);
        input_B     : in  std_logic_vector(31 downto 0);
        result_LO   : out std_logic_vector(31 downto 0);
        result_HI   : out std_logic_vector(31 downto 0)
    );
end entity;

architecture RTL of RV32M_MULTIPLIER is

    signal SignFlag_0, SignFlag_1, SignFlag_2 : std_logic := '0';

    signal storage_A, storage_B : std_logic_vector(15 downto 0) := (others => '0');
    signal Reg1_A, Reg1_B       : std_logic_vector(15 downto 0) := (others => '0');

    signal P0_Reg2, P1_Reg2, P2_Reg2, P3_Reg2     : std_logic_vector(7 downto 0) := (others => '0');
    signal P4_Reg2, P5_Reg2, P6_Reg2, P7_Reg2     : std_logic_vector(7 downto 0) := (others => '0');
    signal P8_Reg2, P9_Reg2, P10_Reg2, P11_Reg2   : std_logic_vector(7 downto 0) := (others => '0');
    signal P12_Reg2, P13_Reg2, P14_Reg2, P15_Reg2 : std_logic_vector(7 downto 0) := (others => '0');

    signal Sum0_Reg3, Sum1_Reg3, Sum2_Reg3, Sum3_Reg3 : std_logic_vector(19 downto 0) := (others => '0');
    signal final_result : std_logic_vector(31 downto 0) := (others => '0');

begin

    process(clock)
begin
    if rising_edge(clock) then
        if enable = '1' then
            -- Store lower 16 bits of input
            storage_A <= input_A(15 downto 0);
            storage_B <= input_B(15 downto 0);

            -- Take 2's complement if negative
            if storage_A(15) = '1' then
                Reg1_A <= (not storage_A) + 1;
            else
                Reg1_A <= storage_A;
            end if;

            if storage_B(15) = '1' then
                Reg1_B <= (not storage_B) + 1;
            else
                Reg1_B <= storage_B;
            end if;

            -- Determine sign
            if (storage_A(15) xor storage_B(15)) = '1' then
                SignFlag_0 <= '1';
            else
                SignFlag_0 <= '0';
            end if;

            SignFlag_1 <= SignFlag_0;

            -- Partial products
            P0_Reg2  <= Reg1_A(3 downto 0)    * Reg1_B(3 downto 0);
            P1_Reg2  <= Reg1_A(3 downto 0)    * Reg1_B(7 downto 4);
            P2_Reg2  <= Reg1_A(3 downto 0)    * Reg1_B(11 downto 8);
            P3_Reg2  <= Reg1_A(3 downto 0)    * Reg1_B(15 downto 12);
            P4_Reg2  <= Reg1_A(7 downto 4)    * Reg1_B(3 downto 0);
            P5_Reg2  <= Reg1_A(7 downto 4)    * Reg1_B(7 downto 4);
            P6_Reg2  <= Reg1_A(7 downto 4)    * Reg1_B(11 downto 8);
            P7_Reg2  <= Reg1_A(7 downto 4)    * Reg1_B(15 downto 12);
            P8_Reg2  <= Reg1_A(11 downto 8)   * Reg1_B(3 downto 0);
            P9_Reg2  <= Reg1_A(11 downto 8)   * Reg1_B(7 downto 4);
            P10_Reg2 <= Reg1_A(11 downto 8)   * Reg1_B(11 downto 8);
            P11_Reg2 <= Reg1_A(11 downto 8)   * Reg1_B(15 downto 12);
            P12_Reg2 <= Reg1_A(15 downto 12)  * Reg1_B(3 downto 0);
            P13_Reg2 <= Reg1_A(15 downto 12)  * Reg1_B(7 downto 4);
            P14_Reg2 <= Reg1_A(15 downto 12)  * Reg1_B(11 downto 8);
            P15_Reg2 <= Reg1_A(15 downto 12)  * Reg1_B(15 downto 12);

            -- Sum partials
            Sum0_Reg3 <= ("000000000000" & P0_Reg2) + ("00000000" & P1_Reg2 & "0000") +
                         ("0000" & P2_Reg2 & "00000000") + (P3_Reg2 & "000000000000");

            Sum1_Reg3 <= ("000000000000" & P4_Reg2) + ("00000000" & P5_Reg2 & "0000") +
                         ("0000" & P6_Reg2 & "00000000") + (P7_Reg2 & "000000000000");

            Sum2_Reg3 <= ("000000000000" & P8_Reg2) + ("00000000" & P9_Reg2 & "0000") +
                         ("0000" & P10_Reg2 & "00000000") + (P11_Reg2 & "000000000000");

            Sum3_Reg3 <= ("000000000000" & P12_Reg2) + ("00000000" & P13_Reg2 & "0000") +
                         ("0000" & P14_Reg2 & "00000000") + (P15_Reg2 & "000000000000");

            -- Final sum with optional sign inversion
            SignFlag_2 <= SignFlag_1;

            if SignFlag_2 = '1' then
                final_result <= not (("00000000" & (("0000" & Sum0_Reg3) + (Sum1_Reg3 & "0000"))) +
                                    ((("0000" & Sum2_Reg3) + (Sum3_Reg3 & "0000")) & "00000000")) + 1;
            else
                final_result <= (("00000000" & (("0000" & Sum0_Reg3) + (Sum1_Reg3 & "0000"))) +
                                 ((("0000" & Sum2_Reg3) + (Sum3_Reg3 & "0000")) & "00000000"));
            end if;

        else
            -- Optional reset when not enabled
            final_result <= (others => '0');
        end if;
    end if;
end process;
    
    
    result_LO <= final_result;  
    result_HI <= (others => '0'); -- Not used in this design

end architecture;