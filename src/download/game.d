module dmcl.download.game;

import dmcl.download;
import dmcl.utils : libNameToPath, getOSName, checkRules, readVersionJSONSafe;
import dmcl.config : config;

import std.net.curl : get;
import std.json : parseJSON;
import std.stdio : writeln;
import std.algorithm : find;
import std.file : mkdirRecurse, readText;
import std.net.curl : download;
import std.format : format;
import std.path : baseName, extension;

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
    writeSafe("%s/versions/%s/%s.json".format(root_path, version_name, version_name), json.toString());
    downloadFile(DownloadFileMeta(
            mirrorUrl(mirror, mc_maven, json["downloads"]["client"]["url"].str),
            "%s/versions/%s/%s.jar".format(root_path, version_name, version_name),
            json["downloads"]["client"]["sha1"].str
    ));
    downloadLibraries(mirror, root_path, version_name);
    downloadAssets(mirror, root_path, version_name);
    waitDownloads();
}

void downloadLibraries(string mirror, string root_path, string version_name)
{
    auto json = readVersionJSONSafe(root_path, version_name);
    foreach (ref lib; json["libraries"].array)
    {
        if ("rules" !in lib || checkRules(lib["rules"]))
        {
            if ("downloads" in lib.object)
            { // vanllia libs
                if ("artifact" in lib["downloads"].object)
                {
                    string savepath = lib["downloads"]["artifact"]["path"].str;
                    downloadFile(DownloadFileMeta(
                            mirrorUrl(mirror, mc_maven, lib["downloads"]["artifact"]["url"].str),
                            "%s/libraries/%s".format(root_path, savepath),
                            lib["downloads"]["artifact"]["sha1"].str
                    ));
                }
            }
            else
            { // modloader libs
                writeln("libraries without download url are unsupported");
                // result ~= "%s/libraries/%s${classpath_separator}".format(
                //     option.root_path, libNameToPath(lib["name"].str));
            }
            if ("natives" in lib.object)
            { // native libs
                if (getOSName() in lib["natives"].object)
                {
                    string native_name = lib["natives"][getOSName()].str;
                    string savepath = lib["downloads"]["classifiers"][native_name]["path"].str;
                    downloadFile(DownloadFileMeta(
                            mirrorUrl(mirror, mc_maven, lib["downloads"]["classifiers"][native_name]["url"]
                            .str),
                            "%s/libraries/%s".format(root_path, savepath),
                            lib["downloads"]["classifiers"][native_name]["sha1"].str
                    ));
                }
            }
        }
    }
}

void downloadAssets(string mirror, string root_path, string version_name)
{
    auto verjson = readVersionJSONSafe(root_path, version_name);
    string id = verjson["assetIndex"]["id"].str;
    auto json = parseJSON(get(mirrorUrl(mirror, mc_meta, verjson["assetIndex"]["url"].str)));
    writeSafe("%s/assets/indexes/%s.json".format(root_path, id), json.toString());
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
