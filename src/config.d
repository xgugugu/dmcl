module dmcl.config;

import dmcl.utils : getConfigPath;

import std.process : environment;
import std.json : parseJSON;
import std.file : readText, exists, getcwd;
import std.array : array, replaceFirst;
import std.path : asAbsolutePath;
import std.stdio : writeln;
import std.format : format;

struct Config
{
    // launch configs
    string launch_java_path = "java";
    string launch_minecraft_root_path = ".minecraft";
    int launch_window_width = 854;
    int launch_window_height = 480;
    int launch_min_memory = 512;
    int launch_max_memory = 2048;
    string launch_custom_info = "";
    string launch_additional_jvm = "-Dfml.ignoreInvalidMinecraftCertificates=True -Dfml.ignorePatchDiscrepancies=True";
    string launch_additional_game = "";
    // account configs
    bool account_online_mode = false;
    string account_username = "player";
    // download configs
    int download_max_tasks = 64;
    bool download_i_dont_need_music = false;
    int download_max_retry = 5;
    string download_mirror = "official";
}

Config config;

void readConfig(string path = getConfigPath() ~ "/dmcl.json")
{
    config.launch_minecraft_root_path = asAbsolutePath(config.launch_minecraft_root_path).array;
    if (exists(path))
    {
        auto json = parseJSON(readText(path));
        void conf(T)(immutable string key, ref T value)
        {
            if (key in json.object)
            {
                value = json[key].get!T;
            }
        }

        foreach (name; __traits(allMembers, Config))
        {
            conf(name.replaceFirst("_", "."), __traits(getMember, config, name));
        }
    }
}

void showConfig()
{
    writeln("CONFIG PATH: ", getConfigPath() ~ "/dmcl.json", "\n");
    foreach (name; __traits(allMembers, Config))
    {
        writeln("%s = %s".format(name.replaceFirst("_", "."), __traits(getMember, config, name)));
    }
}
