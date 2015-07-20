import std.stdio;
import std.string;
import std.process;

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

void main()
{
    writeln("Starting Shell...");
    initShell();

    char[] line;
    char nextChar;
    while(true)
    {
        try
        {
            nextChar = cast(char) fgetc(core.stdc.stdio.stdin);
            if(nextChar)//readln(line) && line !is null)
            {
                if(isprint(nextChar))
                {
                    write(nextChar);
                    line ~= nextChar;
                }
                else if(nextChar == ENTER)
                {
                    //Apparently ENTER is just a carriage return \r,
                    //so we print that and \n
                    writeln(ENTER);
                    line.length = 0;
                }
                else if((nextChar == BACKSPACE || nextChar == DELETE) && line.length > 0)
                {
                    line[$-1] = ' ';
                    // reset to the start of the line and print out the current line's buffer
                    write(ENTER ~ line);
                    line.length = line.length - 1;
                    //fix the location of the cursor...
                    write(ENTER ~ line);
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
