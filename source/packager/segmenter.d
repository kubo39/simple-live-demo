module packager.segmenter;

import std.file : write, remove, exists;
import std.format : format;
import std.path : buildPath;

import packager.playlist : PlaylistManager;
import packager.ts_parser : TSPacket, TS_PACKET_SIZE;

struct Segmenter
{
    string outputDir;
    uint targetDuration;
    uint maxDuration;
    PlaylistManager playlist;

    private
    {
        ubyte[] currentSegment;
        uint segmentIndex;
        long segmentStartPcr;
        bool started;
    }

    void initialize(string dir, uint target = 4)
    {
        outputDir = dir;
        targetDuration = target;
        maxDuration = target * 2;
        playlist.initialize(dir, target);
        segmentIndex = 0;
        started = false;
    }

    void addPacket(ref TSPacket pkt, bool isKeyframe, long pcr)
    {
        if (!started)
        {
            if (!isKeyframe) return;
            started = true;
            segmentStartPcr = pcr;
        }

        double elapsed = cast(double)(pcr - segmentStartPcr) / 90_000.0;
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
            double duration = cast(double)(pcr - segmentStartPcr) / 90_000.0;
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
        segmentIndex++;
        currentSegment = null;

        cleanupOldSegments();
    }

    private void cleanupOldSegments()
    {
        if (segmentIndex <= playlist.maxSegments + 2) return;

        uint oldest = segmentIndex - playlist.maxSegments - 3;
        string filename = format!"segment_%05d.ts"(oldest);
        string path = buildPath(outputDir, filename);
        if (exists(path))
        {
            remove(path);
        }
    }
}
