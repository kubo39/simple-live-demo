module mpeg2ts.packet;

import std.bitmanip : bigEndianToNative;

enum TS_PACKET_SIZE = 188;
enum SYNC_BYTE = 0x47;
enum PAT_PID = 0x0000;
enum PCR_CLOCK_RATE = 90_000;

struct TSPacket
{
    ubyte[TS_PACKET_SIZE] data;
    ushort pid;
    bool payloadUnitStart;
    bool hasAdaptationField;
    bool hasPayload;
    bool randomAccess;
    bool hasPcr;
    long pcrValue;
}

TSPacket parsePacket(ref const(ubyte)[TS_PACKET_SIZE] raw)
{
    TSPacket pkt;
    pkt.data = raw;

    assert(raw[0] == SYNC_BYTE);

    pkt.payloadUnitStart = (raw[1] & 0x40) != 0;
    pkt.pid = readPid(raw, 1);

    ubyte adaptationFieldControl = (raw[3] >> 4) & 0x03;
    pkt.hasAdaptationField = (adaptationFieldControl & 0x02) != 0;
    pkt.hasPayload = (adaptationFieldControl & 0x01) != 0;

    if (pkt.hasAdaptationField)
    {
        ubyte adaptLen = raw[4];
        if (adaptLen > 0)
        {
            ubyte flags = raw[5];
            pkt.randomAccess = (flags & 0x40) != 0;
            if ((flags & 0x10) != 0 && adaptLen >= 7)
            {
                pkt.hasPcr = true;
                pkt.pcrValue = (cast(long) bigEndianToNative!uint(raw[6 .. 10]) << 1)
                    | (raw[10] >> 7);
            }
        }
    }

    return pkt;
}

package:

ushort readPid(const(ubyte)[] raw, size_t offset)
{
    return bigEndianToNative!ushort([raw[offset], raw[offset + 1]]) & 0x1FFF;
}

ushort read12(const(ubyte)[] raw, size_t offset)
{
    return bigEndianToNative!ushort([raw[offset], raw[offset + 1]]) & 0x0FFF;
}

ushort read16(const(ubyte)[] raw, size_t offset)
{
    return bigEndianToNative!ushort([raw[offset], raw[offset + 1]]);
}
