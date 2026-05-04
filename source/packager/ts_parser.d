module packager.ts_parser;

import std.bitmanip : bigEndianToNative;

enum TS_PACKET_SIZE = 188;
enum SYNC_BYTE = 0x47;
enum PAT_PID = 0x0000;

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

struct StreamInfo
{
    ushort pmtPid;
    ushort videoPid;
    ushort audioPid;
    bool hasPmt;
    bool hasStreams;
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

void parsePat(ref StreamInfo info, ref const(ubyte)[TS_PACKET_SIZE] raw)
{
    size_t offset = 4;

    if ((raw[3] >> 4 & 0x02) != 0)
    {
        offset += 1 + raw[4];
    }

    if (raw[offset] != 0x00) return;
    offset++;

    if (raw[offset] != 0x00) return;
    offset++;

    ushort sectionLength = read12(raw, offset);
    offset += 2 + 5;

    size_t endOffset = offset + sectionLength - 5 - 4;
    if (endOffset > TS_PACKET_SIZE) return;

    while (offset + 4 <= endOffset)
    {
        ushort programNum = read16(raw, offset);
        ushort pid = readPid(raw, offset + 2);
        offset += 4;

        if (programNum != 0)
        {
            info.pmtPid = pid;
            info.hasPmt = true;
            break;
        }
    }
}

void parsePmt(ref StreamInfo info, ref const(ubyte)[TS_PACKET_SIZE] raw)
{
    size_t offset = 4;

    if ((raw[3] >> 4 & 0x02) != 0)
    {
        offset += 1 + raw[4];
    }

    offset++;

    if (raw[offset] != 0x02) return;
    offset++;

    ushort sectionLength = read12(raw, offset);
    offset += 2 + 5 + 2;

    ushort progInfoLen = read12(raw, offset);
    offset += 2 + progInfoLen;

    size_t endOffset = offset + sectionLength - 13 - progInfoLen;
    if (endOffset > TS_PACKET_SIZE) return;

    while (offset + 5 <= endOffset)
    {
        ubyte streamType = raw[offset];
        ushort elemPid = readPid(raw, offset + 1);
        ushort esInfoLen = read12(raw, offset + 3);
        offset += 5 + esInfoLen;

        if (streamType == 0x1B || streamType == 0x24)
        {
            info.videoPid = elemPid;
        }
        else if (streamType == 0x0F || streamType == 0x11)
        {
            info.audioPid = elemPid;
        }
    }

    if (info.videoPid != 0)
    {
        info.hasStreams = true;
    }
}

private:

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
