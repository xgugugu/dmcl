module dmcl.download.modloader;

import std.net.curl : get;
import std.json : parseJSON;
import std.algorithm : sort;
import std.stdio : writeln;
import std.format : format;

// Forge
void showForgeVersionList(string mirror, string mcver)
{
    // only support bmclapi
    auto json = parseJSON(get("https://bmclapi2.bangbang93.com/forge/minecraft/" ~ mcver));
    json.array.sort!((x, y) => x["build"].integer < y["build"].integer)();
    foreach (ver; json.array)
    {
        writeln("%s-%s".format(mcver, ver["version"].str));
    }
}

void installForge(string mirror, string vername, string forgever)
{

}
