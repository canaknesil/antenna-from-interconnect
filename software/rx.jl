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

import DSP as dsp
using NPZ
import PyPlot as plt
import AbstractFFTs as fft
import FFTW
import Statistics as s
import StatsBase as sb


trace_fname = ARGS[1]
plotdir = ARGS[2]
original_data_fname = "transmitter-input-data.npy"
syncword_fname = "transmitter-input-data-syncword.npy"


sampling_freq = 2.5e9
signal_bandwidth = 1.0e9
freq_offset_rate = 0.01 # actual freq. is assumed to be in range f * (1 +- rate)
clk_freq = 160e6 # Clock of the FPGA
antenna_clk_division_rate = 12 # clk_freq / freq of toggling antenna signal
antenna_freq = clk_freq / antenna_clk_division_rate # freq. of toggling antenna signal
antenna_period() = sampling_freq / antenna_freq
antenna_period_rounded() = round(Int, antenna_period())

antenna_bandwidth = (antenna_freq / 4, 2.5 * clk_freq)
#antenna_bandwidth = (antenna_freq / 4, clk_freq * 0.9)

#plotting_start = 600 # used in paper
#plotting_end = 1600
plotting_start = 600
plotting_end = 10600

initial_plotting_start = (plotting_start + Int(0e6)) / sampling_freq
initial_plotting_end = (initial_plotting_start + plotting_end - 1) / sampling_freq
plotting_range() = range(ceil(Int, initial_plotting_start * sampling_freq),
                         floor(Int, initial_plotting_end * sampling_freq))

###### TUNING PARAMETERS #####################################

# filter_noise: Badly filtered regions at the edges of the signal.
# barker_threshold_rate: syncword is accepted when auto-correlation of demodulated samples is above this value.
# noise_treshold_over_mean_noise: below mean(abs(noise)) * x is considered as noise.


# Monopole 2000 lines - high resource usage (14 AES cores)
# barker_threshold_rate = 50 / 169
# noise_treshold_over_mean_noise = 3.3

# Monopole 1000 lines - high resource usage (14 AES cores)
# barker_threshold_rate = 100 / 169
# noise_treshold_over_mean_noise = 2.8

# Monopole 1000 lines - high resource usage (13 AES cores)
# barker_threshold_rate = 100 / 169
# noise_treshold_over_mean_noise = 2.7

# Monopole 1000 lines - high resource usage (12 AES cores)
# barker_threshold_rate = 100 / 169
# noise_treshold_over_mean_noise = 3.1

# Monopole 1000 lines - high resource usage (11 AES cores)
# barker_threshold_rate = 100 / 169
# noise_treshold_over_mean_noise = 3.6

# Monopole 500 lines
# barker_threshold_rate = 0.6
# noise_treshold_over_mean_noise = 5

# Monopole 500 lines - high resource usage (14 AES cores)
# barker_threshold_rate = 70 / 169
# noise_treshold_over_mean_noise = 2.9

# Monopole 200 lines
# barker_threshold_rate = 56 / 169
# noise_treshold_over_mean_noise = 4.5

# Monopole 200 lines - half length
# barker_threshold_rate = 100 / 169
# noise_treshold_over_mean_noise = 3.2

# Monopole 200 lines - high resource usage (14 AES cores)
# barker_threshold_rate = 36 / 169
# noise_treshold_over_mean_noise = 3.6

# Monopole 200 lines - high resource usage (8 AES cores)
# barker_threshold_rate = 60 / 169
# noise_treshold_over_mean_noise = 3.1

# Monopole 200 lines - high resource usage (2 AES cores)
# barker_threshold_rate = 100 / 169
# noise_treshold_over_mean_noise = 3.9

# Monopole 100 lines
# barker_threshold_rate = 53 / 169
# noise_treshold_over_mean_noise = 3.2

# Flip-flop 100K lines
# barker_threshold_rate = 138 / 169
# noise_treshold_over_mean_noise = 3.7

# Flip-flop 50K lines and 20K
# barker_threshold_rate = 138 / 169
# noise_treshold_over_mean_noise = 3.5

# Flip-flop 10K lines
# barker_threshold_rate = 86 / 169
# noise_treshold_over_mean_noise = 3.4

# Flip-flop 5K lines
# barker_threshold_rate = 65 / 169
# noise_treshold_over_mean_noise = 3.0

