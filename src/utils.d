module dmcl.utils;

import std.system : os;
import std.zip : ZipArchive;
import std.file : read, write, mkdirRecurse, readText;
import std.array : split, replace;
import std.format : format;
import std.json : JSONValue, JSONType, parseJSON;
import std.path : absolutePath, buildNormalizedPath;
import std.array : array;

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
    string[] rawname = libname.split(":");
    string pkg = rawname[0], name = rawname[1], ver = rawname[2];
    return "%s/%s/%s/%s-%s.jar".format(pkg.replace(".", "/"), name, ver, name, ver);
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

void mergeJSON(ref JSONValue target, const ref JSONValue source)
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
