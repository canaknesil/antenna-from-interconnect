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
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity transmitter is
    Port ( reset : in STD_LOGIC;
           clk : in STD_LOGIC;
           sig_out : out STD_LOGIC);
end transmitter;


architecture Behavioral of transmitter is

component transmitter_data_src
    port(addr: in std_logic_vector(10 downto 0);
         dout: out std_logic);
end component;

signal addr: std_logic_vector(10 downto 0) := (others => '0');
signal data: std_logic;

begin

INCR: process(clk, reset)
begin
    if (reset = '1') then
        addr <= (others => '0');
    elsif (rising_edge(clk)) then
        addr <= addr + 1;
    end if;
end process;

TRANS_INPUT_SRC: transmitter_data_src port map(
    addr => addr,
    dout => data
);

OUT_REG: process(clk, reset)
begin
    if (rising_edge(clk)) then
        sig_out <= data;
    end if;
end process;

end Behavioral;
















