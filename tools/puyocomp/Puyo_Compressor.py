import sys

COUNT: int = 0
IDX: int = 1

def getbacklist(input: list[int], start: int, refidx: int, count: int) -> list[int]:
    ref: list[int] = list(input[start-refidx-1:start]) # Make a copy of elements that are referneced
    for refidx in range(count):
        ref.append(ref[refidx])
    return ref[-count:] # Remove the elements that were referneced at the beginning

assert len(sys.argv)  == 2 or len(sys.argv) == 3, 'Input 4bpp filename must be provided'
output: bytearray = bytearray()
with open(sys.argv[1], 'rb') as infile:
    input = bytearray(infile.read())

assert len(input) != 0, 'Error: Input 4bpp file is empty'
assert len(input) % 4 == 0, 'Error: Size of input 4bpp file must be a multiple of 4'
assert len(input) < 0x10000, 'Error: Size of input 4bpp is 0x10000 bytes or larger which is too big.'

with open(sys.argv[2] if len(sys.argv) == 3 else 'out.bin', 'wb') as outbin:
    forward: int = 0x1
    outbytescount: int = 0
    while outbytescount < len(input):
        forwardmax = min(0x7F, len(input) - outbytescount)
        matchvals: tuple[int, int] = (-1, -1) # (count, index)
        while forward <= forwardmax:
            curidx = forward + outbytescount
            maxfwd: int = min(0x82, len(input) - curidx)
            if maxfwd < 3:
                break # back command byte ranges from 0x80 to 0xFF
            for count in range(3, maxfwd+1, 1):
                for idx in range(0xFF):
                    if ( curidx - (idx + 1)) < 0:
                        break # can't go back any further
                    actual: list[int] = list(input[curidx:curidx+count])
                    if actual == getbacklist(input, curidx, idx, count ):
                        matchvals = (count, idx)
                        break
                if matchvals[COUNT] != count:
                    break
                
            if matchvals != (-1, -1):
                if forward > 0:
                    outbin.write(forward.to_bytes(1))
                    outbin.write(input[outbytescount:curidx])

                outbin.write( ((matchvals[COUNT] - 3) + 0x80).to_bytes(1))
                outbin.write(matchvals[IDX].to_bytes(1))
                outbytescount += forward + matchvals[COUNT]
                forward = 0 # It is possible for there to be another back command
                break
            forward+=1

        if matchvals == (-1, -1): # No backward command, so write forward command with max size
            outbin.write(forwardmax.to_bytes(1))
            outbin.write(input[outbytescount:outbytescount+forwardmax])
            outbytescount += forwardmax
            forward = 0
    outbin.write((0).to_bytes(1)) # stop command