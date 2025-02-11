module dmcl.config;

import dmcl.utils : getPath;
import dmcl.env : LAUNCHER_NAME;

import std.process : environment;
import std.json : parseJSON, toJSON;
import std.file : readText, exists, getcwd, write;
import std.array : array, replaceFirst;
import std.stdio : writeln;
import std.format : format;
import std.traits : isAssociativeArray, ValueType;
import std.process : environment;

struct Config
{
    // launch configs
    string[string] launch_java_configs;
    string launch_java = "autoselect";
    string launch_minecraft_root_path = ".minecraft";
    int launch_window_width = 854;
    int launch_window_height = 480;
    int launch_min_memory = 512;
    int launch_max_memory = 2048;
    string launch_custom_info = LAUNCHER_NAME;
    string launch_additional_jvm = "-Dfml.ignoreInvalidMinecraftCertificates=True -Dfml.ignorePatchDiscrepancies=True";
    string launch_additional_game = "";
    // account configs
    bool account_online_mode = false;
    string account_username = "player";
    // download configs
    int download_max_tasks = 64;
    bool download_i_dont_need_music = false;
    string download_mirror = "official";
}

Config config;

string getConfigPath()
{
    version (Windows)
    {
        return getPath(environment["APPDATA"], "dmcl.json");
    }
    else version (Posix)
    {
        return getPath(environment["HOME"], ".config", "dmcl.json");
    }
    else
    {
        return getPath(".", "dmcl.json");
    }
}

void readConfig(string path = getConfigPath())
{
    if (exists(path))
    {
        auto json = parseJSON(readText(path));
        void conf(T)(immutable string key, ref T value)
        {
            if (key in json.object)
            {
                static if (isAssociativeArray!T)
                {
                    foreach (string x, ref y; json[key].object)
                    {
                        value[x] = y.get!(ValueType!T);
                    }
                }
                else
                {
                    value = json[key].get!T;
                }
            }
        }

        foreach (name; __traits(allMembers, Config))
        {
            conf(name.replaceFirst("_", "."), __traits(getMember, config, name));
        }
    }
    config.launch_minecraft_root_path = getPath(config.launch_minecraft_root_path);
}

void showConfig()
{
    writeln("CONFIG PATH: ", getConfigPath(), "\n");
    foreach (name; __traits(allMembers, Config))
    {
        writeln("%s = %s".format(name.replaceFirst("_", "."), __traits(getMember, config, name)));
    }
}

void saveConfig(names...)()
{
    auto json = parseJSON("{}");
    if (exists(getConfigPath()))
    {
        json = parseJSON(readText(getConfigPath()));
    }
    foreach (name; names)
    {
        static if (isAssociativeArray!(typeof(__traits(getMember, config, name))))
        {
            auto obj = parseJSON("{}");
            foreach (string x, ref y; __traits(getMember, config, name))
            {
                obj.object[x] = y;
            }
            json.object[name.replaceFirst("_", ".")] = obj;
        }
        else
        {
            json.object[name.replaceFirst("_", ".")] = __traits(getMember, config, name);
        }
    }
    write(getConfigPath(), toJSON(json, true));
}
