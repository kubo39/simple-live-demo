module packager.segmenter;

import core.time : Duration, dur, seconds;
import std.file : write, remove, exists, rename;
import std.format : format;
import std.path : buildPath;

import hls_m3u8 : MediaPlaylist, MediaSegment;
import mpeg2ts : TSPacket, TS_PACKET_SIZE, PCR_CLOCK_RATE;

struct Segmenter
{
    string outputDir;
    Duration targetDuration;
    Duration maxDuration;
    uint maxSegments;
    MediaPlaylist playlist;

    private
    {
        ubyte[] currentSegment;
        uint segmentIndex;
        long segmentStartPcr;
        bool started;
    }

    this(string outputDir, Duration targetDuration = 4.seconds, uint maxSegments = 5)
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

        auto elapsed = pcrToDuration(pcr - segmentStartPcr);
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
            auto duration = pcrToDuration(pcr - segmentStartPcr);
            if (duration <= Duration.zero) duration = targetDuration;
            flushSegment(duration);
        }
    }

    private void flushSegment(Duration duration)
    {
        string filename = format!"segment_%05d.ts"(segmentIndex);
        string path = buildPath(outputDir, filename);
        write(path, currentSegment);

        playlist.addSegment(MediaSegment(filename, duration));

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

// PCR (90kHz) を Duration に変換
private Duration pcrToDuration(long pcrTicks)
{
    return dur!"usecs"(pcrTicks * 1_000_000 / PCR_CLOCK_RATE);
}
