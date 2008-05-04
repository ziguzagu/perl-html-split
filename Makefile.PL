use inc::Module::Install;
# metadataes
name 'HTML-Split';
all_from 'lib/HTML/Split.pm';
# dependencies
build_requires 'HTML::Parser';
build_requires 'Class::Accessor::Fast';
# misc
use_test_base;
auto_include;
WriteAll;
