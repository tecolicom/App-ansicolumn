requires 'perl', 'v5.14';

requires 'List::Util', '1.45';
requires 'Term::ReadKey';
requires 'Getopt::EX', 'v1.19.1';
requires 'Text::ANSI::Fold::Util';
requires 'Text::ANSI::Printf', '1.01';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

