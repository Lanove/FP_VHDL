-- FINAL VHDL CODE - COMPLETE PROJECT
-- Incorporates the user-specified "adc_ip" component.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

--------------------------------------------------------------------------------
-- Module: uart_tx
-- Notes: UART transmitter module.
--------------------------------------------------------------------------------
ENTITY uart_tx IS
    GENERIC (
        BIT_RATE     : INTEGER := 3000000; -- bits / sec
        CLK_HZ       : INTEGER := 50_000_000; -- Clock frequency in hertz
        PAYLOAD_BITS : INTEGER := 8;         -- Number of data bits
        STOP_BITS    : INTEGER := 1          -- Number of stop bits
    );
    PORT (
        clk          : IN  STD_LOGIC;
        resetn       : IN  STD_LOGIC;
        uart_txd     : OUT STD_LOGIC;
        uart_tx_busy : OUT STD_LOGIC;
        uart_tx_en   : IN  STD_LOGIC;
        uart_tx_data : IN  STD_LOGIC_VECTOR(PAYLOAD_BITS - 1 DOWNTO 0)
    );
END ENTITY uart_tx;

ARCHITECTURE rtl OF uart_tx IS

    -- Internal parameters
    CONSTANT CYCLES_PER_BIT : INTEGER := CLK_HZ / BIT_RATE;
    -- Determine the necessary width for the cycle counter
    FUNCTION clog2 (val: INTEGER) RETURN INTEGER IS
      VARIABLE temp: INTEGER := val;
      VARIABLE ret: INTEGER := 0;
    BEGIN
      WHILE (temp > 1) LOOP
        ret := ret + 1;
        temp := temp / 2;
      END LOOP;
      RETURN ret + 1;
    END FUNCTION clog2;
    CONSTANT COUNT_REG_LEN : INTEGER := clog2(CYCLES_PER_BIT);

    -- FSM state definition
    TYPE t_fsm_state IS (FSM_IDLE, FSM_START, FSM_SEND, FSM_STOP);
    SIGNAL fsm_state, n_fsm_state : t_fsm_state;

    -- Internal registers
    SIGNAL txd_reg       : STD_LOGIC;
    SIGNAL data_to_send  : STD_LOGIC_VECTOR(PAYLOAD_BITS - 1 DOWNTO 0);
    SIGNAL cycle_counter : UNSIGNED(COUNT_REG_LEN - 1 DOWNTO 0);
    SIGNAL bit_counter   : UNSIGNED(3 DOWNTO 0);

    -- Internal signals for state transitions
    SIGNAL next_bit     : STD_LOGIC;
    SIGNAL payload_done : STD_LOGIC;
    SIGNAL stop_done    : STD_LOGIC;

