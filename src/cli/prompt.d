module dmcl.cli.prompt;

version (Windows)
{
    void clrscr()
    {
        import core.sys.windows.windows;

        HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
        COORD coordScreen = COORD(0, 0);
        DWORD cCharsWritten;
        CONSOLE_SCREEN_BUFFER_INFO csbi;
        DWORD dwConSize;
        GetConsoleScreenBufferInfo(hConsole, &csbi);
        dwConSize = csbi.dwSize.X * csbi.dwSize.Y;
        FillConsoleOutputCharacterA(hConsole, ' ', dwConSize, coordScreen, &cCharsWritten);
        GetConsoleScreenBufferInfo(hConsole, &csbi);
        FillConsoleOutputAttribute(hConsole, csbi.wAttributes, dwConSize, coordScreen, &cCharsWritten);
        SetConsoleCursorPosition(hConsole, coordScreen);
    }

    int getch()
    {
        import core.sys.windows.windows;

        DWORD mode, cc;
        HANDLE h = GetStdHandle(STD_INPUT_HANDLE);
        GetConsoleMode(h, &mode);
        SetConsoleMode(h, mode & ~(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT));
        WCHAR c = 0;
        ReadConsoleW(h, &c, 1, &cc, NULL);
        SetConsoleMode(h, mode);
        return cast(int)(c);
    }
}
else version (Posix)
{
    void clrscr()
    {
        import std.stdio;

        write("\x1B[2J\x1B[H");
        stdout.flush();
    }

    int getch()
    {
        import core.sys.linux.termios;
        import core.sys.linux.unistd;
        import core.stdc.stdio;

        termios oldt, newt;
        tcgetattr(STDIN_FILENO, &oldt);
        newt = oldt;
        newt.c_lflag &= ~(ECHO | ICANON);
        tcsetattr(STDIN_FILENO, TCSANOW, &newt);
        int ch = getchar();
        tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
        return ch;
    }
}

struct PromptDiv
{
}

mixin template CLI_PROMPT(T)
{
    @Command("prompt", "interactive prompt")
    static void prompt()
    {
        import std.traits : getUDAs;
        import std.stdio : write, writeln, stdin;
        import std.algorithm : max;
        import std.array : replicate;

        int select = 0, length = 0;
        size_t max_size = 0;
        foreach (name; __traits(allMembers, T))
        {
            auto cmd = getUDAs!(__traits(getMember, T, name), Command);
            static if (cmd.length != 0)
            {
                if (cmd[0].name == "prompt")
                    continue;
                max_size = max(cmd[0].description.length, max_size);
                length++;
            }
        }
        while (true)
        {
            stdin.flush();
            clrscr();
            writeln("Tip: W/S to control, Enter to select.");
            int i = 0;
            foreach (name; __traits(allMembers, T))
            {
                auto cmd = getUDAs!(__traits(getMember, T, name), Command);
                static if (cmd.length != 0)
                {
                    if (cmd[0].name == "prompt")
                        continue;
                    write(select == i ? "> " : "* ");
                    write(cmd[0].description ~ replicate([' '],
                            max_size - cmd[0].description.length));
                    writeln(select == i ? " <" : " *");
                    i++;
                }
                static if (getUDAs!(__traits(getMember, T, name), PromptDiv).length != 0)
                {
                    writeln("* ", replicate(['-'], max_size), " *");
                }
            }
            int ch = getch();
            switch (ch)
            {
            case 'W':
            case 'w':
                select = (select + length - 1) % length;
                break;
            case 'S':
            case 's':
                select = (select + 1) % length;
                break;
            case 10:
            case 13:
                int j = 0;
                foreach (name; __traits(allMembers, T))
                {
                    auto cmd = getUDAs!(__traits(getMember, T, name), Command);
                    static if (cmd.length != 0)
                    {
                        if (cmd[0].name == "prompt")
                            continue;
                        if (select == j)
                        {
                            prompt_run!(name)();
                            break;
                        }
                        j++;
                    }
                }
                break;
            default:
                break;
            }
        }
    }

    static void prompt_run(name...)()
    {
        import std.traits : getUDAs, isArray;
        import std.stdio : write, writeln, readln, stdin, stdout;
        import std.file : thisExePath;
        import std.conv : to;
        import std.process : spawnProcess, wait, escapeShellCommand;
        import std.string : strip;

        stdin.flush();
        clrscr();
        auto cmd = getUDAs!(__traits(getMember, T, name), Command)[0];
        writeln(cmd.description);
        string[] args = [thisExePath(), cmd.name];
        foreach (param; getUDAs!(__traits(getMember, T, name), Param))
        {
            alias S = typeof(param.default_value);
            write(param.name);
            static if (param.named && is(S == bool))
            {
                write("(y/N): ");
                stdout.flush();
                string str = readln().strip();
                if (str == "Y" || str == "y")
                {
                    args ~= "--" ~ param.name;
                }
            }
            else
            {
                string val = "";
                if (param.has_defval)
                {
                    if (isArray!S && !is(S == string))
                    {
                        string defval = "";
                        foreach (x; param.default_value)
                        {
                            defval ~= to!string(x) ~ ",";
                        }
                        write("(default: ", val = defval[0 .. $ - 1], ")");
                    }
                    else
                    {
                        write("(default: ", val = to!string(param.default_value), ")");
                    }
                }
                write(": ");
                stdout.flush();
                string str = readln().strip();
                if (str != "")
                {
                    val = str;
                }
                if (param.named)
                {
                    args ~= "--" ~ param.name ~ "=" ~ val;
                }
                else
                {
                    args ~= val;
                }
            }
        }
        clrscr();
        writeln("Running: ", escapeShellCommand(args));
        wait(spawnProcess(args));
        stdin.flush();
        writeln("\nPress enter to return.");
        readln();
    }
}
