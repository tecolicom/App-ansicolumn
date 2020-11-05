# ansicolumn

## SCREEN SHOTS

### ANSI colors

![grep](https://raw.githubusercontent.com/kaz-utashiro/App-ansicolumn/master/images/ac-grep.png)

### Page mode

Option **-P** or **--page** construct page-style output.  Page height
is learned from terminal status, and can be given by **--page-height**
option.

```
$ jot 1000 | ansicolumn -P | less
```

![page-option](https://raw.githubusercontent.com/kaz-utashiro/App-ansicolumn/master/images/ac-page-option.png)

### Program source code

Highlighted text in multiple columns.  Option **-C** specifies number
of columns.

```
$ ansicolumn -PC3
```

![color-code](https://raw.githubusercontent.com/kaz-utashiro/App-ansicolumn/master/images/ac-color-code.png)

### Using large screen

Option **-S** specifies width of each column.

```
$ ansicolumn -PS82
```

![large-screen](https://raw.githubusercontent.com/kaz-utashiro/App-ansicolumn/master/images/ac-large-screen.png)

### Japanese Document

Option **-D** or **--document** means document mode, and enables
prohibition handling (禁則処理) of Japanese text.  Default run-in (追い
込み, precisely ぶら下げ in this case) width is 2, and can be set by
**--runin** option.  I prefer 4 but it consumes more space.

```
w3m -dump -cols 1000 https://www.aozora.gr.jp/cards/001779/files/56678_62114.html | ansicolumn -DPC4 --insert-space --runin=4 | less
```

![document](https://raw.githubusercontent.com/kaz-utashiro/App-ansicolumn/master/images/ac-japanese-document.png)

### Japanese Document with color

```
w3m -dump -cols 1000 https://www.aozora.gr.jp/cards/001779/files/56678_62114.html | greple '\p{Han}+|\p{InKatakana}+' --uc --all | ansicolumn -DPC3 --insert-space --no-top-space --runin=4 | less
```

![japanese-color-document](https://raw.githubusercontent.com/kaz-utashiro/App-ansicolumn/master/images/ac-japanese-color-document.png)

### man command output with backspaces

Man command produces formatted output of boldface and underline
sequence using backspaces.

```
man git-rebase | ansicolumn -PDC2 | less
```

![man](https://raw.githubusercontent.com/kaz-utashiro/App-ansicolumn/master/images/ac-man.png)
