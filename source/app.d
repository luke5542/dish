import std.stdio;
import std.string;
import std.process;
import std.algorithm.mutation;

import std.experimental.logger;

import std.c.stdio;

import terminal;

/////////////////////////////////////////////
//Begin variable declaration
/////////////////////////////////////////////
FileLogger logger;
//Terminal term;
//RealTimeConsoleInput inputManager;

/*void main()
{
    writeln("Starting Shell...");
    initShell();
    //Initialize the log file
    logger = new FileLogger("dish.log");

}

void initShell()
{
    term = Terminal(ConsoleOutputType.linear);
    inputManager = RealTimeConsoleInput(&term, ConsoleInputFlags.allInputEvents);
}*/

/*
Used to copy the contents of one slice into the other.
Could possibly be more efficient, but it works so will stay for now...
*/
void copySlice(T)(T[] source, T[] dest)
{
    assert(source.length == dest.length);

    foreach(i, item; source)
    {
        dest[i] = item;
    }
}
