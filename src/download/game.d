module dmcl.download.game;

import dmcl.download;
import dmcl.utils : libNameToPath, getOSName, checkRules, readVersionJSONSafe,
    downloadSafe, writeSafe, getSafe, getPath;
import dmcl.config : config;

import std.net.curl : get;
import std.json : parseJSON;
import std.stdio : writeln;
import std.algorithm : find;
import std.file : mkdirRecurse, readText, exists, read;
import std.net.curl : download;
import std.format : format;
import std.path : baseName, extension;
import std.algorithm : startsWith, canFind;
import std.digest.sha : sha1Of, toHexString, LetterCase;

void showVersionList(string mirror, string[] type = ["release"])
{
    auto json = parseJSON(get(mc_meta[mirror] ~ "/mc/game/version_manifest.json"));
    foreach_reverse (ref ver; json["versions"].array)
    {
        if (type.find(ver["type"].str) != null)
        {
            writeln(ver["type"].str, " ", ver["id"].str);
        }
    }
}

void downloadVanilla(string mirror, string root_path, string version_id, string version_name)
{
    string getVersionURL()
    {
        auto json = parseJSON(get(mc_meta[mirror] ~ "/mc/game/version_manifest.json"));
        foreach_reverse (ref ver; json["versions"].array)
        {
            if (ver["id"].str == version_id)
            {
                return ver["url"].str;
            }
        }
        throw new Error("cannot find " ~ version_id);
    }

    writeln("%s.json".format(version_name));
    auto json = parseJSON(get(mirrorUrl(mirror, mc_meta, getVersionURL())));
    json["id"] = version_name;
    writeSafe("%s/versions/%s/%s.json".format(root_path, version_name, version_name), json.toString());
}

void downloadLibraries(string mirror, string root_path, string version_name)
{
    auto json = readVersionJSONSafe(root_path, version_name);
    downloadFile(DownloadFileMeta(
            mirrorUrl(mirror, mc_maven, json["downloads"]["client"]["url"].str),
            "%s/versions/%s/%s.jar".format(root_path, version_name, version_name),
            json["downloads"]["client"]["sha1"].str
    ));
    foreach (ref lib; json["libraries"].array)
    {
        if ("rules" !in lib || checkRules(lib["rules"]))
        {
            if ("downloads" in lib.object)
            { // easy-download libs
                if ("artifact" in lib["downloads"].object
                    && "url" in lib["downloads"]["artifact"].object)
                {
                    string savepath = lib["downloads"]["artifact"]["path"].str;
                    downloadFile(DownloadFileMeta(
                            mirrorUrl(mirror, null, lib["downloads"]["artifact"]["url"].str),
                            "%s/libraries/%s".format(root_path, savepath),
                            lib["downloads"]["artifact"]["sha1"].str
                    ));
                }
            }
            else
            { // difficult-download libs
                if ("url" !in lib.object)
                {
                    downloadFile(DownloadFileMeta(
                            mc_maven[mirror] ~ "/" ~ libNameToPath(lib["name"].str),
                            "%s/libraries/%s".format(root_path, libNameToPath(lib["name"].str))
                    ));
                }
                else
                {
                    if (lib["name"].str.startsWith("net.minecraftforge:forge:"))
                    { // this fucking file cannot be downloaded
                        continue;
                    }
                    final switch (lib["url"].str)
                    {
                    case "http://files.minecraftforge.net/maven/":
                        downloadFile(DownloadFileMeta(
                                forge_maven[mirror] ~ "/" ~ libNameToPath(lib["name"].str),
                                "%s/libraries/%s".format(root_path, libNameToPath(lib["name"].str))
                        ));
                        break;
                    }
                }
                // result ~= "%s/libraries/%s${classpath_separator}".format(
                //     option.root_path, libNameToPath(lib["name"].str));
            }
            if ("natives" in lib.object)
            { // native libs
                foreach (string native_name, ref native; lib["downloads"]["classifiers"])
                {
                    if (native_name.canFind(getOSName()))
                    {
                        downloadFile(DownloadFileMeta(
                                mirrorUrl(mirror, mc_maven, native["url"].str),
                                "%s/libraries/%s".format(root_path, native["path"].str),
                                native["sha1"].str
                        ));
                    }
                }
            }
        }
    }
}

void downloadAssets(string mirror, string root_path, string version_name)
{
    auto verjson = readVersionJSONSafe(root_path, version_name);
    string id = verjson["assetIndex"]["id"].str;
    string idx_path = getPath(root_path, "assets", "indexes", id ~ ".json");
    if (!(exists(idx_path) && toHexString!(LetterCase.lower)(sha1Of(read(idx_path)))
            == verjson["assetIndex"]["sha1"].str))
    {
        downloadSafe(verjson["assetIndex"]["url"].str, idx_path, verjson["assetIndex"]["sha1"].str);
        writeln(baseName(idx_path));
    }
    auto json = parseJSON(readText(idx_path));
    foreach (key, ref asset; json["objects"].object)
    {
        if (config.download_i_dont_need_music && extension(key) == ".ogg")
        {
            continue;
        }
        if ("virtual" in json.object && json["virtual"].boolean == true)
        { // 1.6 legacy
            string path = "%s/%s".format(asset["hash"].str[0 .. 2], asset["hash"].str);
            downloadFile(DownloadFileMeta(
                    mirrorUrl(mirror, mc_assets, "https://resources.download.minecraft.net/%s".format(path)),
                    "%s/assets/virtual/%s/%s".format(root_path, id, key), asset["hash"].str
            ));
        }
        else
        { // others
            string path = "%s/%s".format(asset["hash"].str[0 .. 2], asset["hash"].str);
            downloadFile(DownloadFileMeta(
                    mirrorUrl(mirror, mc_assets, "https://resources.download.minecraft.net/%s".format(path)),
                    "%s/assets/objects/%s".format(root_path, path), asset["hash"].str
            ));
        }
    }
}

void downloadGameFiles(string mirror, string root_path, string version_name)
{
    downloadLibraries(mirror, root_path, version_name);
    downloadAssets(mirror, root_path, version_name);
    waitDownloads();
}
