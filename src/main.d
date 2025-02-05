module dmcl.main;

import dmcl.config;
import dmcl.cli;

import std.stdio : writeln;

void main(string[] args)
{
	readConfig();
	writeln("!!! DMCL SNAPSHOT !!!\n");
	startCli(args, DmclCli());
}
