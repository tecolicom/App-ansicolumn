requires 'perl', 'v5.16';

requires 'List::Util', '1.56';
requires 'Term::ReadKey';
requires 'Getopt::EX', '2.1.4';
requires 'Getopt::EX::Hashed', '1.05';
requires 'Getopt::EX::RPN', '0.01';
requires 'Term::ANSIColor::Concise', '2.05';
requires 'Text::ANSI::Fold', '2.19';
requires 'Text::ANSI::Fold::Util', '1.01';
requires 'Text::ANSI::Printf', '2.01';
requires 'Math::RPN';
requires 'Clone';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Data::Section::Simple';
    requires 'File::Spec';
    requires 'File::Slurper';
};

