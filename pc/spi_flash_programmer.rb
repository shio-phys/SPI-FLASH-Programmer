#!/bin/env ruby

require 'optparse'
require 'yaml'
require 'bundler'
require 'bundler/setup'
Bundler.require

require_relative 'spi_command_sender.rb'

class SpiFlashProgrammer
    def initialize(host:, port:, rbcp_address:, mcs_filename:, quiet_mode:)

        if quiet_mode
            @progress_out = open('/dev/null', 'w')
        else
            @progress_out = $stderr
        end

        ping_to_board(host)
        create_spi_command_sender(host, port, rbcp_address)

        if !quiet_mode
            print_device_information
        end
        read_mcs(mcs_filename)
        check_capacity

    end

    def print_device_information
        device_information = @spi_command_sender.device_information
        id = '%06X' % @spi_command_sender.id
        name = device_information['name']
        capacity = device_information['capacity']
        sector = device_information['sector']
        sector_size = device_information['sector_size']
        address_mode = device_information['address_mode']

        puts 'SPI FLASH information'
        puts "    JEDEC ID code: #{id}"
        puts "    Name:          #{name}"
        puts "    Capacity:      #{capacity}Mbit"
        puts "    Sector:        #{sector}"
        puts "    Sector size:   #{sector_size}KB"
        puts "    Address mode:  #{address_mode}"
        puts
    end

    def erase
        puts 'Erasing SPI FLASH'
        sector_num = @spi_command_sender.device_information['sector']
        progress_bar = ProgressBar.create(
            total: sector_num,
            format: '%p%% [%b>%i] %c %Rsector/s %e',
            output: @progress_out
        )
        sector_num.times do |sector|
            @spi_command_sender.sector_erase(sector)
            progress_bar.increment
        end
        progress_bar.finish
        puts
    end

    def write
        puts 'Writing binary to SPI FLASH'
        progress_bar = ProgressBar.create(
            total: @binary.length,
            format: '%p%% [%b>%i] %c %RKB/s %e',
            rate_scale: ->(rate){rate / 1024},
            output: @progress_out
        )

        address = 0
        loop do
            data_to_write = @binary.slice(address, 256)
            break if data_to_write == nil or data_to_write == ''
            @spi_command_sender.write(address, data_to_write)
            address += data_to_write.length
            progress_bar.progress += data_to_write.length
        end
        progress_bar.finish
        puts
    end

    def verify
        puts 'Verifying SPI FLASH'
        progress_bar = ProgressBar.create(
            total: @binary.length,
            format: '%p%% [%b>%i] %c %RKB/s %e',
            rate_scale: ->(rate){rate / 1024},
            output: @progress_out
        )
        rom = ''.encode('ASCII-8BIT')
        address = 0
        while address < @binary.length
            read_in_this_time = [8000, @binary.length - address].min
            rom << @spi_command_sender.read(address, read_in_this_time)
            address += read_in_this_time
            progress_bar.progress += read_in_this_time
        end
        progress_bar.finish
        if(@binary != rom)
            puts 'Verify failed'
            puts '    Please rewrite firmware.'
            exit 1
        end
        puts
    end

    private
    def ping_to_board(host)
        pinger = Net::Ping::External.new(host)
        if !pinger.ping?
            $stderr.puts "#{host} is unreachable."
            exit 1
        end
    end

    def read_mcs(mcs_filename)
        McsReader::open(mcs_filename) do |mcs|
            puts 'Reading mcs file'
            mcs_filesize = File::stat(mcs_filename).size
            progress_bar_total = mcs_filesize / 2.81
            progress_bar = ProgressBar.create(
                total: progress_bar_total,
                format: '%p%% [%b>%i] %c %RMB/s %e',
                rate_scale: ->(rate){rate / 1024 / 1024},
                output: @progress_out
            )

            @binary = ''.encode('ASCII-8BIT')
            while !mcs.eof?
                data = mcs.read(1024)
                @binary << data
                if progress_bar_total > @binary.length
                    progress_bar.progress += data.length
                end
            end
            progress_bar.total = @binary.length
            progress_bar.finish
            puts "Binary size: #{(@binary.length / 1024.0 / 1024).round(2)}MB"
            puts
        end
    rescue Errno::ENOENT
        $stderr.puts "No such file: #{mcs_filename}"
        exit 1
    rescue McsReaderException => e
        $stderr.puts "#{mcs_filename} is broken."
        $stderr.puts "Please regenerate it."
        $stderr.puts e.message
        exit 1
    end

    def create_spi_command_sender(host, port, rbcp_address)
        devices_yml = File.expand_path('devices.yml', File.dirname(__FILE__))
        @spi_command_sender = SpiCommandSender.new(host, port, rbcp_address,
                                                   devices_yml)
    rescue SpiCommandSenderException => e
        $stderr.puts e.message
        exit 1
    end

    def check_capacity
        capacity = @spi_command_sender.device_information['capacity']
        capacity = capacity * 1024 * 1024 / 8
        if capacity < @binary.length
            binary_size_in_mb = (@binary.length / 1024.0 / 1024).round(2)
            $stderr.puts 'capacity of SPI FLASH is smaller than binary size.'
            $stderr.puts "    capacity:    #{capacity}MB"
            $stderr.puts "    binary size: #{binary_size_in_mb}MB"
            exit 1
        end
    end
end

Version = '1.0'
OPTS = {}
opt = OptionParser.new
opt.on('-q', '--quiet', 'quiet mode'){|v| OPTS[:quiet] = v}
opt.on('--port=UDP PORT', 'UDP port'){|v| OPTS[:port] = v}
opt.parse!(ARGV)

if ARGV.length != 2
    puts 'Usage:'
    puts "    #{$0} <Options> <MCS file> <IP Address>"
    exit 1
end

settings_yaml = File.expand_path('settings.yml', File.dirname(__FILE__))
settings = YAML.load_file(settings_yaml)
port = settings['udp_port']
rbcp_address = settings['rbcp_address']

mcs_filename = ARGV[0]
ipaddr = ARGV[1]
if OPTS.has_key?(:port)
    port = OPTS[:port]
end
quiet_mode = OPTS.fetch(:quiet, false)

begin
    spi_flash_programmer = SpiFlashProgrammer.new(host: ipaddr,
                                                  port: port,
                                                  rbcp_address: rbcp_address,
                                                  mcs_filename: mcs_filename,
                                                  quiet_mode: quiet_mode)
    spi_flash_programmer.erase
    spi_flash_programmer.write
    spi_flash_programmer.verify
rescue RBCPError => e
    if e.message == 'Timeout'
        $stderr.puts 'RBCP Timeout'
        exit 1
    else
        $stderr.puts 'RBCP Error'
        $stderr.puts e.message
        exit 1
    end
end
