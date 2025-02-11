module dmcl.download.forge;

import dmcl.download;
import dmcl.launch : selectJava;
import dmcl.utils : getPath, getDownload, writeSafe, readVersionJSONSafe,
    mergeJSON, libNameToPath, checkFile;

import std.net.curl : get;
import std.json : parseJSON, JSONValue;
import std.algorithm : sort, startsWith;
import std.stdio : writeln;
import std.format : format;
import std.file : tempDir, readText, read;
import std.zip : ZipArchive;
import std.string : assumeUTF;
import std.path : baseName, pathSeparator;
import std.array : replace, replaceFirst, split;
import std.process : execute, Config;
import std.digest.sha : sha1Of, toHexString, LetterCase;
import std.string : strip;

// Forge
string bmclapiGetForgeVersionName(ref JSONValue ver)
{
    string name = ver["mcversion"].str ~ "-" ~ ver["version"].str;
    if ("branch" in ver.object && !ver["branch"].isNull())
    {
        name ~= "-" ~ ver["branch"].str;
    }
    return name;
}

void showForgeVersionList(string mirror, string mcver)
{
    // only support bmclapi
    auto json = parseJSON(get("https://bmclapi2.bangbang93.com/forge/minecraft/" ~ mcver));
    json.array.sort!((x, y) => x["build"].integer < y["build"].integer)();
    foreach (ver; json.array)
    {
        writeln(bmclapiGetForgeVersionName(ver));
    }
}

string getLatestForge(string mirror, string mcver)
{
    // only support bmclapi
    auto json = parseJSON(get("https://bmclapi2.bangbang93.com/forge/minecraft/" ~ mcver));
    json.array.sort!((x, y) => x["build"].integer > y["build"].integer)();
    return bmclapiGetForgeVersionName(json.array[0]);
}

