module mpeg2ts.psi;

import mpeg2ts.packet : TS_PACKET_SIZE, readPid, read12, read16;

enum : ubyte
{
    TABLE_ID_PAT = 0x00,
    TABLE_ID_PMT = 0x02,
}

enum : ubyte
{
    STREAM_TYPE_H264 = 0x1B,
    STREAM_TYPE_H265 = 0x24,
    STREAM_TYPE_AAC = 0x0F,
    STREAM_TYPE_AAC_LATM = 0x11,
}

struct StreamInfo
{
    ushort pmtPid;
    ushort pcrPid;
    ushort videoPid;
    ushort audioPid;
    bool hasPmt;
    bool hasStreams;
}

void parsePat(ref StreamInfo info, ref const(ubyte)[TS_PACKET_SIZE] raw)
{
    size_t offset = 4;

    // adaptation field があればスキップしてペイロード先頭へ
    if ((raw[3] >> 4 & 0x02) != 0)
    {
        offset += 1 + raw[4];
    }

    // pointer_field: 前セクションの残りバイト数。非ゼロ(パケットまたぎ)は未対応
    if (raw[offset] != 0) return;
    offset++;

    if (raw[offset] != TABLE_ID_PAT) return;
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

    // adaptation field があればスキップしてペイロード先頭へ
    if ((raw[3] >> 4 & 0x02) != 0)
    {
        offset += 1 + raw[4];
    }

    // pointer_field: 前セクションの残りバイト数。非ゼロ(パケットまたぎ)は未対応
    if (raw[offset] != 0) return;
    offset++;

    if (raw[offset] != TABLE_ID_PMT) return;
    offset++;

    ushort sectionLength = read12(raw, offset);
    offset += 2 + 5;

    info.pcrPid = readPid(raw, offset);
    offset += 2;

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

        if (streamType == STREAM_TYPE_H264 || streamType == STREAM_TYPE_H265)
        {
            info.videoPid = elemPid;
        }
        else if (streamType == STREAM_TYPE_AAC || streamType == STREAM_TYPE_AAC_LATM)
        {
            info.audioPid = elemPid;
        }
    }

    if (info.videoPid != 0)
    {
        info.hasStreams = true;
    }
}
