module dmcl.utils;

import std.system : os;
import std.zip : ZipArchive;
import std.file : read, write, mkdirRecurse, readText, exists;
import std.array : split, replace;
import std.format : format;
import std.json : JSONValue, JSONType, parseJSON;
import std.path : absolutePath, buildNormalizedPath, dirName, baseName;
import std.array : array;
import std.digest.sha : sha1Of, toHexString, LetterCase;
import std.net.curl : get, AutoProtocol, CurlException;
import std.stdio : writeln;
import std.algorithm : canFind, splitter;
import std.conv : to;
import std.regex : regex, replaceAll;
import core.stdc.stdlib : exit;

string getPath(string[] paths...)
{
    return absolutePath(buildNormalizedPath(paths));
}

string getOSName()
{
    if (os == os.win32 || os == os.win64)
    {
        return "windows";
    }
    else if (os == os.linux)
    {
        return "linux";
    }
    else if (os == os.osx)
    {
        return "osx";
    }
    return "unknown";
}

void extractZip(string filename, string extract_to)
{
    auto zip = new ZipArchive(read(getPath(filename)));
    mkdirRecurse(getPath(extract_to));
    foreach (member; zip.directory)
    {
        if (member.name[$ - 1] == '/')
            mkdirRecurse(getPath(extract_to, member.name));
        else
            write(getPath(extract_to, member.name), zip.expand(member));
    }
}

string libNameToPath(string libname)
{
    if (!libname.canFind("@"))
        libname ~= "@jar";
    string[] rawstr = libname.split("@");
    string ext = rawstr[1];
    string[] rawname = rawstr[0].split(":");
    string pkg = rawname[0], name = rawname[1], ver = rawname[2];
    string path = "%s/%s/%s/%s".format(pkg.replace(".", "/"), name, ver, name);
    foreach (ref str; rawname[2 .. $])
    {
        path ~= "-" ~ str;
    }
    return path ~ "." ~ ext;
}

string libNameGetName(string libname)
{
    string[] rawname = libname.split(":");
    string name = rawname[0] ~ ":" ~ rawname[1];
    if (rawname.length > 3)
    {
        foreach (ref str; rawname[3 .. $])
        {
            name ~= ":" ~ str;
        }
    }
    return name;
}

string libNameGetVersion(string libname)
{
    return libname.split("@")[0].split(":")[2];
}

long compareVersion(string str1, string str2)
{
    auto reg = regex(r"[^0-9\.]");
    auto ver1 = str1.replaceAll(reg, "").splitter(".");
    auto ver2 = str2.replaceAll(reg, "").splitter(".");
    while (!ver1.empty() || !ver2.empty())
    {
        long n1 = ver1.empty() ? 0 : to!long(ver1.front());
        long n2 = ver2.empty() ? 0 : to!long(ver2.front());
        if (n1 != n2)
            return n1 - n2;
        if (!ver1.empty())
            ver1.popFront();
        if (!ver2.empty())
            ver2.popFront();
    }
    return 0;
}

bool checkRules(ref JSONValue rules)
{
    foreach (ref rule; rules.array)
    {
        if ("features" in rule.object)
        { // ignore features
            return false;
        }
        auto action = rule["action"].str;
        if (action == "allow")
        {
            if ("os" in rule.object && (("name" in rule["os"].object && rule["os"]["name"].str != getOSName())
                    || ("name" !in rule["os"].object) || ("version" in rule["os"].object)))
            {
                return false;
            }
        }
        else if (action == "disallow")
        {
            if ("os" in rule.object && "name" in rule["os"].object && rule["os"]["name"].str == getOSName())
            {
                return false;
            }
        }
    }
    return true;
}

void mergeJSON(ref JSONValue target, JSONValue source)
{
    if (target.type == JSONType.object && source.type == JSONType.object)
    {
        foreach (string key, ref value; source.object)
        {
            if (key in target.object)
            {
                mergeJSON(target[key], source[key]);
            }
            else
            {
                target.object[key] = source[key];
            }
        }
    }
    else if (target.type == JSONType.array && source.type == JSONType.array)
    {
        target.array ~= source.array;
    }
    else
    {
        target = source;
    }
}

JSONValue readVersionJSONSafe(string root_path, string version_name)
{
    auto json = parseJSON(readText(getPath(root_path, "versions", version_name, version_name ~ ".json")));
    if ("inheritsFrom" in json.object)
    { // if json based on another, merge them
        auto oriver = json["inheritsFrom"].str;
        auto orijson = parseJSON(readText(getPath(root_path, "versions", oriver, oriver ~ ".json")));
        // foreach (string key, ref value; orijson)
        // {
        //     if (key !in json)
        //     {
        //         json[key] = orijson[key];
        //     }
        //     else if (key in json && json[key].type == JSONType.array)
        //     {
        //         json[key].array = orijson[key].array ~ json[key].array;
        //     }
        // }
        mergeJSON(orijson, json), json = orijson;
    }
    return json;
}

void writeSafe(T)(string filename, T[] context)
{
    mkdirRecurse(dirName(getPath(filename)));
    write(getPath(filename), context);
}

string getSafe(string url)
{
    try
    {
        return cast(string)(get(url));
    }
    catch (CurlException e)
    {
        return null;
    }
}

ubyte[] getDownload(string url, string sha1 = null)
{
    int retrycnt = 0;
    while (true)
    {
        try
        {
            auto res = get!(AutoProtocol, ubyte)(url);
            if (sha1 == null || toHexString!(LetterCase.lower)(sha1Of(res)) == sha1)
            {
                return res;
            }
            else
            {
                throw new CurlException("Wrong sha1sum");
            }
        }
        catch (CurlException e)
        {
            if (retrycnt == 5)
            {
                writeln("Failed to GET ", url, ": ", "Retried too many times");
                break;
            }
            retrycnt++;
            writeln("Failed to GET ", url, ": ", e.msg, ". Retrying...");
        }
    }
    exit(-1);
}

void downloadSafe(string url, string save_to, string sha1 = null)
{
    auto res = getDownload(url, sha1);
    writeSafe(save_to, res);
}

bool checkFile(string path, string sha1)
{
    return exists(path) && (sha1 == null || toHexString!(LetterCase.lower)(
            sha1Of(read(path))) == sha1);
}
