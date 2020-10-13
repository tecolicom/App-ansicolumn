[![Build Status](https://travis-ci.com/kaz-utashiro/App-ansicolumn.svg?branch=master)](https://travis-ci.com/kaz-utashiro/App-ansicolumn)
# NAME

ansicolumn - ANSI terminal sequence aware column command

# VERSION

Version 0.06

# SYNOPSIS

ansicolumn \[-tx\] \[-c columns\] \[-s sep\] \[file ...\]

# DESCRIPTION

**ansicolumn** is a [column(1)](http://man.he.net/man1/column) command clone which can handle ANSI
terminal sequences.

From [column(1)](http://man.he.net/man1/column):

> The column utility formats its input into multiple columns.  Rows are
> filled before columns.  Input is taken from file operands, or, by
> default, from the standard input.  Empty lines are ignored.
>
> - **-c** #
>
>     Output is formatted for a display columns wide.
>
> - **-s** #
>
>     Specify a set of characters to be used to delimit columns for the
>     \-t option.
>
> - **-t**
>
>     Determine the number of columns the input contains and create a
>     table.  Columns are delimited with whitespace, by default, or
>     with the characters supplied using the -s option.  Useful for
>     pretty-printing displays.
>
> - **-x**
>
>     Fill columns before filling rows.

Some addtional options are compatible with Linux extended version.

> - **--output-width**=#, **-c**#
>
>     Long name for **-c**.
>
> - **--separator**=#, **-s**#
>
>     Long name for **-s**.
>
> - **--table**, **-t**
>
>     Long name for **-t**.
>
> - **--fillrows**, **-x**
>
>     Long name for **-x**.
>
> - **--output-separator**=#, **-o**#
>
>     When used **--table** or **-t** option, each columns are joind by two
>     space characters (' ') by defualt.  This option will change it.

Some options are original.

> - **--tabstop**=#
>
>     Set tab width.
>
> - **--columnunit**=#
>
>     Each columns are placed at unit of 8 by default.  This option changes
>     the number of unit.
>
> - **--fullwidth**
>
>     Use full width of the terminal.
>
> - **--pane**=#, **-C**#
>
>     Output is formatted in specified number of panes.  Setting number of
>     panes implies -**--fullwidth** option enabled.
>
> - **--pagelength**=#
>
>     Set page length and page mode on.
>
> - **--page**, **-P**
>
>     Set pagelength to terminal height - 1.
>
> - **--document**, **-D**
>
>     Document mode on.  Set following options.
>
>         --linebreak=all
>         --linestyle=wrap
>         --boundary=word
>         --postfix=' '
>
>     Next command display document text in 3-up format.
>
>         optex -Mtextconv foo.docx | ansicolumn -DPC3 | less
>
> - **--**\[**no-**\]**ignore-space**, **--**\[**no-**\]**is**
>
>     When used **-t** option, leading spaces are ignored by default.  Use
>     **--no-ignore-space** option to disable it.
>
> - **--linestyle**=_none_|_truncate_|_wrap_|_wordwrap_, **--ls**=_..._
>
>     Set the style of treatment for longer lines.
>     Default is _none_.
>
> - **--linebreak**=_none|all|runin|runout_
>
>     Set the linebreak mode.
>
> - **--prefix**=_string_, **--runout**=_string_
>
>     Set prefix and postfix appended to each data.
>     Default value is empty.
>
> - **--runin**=#, **--runout**=#
>
>     Set number of runin/runout column.
>     Default is both 4.

# INSTALL

## CPANMINUS

    $ cpanm App::Greple
    or
    $ curl -sL http://cpanmin.us | perl - App::ansicolumn

# SEE ALSO

[column(1)](http://man.he.net/man1/column)

[App::ansicolumn](https://metacpan.org/pod/App::ansicolumn),
[https://github.com/kaz-utashiro/App-ansicolumn](https://github.com/kaz-utashiro/App-ansicolumn)

[Text::ANSI::Printf](https://metacpan.org/pod/Text::ANSI::Printf),
[https://github.com/kaz-utashiro/Text-ANSI-Printf](https://github.com/kaz-utashiro/Text-ANSI-Printf)

# AUTHOR

Kazumasa Utashiro

# LICENSE

Copyright 2020 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