# Not-connected Pin antenna 1 pin
# barker_threshold_rate = 100 / 169
# noise_treshold_over_mean_noise = 3.4

# Loop 125 loops
# barker_threshold_rate = 0.6
# noise_treshold_over_mean_noise = 4.0

# Loop 50 loops
# barker_threshold_rate = 0.6
# noise_treshold_over_mean_noise = 4.1

# Loop 25 loops
barker_threshold_rate = 42 / 169
noise_treshold_over_mean_noise = 3.6

filter_noise = 5000

chop_filter_noise(signal) = signal[1+filter_noise:end-filter_noise]
barker_threshold(syncword_len) = syncword_len * barker_threshold_rate

##############################################################


rcParams = plt.PyDict(plt.matplotlib."rcParams")
rcParams["font.size"] = 18

function plot_signal(f::Function, fname::AbstractString, plot_args...)
    plt.figure(figsize=[16, 3])
    f(plot_args...)
    plt.tight_layout()
    plt.savefig(plotdir * "/" * fname)
end

plot_signal(fname::AbstractString, plot_args...) = plot_signal(plt.plot, fname, plot_args...)



function pass_filter(signal::AbstractVector, response_type)
    design_method = dsp.Butterworth(6)
    filter = dsp.digitalfilter(response_type, design_method)
    return dsp.filt(filter, signal)
end


bandpass(signal::AbstractVector, f1::Number, f2::Number, fs) =
    pass_filter(signal, dsp.Bandpass(f1, f2, fs=fs))

function bandpass(signal::AbstractVector, f::Number, fs)
    start = f * (1 - freq_offset_rate)
    stop =  f * (1 + freq_offset_rate)
    if start < fs / 2 && stop > fs / 2
        stop = f
    end
    return pass_filter(signal, dsp.Bandpass(start, stop, fs=fs))
end

lowpass(signal::AbstractVector, f::Number, fs) =
    pass_filter(signal, dsp.Lowpass(f, fs=fs))

highpass(signal::AbstractVector, f::Number, fs) =
    pass_filter(signal, dsp.Highpass(f, fs=fs))


# This function is erronous in case freqs contains the same frequency twice.
# bandpass(signal::AbstractVector, freqs::AbstractVector{<:Number}, fs) =
#     sum(map(f -> bandpass(signal, f, fs), freqs))

function bandstop(signal::AbstractVector, freqs::AbstractVector{<:Number}, fs)
    for f in freqs
        signal -= bandpass(signal, f, fs)
    end
    signal
end


function power_spectral_density(signal, fs; db=false)
    psd = abs.(fft.fft(signal)) .^ 2 # Power Spectral Density
    psd_freqs = (0:length(signal)) .* sampling_freq ./ length(signal)
    psd_freqs = psd_freqs[1:end-1]

    # Second half of the spectrum is mirror of first half.
    psd = psd[1:div(length(psd), 2)]
    psd_freqs = psd_freqs[1:div(length(psd_freqs), 2)]

    # Bandwidth of the signal is known. Removing higher freq. than Nyquist freq.
    stop_idx = round(Int, length(psd) * (signal_bandwidth / 2) / (sampling_freq / 2))
    psd = psd[1:stop_idx]
    psd_freqs = psd_freqs[1:stop_idx]

    if db
        psd = 10 .* log10.(psd) # to decibel
    end

    return psd_freqs, psd
end


function cross_correlate(x::AbstractVector, y::AbstractVector)
    @assert length(x) >= length(y)

    result = zeros(promote_type(eltype(x), eltype(y)), length(x) - length(y) + 1)
    for i = 1:length(result)
        a = x[i:i + length(y) - 1]
        result[i] = sum(a .* y)
    end

    result
end


function barker_score(cors::AbstractVector)
    @assert !iseven(length(cors))
    
    cors = map(c -> c < 0 ? 0 : c, cors)
    median_idx = div(length(cors), 2) + 1
    median = cors[median_idx]
    skirt = s.mean(vcat(cors[1:median_idx-1],
                        cors[median_idx+1:end]))
    return median - skirt
end


function barker_score(cors::AbstractVector, window_size::Integer)
    @assert !iseven(window_size)
    @assert length(cors) >= window_size

    cors_len = length(cors)
    cors = vcat(zeros(div(window_size, 2)),
                cors,
                zeros(div(window_size, 2)))
    result = zeros(cors_len)

    for i = 1:cors_len
        result[i] = barker_score(cors[i:i+window_size-1])
    end

    return result
