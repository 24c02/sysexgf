require "midilib"

MANUFACTURER_ID = 0x7D # we noncommercial/educational in this biatch
MAGIC = "SXGF".bytes.freeze
CHUNK_SIZE = 2048 # max we can do, i think?

MSG_HEADER = 0x01
MSG_DATA   = 0x02

def encode_7bit(data)
  result = []
  data.each_slice(7) do |chunk|
    high_bits = 0
    chunk.each_with_index { |byte, i| high_bits |= ((byte >> 7) & 1) << i }
    result << high_bits
    chunk.each { |byte| result << (byte & 0x7F) }
  end
  result
end

def decode_7bit(data)
  result = []
  data.each_slice(8) do |chunk|
    next if chunk.empty?
    high_bits = chunk[0]
    chunk[1..].each_with_index { |byte, i| result << (byte | (((high_bits >> i) & 1) << 7)) }
  end
  result
end

def build_sysex(msg_type, payload)
  MIDI::SystemExclusive.new([MANUFACTURER_ID] + MAGIC + [msg_type] + payload)
end

def parse_sysex(event)
  return nil unless event.is_a?(MIDI::SystemExclusive)
  data = event.data
  return nil if data.length < 7 || data[1] != MANUFACTURER_ID || data[2..5] != MAGIC
  [data[6], data[7..]] # lol 67
end

def find_sxgf_events(seq)
  events = []
  seq.each do |track|
    track.each do |event|
      parsed = parse_sysex(event)
      events << [event, parsed[0], parsed[1]] if parsed
    end
  end
  events
end
