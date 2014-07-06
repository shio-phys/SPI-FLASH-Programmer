--------------------------------------------------------------------------------
--! @file   SPI_FLASH_Programmer.vhd
--! @brief  Program SPI FLASH via RBCP bus
--! @author Takehiro Shiozaki
--! @date   2014-06-26
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity SPI_FLASH_Programmer is
    generic(
        G_SPI_FLASH_PROGRAMMER_ADDRESS : std_logic_vector(31 downto 0)
            := (others => '0')
    );
    port(
        SPI_CLK : in std_logic;
        SITCP_CLK : in std_logic;
        RESET : in std_logic;

        RBCP_ACT : in std_logic;
        RBCP_ADDR : in std_logic_vector(31 downto 0);
        RBCP_WE : in std_logic;
        RBCP_WD : in std_logic_vector(7 downto 0);
        RBCP_RE : in std_logic;
        RBCP_RD : out std_logic_vector(7 downto 0);
        RBCP_ACK : out std_logic;

        SPI_SCLK : out std_logic;
        SPI_SS_N : out std_logic;
        SPI_MOSI : out std_logic;
        SPI_MISO : in std_logic
    );
end SPI_FLASH_Programmer;

architecture RTL of SPI_FLASH_Programmer is
    component SPI_CommandSender is
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
    end component;

    component RBCP_Sender is
        generic(
            G_ADDR : std_logic_vector(31 downto 0);
            G_LEN : integer;
            G_ADDR_WIDTH : integer
        );
        port(
            CLK : in  std_logic;
            RESET : in  std_logic;

            -- RBCP interface
            RBCP_ACT : in std_logic;
            RBCP_ADDR : in std_logic_vector(31 downto 0);
            RBCP_RE : in std_logic;
            RBCP_RD : out std_logic_vector(7 downto 0);
            RBCP_ACK : out std_logic;

            -- SRAM interface
            ADDR : out std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
            RD : in std_logic_vector(7 downto 0)
        );
    end component;

    component RBCP_Receiver is
        generic(
            G_ADDR : std_logic_vector(31 downto 0);
            G_LEN : integer;
            G_ADDR_WIDTH : integer
        );
        port(
            CLK : in std_logic;
            RESET : in std_logic;

            -- RBCP interface
            RBCP_ACT : in std_logic;
            RBCP_ADDR : in std_logic_vector(31 downto 0);
            RBCP_WE : in std_logic;
            RBCP_WD : in std_logic_vector(7 downto 0);
            RBCP_ACK : out std_logic;

            -- output
            ADDR : out std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
            WE : out std_logic;
            WD : out std_logic_vector(7 downto 0)
        );
    end component;

    component DualPortRam is
        generic(
            G_WIDTH : integer;
            G_DEPTH : integer
        );
        port(
            -- write
            WCLK : in  std_logic;
            DIN : in std_logic_vector(G_WIDTH - 1 downto 0);
            WADDR : in std_logic_vector(G_DEPTH - 1 downto 0);
            WE : in std_logic;

            -- read
            RCLK : in std_logic;
            DOUT : out std_logic_vector(G_WIDTH - 1 downto 0);
            RADDR : in std_logic_vector(G_DEPTH - 1 downto 0)
        );
    end component;

    component Synchronizer is
        port(
            CLK : in  std_logic;
            RESET : in  std_logic;
            DIN : in std_logic;
            DOUT : out std_logic
        );
    end component;

    component SynchEdgeDetector is
        port(
            CLK : in  std_logic;
            RESET : in  std_logic;
            DIN : in  std_logic;
            DOUT : out  std_logic
        );
    end component;

    component SynchronizerNbit is
        generic(
            G_BITS : integer
        );
        port(
            CLK : in  std_logic;
            RESET : in  std_logic;
            DIN : in std_logic_vector(G_BITS - 1 downto 0);
            DOUT : out std_logic_vector(G_BITS - 1 downto 0)
        );
    end component;

    signal CommandSenderStart : std_logic;
    signal CommandSenderBusy : std_logic;
    signal CommandSenderLength : std_logic_vector(12 downto 0);

    signal WriteBufDout : std_logic_vector(7 downto 0);
    signal WriteBufRaddr : std_logic_vector(8 downto 0);
    signal WriteBufDin : std_logic_vector(7 downto 0);
    signal WriteBufWaddr : std_logic_vector(8 downto 0);
    signal WriteBufWe : std_logic;

    signal ReadBufDout : std_logic_vector(7 downto 0);
    signal ReadBufRaddr : std_logic_vector(12 downto 0);
    signal ReadBufDin : std_logic_vector(7 downto 0);
    signal ReadBufWaddr : std_logic_vector(12 downto 0);
    signal ReadBufWe : std_logic;

    signal RbcpRdSender : std_logic_vector(7 downto 0);
    signal RbcpRdStatusRegister : std_logic_vector(7 downto 0);
    signal RbcpAckSender : std_logic;
    signal RbcpAckReceiver : std_logic;
    signal RbcpAckWriteStatusRegister : std_logic;
    signal RbcpAckReadStatusRegister : std_logic;
    signal RbcpAckLength : std_logic;

    signal RbcpAddressLength : std_logic_vector(0 downto 0);
    signal RbcpWeLength : std_logic;
    signal RbcpWdLength : std_logic_vector(7 downto 0);

    signal CommandSenderStartPre : std_logic;
    signal SynchCommandSenderBusy : std_logic;
    signal RbcpAckReadStatusRegisterPre : std_logic;

    signal LengthReg : std_logic_vector(12 downto 0);
