-- THIS SOURCE-CODE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED. IN NO  EVENT WILL THE AUTHOR BE HELD LIABLE FOR ANY DAMAGES ARISING FROM
-- THE USE OF THIS SOURCE-CODE. USE AT YOUR OWN RISK.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity dds is
  generic(
    twos_complement : boolean := true;
    data_width      : natural := 16;
    step_width      : natural := 3;
    lut_len         : natural := 255;  --period= (4*lut_len-4) / step * period(clock) 
    phase_offset    : natural := 0     -- steps= (4*lut_len-4)
    );
  port (
    clock    : in  std_ulogic;
    reset    : in  std_ulogic;
    step     : in  std_ulogic_vector(2 downto 0);
    enable   : in  std_ulogic;
    data_out : out std_ulogic_vector(data_width-1 downto 0)
    );
end dds;

architecture Behavioral of dds is

  function calc_bitwidth(x : natural) return natural is
  begin
    return integer(floor(log(real(x-1))/log(2.0))+1.0);
  end function;

  constant ADDR_WIDTH : natural := calc_bitwidth(lut_len);
  signal addr         : unsigned(ADDR_WIDTH+1 downto 0);
  signal lut_addr     : unsigned(ADDR_WIDTH-1 downto 0);

  type sine_lut_t is array (lut_len-1 downto 0) of std_ulogic_vector(data_width-1 downto 0);


  function real_to_std(x : real; width : natural) return std_ulogic_vector is
    variable ret : std_ulogic_vector(width-1 downto 0);
  begin
    ret := std_ulogic_vector(to_unsigned(integer((x * (2.0**real(width) - 1.0))), width));
    return ret;
  end real_to_std;

  function gen_sine_lut return sine_lut_t is
    variable sinelut : sine_lut_t;
  begin
    for iter in 0 to sinelut'length-1 loop
      sinelut(iter) := '0'&real_to_std(sin(real(iter)/(2.0*real(lut_len-1)) * MATH_PI), sinelut(iter)'length-1);
    end loop;
    return sinelut;
  end gen_sine_lut;

  constant SINE_LUT : sine_lut_t := gen_sine_lut;

  signal data : std_ulogic_vector(data_out'range);
  signal part : std_ulogic_vector(1 downto 0);

begin

  data_out <= data;


  myproc : process (clock, reset) is
  begin
    if reset = '0' then
      data      <= (others => '0');
      addr      <= to_unsigned(phase_offset, addr'length);
      lut_addr <= (others => '0');
      part       <= (others => '0');
    elsif rising_edge(clock) then
      if enable = '1' then

        case part is
          when "00" | "01"=>
            data <= SINE_LUT(to_integer(lut_addr));
            if not twos_complement then
              data(data'high) <= '1';
            end if;
          when others =>  -- "10" | "11"
            if not twos_complement then
              data            <= not SINE_LUT(to_integer(lut_addr));
              data(data'high) <= '0';
            else
              data <= std_ulogic_vector(to_signed(-1*to_integer(unsigned(SINE_LUT(to_integer(lut_addr)))), data'length));
            end if;
        end case;



        if addr <= lut_len-2 then
          part     <= "00";
          lut_addr <= resize(addr, lut_addr'length);
        elsif addr >= lut_len-1 and addr <= 2*lut_len-3 then
          part     <= "01";
          lut_addr <= resize(2*(lut_len-1) - addr, lut_addr'length);
        elsif addr >= 2*lut_len-2 and addr <= 3*lut_len-4 then
          part     <= "10";
          lut_addr <= resize(addr - 2*(lut_len-1), lut_addr'length);
        elsif addr >= 3*lut_len-3 and addr <= 4*lut_len-5 then
          part     <= "11";
          lut_addr <= resize(4*(lut_len-1) - addr, lut_addr'length);
        end if;


        if '0'&addr+unsigned(step) > lut_len*4-5 then
          addr <= (others => '0');
        else
          addr <= addr + unsigned(step);
        end if;
      end if;
    end if;
  end process myproc;
  
end Behavioral;
