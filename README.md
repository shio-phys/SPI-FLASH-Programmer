SPI-FLASH-Programmer
======================
SiTCPを利用してFPGAのSPI FLASHのリモート書き込みをします。
このモジュールはFPGAにインプリメントするファームウェアとPC上でmcsファイルを転送するrubyプログラムの2つからなります。
Xilinxダウンロードケーブルを使用するよりも高速に書き込みが行えます。

FPGA側のファームウェアはRBCPバスからの信号を内部バッファに書き込み、RBCPバスの特定のアドレスに特定の値を書き込んだイベントを検知して、それを転送スタート信号として、SPI通信を行います。
SPI通信で受信したデータは別の内部バッファに書き込まれRBCP通信を使って読み出すことが出来ます。

PC側のrubyスクリプトはmcsファイルをデコードし、UDP通信を使用してRBCPバスと通信を行います。
SPI FLASHに送るコマンド・アドレス・データの管理は主にrubyが行っています。
SPI FLASH情報はYAMLファイルに格納されているため、互換性のあるSPI FLASHであればYAMLファイルに追記することで対応させることができます。


要件
----
### FPGA

+ Artix 7 シリーズFPGA

(デバイスに依存する書き方はしていないので他のFPGAでも対応可能なはず)

+ 以下のSPI FLASH

M25P32, M25P64, M25P128, N25Q032, N25Q064, N25Q128, N25Q256,
W25Q32BV, W25Q64BV, W25Q128BV, W25Q80BW, W25Q64FV, W25Q128FV, W25Q32DW, W25Q64DW

これ以外のデバイスも互換性のあるものであれば、デバイス定義ファイルを更新することで対応することが出来ます。

### PC

+ Cygwin or Linux

Windowsにもそのうち対応予定

+ Ruby >= 2.1.0

Scientific LinuxにインストールされているRubyは古いので[Ruby][Ruby]からインストールすることをお勧めします。
[Ruby]: https://www.ruby-lang.org/


