module dmcl.cli.dmcl;

import dmcl.cli;

import std.stdio : writeln;
import std.file : getcwd;

import dmcl.launch;
import dmcl.account;
import dmcl.download;
import dmcl.config;

struct DmclCli
{
    mixin CLI_HELP!DmclCli;

    @Command("config", "show config")
    static void config_func()
    {
        showConfig();
    }

    @Command("launch", "launch game")
    @UnnamedParam!string("vername", "version-name")
    static void launch(string vername)
    {
        auto account = new OfflineAccount(config.account_username);
        LaunchOption option = {
            account, config.launch_java_path, config.launch_minecraft_root_path, vername
        };
        auto launcher = new GameLauncher(option);
        writeln(launcher.generateCommand());
        launcher.launchGame();
    }

    @Command("list-mc", "show minecraft version list")
    @NamedParam!(string[])("type", "type", "release,snapshot,...", ["release"])
    static void list_mc(string[] type)
    {
        showVersionList(config.download_mirror, type);
    }

    @Command("install", "install game")
    @UnnamedParam!string("verid", "version-id")
    @UnnamedParam!string("vername", "version-name")
    static void install(string verid, string vername)
    {
        downloadVanilla(config.download_mirror, getcwd() ~ "/.minecraft", verid, vername);
    }
}
