[![Build Status](https://travis-ci.com/kaz-utashiro/App-ansicolumn.svg?branch=master)](https://travis-ci.com/kaz-utashiro/App-ansicolumn)
# NAME

ansicolumn - ANSI terminal sequence aware column command

# SYNOPSIS

ansicolumn \[-tx\] \[-c columns\] \[-s sep\] \[file ...\]

# DESCRIPTION

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

**ansicolumn** is a clone which can handle ANSI terminal sequences.

Some addtional options are available.

> - **--column** #
>
>     Long name for **-c**.
>
> - **--separator**
>
>     Long name for **-s**.
>
> - **--table**
>
>     Long name for **-t**.
>
> - **--transpose**, **--xpose**
>
>     Long name for **-x**.
>
> - **--tab** #
>
>     Specify tab width.
>
> - **--pane** #
>
>     Output is formatted in specified number of panes.
>
> - **--join** #
>
>     When used **--table** or **-t** option, each columns are joind by two
>     space characters (' ') by defualt.  This option will change it.
>
> - **--\[no-\]ignore-space**, **--\[no-\]is**
>
>     When used **-t** option, leading spaces are ignored by default.  Use
>     **--no-ignore-space** option to disable it.

# INSTALL

## CPANMINUS

    $ cpanm App::Greple
    or
    $ curl -sL http://cpanmin.us | perl - App::Greple

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