end


"Merge peaks close to each other as square pulses."
function merge_peaks(signal; max_peak_distance, peak_extension)
    signal = copy(signal)
    
    high_sample_indices = findall(n -> n == 1, signal)
    new_high_sample_indices = []
    for i = 1:length(high_sample_indices)-1
        idx = high_sample_indices[i]
        next_idx = high_sample_indices[i+1]
        push!(new_high_sample_indices, idx)
        if next_idx - idx <= max_peak_distance
            append!(new_high_sample_indices, idx+1 : next_idx-1)
        else
            append!(new_high_sample_indices, idx+1 : min(idx+round(Int, peak_extension),
                                                         length(signal)))
        end
    end
    append!(new_high_sample_indices, high_sample_indices[end]:length(signal))
    
    for idx in new_high_sample_indices
        signal[idx] = 1
    end

    return signal
end


to_discrete(f, N) =  f * N / sampling_freq
to_continuous(f, N) = f * sampling_freq / N


"By updating sampling frequency."
function correct_frequency_offset(signal)
    global sampling_freq

    psd_freqs, psd = power_spectral_density(signal, sampling_freq, db=false)
    #plt.figure()
    #plt.plot(psd)
    
    expected_freq = antenna_freq
    expected_freq_idx = round(Int, to_discrete(expected_freq, length(signal))) + 1
    start = floor(Int, expected_freq_idx * (1 - freq_offset_rate))
    stop  =  ceil(Int, expected_freq_idx * (1 + freq_offset_rate))
    actual_freq_idx = argmax(psd[start:stop]) + start - 1
    actual_freq = to_continuous(actual_freq_idx-1, length(signal))
    println("Expected frequency: $expected_freq")
    println("Actual frequency  : $actual_freq")
    #println(psd[actual_freq_idx])
    
    sampling_freq *= expected_freq / actual_freq
    println("Compensating with modified sampling frequency: $sampling_freq")
end


function downsample(signal, step::Integer)
    global sampling_freq /= step
    return signal[1:step:end]
end


chop_at_multiple_of(signal, n) = signal[1:div(end, n) * n]


function demodulate_2bit_AM(signal)
    global sampling_freq

    println("Demodulate_2bit_AM...")
    
    demodulated = abs.(signal)
    
    # Assuming most of the samples are in between spikes so mean(signal) is noise average.
    avg = s.mean(demodulated)
    println("Mean amplitude: $avg")
    threshold = avg * noise_treshold_over_mean_noise
    println("Considering samples below $threshold as noise.")

    plt.figure()
    plt.plot(demodulated[plotting_range()])
    plt.hlines(threshold, 0, length(plotting_range()) - 1, "r")

    demodulated = map(n -> n < threshold ? -1 : 1, demodulated)
    
    plt.figure()
    plt.plot(demodulated[plotting_range()])

    demodulated = merge_peaks(demodulated,
                              max_peak_distance = antenna_period() * 0.75,
                              peak_extension = antenna_period() * 0.4)

    plot_signal("demodulated.png", demodulated[plotting_range()])
    
    correct_frequency_offset(demodulated)
        
    # Resampling is necessary so that later operations are faster.
    demodulated = downsample(demodulated, floor(Int, antenna_period() / 16))
    
    # plt.figure()
    # plt.plot(demodulated[plotting_range()])
    
    
    # Symbol synchronization
    
    function find_rising_edge_offset(start)
        rising_edge = start
        while demodulated[rising_edge] == 1
            rising_edge += 1
        end
        while demodulated[rising_edge] == -1
            rising_edge += 1
        end
        offset = rising_edge % antenna_period() + antenna_period() / 2 
        return round(Int, offset)
    end

    count = 1000
    offsets = map(find_rising_edge_offset,
                  round.(Int, ((1:count+1) * length(demodulated) / (count+1))[1:end-1]))
    cm = sb.countmap(offsets)
    #println("Synchronization offset countmap:"); display(sort(cm)); println()
    _, offset = findmax(cm)
    
    demodulated = demodulated[1 + offset:end]


    # Sampling
    
    sampling_step = antenna_period()
    sample_indices = 1 : sampling_step : length(demodulated)
    sample_indices = map(i -> round(Int, i), sample_indices)
    samples = demodulated[sample_indices]
    
    # plot_signal("samples.png") do
    #     plt.plot(demodulated[plotting_range()])
    #     plt.stem(x_without_offset, samples[x]) # Buggy line
    # end

    
    sampling_freq /= sampling_step

    samples = samples[2:end-1] # in case edge sample are bad
    
    return samples
