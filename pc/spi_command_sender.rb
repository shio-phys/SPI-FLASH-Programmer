require 'yaml'
require_relative 'rbcp.rb'
require_relative 'mcs_reader.rb'

class SpiCommandSenderException < Exception
end

class SpiCommandSender
    attr_reader :device_information, :id

    def initialize(host, port, spi_programmer_address, devices_yaml)
        @rbcp = RBCP.new(host, port)
        @spi_programmer_address = spi_programmer_address

        @id = read_identification.slice(0, 3).each_byte.inject(0){|a, b| a << 8 | b}
        device_informations = YAML.load_file(devices_yaml)
        @device_information = device_informations[@id]
        if @device_information == nil
            raise SpiCommandSenderException.new('unknown JEDEC ID code %06X' % @id)
        end
    end

    def read(address, length)
        ret = ''
        address_mode = @device_information['address_mode']
        while length > 0
            length_to_read_at_this_time = [length, 8192 - address_mode - 1].min
            ret << send_read(address, length_to_read_at_this_time)
            length -= length_to_read_at_this_time
            address += length_to_read_at_this_time
        end
        ret
    end

    def bulk_erase
        send_spi_command(WRITE_ENABLE, 0)
        send_spi_command(BULK_ERASE, 0)
        wait_until_write_in_progress_is_clear
    end

    def sector_erase(sector)
        send_spi_command(WRITE_ENABLE, 0)

        address_mode = @device_information['address_mode']
        sector_size = @device_information['sector_size']
        address_bytes = pack_address(sector * sector_size)
        address_length = address_bytes.length

        send_spi_command(sector_erase_command, address_length, address_bytes)
        wait_until_write_in_progress_is_clear
    end

    def write(address, data)
        length = data.length
        data_ptr = 0
        while length > 0
            send_spi_command(WRITE_ENABLE, 0)
            length_to_write_at_this_time = [length, 256].min
            send_write(address, data.slice(data_ptr, length_to_write_at_this_time))

            length -= length_to_write_at_this_time
            address += length_to_write_at_this_time
            data_ptr += length_to_write_at_this_time
        end
    end

    def read_identification
        send_spi_command(READ_IDENTIFICATION, 20)
        @rbcp.read(data_address + 1, 20)
    end

    private
    def status_register_address
        @spi_programmer_address
    end

    def length_address
        @spi_programmer_address + 1
    end

    def data_address
        @spi_programmer_address + 3
    end

    WRITE_ENABLE                  = 0x06
    READ_IDENTIFICATION           = 0x9f
    READ_STATUS_REGISTER          = 0x05
    READ_DATA_BYTES               = 0x03
    PAGE_PROGRAM                  = 0x02
    SECTOR_ERASE                  = 0xd8
    BULK_ERASE                    = 0xc7

    READ_DATA_BYTES_4_BYTE_ADDRESS = 0x13
    PAGE_PROGRAM_4_BYTE_ADDRESS    = 0x12
    SECTOR_ERASE_4_BYTE_ADDRESS    = 0xdc

    def read_status_register
        send_spi_command(READ_STATUS_REGISTER, 1)
        @rbcp.read8bit(data_address + 1, 1)[0]
    end

    def send_spi_command(command, length, data = nil)
        @rbcp.write16bit(length_address, length)
        @rbcp.write(data_address, command)
        if data
            @rbcp.write(data_address + 1, data)
        end
        start_cycle
        wait_until_cycle_end
    end

    def start_cycle
        @rbcp.write(status_register_address, 0x00)
    end

    def wait_until_cycle_end
        while @rbcp.read8bit(status_register_address, 1).first != 0x00
        end
    end

    def wait_until_write_in_progress_is_clear
        while read_status_register & 0x01 != 0x00
        end
    end

    def pack_address(address)
        address_mode = @device_information['address_mode']
        if address_mode == 3
            pack_3byte_address(address)
        else
            pack_4byte_address(address)
        end
    end

    def pack_3byte_address(address)
        address_bytes = ''.encode('ASCII-8BIT')
        address_bytes << ((address >> 16) & 0xff).chr
        address_bytes << ((address >>  8) & 0xff).chr
        address_bytes << ((address >>  0) & 0xff).chr
    end

    def pack_4byte_address(address)
        address_bytes = ''.encode('ASCII-8BIT')
        address_bytes << ((address >> 24) & 0xff).chr
        address_bytes << ((address >> 16) & 0xff).chr
        address_bytes << ((address >>  8) & 0xff).chr
        address_bytes << ((address >>  0) & 0xff).chr
    end

    def send_read(address, length)
        address_mode = @device_information['address_mode']
        address_bytes = pack_address(address)
        address_length = address_bytes.length

        send_spi_command(read_command, length + address_length, address_bytes)
        @rbcp.read(data_address + address_length + 1, length)
    end

    def send_write(address, data)
        address_mode = @device_information['address_mode']
        address_bytes = pack_address(address)
        data_to_transfer = address_bytes + data

        send_spi_command(page_program_command, data_to_transfer.length,
                         data_to_transfer)
        wait_until_write_in_progress_is_clear
    end

    def read_command
        address_mode = @device_information['address_mode']
        if address_mode == 3
            READ_DATA_BYTES
        else
            READ_DATA_BYTES_4_BYTE_ADDRESS
        end
    end

    def page_program_command
        address_mode = @device_information['address_mode']
        if address_mode == 3
            PAGE_PROGRAM
        else
            PAGE_PROGRAM_4_BYTE_ADDRESS
        end
    end

    def sector_erase_command
        address_mode = @device_information['address_mode']
        if address_mode == 3
            SECTOR_ERASE
        else
            SECTOR_ERASE_4_BYTE_ADDRESS
        end
    end
end
