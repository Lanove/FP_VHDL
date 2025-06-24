-- File: FP_VHDL.vhd
-- Modified to include and use a parallel FIR filter. The filtered output
-- is now sent as the second data channel in the UART packet.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_signed.ALL; -- For SIGNED type used in filter

----------------------------------------------------------------
-- FIR Filter Module
----------------------------------------------------------------
ENTITY fir_filter IS
  PORT (
    clk : IN STD_LOGIC;
    reset_n : IN STD_LOGIC;
    sample_enable : IN STD_LOGIC;
    data_in : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    data_out : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
  );
END ENTITY fir_filter;

ARCHITECTURE rtl OF fir_filter IS
  -- Define a 31-tap filter
  CONSTANT TAPS_COUNT : INTEGER := 51;

  -- Coefficients for a 31-tap filter
  -- Using 16-bit Q15 format (1 sign, 15 fractional bits).
  TYPE coeff_array_t IS ARRAY (0 TO TAPS_COUNT - 1) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
  CONSTANT coeffs : coeff_array_t := (
    0 => x"0013", -- 19
    1 => x"001B", -- 27
    2 => x"0026", -- 38
    3 => x"0033", -- 51
    4 => x"0044", -- 68
    5 => x"0056", -- 86
    6 => x"0067", -- 103
    7 => x"0073", -- 115
    8 => x"0076", -- 118
    9 => x"0069", -- 105
    10 => x"0047", -- 71
    11 => x"000B", -- 11
    12 => x"FFB1", -- -79
    13 => x"FF36", -- -202
    14 => x"FE99", -- -359
    15 => x"FDDE", -- -546
    16 => x"FD07", -- -761
    17 => x"FC1C", -- -996
    18 => x"FB26", -- -1242
    19 => x"FA2F", -- -1489
    20 => x"F943", -- -1725
    21 => x"F86E", -- -1938
    22 => x"F7BB", -- -2117
    23 => x"F734", -- -2252
    24 => x"F6DF", -- -2337
    25 => x"76D1", -- 30417
    26 => x"F6DF", -- -2337
    27 => x"F734", -- -2252
    28 => x"F7BB", -- -2117
    29 => x"F86E", -- -1938
    30 => x"F943", -- -1725
    31 => x"FA2F", -- -1489
    32 => x"FB26", -- -1242
    33 => x"FC1C", -- -996
    34 => x"FD07", -- -761
    35 => x"FDDE", -- -546
    36 => x"FE99", -- -359
    37 => x"FF36", -- -202
    38 => x"FFB1", -- -79
    39 => x"000B", -- 11
    40 => x"0047", -- 71
    41 => x"0069", -- 105
    42 => x"0076", -- 118
    43 => x"0073", -- 115
    44 => x"0067", -- 103
    45 => x"0056", -- 86
    46 => x"0044", -- 68
    47 => x"0033", -- 51
    48 => x"0026", -- 38
    49 => x"001B", -- 27
    50 => x"0013" -- 19
  );
  -- Internal signals
  -- Shift register for input samples (the taps)
  TYPE tap_array_t IS ARRAY (0 TO TAPS_COUNT - 1) OF SIGNED(11 DOWNTO 0);
  SIGNAL taps : tap_array_t := (OTHERS => (OTHERS => '0'));

  SIGNAL sum : STD_LOGIC_VECTOR(27 DOWNTO 0) := (OTHERS => '0');

