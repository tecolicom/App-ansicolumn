[![Build Status](https://travis-ci.com/kaz-utashiro/App-ansicolumn.svg?branch=master)](https://travis-ci.com/kaz-utashiro/App-ansicolumn)
# NAME

ansicolumn - ANSI terminal sequence aware column command

# VERSION

Version 0.13

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

Some additional options are compatible with Linux extended version.

> - **-c**#, **--output-width**=#
>
>     Long name for **-c**.
>
> - **-s**#, **--separator**=#
>
>     Long name for **-s**.
>
> - **-t**, **--table**
>
>     Long name for **-t**.
>
> - **-x**, **--fillrows**
>
>     Long name for **-x**.
>
> - **-o**#, **--output-separator**=#
>
>     When used **--table** or **-t** option, each columns are joined by two
>     space characters (' ') by default.  This option will change it.
>
> - **-R**_columns_, **--table-right**=_columns_
>
>     Right align text in these columns.
>     Support only numbers.

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
>     Use full width of the terminal.  Each panes are expanded to fill
>     terminal width, unless **--pane-width** is specified.
>
> - **-C**#, **--pane**=#
>
>     Output is formatted in the specified number of panes.  Setting number
>     of panes implies **--fullwidth** option enabled.
>
> - **-S**#, **--pane-width**=#, **--pw**=#
>
>     Specify pane width.  This includes border spaces.
>
> - **--page-height**=#, **--ph**=#
>
>     Set page height and page mode on.
>
> - **-P**, **--page**
>
>     Page mode.  Set following options.
>
>         --page-height=[ terminal height - 1 ]
>         --linestyle=wrap
>         --border
>
> - **-D**, **--document**
>
>     Document mode.  Set following options.
>
>         --fullwidth
>         --linebreak=all
>         --linestyle=wrap
>         --boundary=word
>
>     Next command display DOCX text in 3-up format using
>     [App::optex::textconv](https://metacpan.org/pod/App::optex::textconv).
>
>         optex -Mtextconv ansicolumn -DPC3 foo.docx | less
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
> - **--boundary**=_word_
>
>     Set text wrap boundary.  If this option set to **word**, text is
>     wrapped at word boundary.  Option **--document** set this automatically.
>     Use something like \`--boundary=none' to disable it.
>
> - **--linebreak**=_none|all|runin|runout_, **--lb**=...
>
>     Set the linebreak mode.
>
> - **--runin**=#, **--runout**=#
>
>     Set number of runin/runout column.
>     Default is both 2.
>
> - **--**\[**no-**\]**border**
>
>     Print border.  Enabled by **--page** option automatically.  Use
>     **--no-border** to disable it.  Border theme is specified by
>     **--border-theme** option.
>
> - **--border-theme**=_theme_
>
>     Set column border theme.  Default theme is **light-bar**, which is
>     light vertical line filling the page height.  My favorite is
>     **light-block**.  These themes are experimental and subject to change.
>     Use \`perldoc -m App::ansicolumn::Border\` for detail.
>
> - **--insert-space**
>
>     Insert empty line between every successive non-empty lines.
>
> - **--no-top-space**
>
>     Clean up empty lines at the top of each pages.
>
> - **--ambiguous**=_width\_spec_
>
>     Specifies how to treat Unicode ambiguous width characters.  Take a
>     value of 'narrow' or 'wide.  Default is 'narrow'.

# INSTALL

## CPANMINUS

    $ cpanm App::Greple
    or
    $ curl -sL http://cpanmin.us | perl - App::ansicolumn

Until CPAN release, use this:

    $ cpanm https://github.com/kaz-utashiro/App-ansicolumn.git

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
