module dmcl.launch.option;

import dmcl.account : Account;

struct LaunchOption
{
    Account account;
    string java_path;
    string root_path;
    string version_name;
    int window_width = 854;
    int window_height = 480;
    int min_memory = 512;
    int max_memory = 2048;
    string custom_info = "";
    string additional_jvm = "-Dfml.ignoreInvalidMinecraftCertificates=True"
        ~ "-Dfml.ignorePatchDiscrepancies=True";
    string additional_game = "";
}