BEGIN
  -- 1. Input Shift Register (Taps)
  -- On each new sample, shift in the new data
  shift_reg_proc : PROCESS (clk, reset_n)
  BEGIN
    IF reset_n = '0' THEN
      taps <= (OTHERS => (OTHERS => '0'));
    ELSIF rising_edge(clk) THEN
      IF sample_enable = '1' THEN
        taps(50) <= taps(49);
        taps(49) <= taps(48);
        taps(48) <= taps(47);
        taps(47) <= taps(46);
        taps(46) <= taps(45);
        taps(45) <= taps(44);
        taps(44) <= taps(43);
        taps(43) <= taps(42);
        taps(42) <= taps(41);
        taps(41) <= taps(40);
        taps(40) <= taps(39);
        taps(39) <= taps(38);
        taps(38) <= taps(37);
        taps(37) <= taps(36);
        taps(36) <= taps(35);
        taps(35) <= taps(34);
        taps(34) <= taps(33);
        taps(33) <= taps(32);
        taps(32) <= taps(31);
        taps(31) <= taps(30);
        taps(30) <= taps(29);
        taps(29) <= taps(28);
        taps(28) <= taps(27);
        taps(27) <= taps(26);
        taps(26) <= taps(25);
        taps(25) <= taps(24);
        taps(24) <= taps(23);
        taps(23) <= taps(22);
        taps(22) <= taps(21);
        taps(21) <= taps(20);
        taps(20) <= taps(19);
        taps(19) <= taps(18);
        taps(18) <= taps(17);
        taps(17) <= taps(16);
        taps(16) <= taps(15);
        taps(15) <= taps(14);
        taps(14) <= taps(13);
        taps(13) <= taps(12);
        taps(12) <= taps(11);
        taps(11) <= taps(10);
        taps(10) <= taps(9);
        taps(9) <= taps(8);
        taps(8) <= taps(7);
        taps(7) <= taps(6);
        taps(6) <= taps(5);
        taps(5) <= taps(4);
        taps(4) <= taps(3);
        taps(3) <= taps(2);
        taps(2) <= taps(1);
        taps(1) <= taps(0);
        taps(0) <= SIGNED(data_in) - 2048;
      END IF;
    END IF;
  END PROCESS shift_reg_proc;
  -- 3. Parallel Adder Tree (Combinational)
  -- This is a long but purely parallel addition.
  -- For synthesis, the tool will create an efficient adder tree structure.

  -- 3. Parallel Adder Tree (Combinational)
  -- This is a long but purely parallel addition.
  -- For synthesis, the tool will create an efficient adder tree structure.
  sum <= STD_LOGIC_VECTOR(
    signed(taps(0)) * signed(coeffs(0)) +
    signed(taps(1)) * signed(coeffs(1)) +
    signed(taps(2)) * signed(coeffs(2)) +
    signed(taps(3)) * signed(coeffs(3)) +
    signed(taps(4)) * signed(coeffs(4)) +
    signed(taps(5)) * signed(coeffs(5)) +
    signed(taps(6)) * signed(coeffs(6)) +
    signed(taps(7)) * signed(coeffs(7)) +
    signed(taps(8)) * signed(coeffs(8)) +
    signed(taps(9)) * signed(coeffs(9)) +
    signed(taps(10)) * signed(coeffs(10)) +
    signed(taps(11)) * signed(coeffs(11)) +
    signed(taps(12)) * signed(coeffs(12)) +
    signed(taps(13)) * signed(coeffs(13)) +
    signed(taps(14)) * signed(coeffs(14)) +
    signed(taps(15)) * signed(coeffs(15)) +
    signed(taps(16)) * signed(coeffs(16)) +
    signed(taps(17)) * signed(coeffs(17)) +
    signed(taps(18)) * signed(coeffs(18)) +
    signed(taps(19)) * signed(coeffs(19)) +
    signed(taps(20)) * signed(coeffs(20)) +
    signed(taps(21)) * signed(coeffs(21)) +
    signed(taps(22)) * signed(coeffs(22)) +
    signed(taps(23)) * signed(coeffs(23)) +
    signed(taps(24)) * signed(coeffs(24)) +
    signed(taps(25)) * signed(coeffs(25)) +
    signed(taps(26)) * signed(coeffs(26)) +
    signed(taps(27)) * signed(coeffs(27)) +
    signed(taps(28)) * signed(coeffs(28)) +
    signed(taps(29)) * signed(coeffs(29)) +
    signed(taps(30)) * signed(coeffs(30)) +
    signed(taps(31)) * signed(coeffs(31)) +
    signed(taps(32)) * signed(coeffs(32)) +
    signed(taps(33)) * signed(coeffs(33)) +
    signed(taps(34)) * signed(coeffs(34)) +
    signed(taps(35)) * signed(coeffs(35)) +
    signed(taps(36)) * signed(coeffs(36)) +
    signed(taps(37)) * signed(coeffs(37)) +
    signed(taps(38)) * signed(coeffs(38)) +
    signed(taps(39)) * signed(coeffs(39)) +
    signed(taps(40)) * signed(coeffs(40)) +
    signed(taps(41)) * signed(coeffs(41)) +
    signed(taps(42)) * signed(coeffs(42)) +
    signed(taps(43)) * signed(coeffs(43)) +
    signed(taps(44)) * signed(coeffs(44)) +
    signed(taps(45)) * signed(coeffs(45)) +
    signed(taps(46)) * signed(coeffs(46)) +
    signed(taps(47)) * signed(coeffs(47)) +
    signed(taps(48)) * signed(coeffs(48)) +
    signed(taps(49)) * signed(coeffs(49)) +
    signed(taps(50)) * signed(coeffs(50))
    );
  -- 4. Output Scaling and Assignment (Combinational)
  -- The sum is in Q15 format. We need to shift right by 15 to get the integer result,
  -- and select the correct 12 bits. The integer portion starts at bit 15.
  -- We take a 12-bit slice, allowing for bit growth.
  -- data_out <= resize(sum(27 DOWNTO 16), 12);
  -- Correctly scale by shifting right 15 bits, taking the 12 MSBs of the integer result
  data_out <= STD_LOGIC_VECTOR(resize(signed(sum(26 DOWNTO 15)), 12) + 2048);
  -- data_out <= taps(30);