使い方
------
### 回路
![回路図](https://raw.githubusercontent.com/wiki/shio-phys/SPI-FLASH-Programmer/image/circuit.png)

基本的には[Using SPI Flash with 7 Series FPGAs][XAPP586]を参考に接続してください。
7シリーズからCCLKをGPIOとして使用することが出来なくなっているので、他のGPIOをSPI FLASHのクロック入力ピンと接続してください(USER_CLK)。
コンフィグ後のCCLKをフローティングにすることでCCLKとUSER_CLKの衝突を防ぐことが出来ます。

### FPGA

fpgaディレクトリ内のVHDLファイルをプロジェクトに追加し、SPI-FLASH-Programmerをインスタンシエートしてください。

#### ポート

各ポートは次のように接続してください。

| ポート名   | 方向 | ビット幅 |                                                                                  |
|:-----------|-----:|---------:|:---------------------------------------------------------------------------------|
| SPI\_CLK   | 入力 |        1 | SPI通信用クロック入力 <br/> SPI FLASHにはこの半分の周波数でSPI通信が行われます。 |
| SITCP\_CLK | 入力 |        1 | SiTCPクロック入力 <br/> RBCPバスを駆動しているクロックを入力                     |
| RESET      | 入力 |        1 | リセット入力                                                                     |
| RBCP\_ACT  | 入力 |        1 | RBCP\_ACT入力                                                                    |
| RBCP\_ADDR | 入力 |       32 | RBCP\_ADDR入力                                                                   |
| RBCP\_WE   | 入力 |        1 | RBCP\_WE入力                                                                     |
| RBCP\_WD   | 入力 |        8 | RBCP\_WD入力                                                                     |
| RBCP\_RE   | 入力 |        1 | RBCP\_RE入力                                                                     |
| RBCP\_RD   | 出力 |        8 | RBCP\_RD出力                                                                     |
| RBCP\_ACK  | 出力 |        1 | RBCP\_ACK出力                                                                    |
| SPI\_SCLK  | 出力 |        1 | SPI FLASHのクロック入力                                                          |
| SPI\_SS\_N | 出力 |        1 | SPI FLASHのチップセレクト                                                        |
| SPI\_MOSI  | 出力 |        1 | SPI FLASHのデータ入力に接続                                                      |
| SPI\_MISO  | 入力 |        1 | SPI FLASHのデータ出力に接続                                                      |

方向はSPI-FLASH-Programmerから見た入出力の方向です。
SPI\_CLKに供給する周波数は各SPI FLASHのデータシートを参照の上決定ください。

#### ジェネリック
ジェネリックには次のように値を設定してください。

| ジェネリック名                     |                        データ型 |                                      |
|:-----------------------------------|---------------------------------|--------------------------------------|
| G\_SPI\_FLASH\_PROGRAMMER\_ADDRESS | std\_logic\_vector(31 downto 0) | 割り当てるRBCPアドレスの開始アドレス |
| G\_SITCP\_CLK\_FREQ                |                            real | SITCP_CLKの周波数(MHz)               |
| G\_SPI\_CLK\_FREQ                  |                            real | SPI_CLKの周波数(MHz)                 |

SPI-Flash-ProgrammerにG\_SPI\_FLASH\_PROGRAMMER\_ADDRESSから始まる8195byte分のアドレス空間を割り当ててください。

RBCPバスに他のモジュールが接続されているときにはRBCP\_RD、RBCP\_ACKを次のように処理してください。

    RBCP_RD <= RBCP_RD_SPI_PROGRAMMER when(RBCP_ACK_SPI_PROGRAMMER = '1') else
               RBCP_RD_OTHER_MODULE when(RBCP_ACK_OTHER_MODULE = '1') else
               (others => 'X');
    RBCP_ACK <= RBCP_ACK_SPI_PROGRAMMER or RBCP_ACK_OTHER_MODULE;

SPI\_\*の接続先は多くのSPI FLASHでは次のような名称のピンになっています。

| SPI-FLASH-Programmerのポート名 | SPI FLASHのピン名 |
|-------------------------------:|------------------:|
| SPI\_SCLK                      | C                 |
| SPI\_SS\_N                     | S\#               |
| SPI\_MOSI                      | DQ0               |
| SPI\_MISO                      | DQ1               |

セットアップタイムの確保のためにSPI\_\*はIOBのレジスタにマップするように配置制約をかけてください。

    set_property IOB true [get_ports SPI_SCLK]
    set_property IOB true [get_ports SPI_SS_N]
    set_property IOB true [get_ports SPI_MOSI]
    set_property IOB true [get_ports SPI_MISO]

コンフィグ後のCCLKピンがフロートになるように制約をかけてください。

    set_property BITSTREAM.CONFIG.CCLKPIN Pullnone [current_design]


### PC
インターネットに接続されているPCで`pc/install.sh`を実行してください。
必要なライブラリがインストールされます。
Rubyのバージョンが古い場合は2.1.0以上をインストールしてください。

settings.ymlを以下のように変更してください。

    udp_port: <UDP port>
    rbcp_address: <RBCP address of SPI-FLASH-Programmer>

+ `udp_port`:
RBCP通信に使用するUDPポート番号(通常は4660)

+ `rbcp_address`
SPI-FLASH-Programmerをインプリメントする際に割り当てたRBCPアドレス

そして以下のコマンドを実行して書き込みを行ってください。
`pc/spi_flash_programmer.rb [option] <IP address> <mcs file>`

以下のオプションに対応しています。
+ `--port`:
UDPポート番号 setting.ymlに書いたものよりもこちらが優先される。
+ `-q, --quiet`:
プログレスバーとSPI FLASH情報を表示しない
+ `-h, --help`:
ヘルプメッセージを表示する
+ `-v, --version`:
バージョンを表示する

#### エラーメッセージの原因と対処
+ \<IP address\> is unreachable  
\<IP address\>にしてpingが通りません。
    + 指定したIPアドレスがSiTCPのものか確認してください。  
      ボードの電源が入っており、FPGAのRAMにファームウェアが書き込まれていることを確認してください。

+ Verify failed  
Erase、Write後のVerifyに失敗しました。
    + SPI FLASHにファームウェアが正常に書かれていない可能性が高いです。  
      ファームウェアの書き込みをもう1度行ってください。
    + それでも解決しない場合は`SPI_*`ピンのタイミング制約が間違っている場合があります。  
      SPI FLASHデバイスのセットアップタイム、ホールドタイムを満たしているか確認してください。

+ No such file: \<mcs file\>  
mcsファイルが見つかりません。
    + mcsファイルへのパスが正しいか確認してください。

+ \<mcs file\> is broken  
mcsファイルが破損しています。
    + ISE, vivadoを使用して生成しなおしてください。

+ unknown JEDEC ID code  
対応していないJEDECコードのSPI FLASHが接続されています。
    + M25Pと互換性のあるデバイスであればデバイス情報をdevice.ymlに追記することで対応することが出来ます。  
    + device.ymlにデバイス情報が書かれているにも関わらずこのエラーが出る場合は`SPI_*`ピンのタイミング違反が考えられます。  
      SPI FLASHデバイスのセットアップタイム、ホールドタイムを満たしているか確認してください。

+ capacity of SPI FLASH is smaller than binary size  
SPI FLASHの容量がmcsファイルのサイズより小さいです。
    + mcsファイル生成の際に指定したSPI FLASHのサイズを確認してください。

+ RBCP Timeout  
RBCP通信がタイムアウトしました。
    + 指定したIPアドレスがネットワークに存在しますが、SiTCPではない可能性があります。
      IPアドレスを確認してください。  
    + インスタンシエートしたアドレスをsettings.ymlに正しく設定していない可能性があります。
      ファームウェアのソースコードとsettings.ymlを確認してください。  
    + SPI-FLASH-Programmerの使用しているRBCPアドレスが競合している可能性があります。
      RBCPのアドレスマップを再確認してください。

+ RBCP Error  
その他のRBCP通信に関するエラーです。
    + SPI-FLASH-Programmerの使用しているRBCPアドレスが競合している可能性があります。  
      RBCPのアドレスマップを再確認してください。


新たなSPI FLASHの追加方法
-------------------------
SPI FLASHはM32Pと互換性を持っており、以下のコマンドセットに対応している必要があります。

| コマンド名                         | コマンド | アドレス長 | データ長 |
|:-----------------------------------|---------:|-----------:|---------:|
| READ\_DATA\_BYTE                   |     0x03 |          3 |    1～∞ |
| READ\_STATUS\_REGISTER             |     0x05 |          0 |        1 |
| READ\_IDENTIFICATION               |     0x9F |          0 |       20 |
| WRITE\_ENABLE                      |     0x06 |          0 |        0 |
| PAGE\_PROGRAM                      |     0x02 |          3 |   1～256 |
| SECTOR\_ERASE                      |     0xD8 |          3 |        0 |
| BULK\_ERASE                        |     0xC7 |          0 |        0 |

ただし、256Mbit以上のデバイスは代わりに以下のコマンドセットに対応している必要があります。

| コマンド名                         | コマンド | アドレス長 | データ長 |
|:-----------------------------------|---------:|-----------:|---------:|
| 4\_BYTE\_ADDRESS\_READ\_DATA\_BYTE |     0x13 |          4 |    1～∞ |
| READ\_STATUS\_REGISTER             |     0x05 |          0 |        1 |
| READ\_IDENTIFICATION               |     0x9F |          0 |       20 |
| WRITE\_ENABLE                      |     0x06 |          0 |        0 |
| 4\_BYTE\_ADDRESS\_PAGE\_PROGRAM    |     0x12 |          4 |   1～256 |
| 4\_BYTE\_ADDRESS\_SECTOR\_ERASE    |     0xDC |          4 |        0 |
| BULK\_ERASE                        |     0xC7 |          0 |        0 |

デバイス情報を以下のフォーマットに従ってdevices.ymlに追記してください。

    <JEDEC ID code>: {
       name:                 <Device name>,
       capacity:        <Capacity in Mbit>,
       sector:              <total sector>,
       sector_size:    <sector size in KB>,
       address_mode: <address mode 3 or 4>
       },

+ `JEDEC ID code`:
READ\_IDENTIFICATIONコマンドで読み出した時の最初の3byte

+ `capacity`
デバイスの容量をMbit単位で

+ `sector`
全セクター数

+ `sector_size`
ERASE\_SECTORコマンドで消すことのできるセクターサイズをKB単位で

+ `address_mode`
アドレスモードを3byteにするか4byteにするか。256Mbit以上であれば4、以下であれば3に設定

既知のバグ
----------
+ mcsファイルのアドレスが連続していないときにはmcsファイルのデコードを正しく行えない
ISE、vivadoの出力するmcsファイルはそのようなフォーマットになっていないので実用上問題ありません。

関連情報
--------
+ [SiTCP][SiTCP]
+ [Using SPI Flash with 7 Series FPGAs][XAPP586]
+ [Intel HEX format][IntelHEX]
[SiTCP]: http://research.kek.jp/people/uchida/technologies/SiTCP/
[XAPP586]: http://www.xilinx.com/support/documentation/application_notes/xapp586-spi-flash.pdf
[IntelHEX]: http://en.wikipedia.org/wiki/Intel_HEX

ライセンス
----------
Copyright &copy; 2014 Takehiro Shiozaki
Licensed under the [MIT License][MIT].
[MIT]: http://www.opensource.org/licenses/mit-license.php
