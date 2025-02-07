module dmcl.main;

import dmcl.config;
import dmcl.cli;

import std.stdio : writeln;

void main(string[] args)
{
	debug
	{
		writeln("!!! DMCL SNAPSHOT !!!\n");
	}
	readConfig();
	startCli(args, DmclCli());
}