END ARCHITECTURE rtl;

----------------------------------------------------------------
-- Top Level Module
----------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_signed.ALL; -- For SIGNED type used in filter

ENTITY FP_VHDL IS
  PORT (
    clk : IN STD_LOGIC;
    reset_n : IN STD_LOGIC;
    uart_txd : OUT STD_LOGIC;
    -- Unused ports for this test
    ledr : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    hex0 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
    hex1 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
    hex2 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
    hex3 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
  );
END ENTITY FP_VHDL;

ARCHITECTURE rtl OF FP_VHDL IS
  -- Component Declaration for the UART_TX module
  COMPONENT UART_TX IS
    GENERIC (
      g_CLKS_PER_BIT : INTEGER := 17
    );
    PORT (
      i_Clk : IN STD_LOGIC;
      i_TX_DV : IN STD_LOGIC;
      i_TX_Byte : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      o_TX_Active : OUT STD_LOGIC;
      o_TX_Serial : OUT STD_LOGIC;
      o_TX_Done : OUT STD_LOGIC
    );
  END COMPONENT UART_TX;

  -- Component Declaration for the ADC
  COMPONENT adc_ip IS
    PORT (
      CLOCK : IN STD_LOGIC;
      RESET : IN STD_LOGIC;
      CH0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      CH1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      CH2 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      CH3 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      CH4 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      CH5 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      CH6 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      CH7 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
    );
  END COMPONENT adc_ip;

  -- Constants for the UART and Sampling
  CONSTANT CLKS_PER_BIT : INTEGER := 17; -- For ~3 Mbaud with 50MHz clock
  CONSTANT SAMPLE_RATE_DIV : INTEGER := 2000; -- 50MHz / 2000 = 25kHz sample rate

  -- ADC Signals
  SIGNAL ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7 : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL reset_pos : STD_LOGIC;

  -- Signals to connect to the UART
  SIGNAL uart_tx_data : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL uart_tx_dv : STD_LOGIC;
  SIGNAL uart_tx_active : STD_LOGIC;
  SIGNAL uart_tx_done : STD_LOGIC;

  -- Signals for Decimated Sampling
  SIGNAL sample_counter : INTEGER RANGE 0 TO SAMPLE_RATE_DIV - 1;
  SIGNAL new_sample_ready : STD_LOGIC;

  -- Signal to hold the FIR filter's output
  SIGNAL filtered_data_out : STD_LOGIC_VECTOR(11 DOWNTO 0);

  -- FSM Signals and Types
  TYPE t_fsm_state IS (
    IDLE,
    SEND_HEADER,
    SEND_D0_HIGH,
    SEND_D0_LOW,
    SEND_D1_HIGH,
    SEND_D1_LOW,
    SEND_EOL
  );
  SIGNAL state : t_fsm_state := IDLE;

  -- Registers to hold latched ADC data for stable transmission
  SIGNAL adc_data0_reg, adc_data1_reg : STD_LOGIC_VECTOR(11 DOWNTO 0);

  -- Signal to detect rising edge of uart_tx_done
  SIGNAL tx_done_prev : STD_LOGIC;

