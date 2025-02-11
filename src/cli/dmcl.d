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

    static void preProcessArguments(string _, string key, string value)
    {
        switch (key)
        {
        case "java":
            config.launch_java_configs[value] = value;
            config.launch_java = value;
            break;
        case "mirror":
            config.download_mirror = value;
            break;
        default:
            break;
        }
    }

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

    @Command("find-java", "auto find java")
    static void find_java()
    {
        findJava();
    }

    @Command("launch", "launch game")
    @UnnamedParam!string("vername", "version-name")
    static void launch(string vername)
    {
        downloadGameFiles(config.download_mirror, config.launch_minecraft_root_path, vername);
        auto account = new OfflineAccount(config.account_username);
        auto launcher = new GameLauncher(LaunchOption(
                account, config.launch_minecraft_root_path, vername,
                config.launch_window_width, config.launch_window_height,
                config.launch_min_memory, config.launch_max_memory, config.launch_custom_info,
                config.launch_additional_jvm, config.launch_additional_game
        ));
        launcher.launchGame();
    }

    @Command("list-mc", "show minecraft version list")
    @NamedParam!(string[])("type", "type", "release,snapshot,...", ["release"])
    static void list_mc(string[] type)
    {
        showVersionList(config.download_mirror, type);
    }

    @Command("list-forge", "show forge version list")
    @UnnamedParam!(string)("verid", "mc-version-id")
    static void list_forge(string mcver)
    {
        showForgeVersionList(config.download_mirror, mcver);
    }

    @Command("install", "install game")
    @UnnamedParam!string("verid", "mc-version-id")
    @UnnamedParam!string("vername", "version-name")
    @NamedParam!bool("is_install_forge", "forge")
    static void install(string verid, string vername, bool is_install_forge)
    {
        downloadVanilla(config.download_mirror, config.launch_minecraft_root_path, verid, vername);
        if (is_install_forge)
        {
            installForge(config.download_mirror, config.launch_minecraft_root_path,
                vername, getLatestForge(config.download_mirror, verid));
        }
        downloadGameFiles(config.download_mirror, config.launch_minecraft_root_path, vername);
    }

    @Command("install-forge", "install forge on version")
    @UnnamedParam!string("vername", "version-name")
    @UnnamedParam!string("forgever", "forge-version-id")
    static void install_forge(string vername, string forgever)
    {
        installForge(config.download_mirror, config.launch_minecraft_root_path, vername, forgever);
        downloadGameFiles(config.download_mirror, config.launch_minecraft_root_path, vername);
    }
}
