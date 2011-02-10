#!/usr/bin/env perl

use strict;
use warnings;
use lib::abs '../lib';
use Test::More tests => 192;
use Test::NoWarnings;

use MojoX::Routes::DSL;
use Mojo::Transaction::HTTP;
use MojoX::Routes;
use MojoX::Routes::Match;

my $r = MojoX::Routes->new;
routing {
	route { path '/clean'; call clean => 1; };
	route { path '/clean/too'; call something => 1; };
	route {
		path '/:controller/test';
		call action => 'test';
		route {
			path '/edit';
			call action => 'edit';
			name 'test_edit';
		};
		route{
			path '/delete/(id)', id => qr/\d+/;
			call action => 'delete', id => 23;
		};
	};
	bridge {
		path '/test2';
		call controller => 'test2';
		bridge {
			call controller => 'index';
			route {
				path '/foo';
				call controller => 'baz';
			};
			route {
				path '/bar';
				call controller => 'lalala';
			};
		};
		route {
			path '/baz';
			call 'just#works';
		};
	};
	waypoint {
		path '/test3';
		call controller => 's', action => 'l';
		route {
			path '/edit';
			call action => 'edit';
		};
	};
	route {
		path '/';
		call controller => 'hello', action => 'world';
	};
	route {
		path '/wildcards/1/(*wildcard)', wildcard => qr/(.*)/;
		call controller => 'wild', action => 'card';
	};
	route {
		path '/wildcards/2/(*wildcard)';
		call controller => 'card', action => 'wild';
	};
	route {
		path '/wildcards/3/(*wildcard)/foo';
		call controller => 'very', action => 'dangerous';
	};
	route {
		path '/format';
		call controller => 'hello', action => 'you', format => 'html';
	};
	route {
		path '/format2.html';
		call controller => 'you', action => 'hello';
	};
	route {
		path '/format2.json';
		call controller => 'you', action => 'hello_json';
	};
	route {
		path '/format3/:foo.html';
		call controller => 'me', action => 'bye';
	};
	route {
		path '/format3/:foo.json';
		call controller => 'me', action => 'bye_json';
	};
	waypoint {
		path '/articles';
		call (
			controller => 'articles',
			action     => 'index',
			format     => 'html'
		);
		waypoint{
			path '/:id';
			call (
				controller => 'articles',
				action     => 'load',
				format     => 'html'
			);
			bridge {
				call (
					controller => 'articles',
					action     => 'load',
					format     => 'html'
				);
				route {
					path '/edit';
					call controller => 'articles', action => 'edit';
				};
				route {
					path '/delete';
					call (
						controller => 'articles',
						action     => 'delete',
						format     => undef
					);
					name 'articles_delete';
				};
			};
		};
	};
	route {
		path '/method/get';
		via 'GET';
		call controller => 'method', action => 'get';
	};
	route {
		path '/method/post';
		via 'post';
		call controller => 'method', action => 'post';
	};
	route {
		path '/method/post_get';
		via qw/POST get/;
		call controller => 'method', action => 'post_get';
	};
	route {
		path '/simple/form';
		call 'test-test#test';
	};
	route {
		path '/edge';
		bridge {
			path '/auth';
			call 'auth#check';
			route {
				path '/about/';
				call 'pref#about';
			};
			bridge {
				call 'album#allow';
				route {
					path '/album/create/';
					call 'album#create';
				};
			};
			route {
				path '/gift/';
				call 'gift#index';
			};
		};
	};
} $r;

#use MojoX::Routes::AsGraph;
#my $graph = MojoX::Routes::AsGraph->graph($r);
#diag $graph->as_ascii;exit;

=for rem


=cut

# Make sure stash stays clean
my $tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/clean');
my $m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{clean},     1,        'right value');
is($m->stack->[0]->{something}, undef,    'no value');
is($m->url_for,                 '/clean', 'right URL');
is(@{$m->stack},                1,        'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/clean/too');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{clean},     undef,        'no value');
is($m->stack->[0]->{something}, 1,            'right value');
is($m->url_for,                 '/clean/too', 'right URL');
is(@{$m->stack},                1,            'right number of elements');

