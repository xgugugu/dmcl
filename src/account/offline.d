module dmcl.account.offline;

import dmcl.account;

import std.uuid : sha1UUID;

class OfflineAccount : Account
{
    string name;

public:
    this(string arg_name)
    {
        name = arg_name;
    }

    string getName()
    {
        return name;
    }

    string getUUID()
    {
        return sha1UUID(name).toString();
    }

    string getAccessToken()
    {
        return "";
    }

    string getType()
    {
        return "legacy";
    }
}
