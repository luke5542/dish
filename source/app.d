import std.stdio;
import std.string;
import std.process;
import std.algorithm;

import std.c.stdio;

import core.stdc.stdlib;
import core.stdc.ctype;
import core.sys.posix.unistd;
import core.sys.posix.termios;
import core.sys.posix.signal;

/*#include <sys/types.h>
#include <termios.h>
#include <unistd.h>*/


int shellGroupID;
int shellTerminal;
int isShellInteractive;

termios shellModes;
termios newState;

bool sigintCalled = false;

immutable char CTRL_C = 3;
immutable char CTRL_D = 4;
immutable char ENTER = 13;
immutable char BACKSPACE = 8;
immutable char DELETE = 127;
immutable char ARROW_START = '\033';


char[] line;
size_t cursorLoc = 0;

void main()
{
    writeln("Starting Shell...");
    initShell();

    char nextChar;
    while(true)
    {
        try
        {
            nextChar = cast(char) fgetc(core.stdc.stdio.stdin);
            if(nextChar)//readln(line) && line !is null)
            {
                handleCharacter(nextChar);
            }
            else
            {
                /*
                 * When ctrl+d is pressed and it's the only thing on the line,
                 * line is set to null. We could try to continue taking input and ignore
                 * the ctrl+d press, but exiting seems a bit more standard...
                 */
                writeln("Terminating due to end of, or invalid, input.");
                closeShell(0);
            }
        }
        catch (std.stdio.StdioException ex)
        {
            //Just notify that the exception happened, for now, and just continue on...
            if(sigintCalled)
            {
                //writeln(ex);
                line.length = 0;
                sigintCalled = false;
            }
            else
            {
                //exit because there was an error without the interrupt
                //ctrl+d will get sent here when you've, in the past, captured a SIGINT
                //request but continued typing and then later hit ctrl+d.
                //This is an interesting problem...
                std.stdio.stderr.writeln(ex);
                closeShell(1);
            }
        }
    }
}

void handleCharacter(in ref char nextChar)
{
    if(isprint(nextChar))
    {
        write(nextChar);
        line ~= nextChar;
        cursorLoc++;
    }
    else if(nextChar == ENTER)
    {
        //Apparently ENTER is just a carriage return \r,
        //so we print that and \n
        writeln(ENTER);
        line.length = 0;
        cursorLoc = 0;
    }
    else if(nextChar == BACKSPACE)
    {
        version(OSX)
        {
            handleDelete();
        }
        else
        {
            handleBackspace();
        }
    }
    else if(nextChar == DELETE)
    {
        version(OSX)
        {
            handleBackspace();
        }
        else
        {
            handleDelete();
        }
    }
    else if(nextChar == ARROW_START)
    {
        handleArrowKeys();
    }
    else if(nextChar == CTRL_C)
    {
        write("^C");
        closeShell(0);
    }
    else if(nextChar == CTRL_D)
    {
        write("^D");
    }
}

void handleBackspace()
{
    if(line.length > 0)
    {
        //line[cursorLoc-1 .. $-1] = line[cursorLoc .. $];
        std.algorithm.mutation.copy(line[cursorLoc-1 .. $-1], line[cursorLoc .. $]);
        line[$-1] = ' ';
        // reset to the start of the line and print out the current line's buffer
        write(ENTER ~ line);
        line.length = line.length - 1;
        //fix the location of the cursor...
        write(ENTER ~ line); // 1,2,3,4,5,6
    }
}

void handleDelete()
{
    if(line.length > 0 && cursorLoc < line.length)
    {
        //line[cursorLoc .. $-1] = line[cursorLoc+1 .. $];
        std.algorithm.mutation.copy(line[cursorLoc .. $-1], line[cursorLoc+1 .. $]);
        line[$-1] = ' ';
        // reset to the start of the line and print out the current line's buffer
        write(ENTER ~ line);
        line.length = line.length - 1;
        //fix the location of the cursor...
        write(ENTER ~ line);
    }
}

void handleArrowKeys()
{
    char nextChar = cast(char) fgetc(core.stdc.stdio.stdin); // skip the [
    nextChar = cast(char) fgetc(core.stdc.stdio.stdin);
    switch(nextChar) { // the real value
        case 'A':
            // code for arrow up
            write("Arrow ^");
            break;
        case 'B':
            // code for arrow down
            write("Arrow v");
            break;
        case 'C':
            // code for arrow right
            if(cursorLoc < line.length)
            {
                cursorLoc++;
                write(ENTER ~ line[0..cursorLoc]);
            }
            else
            {
                //TODO system beep, because why not...
            }
            break;
        case 'D':
            // code for arrow left
            if(cursorLoc > 0)
            {
                cursorLoc--;
                write(ENTER ~ line[0..cursorLoc]);
            }
            else
            {
                //TODO system beep, because why not...
            }
            break;
        default:
            // whoops
            write("Unknonw Arrow Key");
            break;
    }
}

void initShell()
{
    /* See if we are running interactively.  */
    shellTerminal = STDIN_FILENO;
    isShellInteractive = isatty(shellTerminal);

    writeln("Shell is interactive: ", isShellInteractive);
    if (isShellInteractive)
    {
        /* Loop until we are in the foreground.  */
        while (tcgetpgrp (shellTerminal) != (shellGroupID = getpgrp()))
        {
            kill(- shellGroupID, SIGTTIN);
        }

        //Setup capture for ctrl+c
        sigaction_t sigIntHandler;
        sigIntHandler.sa_handler = &handleControlC;
        sigemptyset(&sigIntHandler.sa_mask);
        sigIntHandler.sa_flags = 0;

        /* Ignore interactive and job-control signals.  */
        sigaction(SIGINT, &sigIntHandler, null); //except actually capture ctrl+c
        signal(SIGQUIT, SIG_IGN);
        signal(SIGTSTP, SIG_IGN);
        signal(SIGTTIN, SIG_IGN);
        signal(SIGTTOU, SIG_IGN);
        signal(SIGCHLD, SIG_IGN);

        /* Put ourselves in our own process group.  */
        shellGroupID = getpid();
        if (setpgid(shellGroupID, shellGroupID) < 0)
        {
            std.stdio.stderr.writeln("Couldn't put the shell in its own process group");
            closeShell(1);
        }

        /* Grab control of the terminal.  */
        tcsetpgrp(shellTerminal, shellGroupID);

        /* Save default terminal attributes for shell.  */
        tcgetattr(shellTerminal, &shellModes);

        // Open stdin in raw mode
        /* Adjust output channel*/
        tcgetattr(1, &newState);           /* get base of new state */
        cfmakeraw(&newState);
        tcsetattr(1, TCSADRAIN, &newState);/* set mode */
    }
}

//Use this instead of exit() so that we don't mess up the terminal...
void closeShell(int status)
{
    tcsetattr(1, TCSADRAIN, &shellModes);
    exit(status);
}

extern(C):
void handleControlC(int s)
{
    writeln("Caught signal ", s);
    sigintCalled = true;
    //exit(0);
}

extern(C) void cfmakeraw(termios *termios_p);
