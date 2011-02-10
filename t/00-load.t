#!/usr/bin/env perl

use strict;
use warnings;
use lib::abs '../lib';
use Test::More tests => 2;
use Test::NoWarnings;

BEGIN {
    use_ok( 'MojoX::Routes::DSL' ) or print "Bail out!\n";
}

diag( "Testing MojoX::Routes::DSL $MojoX::Routes::DSL::VERSION, Perl $], $^X" );
