module packager.playlist;

import std.array : appender;
import std.file : rename, write;
import std.format : format;
import std.path : buildPath;

struct SegmentEntry
{
    string filename;
    double duration;
}

struct PlaylistManager
{
    string outputDir;
    string playlistName;
    uint targetDuration;
    uint maxSegments;
    SegmentEntry[] segments;
    uint mediaSequence;

    void initialize(string dir, uint target = 4, uint maxSegs = 5)
    {
        outputDir = dir;
        playlistName = "stream.m3u8";
        targetDuration = target;
        maxSegments = maxSegs;
    }

    void addSegment(string filename, double duration)
    {
        segments ~= SegmentEntry(filename, duration);

        if (segments.length > maxSegments)
        {
            segments = segments[1 .. $];
            mediaSequence++;
        }

        writePlaylist();
    }

    void writePlaylist()
    {
        import std.math : ceil;
        import std.algorithm : max;

        double maxDur = targetDuration;
        foreach (seg; segments)
        {
            maxDur = max(maxDur, seg.duration);
        }

        auto buf = appender!string;
        buf ~= "#EXTM3U\n";
        buf ~= "#EXT-X-VERSION:3\n";
        buf ~= format!"#EXT-X-TARGETDURATION:%d\n"(cast(uint) ceil(maxDur));
        buf ~= format!"#EXT-X-MEDIA-SEQUENCE:%d\n"(mediaSequence);
        buf ~= "\n";

        foreach (seg; segments)
        {
            buf ~= format!"#EXTINF:%.3f,\n"(seg.duration);
            buf ~= seg.filename ~ "\n";
        }

        string path = buildPath(outputDir, playlistName);
        string tmpPath = path ~ ".tmp";
        write(tmpPath, buf[]);
        rename(tmpPath, path);
    }
}
