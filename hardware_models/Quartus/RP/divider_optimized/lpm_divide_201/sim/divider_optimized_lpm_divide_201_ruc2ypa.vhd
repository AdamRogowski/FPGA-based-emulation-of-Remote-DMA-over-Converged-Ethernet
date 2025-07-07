-- (C) 2001-2020 Intel Corporation. All rights reserved.
-- Your use of Intel Corporation's design tools, logic functions and other 
-- software and tools, and its AMPP partner logic functions, and any output 
-- files from any of the foregoing (including device programming or simulation 
-- files), and any associated documentation or information are expressly subject 
-- to the terms and conditions of the Intel Program License Subscription 
-- Agreement, Intel FPGA IP License Agreement, or other applicable 
-- license agreement, including, without limitation, that your use is for the 
-- sole purpose of programming logic devices manufactured by Intel and sold by 
-- Intel or its authorized distributors.  Please refer to the applicable 
-- agreement for further details.




LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY lpm;
USE lpm.all;

ENTITY divider_optimized_lpm_divide_201_ruc2ypa IS
	PORT
	(
		clock		: IN STD_LOGIC;
		denom		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		numer		: IN STD_LOGIC_VECTOR (35 DOWNTO 0);
		quotient		: OUT STD_LOGIC_VECTOR (35 DOWNTO 0);
		remain		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END divider_optimized_lpm_divide_201_ruc2ypa;


ARCHITECTURE SYN OF divider_optimized_lpm_divide_201_ruc2ypa IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (35 DOWNTO 0);
	SIGNAL sub_wire1	: STD_LOGIC_VECTOR (15 DOWNTO 0);



	COMPONENT lpm_divide
	GENERIC (
		lpm_drepresentation		: STRING;
		lpm_hint		: STRING;
		lpm_nrepresentation		: STRING;
		lpm_pipeline		: NATURAL;
		lpm_type		: STRING;
		lpm_widthd		: NATURAL;
		lpm_widthn		: NATURAL
	);
	PORT (
			clock	: IN STD_LOGIC ;
			denom	: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			numer	: IN STD_LOGIC_VECTOR (35 DOWNTO 0);
			quotient	: OUT STD_LOGIC_VECTOR (35 DOWNTO 0);
			remain	: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	END COMPONENT;

BEGIN
	quotient    <= sub_wire0 (35 DOWNTO 0);
	remain    <= sub_wire1 (15 DOWNTO 0);

	LPM_DIVIDE_component : LPM_DIVIDE
	GENERIC MAP (
		lpm_drepresentation => "UNSIGNED",
		lpm_hint => "MAXIMIZE_SPEED=6,LPM_REMAINDERPOSITIVE=TRUE",
		lpm_nrepresentation => "UNSIGNED",
		lpm_pipeline => 14,
		lpm_type => "LPM_DIVIDE",
		lpm_widthd => 16,
		lpm_widthn => 36
	)
	PORT MAP (
		clock => clock,
		denom => denom,
		numer => numer,
		quotient => sub_wire0,
		remain => sub_wire1
	);



END SYN;

