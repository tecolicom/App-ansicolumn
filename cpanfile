requires 'perl', 'v5.16';

requires 'List::Util', '1.56';
requires 'Term::ReadKey';
requires 'Getopt::EX', '2.2.1';
requires 'Getopt::EX::Hashed', '1.0701';
requires 'Getopt::EX::RPN', '0.01';
requires 'Term::ANSIColor::Concise', '2.08';
requires 'Text::ANSI::Fold', '2.3303';
requires 'Text::ANSI::Fold::Util', '1.05';
requires 'Text::ANSI::Printf', '2.07';
requires 'Math::RPN';
requires 'Clone';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Data::Section::Simple';
    requires 'File::Spec';
    requires 'File::Slurper';
};

