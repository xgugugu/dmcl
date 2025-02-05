module dmcl.utils;

import std.system : os;
import std.zip : ZipArchive;
import std.file : read, write, mkdirRecurse;
import std.array : split, replace;
import std.format : format;
import std.json : JSONValue;
import std.path : asAbsolutePath;
import std.array : array;
import std.process : environment;

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
    auto zip = new ZipArchive(read(filename));
    mkdirRecurse(extract_to);
    foreach (member; zip.directory)
    {
        if (member.name[$ - 1] == '/')
            mkdirRecurse(extract_to ~ '/' ~ member.name);
        else
            write(extract_to ~ '/' ~ member.name, zip.expand(member));
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
                    || ("name" !in rule["os"].object)))
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

string getConfigPath()
{
    version (Windows)
    {
        return environment["APPDATA"];
    }
    else version (Posix)
    {
        return environment["HOME"] ~ "/.config";
    }
    else
    {
        return asAbsolutePath(".").array;
    }
}
