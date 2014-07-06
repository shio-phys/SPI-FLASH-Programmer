class McsReaderException < Exception
end

class McsReader
    include Enumerable

    def initialize(io)
        @io = io
        @buf = ""
        @address = 0
        @extended_linear_address = 0
        @eof = false
    end

    def self.open(filename)
        io = File.open(filename)
        mcs_reader = McsReader.new(io)
        if block_given?
            begin
                yield mcs_reader
            ensure
                io.close
            end
        end
        mcs_reader
    end

    def self.wrap(io)
        mcs_reader = McsReader.new(io)
        if block_given?
            begin
                yield mcs_reader
            ensure
                io.close
            end
        end
    end

    def read(length = nil)
        if @eof
            if length == nil
                return ""
            else
                return nil
            end
        end

        length = Float::INFINITY if length == nil
        ret = ''.encode('ASCII-8BIT')
        while length > 0
            if @buf.length == 0
                read_line
                break if @eof
            end
            length_to_copy = [length, @buf.length].min
            ret << @buf.slice!(0, length_to_copy)
            @address += length_to_copy
            length -= length_to_copy
        end
        ret
    end

    def each
        if block_given?
            while !@eof
                yield read(1)
            end
        else
            self.to_enum
        end
    end

    alias each_byte :each

    attr_reader :eof
    alias eof? :eof

    def getc
        return nil if @eof
        read(1).ord
    end

    def pos
        @address
    end

    alias tell :pos

    def readchar
        raise EOFError if @eof
        read(1).ord
    end

    def rewind
        @buf = ""
        @address = 0
        @extended_linear_address = 0
        @eof = false
        @io.rewind
    end

    private
    def read_line
        line = @io.gets
        return nil if line == nil
        line.chomp!
        start_char = line[0]
        byte_count = line[1..2].hex
        hex_address = line[3..6].hex
        recoed_type = line[7..8].hex
        data_byte = line[9..-3]
        data_byte = data_byte.unpack('a2' * (data_byte.length / 2)).map(&:hex)

        check_sum = line[1..-1].unpack('a2' * ((line[1..-1].length) / 2))
                               .map(&:hex).inject(:+) & 0xff
        raise McsReaderException.new('Startchar Error') unless start_char == ':'
        raise McsReaderException.new('Checksum Error') unless check_sum == 0

        case recoed_type
        when data?
            @address = hex_address + (@extended_linear_address << 16)
            @buf = data_byte.pack('C*').encode('ASCII-8BIT')
        when end_of_file?
            @eof = true
            nil
        when extended_segment_address?
            raise McsReaderException.new('Extended segment address is not supported')
        when start_segment_address?
            raise McsReaderException.new('Start segment address is not supported')
        when extended_linear_address?
            @extended_linear_address = data_byte.inject(0){|a, b| (a << 8) + b}
        when start_linear_address?
            raise McsReaderException.new('Start linear address is not supported')
        else
            raise McsReaderException.new('Unknown record type')
        end
    end

    def data?
        0
    end

    def end_of_file?
        1
    end

    def extended_segment_address?
        2
    end

    def start_segment_address?
        3
    end

    def extended_linear_address?
        4
    end

    def start_linear_address?
        5
    end
end

