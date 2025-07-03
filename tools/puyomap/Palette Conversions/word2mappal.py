import sys

assert len(sys.argv) == 4, '2 Parameters must be provided. 1st for input filename and 2nd for output tile filename and 3rd for output palette filename.'

with open(sys.argv[1], 'rb') as inbin, open(sys.argv[2], 'wb') as outmapbin, open(sys.argv[3], 'wb') as outpalbin:
    assert len(inbin.read())%(2*4) == 0, 'Input file must have a size of multiple of 8, as it should only consist of a multiple of 4 (16-bit) words'
    inbin.seek(0)
    while True:
        wordread = inbin.read(8)
        if len(wordread) == 0:
            break

        palgroupwords = [wordread[0:2], wordread[2:4], wordread[4:6], wordread[6:8]]
        outpalbyte = 0
        for idx, inword in enumerate(palgroupwords):
            outmapbin.write(inword[1].to_bytes(1))
            pal = (inword[0] >> 5) & 0b11
            outpalbyte += pal << (idx*2)
        outpalbin.write(outpalbyte.to_bytes(1))
        