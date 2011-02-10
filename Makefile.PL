use inc::Module::Install;

my $MI  = $Module::Install::MAIN;
name     'MojoX-Routes-DSL';
all_from 'lib/MojoX/Routes/DSL.pm';
author   q{Mons Anderson <mons@cpan.org>};
license  'perl';

build_requires 'Test::More';
build_requires 'lib::abs';

auto_provides;
auto_install;

WriteAll;

print STDERR "Generated makefile for ".$MI->load('name')->name."-".$MI->load('version')->version."\n";
