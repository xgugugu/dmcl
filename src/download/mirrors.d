module dmcl.download.mirrors;

import std.array : replace;

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

string mirrorUrl(string mirror, immutable string[string] mirrors, string url)
{
    return url.replace(mirrors["official"], mirrors[mirror]);
}
