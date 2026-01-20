#!/usr/bin/env ruby
require_relative "./shared"

def batch_encode(input_files, midi_path)
  abort "MIDI file not found: #{midi_path}" unless File.exist?(midi_path)

  seq = MIDI::Sequence.new
  File.open(midi_path, "rb") { |f| seq.read(f) }

  track = seq.tracks.first

  existing = find_sxgf_events(seq)
  file_indices = existing.select { |_, type, _| type == MSG_HEADER }.map { |_, _, payload| payload[0] }
  next_index = file_indices.empty? ? 0 : file_indices.max + 1

  total_chunks = 0

  input_files.each do |input_path|
    next unless File.file?(input_path)

    filename = File.basename(input_path)
    file_data = File.binread(input_path)

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

    puts "Encoded '#{filename}' (#{file_data.length} bytes) as file ##{next_index} [#{chunk_index} chunks]"
    next_index += 1
    total_chunks += chunk_index
  end

  File.open(midi_path, "wb") { |f| seq.write(f) }
  puts "Wrote #{input_files.length} files (#{total_chunks} total chunks) to #{midi_path}"
end

if ARGV.length < 2
  puts "Usage: ruby batchencode.rb <midi_file> <input_files_or_glob...>"
  puts "Example: ruby batchencode.rb output.mid /path/to/files/*"
  exit 1
end

midi_path = ARGV[0]
input_files = ARGV[1..].flat_map { |pattern| Dir.glob(pattern) }.sort

if input_files.empty?
  puts "No input files found"
  exit 1
end

batch_encode(input_files, midi_path)