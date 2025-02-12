module dmcl.download.mirrors;

import std.array : replace;
import std.algorithm : canFind;

immutable string[] mirrors = ["official", "bmclapi"];

immutable string[string] mc_meta = [
    "official": "https://piston-meta.mojang.com",
    "bmclapi": "https://bmclapi2.bangbang93.com"
];

immutable string[string] mc_maven = [
    "official": "https://libraries.minecraft.net",
    "bmclapi": "https://bmclapi2.bangbang93.com/maven"
];

immutable string[string] mc_assets = [
    "official": "https://resources.download.minecraft.net",
    "bmclapi": "https://bmclapi2.bangbang93.com/assets"
];

immutable string[string] forge_maven = [
    "official": "https://files.minecraftforge.net/maven",
    "bmclapi": "https://bmclapi2.bangbang93.com/maven"
];

immutable string[string] neoforge_maven = [
    "official": "https://maven.neoforged.net/releases",
    "bmclapi": "https://bmclapi2.bangbang93.com/maven"
];

immutable string[string] fabric_meta = [
    "official": "https://meta.fabricmc.net",
    "bmclapi": "https://bmclapi2.bangbang93.com/fabric-meta"
];

immutable string[string] fabric_maven = [
    "official": "https://maven.fabricmc.net",
    "bmclapi": "https://bmclapi2.bangbang93.com/maven"
];

string mirrorUrl(string mirror, immutable string[string] mirrors, string url)
{
    if (mirrors != null)
    {
        return url.replace(mirrors["official"], mirrors[mirror]);
    }
    else
    {
        foreach (ref rules; [
                mc_maven, mc_assets,
                forge_maven, neoforge_maven,
                fabric_maven
            ])
        {
            if (url.canFind(rules[mirror]))
            {
                return url.replace(rules["official"], rules[mirror]);
            }
        }
        return url;
    }
}
