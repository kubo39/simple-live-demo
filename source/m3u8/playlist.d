module m3u8.playlist;

import std.algorithm : max;
import std.array : appender;
import std.format : format;
import std.math : ceil;

struct SegmentEntry
{
    string uri;
    double duration;
}

enum HLS_VERSION = 3;

struct MediaPlaylist
{
    uint targetDuration;
    uint maxSegments;
    uint mediaSequence;
    SegmentEntry[] segments;

    this(uint targetDuration, uint maxSegments = 5)
    {
        this.targetDuration = targetDuration;
        this.maxSegments = maxSegments;
    }

    void addSegment(string uri, double duration)
    {
        segments ~= SegmentEntry(uri, duration);

        if (segments.length > maxSegments)
        {
            segments = segments[1 .. $];
            mediaSequence++;
        }
    }

    string serialize()
    {
        double maxDur = targetDuration;
        foreach (seg; segments)
        {
            maxDur = max(maxDur, seg.duration);
        }

        auto buf = appender!string;
        buf ~= "#EXTM3U\n";
        buf ~= format!"#EXT-X-VERSION:%d\n"(HLS_VERSION);
        buf ~= format!"#EXT-X-TARGETDURATION:%d\n"(cast(uint) ceil(maxDur));
        buf ~= format!"#EXT-X-MEDIA-SEQUENCE:%d\n"(mediaSequence);
        buf ~= "\n";

        foreach (seg; segments)
        {
            buf ~= format!"#EXTINF:%.3f,\n"(seg.duration);
            buf ~= seg.uri ~ "\n";
        }

        return buf[];
    }
}
