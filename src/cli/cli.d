module dmcl.cli.cli;

import std.stdio : writeln;
import std.traits : getUDAs, isArray, hasStaticMember;
import std.algorithm : startsWith, findSplit, canFind;
import std.array : split;
import std.conv : to;
import std.functional : bind;

struct Command
{
    string name;
    string description = "";
}

struct Param(T, bool isNamed)
{
    string id, name, description;
    T default_value;
    bool named = isNamed;
    bool has_defval;

    this(string arg_id, string arg_name, string arg_description, T arg_default_value)
    {
        id = arg_id, name = arg_name;
        description = arg_description;
        default_value = arg_default_value;
        has_defval = true;
    }

    this(string arg_id, string arg_name = null)
    {
        if (arg_name == null)
            arg_name = arg_id;
        id = arg_id, description = name = arg_name;
        has_defval = false;
    }
}

alias NamedParam(T) = Param!(T, true);
alias UnnamedParam(T) = Param!(T, false);

mixin template CLI_HELP(T)
{
    @Command("help", "show help")
    static void help()
    {
        import std.stdio : writeln;
        import std.format : format;
        import std.traits : getUDAs;
        import std.conv : to;
        import std.path : baseName;
        import std.file : thisExePath;

        writeln("USAGE:");
        foreach (name; __traits(allMembers, T))
        {
            auto command = getUDAs!(__traits(getMember, T, name), Command);
            static if (command.length == 1)
            {
                string cmd = "\t%s %s ".format(baseName(thisExePath()), command[0].name);
                foreach (param; getUDAs!(__traits(getMember, T, name), Param))
                {
                    if (param.named)
                    {
                        if (param.description != null)
                        {
                            cmd ~= "--" ~ param.name ~ "=<" ~ param.description ~ "> ";
                        }
                        else
                        {
                            cmd ~= "--" ~ param.name ~ " ";
                        }
                    }
                    else
                    {
                        cmd ~= "<" ~ param.description ~ "> ";
                    }
                }
                writeln(cmd ~ ": " ~ command[0].description);
            }
        }
    }
}

void startCli(T)(string[] args, T cli)
{
    T cliTo(T)(ref string str)
    {
        if (isArray!T && !is(T == string))
        {
            return to!T(str.split(","));
        }
        return to!T(str);
    }

    // parse args
    string cmdname = args.length > 1 ? args[1] : "help";
    string[] unnamedargs;
    string[string] namedargs;
    foreach (ref arg; args.length > 2 ? args[2 .. $] : [])
    {
        if (arg.startsWith("--"))
        { // named arg
            if (arg[2 .. $].canFind("="))
            {
                auto str = arg[2 .. $].findSplit("=");
                namedargs[str[0]] = str[2];
                static if (hasStaticMember!(T, "preProcessArguments"))
                {
                    cli.preProcessArguments(cmdname, str[0], str[2]);
                }
            }
            else
            { // bool arg
                namedargs[arg[2 .. $]] = "true";
                static if (hasStaticMember!(T, "preProcessArguments"))
                {
                    cli.preProcessArguments(cmdname, arg[2 .. $], "true");
                }
            }
        }
        else
        { // unnamed arg
            unnamedargs ~= arg;
        }
    }
    // run func
    foreach (name; __traits(allMembers, T))
    {
        auto command = getUDAs!(__traits(getMember, cli, name), Command);
        static if (command.length == 1)
        {
            struct ParamStruct
            {
                static foreach (param; getUDAs!(__traits(getMember, cli, name), Param))
                {
                    mixin(typeof(param.default_value).stringof ~ " " ~ param.id ~ ";");
                }
            }

            if (command[0].name == cmdname)
            {
                ParamStruct params;
                int unnamed_idx = 0;
                foreach (param; getUDAs!(__traits(getMember, cli, name), Param))
                {
                    static if (param.named == true)
                    {
                        static if (is(typeof(param.default_value) == bool))
                        {
                            __traits(getMember, params, param.id) =
                                (param.name in namedargs) ? true : false;
                        }
                        else
                        {
                            bool param_inited = false;
                            if (param.has_defval)
                            {
                                __traits(getMember, params, param.id) = param.default_value;
                                param_inited = true;
                            }
                            if (param.name in namedargs)
                            {
                                __traits(getMember, params, param.id) =
                                    cliTo!(typeof(param.default_value))(namedargs[param.name]);
                                param_inited = true;
                            }
                            // if (param_inited == false)
                            // {
                            //     throw new Error("missing argument: " ~ param.id);
                            // }
                        }
                    }
                    else
                    {
                        __traits(getMember, params, param.id) =
                            cliTo!(typeof(param.default_value))(unnamedargs[unnamed_idx]);
                        unnamed_idx++;
                    }
                }
                params.bind!(__traits(getMember, cli, name));
                return;
            }
        }
    }
    writeln("unknown command");
}
