module packager.segmenter;

import std.file : write, remove, exists, rename;
import std.format : format;
import std.path : buildPath;

import hls_m3u8 : MediaPlaylist, SegmentEntry;
import mpeg2ts : TSPacket, TS_PACKET_SIZE, PCR_CLOCK_RATE;

struct Segmenter
{
    string outputDir;
    uint targetDuration;
    uint maxDuration;
    uint maxSegments;
    MediaPlaylist playlist;

    private
    {
        ubyte[] currentSegment;
        uint segmentIndex;
        long segmentStartPcr;
        bool started;
    }

    this(string outputDir, uint targetDuration = 4, uint maxSegments = 5)
    {
        this.outputDir = outputDir;
        this.targetDuration = targetDuration;
        this.maxDuration = targetDuration * 2;
        this.maxSegments = maxSegments;
        this.playlist = MediaPlaylist(targetDuration);
    }

    void addPacket(ref TSPacket pkt, bool isKeyframe, long pcr)
    {
        if (!started)
        {
            if (!isKeyframe) return;
            started = true;
            segmentStartPcr = pcr;
        }

        double elapsed = cast(double)(pcr - segmentStartPcr) / PCR_CLOCK_RATE;
        bool shouldSplit = isKeyframe && elapsed >= targetDuration;
        bool forceSplit = elapsed >= maxDuration;

        if ((shouldSplit || forceSplit) && currentSegment.length > 0)
        {
            flushSegment(elapsed);
            segmentStartPcr = pcr;
        }

        currentSegment ~= pkt.data[];
    }

    void flush(long pcr)
    {
        if (currentSegment.length > 0)
        {
            double duration = cast(double)(pcr - segmentStartPcr) / PCR_CLOCK_RATE;
            if (duration <= 0) duration = targetDuration;
            flushSegment(duration);
        }
    }

    private void flushSegment(double duration)
    {
        string filename = format!"segment_%05d.ts"(segmentIndex);
        string path = buildPath(outputDir, filename);
        write(path, currentSegment);

        playlist.addSegment(filename, duration);

        if (playlist.segments.length > maxSegments)
        {
            playlist.segments = playlist.segments[1 .. $];
            playlist.mediaSequence++;
        }

        writePlaylist();
        segmentIndex++;
        currentSegment = null;

        cleanupOldSegments();
    }

    private void writePlaylist()
    {
        string path = buildPath(outputDir, "stream.m3u8");
        string tmpPath = path ~ ".tmp";
        write(tmpPath, playlist.serialize());
        rename(tmpPath, path);
    }

    private void cleanupOldSegments()
    {
        if (segmentIndex <= maxSegments + 2) return;

        uint oldest = segmentIndex - maxSegments - 3;
        string filename = format!"segment_%05d.ts"(oldest);
        string path = buildPath(outputDir, filename);
        if (exists(path))
        {
            remove(path);
        }
    }
}
