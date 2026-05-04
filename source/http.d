module http;

import std.conv : to;
import std.file : exists, read;
import std.path : buildPath, extension;
import std.string : indexOf;

import vibe.http.fileserver : serveStaticFiles;
import vibe.http.router : URLRouter;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse, HTTPServerSettings,
    listenHTTP;
import vibe.http.status : HTTPStatus;

void startHttpServer(string workDir, ushort port = 8080)
{
    auto router = new URLRouter;

    router.get("/live/*", serveLive(workDir));
    router.get("/*", serveStaticFiles("static/"));

    auto settings = new HTTPServerSettings;
    settings.port = port;
    settings.bindAddresses = ["0.0.0.0"];
    listenHTTP(settings, router);
}

private auto serveLive(string workDir)
{
    return (scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        auto path = req.requestPath.toString()["/live/".length .. $];

        if (indexOf(path, "..") != -1)
        {
            res.statusCode = HTTPStatus.badRequest;
            res.writeBody("invalid path");
            return;
        }

        auto ext = extension(path);
        if (ext != ".m3u8" && ext != ".ts")
        {
            res.statusCode = HTTPStatus.badRequest;
            res.writeBody("unsupported format");
            return;
        }

        auto fullPath = buildPath(workDir, path);
        if (!exists(fullPath))
        {
            res.statusCode = HTTPStatus.notFound;
            res.writeBody("not found");
            return;
        }

        auto data = cast(ubyte[]) read(fullPath);

        res.headers["Access-Control-Allow-Origin"] = "*";
        res.headers["Content-Length"] = to!string(data.length);

        if (ext == ".m3u8")
        {
            res.headers["Content-Type"] = "application/vnd.apple.mpegurl";
            res.headers["Cache-Control"] = "no-cache, no-store";
        }
        else
        {
            res.headers["Content-Type"] = "video/mp2t";
            res.headers["Cache-Control"] = "public, max-age=60";
        }

        res.writeBody(data);
    };
}
