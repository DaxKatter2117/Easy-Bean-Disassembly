import sys

assert len(sys.argv) == 3, '2 Parameters must be provided. one for input filename and one for output filename.'

with open(sys.argv[1], 'rb') as inbin, open(sys.argv[2], 'wb') as outbin:
    assert len(inbin.read())%2 == 0, 'Input file must have a size of multiple of 2, as it should only consist of (16-bit) words'
    inbin.seek(0)
    while True:
        wordread = inbin.read(2)
        if len(wordread) == 0:
            break
        assert wordread[0] == 0, f'Word {int.from_bytes(wordread):04x} at index {inbin.tell() - 2:x} does not start with byte 00'
        
        outbin.write(wordread[1].to_bytes(1))
        