void installForge(string mirror, string root_path, string vername, string forgever)
{
    auto verpath = getPath(root_path, "versions", vername, vername ~ ".json");
    auto mc_json = parseJSON(readText(verpath));
    // download instaler
    auto installer = getDownload("%s/net/minecraftforge/forge/%s/forge-%s-installer.jar"
            .format(forge_maven[mirror], forgever, forgever));
    writeln("forge-%s-installer.jar".format(forgever));
    auto zip = new ZipArchive(installer);
    // extract forge jar
    if ("maven/" in zip.directory)
    { // forge jar in path maven
        foreach (file; zip.directory)
        {
            if (file.name[$ - 1] != '/' && file.name.startsWith("maven/"))
            {
                writeSafe(getPath(file.name.replaceFirst("maven/", root_path ~ "/libraries/")),
                    zip.expand(zip.directory[file.name]));
                writeln(baseName(file.name));
            }
        }
    }
    else if ("version.json" !in zip.directory)
    { // forge jar in root
        auto forgelibpath = libNameToPath("net.minecraftforge:forge:" ~ forgever);
        auto profile = parseJSON(zip.expand(zip.directory["install_profile.json"]).assumeUTF());
        auto jarpath = profile["install"]["filePath"].str;
        writeSafe(getPath(root_path, "libraries", forgelibpath), zip.expand(zip.directory[jarpath]));
        writeln(baseName(forgelibpath));
    }
    if ("data/client.lzma" in zip.directory)
    { // 1.13+ generate forge-client.jar
        // download libraries
        auto profile = parseJSON(zip.expand(zip.directory["install_profile.json"]).assumeUTF());
        foreach (ref lib; profile["libraries"].array)
        {
            string savepath = lib["downloads"]["artifact"]["path"].str;
            downloadFile(DownloadFileMeta(
                    mirrorUrl(mirror, null, lib["downloads"]["artifact"]["url"].str),
                    "%s/libraries/%s".format(root_path, savepath),
                    lib["downloads"]["artifact"]["sha1"].str
            ));
        }
        downloadLibraries(mirror, root_path, vername);
        waitDownloads();
        // extract client.lzma
        string tmp_path = getPath(tempDir(), "dmcl-forge-" ~ forgever ~ "-autoinstall");
        string lzma_path = getPath(tmp_path, "client.lzma");
        writeSafe(lzma_path, zip.expand(zip.directory["data/client.lzma"]));
        // run steps
        auto java = selectJava(mc_json["javaVersion"]["majorVersion"].integer);
        foreach (ref step; profile["processors"].array)
        {
            // ignore server
            bool isClient()
            {
                if ("sides" !in step)
                {
                    return true;
                }
                foreach (ref side; step["sides"].array)
                {
                    if (side.str == "client")
                    {
                        return true;
                    }
                }
                return false;
            }

            if (!isClient())
            {
                continue;
            }
            // generate arguments
            string getArg(string arg)
            {
                if (arg[0] == '{' && arg[$ - 1] == '}')
                {
                    switch (arg[1 .. $ - 1])
                    {
                    case "MINECRAFT_JAR":
                        arg = getPath(root_path, "versions", vername, vername ~ ".jar");
                        break;
                    case "SIDE":
                        arg = "client";
                        break;
                    default:
                        arg = profile["data"][arg[1 .. $ - 1]]["client"].str;
                    }
                }
                if (arg == "/data/client.lzma")
                {
                    arg = lzma_path;
                }
                if (arg[0] == '[' && arg[$ - 1] == ']')
                {
                    arg = getPath(root_path, "libraries", libNameToPath(arg[1 .. $ - 1]));
                }
                if (arg[0] == '\'' && arg[$ - 1] == '\'')
                {
                    arg = arg[1 .. $ - 1];
                }
                return arg;
            }
            // classpaths
            string cp_str = getPath(root_path, "libraries", libNameToPath(step["jar"].str));
            foreach (ref cp; step["classpath"].array)
            {
                cp_str ~= pathSeparator ~ getPath(root_path, "libraries",
                    libNameToPath(cp.str));
            }
            // args
            string[] args;
            foreach (ref json_arg; step["args"].array)
            {
                args ~= getArg(json_arg.str);
            }
            // main class
            auto main_jar = new ZipArchive(read(getPath(root_path, "libraries",
                    libNameToPath(step["jar"].str))));
            auto manifest = main_jar.expand(main_jar.directory["META-INF/MANIFEST.MF"]).assumeUTF();
            string mainclass = cast(string)(
                manifest.split("Main-Class: ")[1].split('\n')[0].strip());
            // execute!
            string[] cmd = [java.path, "-cp", cp_str, mainclass] ~ args;
            auto res = execute(cmd, null, Config.none, size_t.max, tmp_path);
            if (res.status != 0)
            {
                writeln(res.output);
                throw new Error("failed to run " ~ step["jar"].str ~ ". command: %s".format(cmd));
            }
            // checksums
            if ("outputs" in step.object)
            {
                foreach (key, value; step["outputs"].object)
                {
                    if (!checkFile(getArg(key), getArg(value.str)))
                    {
                        throw new Error(getArg(key) ~ ": wrong sha1sum");
                    }
                }
            }
            // end
            writeln("finished ", step["jar"].str);
        }
    }
    // generate version json    
    string getVersionJson()
    {
        if ("version.json" in zip.directory)
        {
            return zip.expand(zip.directory["version.json"]).assumeUTF();
        }
        else
        {
            auto profile = parseJSON(zip.expand(zip.directory["install_profile.json"]).assumeUTF());
            auto zip2path = profile["install"]["filePath"].str;
            auto zip2 = new ZipArchive(zip.expand(zip.directory[zip2path]));
            return zip2.expand(zip2.directory["version.json"]).assumeUTF();
        }
    }

    mergeJSON(mc_json, parseJSON(getVersionJson()));
    mc_json.object.remove("_comment_");
    mc_json.object.remove("inheritsFrom");
    mc_json["id"] = vername, mc_json["jar"] = vername;
    writeSafe(verpath, mc_json.toString());
}
