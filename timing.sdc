# =============================================================
#         FINAL Correct Timing Constraint File
# =============================================================

# 1. Define the main 50 MHz system clock on the 'clk' port.
create_clock -name {clk_50MHz} -period 20.0 [get_ports {clk}]

# 2. Define the 10 MHz ADC clock on the 'adc_clk' port.
# create_clock -name {adc_clk_10MHz} -period 100.0 [get_ports {adc_clk}]

# # 3. Tell the analyzer that these two clocks are asynchronous and unrelated.
# #    This is critical. It allows the 2-flop synchronizer in the VHDL
# #    to work correctly.
# set_clock_groups -asynchronous -group [get_clocks {clk_50MHz}] -group [get_clocks {adc_clk_10MHz}]

# 4. Derive clock uncertainty (good practice).
derive_clock_uncertainty