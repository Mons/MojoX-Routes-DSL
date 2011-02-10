use lib::abs '../lib';
use Mojolicious;
use Mojolicious::Routes;
use Mojolicious::Command::Routes;

use MojoX::Routes::DSL;

my $r = routing {
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
} Mojolicious::Routes->new;

my $routes = [];
Mojolicious::Command::Routes->_walk($_, 0, $routes) for @{$r->children};
Mojolicious::Command::Routes->_draw($routes);
