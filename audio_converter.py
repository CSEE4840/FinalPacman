import wave
import struct

# Input and output filenames
wav_file = 'pacman-intro.wav'
hex_file = 'pacman-intro.hex'

# Open WAV file
with wave.open(wav_file, 'rb') as w:
    assert w.getsampwidth() == 2, "WAV must be 16-bit"
    assert w.getnchannels() == 1, "WAV must be mono"
    assert w.getframerate() == 8000, "WAV must be 8000 Hz"

    frames = w.readframes(w.getnframes())
    samples = struct.unpack('<' + 'h' * w.getnframes(), frames)

# Write HEX file (each line = one 16-bit sample, in hex)
with open(hex_file, 'w') as f:
    for sample in samples:
        f.write(f'{sample & 0xFFFF:04X}\n')
