require 'socket'

class RBCPHeader
    READ = 0xC0
    WRITE = 0x80
    def initialize(rw, id, data_length, address)
        @ver_type = 0xff
        @cmd_flag = rw & 0xff
        @id = id & 0xff
        @data_length = data_length & 0xff
        @address = address & 0xffffffff
    end

    def self.from_bin(str)
        RBCPHeader.new(str[1].unpack('C')[0], str[2].unpack('C')[0], str[3].unpack('C')[0], str[4, 4].unpack('N')[0])
    end

    def to_s
        str = ''.encode('ASCII-8BIT')
        str << @ver_type
        str << @cmd_flag
        str << @id
        str << @data_length
        str << [@address].pack('N')
    end
    attr_accessor :ver_type, :cmd_flag, :id, :data_length, :address
end

class RBCPError < Exception; end

class RBCP
    def initialize(host, port)
        @host = host
        @port = port
        @id = 0
    end

    def read(address, data_length)
        read_data = ''.encode('ASCII-8BIT')
        while data_length > 0 do
            data_length_one_packet = [data_length, 255].min
            read_data << com(RBCPHeader::READ, address, data_length_one_packet, '')
            data_length -= data_length_one_packet
            address += data_length_one_packet
        end
        read_data
    end

    def read8bit(address, data_length)
        read(address, data_length).unpack('C*')
    end

    def read16bit(address, data_length)
        read(address, data_length * 2).unpack('n*')
    end

    def read32bit(address, data_length)
        read(address, data_length * 4).unpack('N*')
    end

    def write(address, data)
        if data.is_a?(Fixnum)
            data = [data]
        end

        if data.is_a?(Array)
            data = data.pack('C*')
        end

        remaining_data_length = data.length
        data_index = 0
        while remaining_data_length > 0
            data_length_one_packet = [remaining_data_length, 255].min
            data_to_write = data[data_index, data_length_one_packet]
            com(RBCPHeader::WRITE, address + data_index, data_length_one_packet,
                data_to_write)
            remaining_data_length -= data_length_one_packet
            data_index += data_length_one_packet
        end
    end

    def write8bit(address, data)
        write(address, data)
    end

    def write16bit(address, data)
        if data.is_a?(Fixnum)
            data = [data]
        end

        write(address, data.pack('n*'))
    end

    def write32bit(address, data)
        if data.is_a?(Fixnum)
            data = [data]
        end

        write(address, data.pack('N*'))
    end

    private
    def com(rw, address, data_length, data)
        retries = 0
        max_retries = 3
        begin
            return comSub(rw, address, data_length, data)
        rescue RBCPError => e
            puts e.message
            retries += 1
            retry if retries < max_retries
            raise e
        end
    end

    def comSub(rw, address, data_length, data)
        sock = UDPSocket.open()
        begin
            sock.bind('0.0.0.0', 0)

            header = RBCPHeader.new(rw, @id, data_length, address)
            data.force_encoding('ASCII-8BIT')
            data_to_be_sent = header.to_s + data
            if sock.send(data_to_be_sent, 0, @host, @port) != data_to_be_sent.length
                raise RBCPError.new("cannot send data")
            end

            # wait for 1 seconds until ACK is received
            sel = IO::select([sock], nil, nil, 1)
            raise RBCPError.new('Timeout') if sel == nil
            received_data = sock.recv(255+8)
            validate(rw, address, data_length, data, received_data)
        ensure
            sock.close
            @id = (@id + 1) & 0xff
        end
        received_data.slice(0, 8)
    end

    def validate(rw, address, data_length, data, received_data)
        header = RBCPHeader.from_bin(received_data)
        raise RBCPError.new('Invalid Ver Type')   if received_data.getbyte(0) != 0xff
        if header.cmd_flag != (rw | 0x08)
            if header.cmd_flag & 0x01
                raise RBCPError.new('Bus Error')
            else
                raise RBCPError.new('Invalid CMD Flag')
            end
        end
        raise RBCPError.new('Invalid ID')         if header.id != @id
        raise RBCPError.new('Invalid DataLength') if header.data_length != data_length
        raise RBCPError.new('Invalid Address')    if header.address != address
        raise RBCPError.new('Frame Error')        if header.data_length != received_data.length - 8
    end
end
