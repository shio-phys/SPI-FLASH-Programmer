--------------------------------------------------------------------------------
--! @file   SPI_CommandSender.vhd
--! @brief  Send command to SPI FLASH and receive data from SPI FLASH
--! @author Takehiro Shiozaki
--! @date   2014-06-24
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity SPI_CommandSender is
    port(
        CLK : in std_logic;
        RESET : in std_logic;

        START : in std_logic;
        BUSY : out std_logic;
        LENGTH : in std_logic_vector(12 downto 0);

        WE : out std_logic;
        DOUT : out std_logic_vector(7 downto 0);
        WADDR : out std_logic_vector(12 downto 0);

        DIN : in std_logic_vector(7 downto 0);
        RADDR : out std_logic_vector(8 downto 0);

        SPI_SCLK : out std_logic;
        SPI_SS_N : out std_logic;
        SPI_MOSI : out std_logic;
        SPI_MISO : in std_logic
    );
end SPI_CommandSender;

architecture RTL of SPI_CommandSender is
    component SPI_IF is
        port(
            CLK : in std_logic;
            RESET : in std_logic;

            DIN : in std_logic_vector(7 downto 0);
            DOUT : out std_logic_vector(7 downto 0);
            START : in std_logic;
            BUSY : out std_logic;

            SPI_SCLK : out std_logic;
            SPI_MISO : in std_logic;
            SPI_MOSI : out std_logic
        );
    end component;

    signal int_WADDR : std_logic_vector(12 downto 0);
    signal WaddrCountUp : std_logic;
    signal WaddrCountClear : std_logic;

    signal int_RADDR : std_logic_vector(8 downto 0);
    signal RaddrCountUp : std_logic;
    signal RaddrCountClear : std_logic;

    signal LengthReg : std_logic_vector(12 downto 0);
    signal LengthRegCountDown : std_logic;

    signal StartIf : std_logic;
    signal BusyIf : std_logic;

    signal SpiSSNPre : std_logic;

    type State is (IDLE, START_IF, WAIT_BUSY, WRITE_DATA);
    signal CurrentState, NextState : State;
begin
    SPI_IF_0: SPI_IF
    port map(
        CLK => CLK,
        RESET => RESET,
        DIN => DIN,
        DOUT => DOUT,
        START => StartIf,
        BUSY => BusyIf,
        SPI_SCLK => SPI_SCLK,
        SPI_MISO => SPI_MISO,
        SPI_MOSI => SPI_MOSI
    );

    process(CLK)
    begin
        if(CLK'event and CLK = '1') then
            if(WaddrCountClear = '1') then
                int_WADDR <= (others => '0');
            elsif(WaddrCountUp = '1') then
                int_WADDR <= int_WADDR + 1;
            end if;
        end if;
    end process;
    WADDR <= int_WADDR;

    process(CLK)
    begin
        if(CLK'event and CLK = '1') then
            if(RaddrCountClear = '1') then
                int_RADDR <= (others => '0');
            elsif(RaddrCountUp = '1') then
                int_RADDR <= int_RADDR + 1;
            end if;
        end if;
    end process;
    RADDR <= int_RADDR;

    process(CLK)
    begin
        if(CLK'event and CLK = '1') then
            if(START = '1') then
                LengthReg <= LENGTH;
            elsif(LengthRegCountDown = '1') then
                LengthReg <= LengthReg - 1;
            end if;
        end if;
    end process;

    process(CLK)
    begin
        if(CLK'event and CLK = '1') then
            if(RESET = '1') then
                CurrentState <= IDLE;
            else
                CurrentState <= NextState;
            end if;
        end if;
    end process;

    process(CurrentState, START, BusyIf, LengthReg)
    begin
        case CurrentState is
            when IDLE =>
                if(START = '1') then
                    NextState <= START_IF;
                else
                    NextState <= CurrentState;
                end if;
            when START_IF =>
                NextState <= WAIT_BUSY;
            when WAIT_BUSY =>
                if(BusyIf = '1') then
                    NextState <= CurrentState;
                else
                    NextState <= WRITE_DATA;
                end if;
            when WRITE_DATA =>
                if(LengthReg = 0) then
                    NextState <= IDLE;
                else
                    NextState <= START_IF;
                end if;
        end case;
    end process;

    WaddrCountUp <= '1' when(CurrentState = WRITE_DATA) else
                    '0';
    WaddrCountClear <= '1' when(CurrentState = IDLE) else
                       '0';
    RaddrCountUp <= '1' when(CurrentState = START_IF) else
                    '0';
    RaddrCountClear <= '1' when(CurrentState = IDLE) else
                       '0';
    LengthRegCountDown <= '1' when(CurrentState = WRITE_DATA) else
                          '0';
    StartIf <= '1' when(CurrentState = START_IF) else
               '0';

    SpiSSNPre <= '1' when(CurrentState = IDLE) else
                '0';
    WE <= '1' when(CurrentState = WRITE_DATA) else
          '0';
    BUSY <= '0' when(CurrentState = IDLE) else
            '1';

    process(CLK)
    begin
        if(CLK'event and CLK = '1') then
            SPI_SS_N <= SpiSSNPre;
        end if;
    end process;

end RTL;
