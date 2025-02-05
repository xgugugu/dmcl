module dmcl.account.account;

interface Account
{
public:
    string getName();
    string getUUID();
    string getAccessToken();
    string getType();
}
