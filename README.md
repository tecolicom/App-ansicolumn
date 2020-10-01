[![Build Status](https://travis-ci.com/kaz-utashiro/App-ansicolumn.svg?branch=master)](https://travis-ci.com/kaz-utashiro/App-ansicolumn)
# NAME

ansicolumn - ANSI sequence aware column command

# SYNOPSIS

ansicolumn \[-tx\] \[-c columns\]

# DESCRIPTION

From column(1):

> The column utility formats its input into multiple columns.  Rows are
> filled before columns.  Input is taken from file operands, or, by
> default, from the standard input.  Empty lines are ignored.
>
> - -c
>
>     Output is formatted for a display columns wide.
>
> - -s
>
>     Specify a set of characters to be used to delimit columns for the
>     \-t option.
>
> - -t
>
>     Determine the number of columns the input contains and create a
>     table.  Columns are delimited with whitespace, by default, or
>     with the characters supplied using the -s option.  Useful for
>     pretty-printing displays.
>
> - -x
>
>     Fill columns before filling rows.

**ansicolumn** is a clone which can handle ANSI terminal sequences.

# AUTHOR

Kazumasa Utashiro

# LICENSE

Copyright 2020 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