begin
    SPI_CommandSender_0: SPI_CommandSender
    port map(
        CLK => SPI_CLK,
        RESET => RESET,
        START => CommandSenderStart,
        BUSY => CommandSenderBusy,
        LENGTH => CommandSenderLength,
        WE => ReadBufWe,
        DOUT => ReadBufDin,
        WADDR => ReadBufWaddr,
        DIN => WriteBufDout,
        RADDR => WriteBufRaddr,
        SPI_SCLK => SPI_SCLK,
        SPI_SS_N => SPI_SS_N,
        SPI_MOSI => SPI_MOSI,
        SPI_MISO => SPI_MISO
    );

    RBCP_Sender_0: RBCP_Sender
    generic map(
        G_ADDR => G_SPI_FLASH_PROGRAMMER_ADDRESS + 3,
        G_LEN => 8192,
        G_ADDR_WIDTH => 13
    )
    port map(
        CLK => SITCP_CLK,
        RESET => RESET,
        RBCP_ACT => RBCP_ACT,
        RBCP_ADDR => RBCP_ADDR,
        RBCP_RE => RBCP_RE,
        RBCP_RD => RbcpRdSender,
        RBCP_ACK => RbcpAckSender,
        ADDR => ReadBufRaddr,
        RD => ReadBufDout
    );

    RBCP_Receiver_0: RBCP_Receiver
    generic map(
        G_ADDR => G_SPI_FLASH_PROGRAMMER_ADDRESS + 3,
        G_LEN => 512,
        G_ADDR_WIDTH => 9
    )
    port map(
        CLK => SITCP_CLK,
        RESET => RESET,
        RBCP_ACT => RBCP_ACT,
        RBCP_ADDR => RBCP_ADDR,
        RBCP_WE => RBCP_WE,
        RBCP_WD => RBCP_WD,
        RBCP_ACK => RbcpAckReceiver,
        ADDR => WriteBufWaddr,
        WE => WriteBufWe,
        WD => WriteBufDin
    );

    ReadBuf: DualPortRam
    generic map(
        G_WIDTH => 8,
        G_DEPTH => 13
    )
    port map(
        WCLK => SPI_CLK,
        DIN => ReadBufDin,
        WADDR => ReadBufWaddr,
        WE => ReadBufWe,
        RCLK => SITCP_CLK,
        DOUT => ReadBufDout,
        RADDR => ReadBufRaddr
    );

    WriteBuf: DualPortRam
    generic map(
        G_WIDTH => 8,
        G_DEPTH => 9
    )
    port map(
        WCLK => SITCP_CLK,
        DIN => WriteBufDin,
        WADDR => WriteBufWaddr,
        WE => WriteBufWe,
        RCLK => SPI_CLK,
        DOUT => WriteBufDout,
        RADDR => WriteBufRaddr
    );

    CommandSenderStartPre <= '1' when(RBCP_ACT = '1' and RBCP_WE = '1' and
                                      RBCP_WD = X"00" and
                                      RBCP_ADDR = G_SPI_FLASH_PROGRAMMER_ADDRESS) else
                             '0';
    process(SITCP_CLK)
    begin
        if(SITCP_CLK'event and SITCP_CLK = '1') then
            RbcpAckWriteStatusRegister <= CommandSenderStartPre;
        end if;
    end process;

    SynchEdgeDetector_CommandSenderStart: SynchEdgeDetector
    port map(
        CLK => SPI_CLK,
        RESET => RESET,
        DIN => CommandSenderStartPre,
        DOUT => CommandSenderStart
    );

    Synchronizer_CommandSenderBusy: Synchronizer
    port map(
        CLK => SITCP_CLK,
        RESET => RESET,
        DIN => CommandSenderBusy,
        DOUT => SynchCommandSenderBusy
    );

    RbcpRdStatusRegister <= "0000000" & SynchCommandSenderBusy;

    RbcpAckReadStatusRegisterPre <= '1' when(RBCP_ACT = '1' and RBCP_RE = '1' and
                                             RBCP_ADDR = G_SPI_FLASH_PROGRAMMER_ADDRESS) else
                          '0';
    process(SITCP_CLK)
    begin
        if(SITCP_CLK'event and SITCP_CLK = '1') then
            RbcpAckReadStatusRegister <= RbcpAckReadStatusRegisterPre;
        end if;
    end process;

    RBCP_Receiver_Length: RBCP_Receiver
    generic map(
        G_ADDR => G_SPI_FLASH_PROGRAMMER_ADDRESS + 1,
        G_LEN => 2,
        G_ADDR_WIDTH => 1
    )
    port map(
        CLK => SITCP_CLK,
        RESET => RESET,
        RBCP_ACT => RBCP_ACT,
        RBCP_ADDR => RBCP_ADDR,
        RBCP_WE => RBCP_WE,
        RBCP_WD => RBCP_WD,
        RBCP_ACK => RbcpAckLength,
        ADDR => RbcpAddressLength,
        WE => RbcpWeLength,
        WD => RbcpWdLength
    );

    process(SITCP_CLK)
    begin
        if(SITCP_CLK'event and SITCP_CLK = '1') then
            if(RbcpWeLength = '1') then
                if(RbcpAddressLength(0) = '0') then
                    LengthReg(12 downto 8) <= RbcpWdLength(4 downto 0);
                else
                    LengthReg(7 downto 0) <= RbcpWdLength;
                end if;
            end if;
        end if;
    end process;

    SynchronizerNbit_Length: SynchronizerNbit
    generic map(
        G_BITS => 13
    )
    port map(
        CLK => SPI_CLK,
        RESET => RESET,
        DIN => LengthReg,
        DOUT => CommandSenderLength
    );

    RBCP_RD <= RbcpRdSender when(RbcpAckSender = '1') else
               RbcpRdStatusRegister;

    RBCP_ACK <= RbcpAckReceiver or RbcpAckSender or
                RbcpAckWriteStatusRegister or RbcpAckReadStatusRegister or
                RbcpAckLength;
end RTL;
