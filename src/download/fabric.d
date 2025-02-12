module dmcl.download.fabric;

import dmcl.download;
import dmcl.utils : getPath, mergeJSON, writeSafe;

import std.net.curl : get;
import std.json : parseJSON;
import std.stdio : writeln;
import std.format : format;
import std.file : readText;

void showFabricVersionList(string mirror, string mc_version)
{
    auto json = parseJSON(get(fabric_meta[mirror] ~ "/v2/versions/loader/" ~ mc_version));
    foreach_reverse (ref meta; json.array)
    {
        writeln(mc_version ~ "/" ~ meta["loader"]["version"].str,
            meta["loader"]["stable"].boolean ? "(recommanded)" : "");
    }
}

string getLatestFabric(string mirror, string mc_version)
{
    auto json = parseJSON(get(fabric_meta[mirror] ~ "/v2/versions/loader/" ~ mc_version));
    foreach_reverse (ref meta; json.array)
    {
        if (meta["loader"]["stable"].boolean)
        {
            return mc_version ~ "/" ~ meta["loader"]["version"].str;
        }
    }
    return mc_version ~ "/" ~ json[0]["loader"]["version"].str;
}

void installFabric(string mirror, string root_path, string mc_version, string fabric_version)
{ // fabric autoinstall is too easy, look at what forge did!!!
    auto fabric_json = parseJSON(get("%s/v2/versions/loader/%s/profile/json".format(
            fabric_meta[mirror], fabric_version)));
    auto mc_json = parseJSON(readText(getPath(root_path, "versions", mc_version, mc_version ~ ".json")));
    mergeJSON(mc_json, fabric_json);
    mc_json.object.remove("inheritsFrom");
    mc_json["id"] = mc_version;
    writeSafe(getPath(root_path, "versions", mc_version, mc_version ~ ".json"), mc_json.toString());
}
