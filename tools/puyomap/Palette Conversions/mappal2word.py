import sys

assert len(sys.argv) == 4, '3 Parameters must be provided. 1st for input mapping filename, 2nd for input palette filename and 3rd for output filename.'

with open(sys.argv[1], 'rb') as mapbin, open(sys.argv[2], 'rb') as palbin, open(sys.argv[3], 'wb') as outbin:
    assert len(mapbin.read()) == 4*len(palbin.read()), 'Mapping file should be 4 times as big as the palette file'
    mapbin.seek(0)
    palbin.seek(0)
    while True:
        palbyte = palbin.read(1)
        if len(palbyte) != 1:
            break
        individualpalettes: list[int] = []
        for i in range(0, 8, 2):
            individualpalettes.append( (int.from_bytes(palbyte) >> i) & 0b11)
        for pal in individualpalettes:
            bytewithpal2bits: bytes = (pal << 5).to_bytes(1)
            mapbyte = mapbin.read(1)
            outbin.write(bytewithpal2bits + mapbyte)
            