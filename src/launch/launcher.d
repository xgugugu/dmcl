module dmcl.launch.launcher;

import dmcl.launch;
import dmcl.env : LAUNCHER_NAME, LAUNCHER_VERSION;
import dmcl.utils : getOSName, extractZip, libNameToPath, checkRules;

import std.format : format;
import std.file : readText, exists;
import std.json : JSONValue, JSONType, parseJSON;
import std.array : split, replace;
import std.system : os, arch = instructionSetArchitecture;
import std.conv : to;
import std.process : pipeProcess, escapeShellCommand, Redirect, Config;
import std.path : pathSeparator;

class GameLauncher
{
    LaunchOption option;
    string version_path;
    string natives_path;
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
                        result ~= "%s/libraries/%s${classpath_separator}".format(option.root_path,
                            lib["downloads"]["artifact"]["path"].str);
                    }
                }
                else
                { // modloader libs
                    result ~= "%s/libraries/%s${classpath_separator}".format(
                        option.root_path, libNameToPath(lib["name"].str));
                }
                if ("natives" in lib.object)
                { // native libs
                    if (getOSName() in lib["natives"].object)
                    {
                        string native_name = lib["natives"][getOSName()].str;
                        string jar_path = "%s/libraries/%s".format(option.root_path,
                            lib["downloads"]["classifiers"][native_name]["path"].str);
                        extractZip(jar_path, natives_path);
                    }
                }
            }
        }
        if ("inheritsFrom" in json.object)
        { // if json based on another, add it to cp
            auto oriver = json["inheritsFrom"].str;
            result ~= "%s/versions/%s/%s.jar${classpath_separator}".format(option.root_path, oriver, oriver);
        }
        if (exists("%s/%s.jar".format(version_path, option.version_name)))
        {
            result ~= "%s/%s.jar".format(version_path, option.version_name);
        }
        return result;
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
                    args ~= arg["value"].str;
                }
            }
            return args;
        }
    }

    string[] genArgs()
    {
        string[] args;
        // java path
        args ~= option.java_path;
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
                .replace("${natives_directory}", natives_path)
                .replace("${launcher_name}", LAUNCHER_NAME)
                .replace("${launcher_version}", LAUNCHER_VERSION)
                .replace("${classpath}", getLibraries())
                .replace("${library_directory}", option.root_path ~ "/libraries")
                .replace("${auth_player_name}", option.account.getName())
                .replace("${auth_uuid}", option.account.getUUID())
                .replace("${uuid}", option.account.getUUID())
                .replace("${version_name}", json["id"].str)
                .replace("${game_directory}", version_path)
                .replace("${assets_root}", option.root_path ~ "/assets")
                .replace("${assets_index_name}", json["assetIndex"]["id"].str)
                .replace("${auth_access_token}", option.account.getAccessToken())
                .replace("${auth_session}", option.account.getAccessToken())
                .replace("${user_type}", option.account.getType())
                .replace("${version_type}", option.custom_info)
                .replace("${user_properties}", "{}")
                .replace("${game_assets}", json["assetIndex"]["id"].str == "legacy" ?
                        option.root_path ~ "/assets/virtual/legacy" : option.root_path ~ "/assets")
                .replace("${classpath_separator}", pathSeparator);
        }
        return args;
    }

public:
    this(LaunchOption arg_option)
    {
        option = arg_option;
        version_path = "%s/versions/%s".format(option.root_path, option.version_name);
        natives_path = "%s/%s-%s-%s-natives".format(version_path, getOSName(), to!string(arch), LAUNCHER_NAME);
        json = parseJSON(readText("%s/%s.json".format(version_path, option.version_name)));
        if ("inheritsFrom" in json.object)
        { // if json based on another, merge them
            auto oriver = json["inheritsFrom"].str;
            auto orijson = parseJSON(readText("%s/versions/%s/%s.json".format(option.root_path, oriver, oriver)));
            foreach (string key, ref value; orijson)
            {
                if (key !in json)
                {
                    json[key] = orijson[key];
                }
                else if (key in json && json[key].type == JSONType.array)
                {
                    json[key].array = orijson[key].array ~ json[key].array;
                }
            }
        }
    }

    string generateCommand()
    {
        return escapeShellCommand(genArgs());
    }

    GameMonitor launchGame()
    {
        pipeProcess(genArgs(), Redirect.all, null, Config.none, version_path);
        return new GameMonitor();
    }
}
