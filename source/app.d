import std.stdio;
import std.string;
import std.process;

import core.stdc.stdlib;
import core.sys.posix.unistd;
import core.sys.posix.termios;
import core.sys.posix.signal;

/*#include <sys/types.h>
#include <termios.h>
#include <unistd.h>*/


int shell_pgid;
termios shell_tmodes;
int shell_terminal;
int shell_is_interactive;

bool sigintCalled = false;

void main()
{
    writeln("Starting Shell...");
    initShell();

    char[] line;
    while(true)
    {
        try
        {
            if(readln(line) && line !is null)
            {
                if(line.length > 0)
                {
                    line = chomp(line);
                    if(line == "exit")
                    {
                        exit(0);
                    }
                    writeln(line);
                }
            }
            else
            {
                /*
                 * When ctrl+d is pressed and it's the only thing on the line,
                 * line is set to null. We could try to continue taking input and ignore
                 * the ctrl+d press, but exiting seems a bit more standard...
                 */
                writeln("Terminating due to end of input.");
                exit(0);
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
                stderr.writeln(ex);
                exit(1);
            }
        }
    }
}

void initShell()
{
    /* See if we are running interactively.  */
    shell_terminal = STDIN_FILENO;
    shell_is_interactive = isatty(shell_terminal);

    writeln("Shell is interactive: ", shell_is_interactive);
    if (shell_is_interactive)
    {
        /* Loop until we are in the foreground.  */
        while (tcgetpgrp (shell_terminal) != (shell_pgid = getpgrp()))
        {
            kill(- shell_pgid, SIGTTIN);
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
        shell_pgid = getpid();
        if (setpgid(shell_pgid, shell_pgid) < 0)
        {
            stderr.writeln("Couldn't put the shell in its own process group");
            exit(1);
        }

        /* Grab control of the terminal.  */
        tcsetpgrp(shell_terminal, shell_pgid);

        /* Save default terminal attributes for shell.  */
        tcgetattr(shell_terminal, &shell_tmodes);
    }
}

extern(C):
void handleControlC(int s)
{
    writeln("Caught signal ", s);
    sigintCalled = true;
    //exit(0);
}
