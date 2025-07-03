import sys

assert len(sys.argv) == 3, '2 Parameters must be provided. one for input filename and one for output filename.'

with open(sys.argv[1], 'rb') as inbin, open(sys.argv[2], 'wb') as outbin:
    while True:
        byteread = inbin.read(1)
        if len(byteread) != 1:
            break
        
        outbin.write(b'\x00' + byteread)
        