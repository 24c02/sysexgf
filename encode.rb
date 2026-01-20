#!/usr/bin/env ruby
require_relative "./shared"

def encode_file(input_path, midi_path)
  filename = File.basename(input_path)
  file_data = File.binread(input_path)

  abort "MIDI file not found: #{midi_path}" unless File.exist?(midi_path)

  seq = MIDI::Sequence.new
  File.open(midi_path, "rb") { |f| seq.read(f) }

  track = seq.tracks.first

  existing = find_sxgf_events(seq)
  file_indices = existing.select { |_, type, _| type == MSG_HEADER }.map { |_, _, payload| payload[0] }
  next_index = file_indices.empty? ? 0 : file_indices.max + 1

  name_bytes = encode_7bit(filename.bytes)
  length_raw = [
    (file_data.length >> 24) & 0xFF,
    (file_data.length >> 16) & 0xFF,
    (file_data.length >> 8) & 0xFF,
    file_data.length & 0xFF
  ]
  length_bytes = encode_7bit(length_raw)

  header_payload = [next_index, name_bytes.length, length_bytes.length] + name_bytes + length_bytes
  header_event = build_sysex(MSG_HEADER, header_payload)
  header_event.time_from_start = 0
  track.events << header_event

  encoded_data = encode_7bit(file_data.bytes)
  chunk_index = 0
  encoded_data.each_slice(CHUNK_SIZE) do |chunk|
    data_payload = [next_index, (chunk_index >> 7) & 0x7F, chunk_index & 0x7F] + chunk
    data_event = build_sysex(MSG_DATA, data_payload)
    data_event.time_from_start = 0
    track.events << data_event
    chunk_index += 1
  end

  File.open(midi_path, "wb") { |f| seq.write(f) }

  puts "Encoded '#{filename}' (#{file_data.length} bytes) as file ##{next_index}"
  puts "Added #{chunk_index} data chunks to #{midi_path}"
end

if ARGV.length < 2
  puts "Usage: ruby encode.rb <input_file> <midi_file>"
  exit 1
end

encode_file(ARGV[0], ARGV[1])
