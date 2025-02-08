module dmcl.launch.launcher;

import dmcl.launch;
import dmcl.config : config;
import dmcl.env : LAUNCHER_NAME, LAUNCHER_VERSION;
import dmcl.utils : getOSName, extractZip, libNameToPath, checkRules, mergeJSON, readVersionJSONSafe, getPath;

import std.format : format;
import std.file : readText, exists, tempDir;
import std.json : JSONValue, JSONType, parseJSON;
import std.array : split, replace, replaceLast;
import std.system : os, arch = instructionSetArchitecture;
import std.conv : to;
import std.process : pipeProcess, escapeShellCommand, Redirect, Config;
import std.path : pathSeparator, driveName;
import std.stdio : writeln;
import std.uuid : sha1UUID;
import std.math : abs;

class GameLauncher
{
    LaunchOption option;
    string version_path;
    string natives_path;
    JavaOption java;
    JSONValue json;

    string getLibraries()
    {
        string result;
        foreach (ref lib; json["libraries"].array)
        {
            if ("rules" !in lib || checkRules(lib["rules"]))
            {
                if ("downloads" in lib.object)
                { // vanllia libs
                    if ("artifact" in lib["downloads"].object)
                    { // java libs
                        result ~= getPath("%s/libraries/%s${classpath_separator}".format(option.root_path,
                                lib["downloads"]["artifact"]["path"].str));
                    }
                }
                else
                { // modloader libs
                    result ~= getPath("%s/libraries/%s${classpath_separator}".format(
                            option.root_path, libNameToPath(lib["name"].str)));
                }
                if ("natives" in lib.object)
                { // native libs
                    if (getOSName() in lib["natives"].object)
                    {
                        string native_name = lib["natives"][getOSName()].str
                            .replace("${arch}", to!string(java.arch));
                        string jar_path = getPath("%s/libraries/%s".format(option.root_path,
                                lib["downloads"]["classifiers"][native_name]["path"].str));
                        extractZip(jar_path, natives_path);
                    }
                }
            }
        }
        if ("inheritsFrom" in json.object)
        { // if json based on another, add it to cp
            auto oriver = json["inheritsFrom"].str;
            result ~= getPath("%s/versions/%s/%s.jar${classpath_separator}"
                    .format(option.root_path, oriver, oriver));
        }
        if (exists(getPath("%s/%s.jar".format(version_path, option.version_name))))
        {
            result ~= getPath("%s/%s.jar${classpath_separator}".format(version_path, option
                    .version_name));
        }
        return result.replaceLast("${classpath_separator}", "");
    }

    string[] getArguments(string key)
    {
        if ("arguments" !in json.object)
        { // 1.12.2 or above
            return null;
        }
        else
        { // 1.13 or later
            auto json_args = json["arguments"][key];
            string[] args;
            foreach (ref arg; json_args.array)
            {
                if (arg.type != JSONType.object)
                {
                    args ~= arg.str;
                }
                else if ("rules" in arg && checkRules(arg["rules"]))
                {
                    if (arg["value"].type == JSONType.array)
                    {
                        foreach (ref val; arg["value"].array)
                        {
                            args ~= val.str;
                        }
                    }
                    else
                    {
                        args ~= arg["value"].str;
                    }
                }
            }
            return args;
        }
    }

    void selectJava()
    {
        string java_name = config.launch_java;
        auto required_major = json["javaVersion"]["majorVersion"].integer;
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
        java = JavaOption(config.launch_java_configs[java_name]);
        if (java.major_version != required_major)
        {
            writeln("warning: using unsupported java version(require %s but using %s)"
                    .format(required_major, java.major_version));
        }
    }

    string[] genArgs()
    {
        string[] args;
        // java path
        selectJava();
        args ~= java.path;
        // jvm args
        if ("arguments" in json.object)
        { // 1.13 or later
            args ~= getArguments("jvm");
        }
        else
        { // 1.12.2 or above
            args ~= [
                "-Djava.library.path=${natives_directory}",
                "-cp", "${classpath}"
            ];
        }
        // additional jvm args
        args ~= option.additional_jvm.split(" ");
        // memory limits
        args ~= [
            "-Xmn%sm".format(option.min_memory),
            "-Xmx%sm".format(option.max_memory)
        ];
        // main class
        args ~= json["mainClass"].str;
        // game args
        if ("arguments" in json.object)
        { // 1.13 or later
            args ~= getArguments("game");
        }
        else
        { // 1.12.2 or above
            args ~= json["minecraftArguments"].str.split(" ");
        }
        // width and height
        args ~= [
            "--width", to!string(option.window_width),
            "--height", to!string(option.window_height)
        ];
        // additional game args
        args ~= option.additional_game.split(" ");
        // replace templates
        foreach (ref arg; args)
        {
            arg = arg
                .replace("${natives_directory}", getPath(natives_path))
                .replace("${launcher_name}", LAUNCHER_NAME)
                .replace("${launcher_version}", LAUNCHER_VERSION)
                .replace("${classpath}", getLibraries())
                .replace("${library_directory}", getPath(option.root_path, "libraries"))
                .replace("${auth_player_name}", option.account.getName())
                .replace("${auth_uuid}", option.account.getUUID())
                .replace("${uuid}", option.account.getUUID())
                .replace("${version_name}", json["id"].str)
                .replace("${game_directory}", version_path)
                .replace("${assets_root}", getPath(option.root_path, "assets"))
                .replace("${assets_index_name}", json["assetIndex"]["id"].str)
                .replace("${auth_access_token}", option.account.getAccessToken())
                .replace("${auth_session}", option.account.getAccessToken())
                .replace("${user_type}", option.account.getType())
                .replace("${version_type}", option.custom_info)
                .replace("${user_properties}", "{}")
                .replace("${game_assets}", getPath(json["assetIndex"]["id"].str == "legacy" ?
                        option.root_path ~ "/assets/virtual/legacy" : option.root_path ~ "/assets"))
                .replace("${classpath_separator}", pathSeparator);
        }
        return args;
    }

public:
    this(LaunchOption arg_option)
    {
        option = arg_option;
        version_path = getPath("%s/versions/%s".format(option.root_path, option.version_name));
        natives_path = getPath(tempDir(), "dmcl-natives-%s"
                .format(sha1UUID(option.version_name).toString()));
        json = readVersionJSONSafe(option.root_path, option.version_name);
    }

    string generateCommand()
    {
        return escapeShellCommand(genArgs());
    }

    GameMonitor launchGame()
    {
        auto args = genArgs();
        writeln("command: ", escapeShellCommand(["cd", driveName(version_path)]), " && ",
            escapeShellCommand(["cd", version_path]), " && ", escapeShellCommand(args));
        pipeProcess(args, Redirect.all, null, Config.none, version_path);
        return new GameMonitor();
    }
}