BEGIN
    uart_tx_busy <= '0' WHEN fsm_state = FSM_IDLE ELSE '1';
    uart_txd     <= txd_reg;

    next_bit     <= '1' WHEN cycle_counter = to_unsigned(CYCLES_PER_BIT - 1, COUNT_REG_LEN) ELSE '0';
    payload_done <= '1' WHEN bit_counter = PAYLOAD_BITS ELSE '0';
    stop_done    <= '1' WHEN (bit_counter = STOP_BITS) AND (fsm_state = FSM_STOP) ELSE '0';

    -- FSM next state logic
    p_n_fsm_state : PROCESS (fsm_state, uart_tx_en, next_bit, payload_done, stop_done)
    BEGIN
        CASE fsm_state IS
            WHEN FSM_IDLE =>
                IF uart_tx_en = '1' THEN
                    n_fsm_state <= FSM_START;
                ELSE
                    n_fsm_state <= FSM_IDLE;
                END IF;
            WHEN FSM_START =>
                IF next_bit = '1' THEN
                    n_fsm_state <= FSM_SEND;
                ELSE
                    n_fsm_state <= FSM_START;
                END IF;
            WHEN FSM_SEND =>
                IF payload_done = '1' THEN
                    n_fsm_state <= FSM_STOP;
                ELSE
                    n_fsm_state <= FSM_SEND;
                END IF;
            WHEN FSM_STOP =>
                IF stop_done = '1' THEN
                    n_fsm_state <= FSM_IDLE;
                ELSE
                    n_fsm_state <= FSM_STOP;
                END IF;
        END CASE;
    END PROCESS p_n_fsm_state;

    -- FSM state register
    p_fsm_state : PROCESS (clk, resetn)
    BEGIN
        IF resetn = '0' THEN
            fsm_state <= FSM_IDLE;
        ELSIF rising_edge(clk) THEN
            fsm_state <= n_fsm_state;
        END IF;
    END PROCESS p_fsm_state;

    -- Data register: Replicates the exact (and unusual) shift from the Verilog source
    p_data_to_send : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF fsm_state = FSM_IDLE AND uart_tx_en = '1' THEN
                data_to_send <= uart_tx_data;
            ELSIF fsm_state = FSM_SEND AND next_bit = '1' THEN
                FOR i IN 0 TO PAYLOAD_BITS - 2 LOOP
                    data_to_send(i) <= data_to_send(i + 1);
                END LOOP;
            END IF;
        END IF;
    END PROCESS p_data_to_send;

    -- Bit counter
    p_bit_counter : PROCESS (clk, resetn)
    BEGIN
        IF resetn = '0' THEN
            bit_counter <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            IF (fsm_state /= FSM_SEND AND fsm_state /= FSM_STOP) OR (fsm_state = FSM_SEND AND n_fsm_state = FSM_STOP) THEN
                bit_counter <= (OTHERS => '0');
            ELSIF (fsm_state = FSM_SEND OR fsm_state = FSM_STOP) AND next_bit = '1' THEN
                bit_counter <= bit_counter + 1;
            END IF;
        END IF;
    END PROCESS p_bit_counter;

    -- Cycle counter
    p_cycle_counter : PROCESS (clk, resetn)
    BEGIN
        IF resetn = '0' THEN
            cycle_counter <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            IF next_bit = '1' OR (fsm_state = FSM_IDLE) THEN
                cycle_counter <= (OTHERS => '0');
            ELSIF fsm_state = FSM_START OR fsm_state = FSM_SEND OR fsm_state = FSM_STOP THEN
                cycle_counter <= cycle_counter + 1;
            END IF;
        END IF;
    END PROCESS p_cycle_counter;

    -- TXD output register
    p_txd_reg : PROCESS (clk, resetn)
    BEGIN
        IF resetn = '0' THEN
            txd_reg <= '1';
        ELSIF rising_edge(clk) THEN
            IF fsm_state = FSM_IDLE OR fsm_state = FSM_STOP THEN
                txd_reg <= '1';
            ELSIF fsm_state = FSM_START THEN
                txd_reg <= '0';
            ELSIF fsm_state = FSM_SEND THEN
                txd_reg <= data_to_send(0);
            END IF;
        END IF;
    END PROCESS p_txd_reg;

END ARCHITECTURE rtl;