end


function decode_2bit_AM(samples::AbstractVector)
    @assert iseven(length(samples))
    samples = copy(samples)
    
    decoded = []
    while length(samples) > 0
        code = samples[1:2]
        if code == [1, 0]
            b = 1
        elseif code == [0, 0]
            b = -1
        else
            error("Decoding error")
        end
        push!(decoded, b)
        deleteat!(samples, [1, 2])
    end
    
    return decoded
end



##################
###### MAIN ######
##################


println("Reading from input files...")

trace = npzread(trace_fname)
println("size(trace): $(size(trace))")
#trace = trace[1:10000] # For debugging

plot_signal("raw.png", trace[plotting_range()])


println("Calculating PSD...")
psd_freqs, psd = power_spectral_density(trace, sampling_freq, db=false)
plot_signal("raw-psd.png", psd_freqs, psd)


original = npzread(original_data_fname)

decoded = decode_2bit_AM(original)
frame_size = length(decoded)


println("Filtering...")

low = antenna_bandwidth[1]
high = antenna_bandwidth[2]

noise_freqs = vcat(clk_freq : clk_freq : sampling_freq/2,
                   clk_freq*3/5 : clk_freq*3/5 : sampling_freq/2,
                   clk_freq*3 : clk_freq*3 : sampling_freq/2,
                   740e6*clk_freq/160e6 : 740e6*clk_freq/160e6 : sampling_freq/2)

filtered = bandstop(trace, noise_freqs, sampling_freq)
filtered = bandpass(filtered, low, high, sampling_freq)
filtered = chop_filter_noise(filtered)


plot_signal("filtered.png", filtered[plotting_range()])


println("Calculating PSD...")
psd_freqs, psd = power_spectral_density(filtered, sampling_freq, db=false)
plot_signal("filtered-psd.png", psd_freqs, psd)


println("Demodulation...")

samples = demodulate_2bit_AM(filtered)
samples = reverse(samples) # Forgot to reverse when putting in VHDL, so now I reverse.


# Compare frames with each other (for this, no need for frame synchronization)

frame_size = 1024
frames = chop_at_multiple_of(samples, frame_size)
frames = reshape(frames, frame_size, :)
frames = frames[:,2:end-1] # first and last frames may be incomplete
intra_frame_error_rate = map(s.var , eachrow(frames))
intra_frame_error_rate /= 2 # [-1, 1] range
intra_frame_error_rate /= 2 # Normalize with bit error rate. Assuming frames deviate from each other twice as they deviate from the original.

# plt.figure()
# plt.plot(intra_frame_error_rate)

println("Average intra-frame-standard-deviation: $(s.mean(intra_frame_error_rate))")


println("Frame synchronization...")

syncword = npzread(syncword_fname)
cors = cross_correlate(samples, syncword)

# plt.figure()
# plt.plot(cors)

scores = barker_score(cors, length(syncword))
bt = barker_threshold(length(syncword))

plt.figure()
plt.plot(scores)
plt.hlines(bt, 0, length(scores) - 1, "r")

frame_start_indices = findall(c -> c >= bt, scores[1:end-(frame_size-1)])
frames = zeros(eltype(samples), frame_size, length(frame_start_indices))
for (i, idx) in enumerate(frame_start_indices)
    frames[:,i] = samples[idx:idx+frame_size-1]
end
println("Number of detected frames: $(size(frames, 2))")

# Compare with original string of bits

bits = frames[1+length(syncword):end,:]
correct_bits = decoded[1+length(syncword):end]
if size(bits, 2) > 0
    n_wrong_bits = sum(broadcast(!=, correct_bits, bits))
    bit_error_rate = n_wrong_bits / length(bits)
    println("Bit Error Rate: $bit_error_rate ($n_wrong_bits / $(length(bits)))") # 0.5 is random bits
else
    println("Bit Error Rate: N/A")
end


println("Done.")
plt.show()

