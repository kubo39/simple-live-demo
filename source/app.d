module app;

import core.thread : Thread;

import std.file : exists, mkdirRecurse, rmdirRecurse;
import std.getopt : getopt, defaultGetoptPrinter;
import std.stdio : File, stdin, writeln, writefln;

import vibe.core.core : runApplication;
import vibe.core.log;

import ffmpeg : FFmpegManager;
import http : startHttpServer;
import packager : runPackager;

void main(string[] args)
{
    if (args.length > 1 && args[1] == "packager")
    {
        runPackagerCli(args[1 .. $]);
        return;
    }

    runServer(args);
}

private void runServer(string[] args)
{
    string outputDir = "work";
    string inputSource = "testsrc2=size=1280x720:rate=30";
    string inputFormat = "lavfi";
    ushort port = 8080;

    auto helpInfo = getopt(
        args,
        "output|o", "Output directory for segments", &outputDir,
        "input|i", "FFmpeg input source", &inputSource,
        "format|f", "FFmpeg input format (e.g. lavfi, flv)", &inputFormat,
        "port|p", "HTTP server port", &port,
    );

    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter(
            "Usage: simple-live-example [options]\n\n" ~
            "Start HTTP server and FFmpeg pipeline.\n",
            helpInfo.options,
        );
        return;
    }

    if (exists(outputDir))
    {
        rmdirRecurse(outputDir);
    }
    mkdirRecurse(outputDir);

    FFmpegManager mgr;
    mgr.config.inputSource = inputSource;
    mgr.config.inputFormat = inputFormat;
    mgr.config.outputDir = outputDir;

    startHttpServer(outputDir, port);
    logInfo("server listening on :%d", port);

    new Thread({ mgr.start(); }).start();

    runApplication();
}

private void runPackagerCli(string[] args)
{
    string outputDir = "work";
    string inputFile;

    auto helpInfo = getopt(
        args,
        "output|o", "Output directory for segments", &outputDir,
        "input|i", "Input MPEG-TS file (default: stdin)", &inputFile,
    );

    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter(
            "Usage: simple-live-example packager [options]\n\n" ~
            "Read MPEG-TS from stdin or file, output HLS segments.\n",
            helpInfo.options,
        );
        return;
    }

    mkdirRecurse(outputDir);

    File input;
    if (inputFile.length > 0)
    {
        input = File(inputFile, "rb");
    }
    else
    {
        input = stdin;
    }

    writefln!"[packager] reading from %s, output to %s/"(
        inputFile.length > 0 ? inputFile : "<stdin>", outputDir
    );

    runPackager(input, outputDir);

    writeln("[packager] done");
}
