# SysExGF

steganographizes files into SysEx messages in a standard MIDI file!

# usage:

i wouldn't...

but `encode.rb <file> <midi file>` to add files as many times as you like, then `decode.rb <midi file> [output dir]`

if you're using this for anything serious, you're a fool, but you should also know that a maliciously crafted MIDI file might be able to overwrite arbitrary paths. don't use untrusted MIDI files, i guess...

also, max 128 files per MIDI. the file index is a single byte and MIDI data bytes max out at 127. could fix it but i'd need to have thought to include a version byte and honestly if you're stuffing more than 128 files into a MIDI you need to rethink some things.

# how it works:

MIDI has these things called SysEx (System Exclusive) messages that are basically "here's some proprietary blob, ignore it if you don't understand it". synths use them for firmware updates & shuffling patches around & what have you. we use them to hide files in your banger eurobeat remixes.

the catch is MIDI data bytes can only be 0-127 (7-bit), so we pack every 7 bytes of your file into 8 bytes of sysex-safe data (like you used to have to do for non-8-bit-clean email servers :-P)

each file gets:
- a header sysex with the filename and length (also 7-bit encoded because nothing is sacred)
- a bunch of data chunk sysexes

every spec-compliant player will ignore the SysEx messages, so your file should still sound fine (extra weight notwithstanding)