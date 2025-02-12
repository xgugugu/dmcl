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
    mixin CLI_PROMPT!DmclCli;

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

    @PromptDiv
    static void div_0()
    {
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

    @PromptDiv
    static void div_1()
    {
    }

    @Command("install", "install game")
    @UnnamedParam!string("version_id", "mc-version-id")
    @UnnamedParam!string("version_name", "version-name")
    @NamedParam!bool("is_install_forge", "forge")
    @NamedParam!bool("is_install_neoforge", "neoforge")
    @NamedParam!bool("is_install_fabric", "fabric")
    static void install(string version_id, string version_name,
        bool is_install_forge, bool is_install_neoforge,
        bool is_install_fabric)
    {
        downloadVanilla(config.download_mirror, config.launch_minecraft_root_path, version_id, version_name);
        if (is_install_forge)
        {
            installForge(config.download_mirror, config.launch_minecraft_root_path,
                version_name, getLatestForge(config.download_mirror, version_id));
        }
        if (is_install_neoforge)
        {
            installNeoForge(config.download_mirror, config.launch_minecraft_root_path,
                version_name, getLatestNeoForge(config.download_mirror, version_id));
        }
        if (is_install_fabric)
        {
            installFabric(config.download_mirror, config.launch_minecraft_root_path,
                version_name, getLatestFabric(config.download_mirror, version_id));
        }
        downloadGameFiles(config.download_mirror, config.launch_minecraft_root_path, version_name);
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

    @Command("list-neoforge", "show neoforge version list")
    @UnnamedParam!(string)("verid", "mc-version-id")
    static void list_neoforge(string mcver)
    {
        showNeoForgeVersionList(config.download_mirror, mcver);
    }

    @Command("list-fabric", "show fabric version list")
    @UnnamedParam!(string)("verid", "mc-version-id")
    static void list_fabric(string mc_version)
    {
        showFabricVersionList(config.download_mirror, mc_version);
    }

    @Command("install-forge", "install forge on version")
    @UnnamedParam!string("vername", "version-name")
    @UnnamedParam!string("forgever", "forge-version-id")
    static void install_forge(string vername, string forgever)
    {
        installForge(config.download_mirror, config.launch_minecraft_root_path, vername, forgever);
        downloadGameFiles(config.download_mirror, config.launch_minecraft_root_path, vername);
    }

    @Command("install-neoforge", "install neoforge on version")
    @UnnamedParam!string("vername", "version-name")
    @UnnamedParam!string("forgever", "neoforge-version-id")
    static void install_neoforge(string vername, string forgever)
    {
        installNeoForge(config.download_mirror, config.launch_minecraft_root_path, vername, forgever);
        downloadGameFiles(config.download_mirror, config.launch_minecraft_root_path, vername);
    }

    @Command("search-java", "search java automatically")
    static void find_java()
    {
        findJava();
    }

    @PromptDiv
    static void div_2()
    {
    }

    mixin CLI_HELP!DmclCli;

    @Command("version", "show version")
    static void version_()
    {
        writeln(LAUNCHER_NAME ~ " version " ~ LAUNCHER_VERSION);
        writeln("build time: " ~ __DATE__ ~ " " ~ __TIME__);
        writeln();
        writeln("thanks: bmclapi");
    }

    @Command("config", "show config")
    static void config_cmd()
    {
        showConfig();
    }

    @Command("edit-config", "edit config")
    static void edit_config()
    {
        writeln("Tip: edit ", getConfigPath());
    }

    @PromptDiv
    static void div_3()
    {
    }
}
