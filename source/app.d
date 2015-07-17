import std.stdio;
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

void main()
{
    writeln("Starting Shell...");
    initShell();

    while(true)
    {
        auto line = readln()[0..$-1];
        if(line == "exit")
        {
            exit(0);
        }
        writeln(line);
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

        /* Ignore interactive and job-control signals.  */
        signal(SIGINT,  SIG_IGN);
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
