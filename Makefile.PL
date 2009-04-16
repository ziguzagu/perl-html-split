use inc::Module::Install;
# metadataes
name 'HTML-Split';
all_from 'lib/HTML/Split.pm';
# dependencies
build_requires 'HTML::Parser';
build_requires 'Class::Accessor::Fast';
# tests
tests 't/*.t';
use_test_base;
# misc
auto_include;
WriteAll;