BEGIN

  -- Create active-high reset for ADC component
  reset_pos <= NOT reset_n;

  -- Component Instantiation
  adc_inst : adc_ip
  PORT MAP(
    CLOCK => clk,
    RESET => reset_pos,
    CH0 => ch0, CH1 => ch1, CH2 => ch2, CH3 => ch3,
    CH4 => ch4, CH5 => ch5, CH6 => ch6, CH7 => ch7
  );

  uart_tx_inst : COMPONENT UART_TX
    GENERIC MAP(
      g_CLKS_PER_BIT => CLKS_PER_BIT
    )
    PORT MAP(
      i_Clk => clk,
      i_TX_DV => uart_tx_dv,
      i_TX_Byte => uart_tx_data,
      o_TX_Active => uart_tx_active,
      o_TX_Serial => uart_txd,
      o_TX_Done => uart_tx_done
    );

    -- Instantiate the FIR Filter
    fir_inst : ENTITY work.fir_filter
      PORT MAP(
        clk => clk,
        reset_n => reset_n,
        sample_enable => new_sample_ready,
        data_in => ch0,
        data_out => filtered_data_out
      );

    ----------------------------------------------------------------
    -- Process to generate a 25kHz sampling trigger
    ----------------------------------------------------------------
    sample_trigger_proc : PROCESS (clk, reset_n)
    BEGIN
      IF reset_n = '0' THEN
        sample_counter <= 0;
        new_sample_ready <= '0';
      ELSIF rising_edge(clk) THEN
        new_sample_ready <= '0'; -- Default to '0', it's a single-cycle pulse
        IF sample_counter = SAMPLE_RATE_DIV - 1 THEN
          sample_counter <= 0;
          new_sample_ready <= '1';
        ELSE
          sample_counter <= sample_counter + 1;
        END IF;
      END IF;
    END PROCESS sample_trigger_proc;

    ----------------------------------------------------------------
    -- Integrated FSM Process
    -- Synchronized to the new_sample_ready trigger
    ----------------------------------------------------------------
    fsm_proc : PROCESS (clk)
    BEGIN
      IF rising_edge(clk) THEN
        -- Use the top-level active-low reset directly
        IF reset_n = '0' THEN
          state <= IDLE;
          uart_tx_dv <= '0';
          uart_tx_data <= x"00";
          adc_data0_reg <= (OTHERS => '0');
          adc_data1_reg <= (OTHERS => '0');
          tx_done_prev <= '0';
        ELSE
          -- Register the uart_tx_done signal to detect its rising edge
          tx_done_prev <= uart_tx_done;

          CASE state IS
            WHEN IDLE =>
              -- Wait for a new sample AND for the UART to be free
              IF new_sample_ready = '1' AND uart_tx_active = '0' THEN
                -- Latch the raw and filtered ADC data
                adc_data0_reg <= ch0;
                adc_data1_reg <= filtered_data_out;
                -- Prepare to send the start byte
                uart_tx_data <= x"AE";
                uart_tx_dv <= '1';
                state <= SEND_HEADER;
              END IF;

            WHEN SEND_HEADER =>
              -- De-assert data valid once the UART takes the data
              IF uart_tx_active = '1' THEN
                uart_tx_dv <= '0';
              END IF;
              -- When the UART is done, send the next byte
              IF uart_tx_done = '1' AND tx_done_prev = '0' THEN
                uart_tx_data <= x"BC";
                uart_tx_dv <= '1';
                state <= SEND_D0_HIGH;
              END IF;

            WHEN SEND_D0_HIGH =>
              IF uart_tx_active = '1' THEN
                uart_tx_dv <= '0';
              END IF;
              IF uart_tx_done = '1' AND tx_done_prev = '0' THEN
                uart_tx_data <= adc_data0_reg(11 DOWNTO 4);
                uart_tx_dv <= '1';
                state <= SEND_D0_LOW;
              END IF;

            WHEN SEND_D0_LOW =>
              IF uart_tx_active = '1' THEN
                uart_tx_dv <= '0';
              END IF;
              IF uart_tx_done = '1' AND tx_done_prev = '0' THEN
                uart_tx_data <= adc_data0_reg(3 DOWNTO 0) & "0000";
                uart_tx_dv <= '1';
                state <= SEND_D1_HIGH;
              END IF;

            WHEN SEND_D1_HIGH =>
              IF uart_tx_active = '1' THEN
                uart_tx_dv <= '0';
              END IF;
              IF uart_tx_done = '1' AND tx_done_prev = '0' THEN
                uart_tx_data <= adc_data1_reg(11 DOWNTO 4);
                uart_tx_dv <= '1';
                state <= SEND_D1_LOW;
              END IF;

            WHEN SEND_D1_LOW =>
              IF uart_tx_active = '1' THEN
                uart_tx_dv <= '0';
              END IF;
              IF uart_tx_done = '1' AND tx_done_prev = '0' THEN
                uart_tx_data <= adc_data1_reg(3 DOWNTO 0) & "0000";
                uart_tx_dv <= '1';
                state <= SEND_EOL;
              END IF;

            WHEN SEND_EOL =>
              IF uart_tx_active = '1' THEN
                uart_tx_dv <= '0';
              END IF;
              -- After sending the last byte, go directly back to IDLE
              IF uart_tx_done = '1' AND tx_done_prev = '0' THEN
                state <= IDLE;
              END IF;

            WHEN OTHERS =>
              state <= IDLE;
          END CASE;
        END IF;
      END IF;
    END PROCESS fsm_proc;

    ----------------------------------------------------------------
    -- Unchanged Display and LED logic
    ----------------------------------------------------------------
    -- Display sampled ADC value on LEDs
    ledr <= ch0(9 DOWNTO 0);

  END ARCHITECTURE rtl;