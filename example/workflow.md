# Workflow

This file describes the workflow of compilation and configuration of
the FPGA design that contains the transmitter and an antenna,
capture of an acquisition, execution of demodulation and analysis.


## Generate the data frame for the transmitter

```
$ julia ../software/generate-transmitter-input-data.jl
```

Output: The data frame to standard output.  
Output: `./transmitter-input-data.npy`  
Output: `./transmitter-input-data-syncword.npy`


Manually transfer the data stream from the standard output in to
`/fpga/transmitter_data_src.vhd` and assign it to the signal `rom`.


## Prepare the FPGA design

Select the desired type of antenna by uncommenting the appropriate
component initializations at the end of `/fpga/antenna_top.vhd` and
set the desired antenna strength using the generic variables (if
applicable).

For the pin antenna, uncomment the port `pin_antenna_pins` at the
beginning of `/fpga/antenna_top.vhd`.

Enable the appropriate constraints file related to the antenna type
and strength. For example, for the monopole antenna with 200 lines,
enable `/fpga/monopole_antenna_200_lines.xdc`.


Initialize the component `antenna_top` in the top-most level. The top
level HDL file is not provided in this repository. Example Vivado
projects for the FPGA board used in our experiments (CW305) can be
found in ChipWhisperer codebase.

Port descriptions of the entity `antenna_top`:  
input port `reset`: Disconnects the antenna when high. Can be assigned to a switch to visually observe the effect of the antenna on the oscilloscope display.  
input port `clk`: Not used. Can be set to the same signal as `antenna_clk`  
input port `antenna_clk`: Clock for the transmitter and the flip-flop antenna, 160 MHz.  
output port `pin_antenna_pins`: When used, should be connected to the desired pins that will be used as antenna.


## Compile the FPGA design into a bitstream and load it to the FPGA

The FPGA board used in our experiments (CW305) can be programmed with
the ChipWhisperer software beside through the JTAG.

Once the bitstream is programmed in to the FPGA, the transmitter automatically starts to transmit the data frame in an infinite loop.


## Acquisition

Position the near-field probe on top of the FPGA chip as shown
in Fig. 3 in the paper. The probe should be connected to the
oscilloscope through the amplifier. Capture a single acquisition,
transfer it to the computer and store it in `.npy` file format.

Oscilloscope settings used in our experiments:  
Bandwidth: 1 GHz  
Sampling rate: 2.5 GHz  
Capture duration: 8 ms (includes 103 data frames)


## Demodulation and analysis

In `/software/rx.jl`, in the section labeled `TUNING PARAMETERS`
select the appropriate value for the parameters
`barker_threshold_rate` and `noise_treshold_over_mean_noise` by
uncommenting the appropriate lines. If there is a change in the experimental
setup, these two parameters should be optimized to obtain the
smallest bit error rate.

Run the following command for demodulation and analysis.

```
$ julia ../software/rx.jl ./trace_monopole-200-lines.npy ./plots  
Reading from input files...  
size(trace): (20000014,)  
Calculating PSD...  
Filtering...  
Calculating PSD...  
Demodulation...  
Demodulate_2bit_AM...  
Mean amplitude: 0.0008690511902546594  
Considering samples below 0.003910730356145967 as noise.  
Expected frequency: 1.3333333333333334e7  
Actual frequency  : 1.3333157245412635e7  
Compensating with modified sampling frequency: 2.500033016921172e9  
Average intra-frame-standard-deviation: 0.001183401887982917  
Frame synchronization...  
Number of detected frames: 103  
Bit Error Ratio: 0.0012717878839493557 (112 / 88065)  
Done.
```

input: Captured acquisition (trace) `./trace_monopole-200-lines.npy`.  
input: Directory where the resulting plots are saved `./plots`.  
input (hardcoded): `./transmitter-input-data.npy`  
input (hardcoded): `./transmitter-input-data-syncword.npy`  
output: Several plots belonging to different stages of the execution. The plots are displayed and saved into the specified directory.  
output: Numerical results at standard output.

The expected standard output is as above. The important metric is bit error ratio (BER), which is used in the presented results.


## Get routing resource utilization

The repository includes two Tcl scripts that need to be run in
Vivado Tcl console after the implementation stage to get the necessary
information for calculation of routing resource utilization.

`/software/get-all-nodes.tcl` saves the `COST_CODE_NAME` of all the
FPGA nodes into a file, one `COST_CODE_NAME` on each line. The
execution takes approximately 2 days on a personal desktop
computer. The output file for Artix-7 100t FPGA generated in our
experiments is provided in this repository,
`./routing_resources_all_nodes.txt`.

Before running the script, manually set the variables `workdir` and
`all_nodes_fname` to the desired location.

`/software/get-used-nodes.tcl` saves the `COST_CODE_NAME` of all used
nodes that are under a desired object into a file, one `COST_CODE_NAME` on each
line. The execution generally takes several seconds. The output file
generated for the provided design that includes a monopole antenna
with 200 lines is provided in this repository,
`./routing_resources_used_nodes_monopole_200.txt`.

To calculate the routing resource utilization, the two files
generated with above scripts should be compared by counting
occurrences of every `COST_CODE_NAME` in each file. For example,
`VLONG` appears 10350 times in `/software/get-used-nodes.tcl` while
1270 times in `./routing_resources_used_nodes_monopole_200.txt`.
