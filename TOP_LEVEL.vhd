library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
USE ieee.std_logic_unsigned.ALL;

library WORK;

entity TOP_LEVEL is

    port (
        CLOCK    : in  std_logic:= '0';
        en       :   IN  std_logic;							-- multiplier clocking enable,active high
		
		-- Two 16-bit input operands (input_A and input_B), and a 32-bit output (final_result) for the product.
		input_A   :   IN  std_logic_vector(15 downto 0); -- multiplicant input
        input_B   :   IN  std_logic_vector(15 downto 0); -- multiplier input
        final_result :   OUT std_logic_vector(31 downto 0) -- product output
		  
    );

end entity;

architecture RTL of TOP_LEVEL is

	SIGNAL SignFlag_0,SignFlag_1,SignFlag_2,SignFlag_3:std_logic; --define the type of input signflag

	-- Within the archetecture, serval internal signals are declared to facilitate intermediate processing, such as resgisters for storing inputs
	SIGNAL storage_A: std_logic_vector(15 downto 0); -- data from input portA is stored in storage_A
	SIGNAL storage_B: std_logic_vector(15 downto 0); -- data from input portB is stored in storage_B
   
	
	-- The difference between storage_A and Reg_1A is that this is their adjusted absolute values
	SIGNAL Reg1_A: std_logic_vector(15 downto 0); -- data from storage_A is stored in Reg1_A afer checking 15th bit and taking 2's compliment
	SIGNAL Reg1_B: std_logic_vector(15 downto 0); -- data from storage_B is stored in Reg1_b afer checking 15th bit and taking 2's compliment

--Each generated product term is stored in a register    
	SIGNAL P0_Reg2, P1_Reg2,  P2_Reg2, P3_Reg2   : std_logic_vector(7 downto 0);        
	SIGNAL P4_Reg2, P5_Reg2,  P6_Reg2, P7_Reg2   : std_logic_vector(7 downto 0); 
	SIGNAL P8_Reg2, P9_Reg2,  P10_Reg2, P11_Reg2 : std_logic_vector(7 downto 0); 
	SIGNAL P12_Reg2,P13_Reg2, P14_Reg2,P15_Reg2  : std_logic_vector(7 downto 0);  

--Sums are stored in registers3
	SIGNAL Sum0_Reg3: std_logic_vector(19 downto 0);
	SIGNAL Sum1_Reg3: std_logic_vector(19 downto 0);
	SIGNAL Sum2_Reg3: std_logic_vector(19 downto 0);
	SIGNAL Sum3_Reg3: std_logic_vector(19 downto 0);


begin
MULTIPLIER: process(CLOCK,en)

BEGIN

if ((CLOCK'event and CLOCK = '1') and (en = '1')) then
storage_A <= input_A;
storage_B <= input_B;

--Store value of portA input if positive, else take 2's complement of portA
-- and store it in Reg1_A register
--Overall to determine if the value is negative	, if it is negative it computes the 2's complement to find the absolute value.
if(storage_A(15) = '1') then 
Reg1_A<=(not storage_A) + 1;
else
Reg1_A<=storage_A;
end if;

--Store value of portB input if positive, else take 2's complement of portB
-- and store it in Reg1_B register
if(storage_B(15) = '1') then 
Reg1_B<=(not storage_B) + 1;
else
Reg1_B<=storage_B;
end if;

--Determine if product result will be positive or negative 
--or rather the sign of the product is determined by comparing the signs of 
if (((storage_A(15) = '1') and (storage_B(15) = '1') )OR ((storage_A(15) = '0') and (storage_B(15) = '0')))then 
SignFlag_0 <= '0';
else
SignFlag_0 <= '1';
end if;

--**** partial products are generated and stored in registers2  *******************************
P0_Reg2<=Reg1_A (3  downto 0)*Reg1_B(3   downto 0); -- Multiplication Product of A0B0
P1_Reg2<=Reg1_A (3  downto 0)*Reg1_B(7   downto 4); -- Multiplication Product of A0B1 
P2_Reg2<=Reg1_A (3  downto 0)*Reg1_B(11  downto 8); -- Multiplication Product of A0B2
P3_Reg2<=Reg1_A (3  downto 0)*Reg1_B(15  downto 12); -- Multiplication Product of A0B3
P4_Reg2<=Reg1_A (7  downto 4)*Reg1_B(3   downto 0); -- Multiplication Product of A1B0
P5_Reg2<=Reg1_A (7  downto 4)*Reg1_B(7   downto 4); -- Multiplication Product of A1B1
P6_Reg2<=Reg1_A (7  downto 4)*Reg1_B(11  downto 8); -- Multiplication Product of A1B2
P7_Reg2<=Reg1_A (7  downto 4)*Reg1_B(15  downto 12);-- Multiplication Product of A1B3
P8_Reg2<=Reg1_A (11 downto 8)*Reg1_B(3   downto 0); -- Multiplication Product of A2B0
P9_Reg2<=Reg1_A (11 downto 8)*Reg1_B(7   downto 4); -- Multiplication Product of A2B1  
P10_Reg2<=Reg1_A(11 downto 8)*Reg1_B(11  downto 8); -- Multiplication Product of A2B2
P11_Reg2<=Reg1_A(11 downto 8)*Reg1_B(15  downto 12); -- Multiplication Product of A2B3
P12_Reg2<=Reg1_A(15 downto 12)*Reg1_B(3  downto 0);  -- Multiplication Product of A3B0
P13_Reg2<=Reg1_A(15 downto 12)*Reg1_B(7  downto 4);  -- Multiplication Product of A3B1
P14_Reg2<=Reg1_A(15 downto 12)*Reg1_B(11 downto 8);  -- Multiplication Product of A3B2
P15_Reg2<=Reg1_A(15 downto 12)*Reg1_B(15 downto 12); -- Multiplication Product of A3B3

SignFlag_1<=SignFlag_0;            -- here we propagate the number value sign 

--Storing partial sums in Register 3, 20 bit adder	
Sum0_Reg3<= ("000000000000"&P0_Reg2)+("00000000"&P1_Reg2&"0000")+
	   ("0000"&P2_Reg2&"00000000")+(P3_Reg2&"000000000000");
             
Sum1_Reg3<= ("000000000000"&P4_Reg2)+("00000000"&P5_Reg2&"0000")+
           ("0000"&P6_Reg2&"00000000")+(P7_Reg2&"000000000000");

Sum2_Reg3<= ("000000000000"&P8_Reg2)+("00000000"&P9_Reg2&"0000")+
	    ("0000"&P10_Reg2&"00000000")+(P11_Reg2&"000000000000");

Sum3_Reg3<= ("000000000000"&P12_Reg2)+("00000000"&P13_Reg2&"0000")+
	    ("0000"&P14_Reg2&"00000000")+(P15_Reg2&"000000000000");

SignFlag_2<=SignFlag_1;    -- here we propagate the number value sign 

--final sum--
if(SignFlag_2='1') then
final_result<=(NOT (("00000000"&(("0000"&Sum0_Reg3) + (Sum1_Reg3&"0000")))+
		((("0000"&Sum2_Reg3) + (Sum3_Reg3&"0000"))&"00000000")) + 1);
else
final_result<=(("00000000"&(("0000"&Sum0_Reg3) + (Sum1_Reg3&"0000")))+
		((("0000"&Sum2_Reg3) + (Sum3_Reg3&"0000"))&"00000000"));
end if;

END IF;	
END PROCESS MULTIPLIER;



end architecture;
