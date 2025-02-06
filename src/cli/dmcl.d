module dmcl.cli.dmcl;

import dmcl.cli;

import std.stdio : writeln;
import std.file : getcwd;

import dmcl.launch;
import dmcl.account;
import dmcl.download;
import dmcl.config;
import dmcl.env;

struct DmclCli
{
    mixin CLI_HELP!DmclCli;

    @Command("version", "show version info")
    static void version_()
    {
        writeln(LAUNCHER_NAME ~ " version " ~ LAUNCHER_VERSION);
        writeln("build time: " ~ __DATE__ ~ " " ~ __TIME__);
    }

    @Command("config", "show config")
    static void config_cmd()
    {
        showConfig();
    }

    @Command("launch", "launch game")
    @UnnamedParam!string("vername", "version-name")
    static void launch(string vername)
    {
        auto account = new OfflineAccount(config.account_username);
        auto launcher = new GameLauncher(LaunchOption(
                account, config.launch_java_path, config.launch_minecraft_root_path, vername,
                config.launch_window_width, config.launch_window_height,
                config.launch_min_memory, config.launch_max_memory, config.launch_custom_info,
                config.launch_additional_jvm, config.launch_additional_game
        ));
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
