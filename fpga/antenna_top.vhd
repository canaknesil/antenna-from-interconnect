-- MIT License

-- Copyright (c) 2022 Can Aknesil

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity antenna_top is
    Port ( reset: in STD_LOGIC; -- used as disable signal of the antenna
           clk : in STD_LOGIC;
           antenna_clk: in std_logic
           --pin_antenna_pins: out std_logic_vector(0 downto 0)
    );
end antenna_top;

architecture Behavioral of antenna_top is

component loop_antenna
    port(pos: in std_logic;
         neg: out std_logic);
end component;

component monopole_antenna
    port(pos: in std_logic);
end component;

component flip_flop_antenna
    port(clk: in std_logic;
         pos: in std_logic);
end component;

component clock_divider
    port(reset: in std_logic;
         clk_in: in std_logic;
         clk_out: out std_logic);
end component;

component transmitter
    port(reset: in std_logic;
         clk: in std_logic;
         sig_out: out std_logic);
end component;

signal antenna_clk_divided: std_logic;
signal antenna_signal: std_logic;
signal en: std_logic;
signal antenna_pos, antenna_neg: std_logic;

attribute dont_touch: string;
attribute dont_touch of antenna_signal, en, antenna_pos, antenna_neg: signal is "true";

begin

CLK_DIV: clock_divider port map(reset => '0', 
                                clk_in => antenna_clk, 
                                clk_out => antenna_clk_divided);

TRANS: transmitter port map(reset => '0',
                            clk => antenna_clk_divided,
                            sig_out => antenna_signal);

en <= not reset;
antenna_pos <= antenna_signal when (en = '1') else  '0';

LOOPP: loop_antenna port map(antenna_pos, antenna_neg);
--MONOPOLE: monopole_antenna port map(pos => antenna_pos);
--FF_ANTENNA: flip_flop_antenna port map(clk => antenna_clk_divided, pos => antenna_pos);
--pin_antenna_pins <= (others => antenna_pos);

end Behavioral;
