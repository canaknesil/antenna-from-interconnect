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
use IEEE.STD_LOGIC_MISC.ALL;

entity loop_antenna is
    generic(n_loop: integer := 250);
    Port ( pos : in STD_LOGIC;
           neg : out STD_LOGIC);
end loop_antenna;

architecture Behavioral of loop_antenna is

signal stem_start, stem_end: std_logic;
signal lines1, lines2, lines3, lines4: std_logic_vector(1 to n_loop);

attribute dont_touch: string;
attribute dont_touch of lines1, lines2, lines3, lines4, stem_start, stem_end: signal is "true";

begin

stem_start <= pos;
lines1 <= (others => stem_start);
lines2 <= lines1;
lines3 <= lines2;
lines4 <= lines3;
stem_end <= or_reduce(lines4);
neg <= stem_end;


end Behavioral;