# Real world example using most features at once
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/articles.html');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'articles',       'right value');
is($m->stack->[0]->{action},     'index',          'right value');
is($m->stack->[0]->{format},     'html',           'right value');
is($m->url_for,                  '/articles.html', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/articles/1.html');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'articles',         'right value');
is($m->stack->[0]->{action},     'load',             'right value');
is($m->stack->[0]->{id},         '1',                'right value');
is($m->stack->[0]->{format},     'html',             'right value');
is($m->url_for,                  '/articles/1.html', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/articles/1/edit');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[1]->{controller}, 'articles',              'right value');
is($m->stack->[1]->{action},     'edit',                  'right value');
is($m->stack->[1]->{format},     'html',                  'right value');
is($m->url_for,                  '/articles/1/edit.html', 'right URL');
is($m->url_for('articles_delete', format => undef),
    '/articles/1/delete', 'right URL');
is(@{$m->stack}, 2, 'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/articles/1/delete');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[1]->{controller}, 'articles',           'right value');
is($m->stack->[1]->{action},     'delete',             'right value');
is($m->stack->[1]->{format},     undef,                'no value');
is($m->url_for,                  '/articles/1/delete', 'right URL');
is(@{$m->stack}, 2, 'right number of elements');

# Root
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->captures->{controller},   'hello', 'right value');
is($m->captures->{action},       'world', 'right value');
is($m->stack->[0]->{controller}, 'hello', 'right value');
is($m->stack->[0]->{action},     'world', 'right value');
is($m->url_for,                  '/',     'right URL');
is(@{$m->stack},                 1,       'right number of elements');

# Path and captures
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/foo/test/edit');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->captures->{controller},   'foo',            'right value');
is($m->captures->{action},       'edit',           'right value');
is($m->stack->[0]->{controller}, 'foo',            'right value');
is($m->stack->[0]->{action},     'edit',           'right value');
is($m->url_for,                  '/foo/test/edit', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');

# Optional captures in sub route with requirement
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/bar/test/delete/22');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->captures->{controller},   'bar',                 'right value');
is($m->captures->{action},       'delete',              'right value');
is($m->captures->{id},           22,                    'right value');
is($m->stack->[0]->{controller}, 'bar',                 'right value');
is($m->stack->[0]->{action},     'delete',              'right value');
is($m->stack->[0]->{id},         22,                    'right value');
is($m->url_for,                  '/bar/test/delete/22', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');

# Defaults in sub route
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/bar/test/delete');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->captures->{controller},   'bar',              'right value');
is($m->captures->{action},       'delete',           'right value');
is($m->captures->{id},           23,                 'right value');
is($m->stack->[0]->{controller}, 'bar',              'right value');
is($m->stack->[0]->{action},     'delete',           'right value');
is($m->stack->[0]->{id},         23,                 'right value');
is($m->url_for,                  '/bar/test/delete', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');

# Chained routes
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/test2/foo');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'test2',      'right value');
is($m->stack->[1]->{controller}, 'index',      'right value');
is($m->stack->[2]->{controller}, 'baz',        'right value');
is($m->captures->{controller},   'baz',        'right value');
is($m->url_for,                  '/test2/foo', 'right URL');
is(@{$m->stack},                 3,            'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/test2/bar');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'test2',      'right value');
is($m->stack->[1]->{controller}, 'index',      'right value');
is($m->stack->[2]->{controller}, 'lalala',     'right value');
is($m->captures->{controller},   'lalala',     'right value');
is($m->url_for,                  '/test2/bar', 'right URL');
is(@{$m->stack},                 3,            'right number of elements');
$tx->req->url->parse('/test2/baz');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'test2',      'right value');
is($m->stack->[1]->{controller}, 'just',       'right value');
is($m->stack->[1]->{action},     'works',      'right value');
is($m->stack->[2],               undef,        'no value');
is($m->captures->{controller},   'just',       'right value');
is($m->url_for,                  '/test2/baz', 'right URL');
is(@{$m->stack},                 2,            'right number of elements');

# Waypoints
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/test3');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 's',      'right value');
is($m->stack->[0]->{action},     'l',      'right value');
is($m->url_for,                  '/test3', 'right URL');
is(@{$m->stack},                 1,        'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/test3/');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 's',      'right value');
is($m->stack->[0]->{action},     'l',      'right value');
is($m->url_for,                  '/test3', 'right URL');
is(@{$m->stack},                 1,        'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/test3/edit');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 's',           'right value') or diag explain $m->stack;
is($m->stack->[0]->{action},     'edit',        'right value');
is($m->url_for,                  '/test3/edit', 'right URL');
is(@{$m->stack},                 1,             'right number of elements');

# Named url_for
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/test3');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->url_for, '/test3', 'right URL');
is($m->url_for('test_edit', controller => 'foo'),
    '/foo/test/edit', 'right URL');
