# MIT License

# Copyright (c) 2022 Can Aknesil

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

include("Utils.jl")
import .Utils as u
using NPZ


mem_size = 2048 # Must be power of 2
syncword = u.barker_code_13_13

encoding_len = 2 # DON'T FORGET TO MANUALLY CHANGE THIS !
#encode(n) = n == 1 ? UInt8[1, 0, 0, 0] : UInt8[0, 0, 1, 0] # 4bit-BPSK
encode(n) = n == 1 ? UInt8[1, 0] : UInt8[0, 0] # 2bit-AM

n_bits = div(mem_size, encoding_len)

data = map(n -> rand(Int8.([1, -1])), 1:n_bits-length(syncword))
data = vcat(syncword, data)
data = vcat(map(encode, data)...)


npzwrite("transmitter-input-data.npy", data)
npzwrite("transmitter-input-data-syncword.npy", syncword)

for b in data
    print(string(b))
end
println()


