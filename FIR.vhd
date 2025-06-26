
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_signed.ALL;

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
  CONSTANT TAPS_COUNT : INTEGER := 51;

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

  TYPE tap_array_t IS ARRAY (0 TO TAPS_COUNT - 1) OF SIGNED(11 DOWNTO 0);
  SIGNAL taps : tap_array_t := (OTHERS => (OTHERS => '0'));

  SIGNAL sum : STD_LOGIC_VECTOR(27 DOWNTO 0) := (OTHERS => '0');

BEGIN
  -- Shifter
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

  -- MAC (Multiply Accumulate Unit)
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

  -- Rescale output
  data_out <= STD_LOGIC_VECTOR(resize(signed(sum(26 DOWNTO 15)), 12) + 2048);

END ARCHITECTURE rtl;