is($m->url_for('test_edit', {controller => 'foo'}),
    '/foo/test/edit', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');

# Wildcards
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/wildcards/1/hello/there');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'wild',                     'right value');
is($m->stack->[0]->{action},     'card',                     'right value');
is($m->stack->[0]->{wildcard},   'hello/there',              'right value');
is($m->url_for,                  '/wildcards/1/hello/there', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/wildcards/2/hello/there');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'card',                     'right value');
is($m->stack->[0]->{action},     'wild',                     'right value');
is($m->stack->[0]->{wildcard},   'hello/there',              'right value');
is($m->url_for,                  '/wildcards/2/hello/there', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/wildcards/3/hello/there/foo');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'very',        'right value');
is($m->stack->[0]->{action},     'dangerous',   'right value');
is($m->stack->[0]->{wildcard},   'hello/there', 'right value');
is($m->url_for, '/wildcards/3/hello/there/foo', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');

# Escaped
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/wildcards/1/http://www.google.com');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'wild',                  'right value');
is($m->stack->[0]->{action},     'card',                  'right value');
is($m->stack->[0]->{wildcard},   'http://www.google.com', 'right value');
is($m->url_for, '/wildcards/1/http://www.google.com', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/wildcards/1/http%3A%2F%2Fwww.google.com');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'wild',                  'right value');
is($m->stack->[0]->{action},     'card',                  'right value');
is($m->stack->[0]->{wildcard},   'http://www.google.com', 'right value');
is($m->url_for, '/wildcards/1/http://www.google.com', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');

# Format
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/format');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'hello',        'right value');
is($m->stack->[0]->{action},     'you',          'right value');
is($m->stack->[0]->{format},     'html',         'right value');
is($m->url_for,                  '/format.html', 'right URL');
is(@{$m->stack},                 1,              'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/format.html');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'hello',        'right value');
is($m->stack->[0]->{action},     'you',          'right value');
is($m->stack->[0]->{format},     'html',         'right value');
is($m->url_for,                  '/format.html', 'right URL');
is(@{$m->stack},                 1,              'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/format2.html');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'you',           'right value');
is($m->stack->[0]->{action},     'hello',         'right value');
is($m->stack->[0]->{format},     'html',          'right value');
is($m->url_for,                  '/format2.html', 'right URL');
is(@{$m->stack},                 1,               'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/format2.json');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'you',           'right value');
is($m->stack->[0]->{action},     'hello_json',    'right value');
is($m->stack->[0]->{format},     'json',          'right value');
is($m->url_for,                  '/format2.json', 'right URL');
is(@{$m->stack},                 1,               'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/format3/baz.html');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'me',                'right value');
is($m->stack->[0]->{action},     'bye',               'right value');
is($m->stack->[0]->{format},     'html',              'right value');
is($m->stack->[0]->{foo},        'baz',               'right value');
is($m->url_for,                  '/format3/baz.html', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/format3/baz.json');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'me',                'right value');
is($m->stack->[0]->{action},     'bye_json',          'right value');
is($m->stack->[0]->{format},     'json',              'right value');
is($m->stack->[0]->{foo},        'baz',               'right value');
is($m->url_for,                  '/format3/baz.json', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');

# Request methods
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/method/get.html');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'method',           'right value');
is($m->stack->[0]->{action},     'get',              'right value');
is($m->stack->[0]->{format},     'html',             'right value');
is($m->url_for,                  '/method/get.html', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('POST');
$tx->req->url->parse('/method/post');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'method',       'right value');
is($m->stack->[0]->{action},     'post',         'right value');
is($m->stack->[0]->{format},     undef,          'no value');
is($m->url_for,                  '/method/post', 'right URL');
is(@{$m->stack},                 1,              'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/method/post_get');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'method',           'right value');
is($m->stack->[0]->{action},     'post_get',         'right value');
is($m->stack->[0]->{format},     undef,              'no value');
is($m->url_for,                  '/method/post_get', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('POST');
$tx->req->url->parse('/method/post_get');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'method',           'right value');
is($m->stack->[0]->{action},     'post_get',         'right value');
is($m->stack->[0]->{format},     undef,              'no value');
is($m->url_for,                  '/method/post_get', 'right URL');
is(@{$m->stack}, 1, 'right number of elements');
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('DELETE');
$tx->req->url->parse('/method/post_get');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, undef, 'no value');
is($m->stack->[0]->{action},     undef, 'no value');
is($m->stack->[0]->{format},     undef, 'no value');
is($m->url_for,                  '',    'no URL');
is(@{$m->stack},                 1,     'right number of elements');

# Not found
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/not_found');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->url_for('test_edit', controller => 'foo'),
    '/foo/test/edit', 'right URL');
is(@{$m->stack}, 0, 'no elements');

# Simplified form
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/simple/form');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'test-test',    'right value');
is($m->stack->[0]->{action},     'test',         'right value');
is($m->stack->[0]->{format},     undef,          'no value');
is($m->url_for,                  '/simple/form', 'right URL');
is(@{$m->stack},                 1,              'right number of elements');

# Special edge case with nested bridges
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/edge/auth/gift');
$m = MojoX::Routes::Match->new($tx)->match($r);
is($m->stack->[0]->{controller}, 'auth',            'right value');
is($m->stack->[0]->{action},     'check',           'right value');
is($m->stack->[0]->{format},     undef,             'no value');
is($m->stack->[1]->{controller}, 'gift',            'right value');
is($m->stack->[1]->{action},     'index',           'right value');
is($m->stack->[1]->{format},     undef,             'no value');
is($m->stack->[2],               undef,             'no value');
is($m->url_for,                  '/edge/auth/gift', 'right URL');
is(@{$m->stack}, 2, 'right number of elements');
=cut
