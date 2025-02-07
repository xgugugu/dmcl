module dmcl.download.multitasks;

import dmcl.config : config;
import dmcl.utils : getPath;

import std.parallelism : TaskPool, defaultPoolThreads, task;
import std.net.curl : download;
import std.array : replicate;
import std.file : mkdirRecurse, read, exists, write;
import std.path : dirName, baseName;
import std.digest.sha : sha1Of, toHexString, LetterCase;
import std.stdio : writeln;

void writeSafe(string filename, string context)
{
    mkdirRecurse(dirName(getPath(filename)));
    write(getPath(filename), context);
}

void downloadSafe(string url, string save_to)
{
    mkdirRecurse(dirName(getPath(save_to)));
    download(url, getPath(save_to));
}

struct DownloadFileMeta
{
    string url, save_to;
    string sha1;
}

int downloadFiles_downloadFunc(DownloadFileMeta meta)
{
    mkdirRecurse(dirName(meta.save_to));
    int retrycnt = 0;
    if (exists(meta.save_to) &&
        (toHexString!(LetterCase.lower)(sha1Of(read(meta.save_to))) == meta.sha1
            || meta.sha1 == null))
    {
        return 0;
    }
    while (true)
    {
        download(meta.url, meta.save_to);
        if (toHexString!(LetterCase.lower)(sha1Of(read(meta.save_to))) == meta.sha1
            || meta.sha1 == null)
        {
            break;
        }
        retrycnt++;
        if (retrycnt == config.download_max_retry)
        {
            throw new Error("retry too many times");
        }
    }
    writeln(baseName(meta.save_to));
    return 0;
}

TaskPool taskPool = null;

void downloadFile(DownloadFileMeta meta)
{
    if (taskPool is null)
    {
        taskPool = new TaskPool(config.download_max_tasks);
    }
    meta.save_to = getPath(meta.save_to);
    taskPool.put(task!downloadFiles_downloadFunc(meta));
}

void waitDownloads()
{
    if (!(taskPool is null))
    {
        taskPool.finish(true);
    }
}
