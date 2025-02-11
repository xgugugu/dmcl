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
import std.process : environment;
import std.math : abs;

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
        string[] possible_paths = [
            environment["ProgramFiles"],
            environment["ProgramFiles(x86)"],
            environment["APPDATA"]
        ];
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

JavaOption selectJava(long required_major)
{
    string java_name = config.launch_java;
    if (java_name == "autoselect")
    {
        if (config.launch_java_configs.length == 0)
        {
            findJava();
        }
        if (config.launch_java_configs.length == 0)
        {
            throw new Error("no configured java");
        }
        long minn = 1024;
        foreach (string name, ref path; config.launch_java_configs)
        {
            auto thisjava = JavaOption(path);
            if (thisjava.major_version >= required_major
                && abs(thisjava.major_version - required_major) < minn)
            {
                minn = abs(thisjava.major_version - required_major), java_name = name;
            }
            if (thisjava.major_version == required_major)
            {
                java_name = name;
                break;
            }
        }
        if (java_name == "autoselect")
        {
            java_name = config.launch_java_configs.keys[0];
        }
    }
    auto java = JavaOption(config.launch_java_configs[java_name]);
    if (java.major_version != required_major)
    {
        writeln("warning: using unsupported java version(require %s but using %s)"
                .format(required_major, java.major_version));
    }
    return java;
}
