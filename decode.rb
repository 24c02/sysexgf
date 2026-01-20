#!/usr/bin/env ruby
require_relative "./shared"

def decode_files(midi_path, output_dir = ".")
  abort "MIDI file not found: #{midi_path}" unless File.exist?(midi_path)

  seq = MIDI::Sequence.new
  File.open(midi_path, "rb") { |f| seq.read(f) }

  events = find_sxgf_events(seq)
  return puts "don't think there's anything in here!" if events.empty?

  headers = {}
  data_chunks = Hash.new { |h, k| h[k] = {} }

  events.each do |_, msg_type, payload|
    case msg_type
    when MSG_HEADER
      file_idx = payload[0]
      name_len = payload[1]
      len_len = payload[2]
      name_bytes = decode_7bit(payload[3, name_len])
      length_enc = payload[3 + name_len, len_len]
      length_raw = decode_7bit(length_enc)
      file_length = (length_raw[0] << 24) | (length_raw[1] << 16) | (length_raw[2] << 8) | length_raw[3]
      headers[file_idx] = { name: name_bytes.pack("C*"), length: file_length }
    when MSG_DATA
      file_idx = payload[0]
      chunk_idx = (payload[1] << 7) | payload[2]
      data_chunks[file_idx][chunk_idx] = payload[3..]
    end
  end

  headers.each do |file_idx, info|
    chunks = data_chunks[file_idx]
    encoded_data = chunks.keys.sort.flat_map { |i| chunks[i] }
    decoded = decode_7bit(encoded_data).take(info[:length])

    output_path = File.join(output_dir, info[:name])
    File.binwrite(output_path, decoded.pack("C*"))
    puts "Extracted '#{info[:name]}' (#{info[:length]} bytes)"
  end
end

if ARGV.empty?
  puts "Usage: ruby decode.rb <midi_file> [output_dir]"
  exit 1
end

decode_files(ARGV[0], ARGV[1] || ".")
