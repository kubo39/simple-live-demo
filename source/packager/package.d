module packager;

import std.stdio : File;

import mpeg2ts;
import packager.segmenter;

void runPackager(File input, string outputDir)
{
    StreamInfo streamInfo;
    auto segmenter = Segmenter(outputDir);

    ubyte[TS_PACKET_SIZE] buf;
    long firstPcr = -1;
    long currentPcr;

    while (true)
    {
        auto data = input.rawRead(buf[]);
        if (data.length == 0) break;
        if (data.length != TS_PACKET_SIZE) break;
        if (data[0] != SYNC_BYTE)
        {
            resync(input, buf);
            continue;
        }

        auto pkt = parsePacket(buf);

        if (pkt.hasPcr && streamInfo.hasStreams && pkt.pid == streamInfo.pcrPid)
        {
            if (firstPcr < 0)
            {
                firstPcr = pkt.pcrValue;
            }
            currentPcr = pkt.pcrValue;
        }

        if (pkt.pid == PAT_PID && pkt.payloadUnitStart)
        {
            parsePat(streamInfo, buf);
        }
        else if (streamInfo.hasPmt && pkt.pid == streamInfo.pmtPid && pkt.payloadUnitStart)
        {
            parsePmt(streamInfo, buf);
        }

        if (!streamInfo.hasStreams) continue;

        bool isKeyframe = (pkt.pid == streamInfo.videoPid) && pkt.randomAccess;
        segmenter.addPacket(pkt, isKeyframe, currentPcr);
    }

    segmenter.flush(currentPcr);
}

private void resync(ref File input, ref ubyte[TS_PACKET_SIZE] buf)
{
    ubyte[1] b;
    while (true)
    {
        auto data = input.rawRead(b[]);
        if (data.length == 0) return;
        if (b[0] == SYNC_BYTE)
        {
            buf[0] = SYNC_BYTE;
            input.rawRead(buf[1 .. $]);
            return;
        }
    }
}
