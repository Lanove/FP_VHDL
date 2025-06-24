-- File: FP_VHDL.vhd
-- Modified to remove the explicit wait states after UART transmission.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

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
  CONSTANT SAMPLE_RATE_DIV : INTEGER := 2000; -- 50MHz / 1000 = 50kHz sample rate

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

    ----------------------------------------------------------------
    -- Process to generate a 50kHz sampling trigger
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
                -- Latch the current ADC data
                adc_data0_reg <= ch0;
                adc_data1_reg <= x"234";
                -- Prepare to send the start byte 'S'
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