--------------------------------------------------------------------------------
-- Module: binary_to_bcd
-- Notes: Converts a 12-bit binary number to BCD using the Double Dabble algorithm.
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY binary_to_bcd IS
    PORT (
        binary    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
        thousands : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        hundreds  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        tens      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        ones      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY binary_to_bcd;

ARCHITECTURE rtl OF binary_to_bcd IS
BEGIN
    bcd_conversion_proc : PROCESS (binary)
        VARIABLE shift_reg : STD_LOGIC_VECTOR(27 DOWNTO 0);
    BEGIN
        shift_reg := (OTHERS => '0');
        shift_reg(11 DOWNTO 0) := binary;

        FOR i IN 0 TO 11 LOOP
            IF unsigned(shift_reg(15 DOWNTO 12)) >= 5 THEN
                shift_reg(15 DOWNTO 12) := std_logic_vector(unsigned(shift_reg(15 DOWNTO 12)) + 3);
            END IF;
            IF unsigned(shift_reg(19 DOWNTO 16)) >= 5 THEN
                shift_reg(19 DOWNTO 16) := std_logic_vector(unsigned(shift_reg(19 DOWNTO 16)) + 3);
            END IF;
            IF unsigned(shift_reg(23 DOWNTO 20)) >= 5 THEN
                shift_reg(23 DOWNTO 20) := std_logic_vector(unsigned(shift_reg(23 DOWNTO 20)) + 3);
            END IF;
            IF unsigned(shift_reg(27 DOWNTO 24)) >= 5 THEN
                shift_reg(27 DOWNTO 24) := std_logic_vector(unsigned(shift_reg(27 DOWNTO 24)) + 3);
            END IF;

            -- On the last iteration, don't shift
            IF i < 12 THEN
                shift_reg := shift_reg(26 DOWNTO 0) & '0';
            END IF;
        END LOOP;

        ones      <= shift_reg(15 DOWNTO 12);
        tens      <= shift_reg(19 DOWNTO 16);
        hundreds  <= shift_reg(23 DOWNTO 20);
        thousands <= shift_reg(27 DOWNTO 24);
    END PROCESS bcd_conversion_proc;
END ARCHITECTURE rtl;


--------------------------------------------------------------------------------
-- Module: fir_filter
-- Notes: A 31-tap FIR filter.
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_signed.ALL;

ENTITY fir_filter IS
    PORT (
        clk           : IN  STD_LOGIC;
        reset_n       : IN  STD_LOGIC;
        sample_enable : IN  STD_LOGIC;
        data_in       : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
        data_out      : OUT SIGNED(11 DOWNTO 0)
    );
END ENTITY fir_filter;

ARCHITECTURE rtl OF fir_filter IS
    CONSTANT taps        : INTEGER := 31;
    CONSTANT input_size  : INTEGER := 12;
    CONSTANT output_size : INTEGER := 49;

    -- FIR coefficients
    CONSTANT h0  : SIGNED(31 DOWNTO 0) := "11111111110111111111110111111111"; -- xFFDFFDFF
    CONSTANT h1  : SIGNED(31 DOWNTO 0) := "11111111100111010101011101001111"; -- xFF9D574F
    CONSTANT h2  : SIGNED(31 DOWNTO 0) := "11111111010110000000110010000011"; -- xFF580C83
    CONSTANT h3  : SIGNED(31 DOWNTO 0) := "11111111000100010011101111110011"; -- xFF113BF3
    CONSTANT h4  : SIGNED(31 DOWNTO 0) := "11111110110010100001001101110111"; -- xFECA1377
    CONSTANT h5  : SIGNED(31 DOWNTO 0) := "11111110100000111100101000011111"; -- xFE83CA1F
    CONSTANT h6  : SIGNED(31 DOWNTO 0) := "11111110001111111001100110100010"; -- xFE3F99A2
    CONSTANT h7  : SIGNED(31 DOWNTO 0) := "11111101111111101011011110100100"; -- xFDFEB7A4
    CONSTANT h8  : SIGNED(31 DOWNTO 0) := "11111101110000100100111100001100"; -- xFDC24F0C
    CONSTANT h9  : SIGNED(31 DOWNTO 0) := "11111101100010110111100101110110"; -- xFD8B7976
    CONSTANT h10 : SIGNED(31 DOWNTO 0) := "11111101010110110011100100001101"; -- xFD5B390D
    CONSTANT h11 : SIGNED(31 DOWNTO 0) := "11111101001100100111001011010001"; -- xFD3272D1
    CONSTANT h12 : SIGNED(31 DOWNTO 0) := "11111101000100011110100110001001"; -- xFD11E989
    CONSTANT h13 : SIGNED(31 DOWNTO 0) := "11111100111110100011100101100100"; -- xFCFA3964
    CONSTANT h14 : SIGNED(31 DOWNTO 0) := "11111100111010111101010010000110"; -- xFCEBD486
    CONSTANT h15 : SIGNED(31 DOWNTO 0) := "01111100111001111000011000100000"; -- x7CE78620
    CONSTANT h16 : SIGNED(31 DOWNTO 0) := h14;
    CONSTANT h17 : SIGNED(31 DOWNTO 0) := h13;
    CONSTANT h18 : SIGNED(31 DOWNTO 0) := h12;
    CONSTANT h19 : SIGNED(31 DOWNTO 0) := h11;
    CONSTANT h20 : SIGNED(31 DOWNTO 0) := h10;
    CONSTANT h21 : SIGNED(31 DOWNTO 0) := h9;
    CONSTANT h22 : SIGNED(31 DOWNTO 0) := h8;
    CONSTANT h23 : SIGNED(31 DOWNTO 0) := h7;
    CONSTANT h24 : SIGNED(31 DOWNTO 0) := h6;
    CONSTANT h25 : SIGNED(31 DOWNTO 0) := h5;
    CONSTANT h26 : SIGNED(31 DOWNTO 0) := h4;
    CONSTANT h27 : SIGNED(31 DOWNTO 0) := h3;
    CONSTANT h28 : SIGNED(31 DOWNTO 0) := h2;
    CONSTANT h29 : SIGNED(31 DOWNTO 0) := h1;
    CONSTANT h30 : SIGNED(31 DOWNTO 0) := h0;

    -- Delay line array to store signed values
    TYPE t_fir_array IS ARRAY (1 TO taps - 1) OF SIGNED(input_size - 1 DOWNTO 0);
    SIGNAL FIR : t_fir_array;

    SIGNAL data_in_signed : SIGNED(11 DOWNTO 0);
    SIGNAL mac_result     : SIGNED(output_size - 1 DOWNTO 0);

BEGIN
    -- Convert input to signed by subtracting offset
    data_in_signed <= signed(data_in) - to_signed(2048, 12);

    -- Combinational MAC operation.
    -- Each product is resized to the full output width before summation to mimic Verilog's behavior.
    mac_result <= resize(h0 * data_in_signed, output_size) +
                  resize(h1 * FIR(1) , output_size) + resize(h2  * FIR(2) , output_size) +
                  resize(h3 * FIR(3) , output_size) + resize(h4  * FIR(4) , output_size) +
                  resize(h5 * FIR(5) , output_size) + resize(h6  * FIR(6) , output_size) +
                  resize(h7 * FIR(7) , output_size) + resize(h8  * FIR(8) , output_size) +
                  resize(h9 * FIR(9) , output_size) + resize(h10 * FIR(10), output_size) +
                  resize(h11* FIR(11), output_size) + resize(h12 * FIR(12), output_size) +
                  resize(h13* FIR(13), output_size) + resize(h14 * FIR(14), output_size) +
                  resize(h15* FIR(15), output_size) + resize(h16 * FIR(16), output_size) +
                  resize(h17* FIR(17), output_size) + resize(h18 * FIR(18), output_size) +
                  resize(h19* FIR(19), output_size) + resize(h20 * FIR(20), output_size) +
                  resize(h21* FIR(21), output_size) + resize(h22 * FIR(22), output_size) +
                  resize(h23* FIR(23), output_size) + resize(h24 * FIR(24), output_size) +
                  resize(h25* FIR(25), output_size) + resize(h26 * FIR(26), output_size) +
                  resize(h27* FIR(27), output_size) + resize(h28 * FIR(28), output_size) +
                  resize(h29* FIR(29), output_size) + resize(h30 * FIR(30), output_size);

    -- Scale down by 2^31 (by taking upper bits) and add back offset
    data_out <= resize(mac_result(42 DOWNTO 31), 12) + to_signed(2048, 12);

    -- Delay line shift register
    fir_shift_proc : PROCESS (clk, reset_n)
    BEGIN
        IF reset_n = '0' THEN
            FIR <= (OTHERS => (OTHERS => '0'));
        ELSIF rising_edge(clk) THEN
            IF sample_enable = '1' THEN
                FIR(1) <= data_in_signed;
                FOR i IN 2 TO taps - 1 LOOP
                    FIR(i) <= FIR(i - 1);
                END LOOP;
            END IF;
        END IF;
    END PROCESS fir_shift_proc;

END ARCHITECTURE rtl;

--------------------------------------------------------------------------------
-- Module: FP (Top Level)
-- Notes: Main module for ADC sampling, filtering, UART transmission, and display.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY FP_VHDL IS
    PORT (
        clk     : IN  STD_LOGIC;
        reset_n : IN  STD_LOGIC;
        ledr    : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        hex0    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex1    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex2    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        hex3    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        uart_txd: OUT STD_LOGIC
    );
END ENTITY FP_VHDL;

ARCHITECTURE rtl OF FP_VHDL IS
    -- Component Declarations
    
    -- === CHANGE 1: Use the component name from your IP template ===
    COMPONENT adc_ip IS
        PORT (
            CLOCK : IN  STD_LOGIC;
            RESET : IN  STD_LOGIC;
            CH0   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            CH1   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            CH2   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            CH3   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            CH4   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            CH5   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            CH6   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
            CH7   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
        );
    END COMPONENT adc_ip;

    -- Re-use component definitions from above
    COMPONENT fir_filter IS
        PORT (
            clk           : IN  STD_LOGIC;
            reset_n       : IN  STD_LOGIC;
            sample_enable : IN  STD_LOGIC;
            data_in       : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
            data_out      : OUT SIGNED(11 DOWNTO 0)
        );
    END COMPONENT fir_filter;

    COMPONENT uart_tx IS
        GENERIC (
            BIT_RATE     : INTEGER;
            CLK_HZ       : INTEGER;
            PAYLOAD_BITS : INTEGER;
            STOP_BITS    : INTEGER
        );
        PORT (
            clk          : IN  STD_LOGIC;
            resetn       : IN  STD_LOGIC;
            uart_txd     : OUT STD_LOGIC;
            uart_tx_busy : OUT STD_LOGIC;
            uart_tx_en   : IN  STD_LOGIC;
            uart_tx_data : IN  STD_LOGIC_VECTOR(PAYLOAD_BITS - 1 DOWNTO 0)
        );
    END COMPONENT uart_tx;

    COMPONENT binary_to_bcd IS
        PORT (
            binary    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
            thousands : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            hundreds  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            tens      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            ones      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
        );
    END COMPONENT binary_to_bcd;

    -- Constants
    CONSTANT SAMPLE_RATE_DIV : INTEGER := 1000;
    CONSTANT DECIMATION_DIV  : INTEGER := 2;

    -- ADC Signals
    SIGNAL ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7 : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL reset_pos : STD_LOGIC;

    -- Sampling and Decimation Signals
    SIGNAL sample_counter     : UNSIGNED(9 DOWNTO 0);
    SIGNAL sample_enable      : STD_LOGIC;
    SIGNAL decimation_counter : UNSIGNED(9 DOWNTO 0);
    SIGNAL decimation_enable  : STD_LOGIC;

    -- FIR Filter Signals
    SIGNAL filtered_data : SIGNED(11 DOWNTO 0);
    SIGNAL sampled_adc   : STD_LOGIC_VECTOR(11 DOWNTO 0);

    -- UART Signals
    SIGNAL uart_tx_data : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL uart_tx_en   : STD_LOGIC;
    SIGNAL uart_tx_busy : STD_LOGIC;

    -- UART Transmission State Machine
    TYPE t_tx_state IS (TX_IDLE, TX_HEADER1, TX_HEADER2, TX_RAW_H, TX_RAW_L, TX_FILT_H, TX_FILT_L);
    SIGNAL tx_state  : t_tx_state;
    SIGNAL tx_buffer : STD_LOGIC_VECTOR(47 DOWNTO 0);

    -- BCD Conversion Signals
    SIGNAL thousands, hundreds, tens, ones : STD_LOGIC_VECTOR(3 DOWNTO 0);

    -- Seven Segment Decoder Function
    FUNCTION seven_seg_decode (digit : STD_LOGIC_VECTOR(3 DOWNTO 0)) RETURN STD_LOGIC_VECTOR IS
    BEGIN
        CASE digit IS
            WHEN x"0"   => RETURN "1000000"; -- 0
            WHEN x"1"   => RETURN "1111001"; -- 1
            WHEN x"2"   => RETURN "0100100"; -- 2
            WHEN x"3"   => RETURN "0110000"; -- 3
            WHEN x"4"   => RETURN "0011001"; -- 4
            WHEN x"5"   => RETURN "0010010"; -- 5
            WHEN x"6"   => RETURN "0000010"; -- 6
            WHEN x"7"   => RETURN "1111000"; -- 7
            WHEN x"8"   => RETURN "0000000"; -- 8
            WHEN x"9"   => RETURN "0010000"; -- 9
            WHEN OTHERS => RETURN "1111111"; -- blank
        END CASE;
    END FUNCTION seven_seg_decode;

BEGIN
    -- Invert reset for ADC (since IP takes active-high RESET)
    reset_pos <= NOT reset_n;

    -- === CHANGE 2: Instantiate your IP component "adc_ip" ===
    adc_inst : adc_ip
        PORT MAP(
            CLOCK => clk,
            RESET => reset_pos,
            CH0   => ch0,
            CH1   => ch1,
            CH2   => ch2,
            CH3   => ch3,
            CH4   => ch4,
            CH5   => ch5,
            CH6   => ch6,
            CH7   => ch7
        );

    -- Instantiate FIR filter
    fir_inst : fir_filter
        PORT MAP(
            clk           => clk,
            reset_n       => reset_n,
            sample_enable => sample_enable,
            data_in       => sampled_adc,
            data_out      => filtered_data
        );

    -- Instantiate UART TX
    uart_tx_inst : uart_tx
        GENERIC MAP(
            BIT_RATE     => 3000000,
            CLK_HZ       => 50000000,
            PAYLOAD_BITS => 8,
            STOP_BITS    => 1
        )
        PORT MAP(
            clk          => clk,
            resetn       => reset_n,
            uart_txd     => uart_txd,
            uart_tx_busy => uart_tx_busy,
            uart_tx_en   => uart_tx_en,
            uart_tx_data => uart_tx_data
        );

    -- Instantiate Binary to BCD converter
    bcd_converter : binary_to_bcd
        PORT MAP(
            binary    => sampled_adc,
            thousands => thousands,
            hundreds  => hundreds,
            tens      => tens,
            ones      => ones
        );

    -- 50kHz sampling clock generator
    sample_gen_proc : PROCESS (clk, reset_n)
    BEGIN
        IF reset_n = '0' THEN
            sample_counter <= (OTHERS => '0');
            sample_enable  <= '0';
        ELSIF rising_edge(clk) THEN
            IF sample_counter = to_unsigned(SAMPLE_RATE_DIV - 1, 10) THEN
                sample_counter <= (OTHERS => '0');
                sample_enable  <= '1';
            ELSE
                sample_counter <= sample_counter + 1;
                sample_enable  <= '0';
            END IF;
        END IF;
    END PROCESS sample_gen_proc;

    -- Decimator (25kHz enable generator)
    decimation_proc : PROCESS (clk, reset_n)
    BEGIN
        IF reset_n = '0' THEN
            decimation_counter <= (OTHERS => '0');
            decimation_enable  <= '0';
        ELSIF rising_edge(clk) THEN
            decimation_enable <= '0'; -- Default value
            IF sample_enable = '1' THEN
                IF decimation_counter = to_unsigned(DECIMATION_DIV - 1, 10) THEN
                    decimation_counter <= (OTHERS => '0');
                    decimation_enable  <= '1';
                ELSE
                    decimation_counter <= decimation_counter + 1;
                    decimation_enable  <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS decimation_proc;

    -- Sample ADC data
    sample_adc_proc : PROCESS (clk, reset_n)
    BEGIN
        IF reset_n = '0' THEN
            sampled_adc <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            IF sample_enable = '1' THEN
                sampled_adc <= ch0;
            END IF;
        END IF;
    END PROCESS sample_adc_proc;

    -- UART transmission state machine
    uart_fsm_proc : PROCESS (clk, reset_n)
    BEGIN
        IF reset_n = '0' THEN
            tx_state     <= TX_IDLE;
            uart_tx_en   <= '0';
            uart_tx_data <= (OTHERS => '0');
            tx_buffer    <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            -- Default assignments
            uart_tx_en <= '0';

            CASE tx_state IS
                WHEN TX_IDLE =>
                    IF decimation_enable = '1' THEN
                        -- Prepare 6-byte packet: [0xAE][0xAE][RAW_H][RAW_L][FILT_H][FILT_L]
                        tx_buffer <= x"AEAE" & "0000" & sampled_adc & "0000" & std_logic_vector(filtered_data);
                        tx_state  <= TX_HEADER1;
                    END IF;

                WHEN TX_HEADER1 =>
                    IF uart_tx_busy = '0' THEN
                        uart_tx_data <= tx_buffer(47 DOWNTO 40);
                        uart_tx_en   <= '1';
                        tx_state     <= TX_HEADER2;
                    END IF;

                WHEN TX_HEADER2 =>
                    IF uart_tx_busy = '0' THEN
                        uart_tx_data <= tx_buffer(39 DOWNTO 32);
                        uart_tx_en   <= '1';
                        tx_state     <= TX_RAW_H;
                    END IF;

                WHEN TX_RAW_H =>
                    IF uart_tx_busy = '0' THEN
                        uart_tx_data <= tx_buffer(31 DOWNTO 24);
                        uart_tx_en   <= '1';
                        tx_state     <= TX_RAW_L;
                    END IF;

                WHEN TX_RAW_L =>
                    IF uart_tx_busy = '0' THEN
                        uart_tx_data <= tx_buffer(23 DOWNTO 16);
                        uart_tx_en   <= '1';
                        tx_state     <= TX_FILT_H;
                    END IF;

                WHEN TX_FILT_H =>
                    IF uart_tx_busy = '0' THEN
                        uart_tx_data <= tx_buffer(15 DOWNTO 8);
                        uart_tx_en   <= '1';
                        tx_state     <= TX_FILT_L;
                    END IF;

                WHEN TX_FILT_L =>
                    IF uart_tx_busy = '0' THEN
                        uart_tx_data <= tx_buffer(7 DOWNTO 0);
                        uart_tx_en   <= '1';
                        tx_state     <= TX_IDLE;
                    END IF;

            END CASE;
        END IF;
    END PROCESS uart_fsm_proc;

    -- Display sampled ADC value on LEDs
    ledr <= sampled_adc(9 DOWNTO 0);

    -- Seven segment display assignment
    hex0 <= seven_seg_decode(ones);
    hex1 <= seven_seg_decode(tens);
    hex2 <= seven_seg_decode(hundreds);
    hex3 <= seven_seg_decode(thousands);

END ARCHITECTURE rtl;