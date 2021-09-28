requires 'perl', 'v5.16';

requires 'List::Util', '1.45';
requires 'Term::ReadKey';
requires 'Getopt::EX', 'v1.25.0';
requires 'Getopt::EX::Hashed', '0.9920';
requires 'Text::ANSI::Fold', '2.11';
requires 'Text::ANSI::Fold::Util';
requires 'Text::ANSI::Printf', '1.03';
requires 'Math::RPN';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

