module dmcl.launch.java;

import dmcl.utils : getPath;
import dmcl.config : config, saveConfig;

import std.process : execute;
import std.algorithm : canFind;
import std.array : replace, split;
import std.conv : to;
import std.file : dirEntries, SpanMode;
import std.stdio : writeln;
import std.format : format;

struct JavaOption
{
    string path;
    string type;
    int arch;
    int major_version;
    string version_str;
    this(string arg_path)
    {
        path = arg_path;
        auto ret = execute([path, "-version"]).output;
        auto strs = ret.replace("\"", "").replace("\n", " ").split(" ");
        type = strs[0], version_str = strs[2];
        arch = ret.canFind("64-Bit") ? 64 : 32;
        auto vers = version_str.split(".");
        major_version = vers[0] != "1" ? to!int(vers[0]) : to!int(vers[1]);
    }
}

void findJava()
{
    version (Posix)
    {
        string[] possible_paths = ["/lib/jvm/"];
        string pattern = "java";
    }
    else version (Windows)
    {
        string[] possible_paths = [];
        string pattern = "java.exe";
        throw new Error("finding java are not supported on windows!");
    }
    else
    {
        string[] possible_paths = [];
        string pattern = "java";
        throw new Error("finding java are not supported on this platform!");
    }
    writeln("find following javas:");
    string[string] java_configs;
    foreach (ref p_path; possible_paths)
    {
        foreach (string path; dirEntries(p_path, pattern, SpanMode.depth, false))
        {
            auto java = JavaOption(path);
            string name = "%s-%s-bit-%s".format(java.type, java.arch, java.version_str);
            writeln(name, ": ", java.path);
            java_configs[name] = java.path;
        }
    }
    config.launch_java_configs = java_configs;
    config.launch_java = "autoselect";
    saveConfig!("launch_java_configs", "launch_java")();
}
