module dmcl.download.multitasks;

import dmcl.config : config;
import dmcl.utils : getPath, getDownload, writeSafe, downloadSafe;

import std.parallelism : TaskPool, defaultPoolThreads, task;
import std.array : replicate;
import std.stdio : writeln;
import std.path : baseName;
import std.file : exists, read;
import std.digest.sha : sha1Of, toHexString, LetterCase;

struct DownloadFileMeta
{
    string url, save_to;
    string sha1;
}

int downloadFiles_downloadFunc(DownloadFileMeta meta)
{
    if (!(exists(meta.save_to) && (meta.sha1 == null
            || toHexString!(LetterCase.lower)(sha1Of(read(meta.save_to))) == meta.sha1)))
    {
        downloadSafe(meta.url, meta.save_to, meta.sha1);
        writeln(baseName(meta.save_to));
    }
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
        taskPool = null;
    }
}
