module ffmpeg;

import core.sys.posix.signal : SIGTERM, SIGKILL;
import core.thread : Thread;
import core.time : dur, seconds, MonoTime;

import std.process : Pid, ProcessPipes, pipeProcess, Redirect, kill, wait,
    tryWait;
import std.stdio : File;
import std.format : format;

import vibe.core.log;

import packager : runPackager;

struct FFmpegConfig
{
    string inputSource = "testsrc2=size=1280x720:rate=30";
    string inputFormat = "lavfi";
    string audioSource = "sine=frequency=440:sample_rate=48000";
    string audioFormat = "lavfi";
    string outputDir = "work";
    bool passthrough = false;
    string videoBitrate = "2M";
    string videoPreset = "veryfast";
    string videoScale = "-2:720";
    string audioBitrate = "128k";
    int keyframeInterval = 4;
}

enum State
{
    idle,
    starting,
    running,
    stopping,
}

struct FFmpegManager
{
    FFmpegConfig config;
    State state = State.idle;
    private ProcessPipes pipes;
    private Pid pid;
    private Thread packagerThread;

    void start()
    {
        if (state != State.idle) return;
        state = State.starting;

        auto args = buildArgs();
        logInfo("ffmpeg starting: %-(%s %)", args);

        pipes = pipeProcess(args, Redirect.stdout | Redirect.stderr);
        pid = pipes.pid;
        state = State.running;

        packagerThread = new Thread({
            runPackager(pipes.stdout, config.outputDir);
        });
        packagerThread.start();

        new Thread({
            foreach (line; pipes.stderr.byLine)
            {
                logWarn("ffmpeg: %s", line);
            }
        }).start();
    }

    void stop()
    {
        if (state != State.running) return;
        state = State.stopping;

        logInfo("ffmpeg stopping...");
        kill(pid, SIGTERM);

        auto deadline = MonoTime.currTime() + 5.seconds;
        while (MonoTime.currTime() < deadline)
        {
            auto status = tryWait(pid);
            if (status.terminated)
            {
                state = State.idle;
                if (packagerThread) packagerThread.join();
                logInfo("ffmpeg stopped");
                return;
            }
            Thread.sleep(dur!"msecs"(100));
        }

        logWarn("ffmpeg did not exit gracefully, sending SIGKILL");
        kill(pid, SIGKILL);
        wait(pid);
        if (packagerThread) packagerThread.join();
        state = State.idle;
    }

    private string[] buildArgs()
    {
        string[] args = [
            "ffmpeg",
            "-loglevel", "warning",
        ];

        // lavfi sources generate frames at CPU speed without -re (~12x real-time).
        // This causes a cascade: segments are deleted before the player fetches them
        // → 404 retries waste time → even more segments advance → 1-minute jumps.
        if (config.inputFormat == "lavfi")
        {
            args ~= "-re";
        }

        if (config.inputFormat.length > 0)
        {
            args ~= ["-f", config.inputFormat];
        }

        args ~= ["-i", config.inputSource];

        if (config.audioSource.length > 0)
        {
            if (config.audioFormat.length > 0)
            {
                args ~= ["-f", config.audioFormat];
            }
            args ~= ["-i", config.audioSource];
        }

        if (config.passthrough)
        {
            args ~= ["-c", "copy"];
        }
        else
        {
            args ~= [
                "-c:v", "libx264",
                "-preset", config.videoPreset,
                "-b:v", config.videoBitrate,
                "-vf", format!"scale=%s"(config.videoScale),
                "-force_key_frames",
                format!"expr:gte(t,n_forced*%d)"(config.keyframeInterval),
                "-c:a", "aac",
                "-b:a", config.audioBitrate,
            ];
        }

        args ~= [
            "-f", "mpegts",
            "pipe:1",
        ];
        return args;
    }
}
