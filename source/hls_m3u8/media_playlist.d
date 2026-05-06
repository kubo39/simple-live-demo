module hls_m3u8.media_playlist;

import core.time : Duration, dur;
import std.array : appender;
import std.format : format;

struct SegmentEntry
{
    string uri;
    Duration duration;
}

enum HLS_VERSION = 3;

struct MediaPlaylist
{
    Duration targetDuration;
    uint mediaSequence;
    SegmentEntry[] segments;

    this(Duration targetDuration)
    {
        this.targetDuration = targetDuration;
    }

    void addSegment(string uri, Duration duration)
    {
        segments ~= SegmentEntry(uri, duration);
    }

    string serialize()
    {
        Duration maxDur = targetDuration;
        foreach (seg; segments)
        {
            if (seg.duration > maxDur)
                maxDur = seg.duration;
        }

        auto buf = appender!string;
        buf ~= "#EXTM3U\n";
        buf ~= format!"#EXT-X-VERSION:%d\n"(HLS_VERSION);
        buf ~= format!"#EXT-X-TARGETDURATION:%d\n"((maxDur.total!"msecs" + 999) / 1000);
        buf ~= format!"#EXT-X-MEDIA-SEQUENCE:%d\n"(mediaSequence);
        buf ~= "\n";

        foreach (seg; segments)
        {
            buf ~= format!"#EXTINF:%.3f,\n"(seg.duration.total!"msecs" / 1000.0);
            buf ~= seg.uri ~ "\n";
        }

        return buf[];
    }
}
