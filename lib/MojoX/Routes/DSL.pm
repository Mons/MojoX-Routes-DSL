package MojoX::Routes::DSL;

use 5.010;
use strict;
use warnings;

=head1 NAME

MojoX::Routes::DSL - DSL around Mojo routing

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

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

=head1 EXPORT

    routing
        Lexical wrapper for DSL functions

All other functions are the same as for classic L<Mojo::Routes>

    route { ... }
    bridge { ... }
    waypoint { ... }

And inside them you can use

    path
    call
    via
    name
    over
    websocket

=head1 FUNCTIONS

=cut


our $PARENT;
our $NESTED = [];
our $ATTR;
our @EXPORT = qw(routing path call via name over websocket route bridge waypoint);

BEGIN {
    no strict 'refs';
    for my $attr (qw(path call via name over)) {
        *$attr = sub (@) {
            $ATTR->{$attr} and warn "Previous $attr @{$ATTR->{$attr}} redefined at @{[ (caller)[1,2] ]}\n";
            $ATTR->{$attr} = [@_];
        };
    }
    sub websocket () { $ATTR->{websocket} = 1; }
    for my $method (qw(route bridge waypoint)) {
        *$method = sub (&) {
            my $code = shift;
            return push @$NESTED, sub{ $method->($code) } if !$PARENT;
            local $NESTED = my $nested = [];
            local $ATTR   = my $attr = {};
            {
                local $PARENT = undef;
                $code->();
            }
            if ($method eq 'route' and !@$NESTED and !$attr->{call}) {
                die "Use of route without call or nested route is useless at @{[ (caller)[1,2] ]}\n";
            }
            if ($method eq 'waypoint' and !$attr->{call}) {
                warn "Call not defined for waypoint at @{[ (caller)[1,2] ]}\n";
            }
            if ($method eq 'bridge' and !@$NESTED) {
                warn "Use of bridge without nested routes is useless at @{[ (caller)[1,2] ]}\n";
            }
            
            my $route = $PARENT->$method(@{$attr->{path}});
            
            $route->via(@{$attr->{via}})   if $attr->{via};
            $route->over(@{$attr->{over}}) if $attr->{over};
            $route->websocket              if $attr->{websocket};
            
            $route->to(@{$attr->{call}}) if $attr->{call};
            
            $route->name(@{$attr->{name}}) if $attr->{name};
            #warn "setup $method(".$route->pattern->pattern.") for ".( $PARENT->pattern->pattern || '/' )."\n";
            {
                local $PARENT = $route;
                $_->() for @$nested;
            }
            return $route;
        };
    }
}

=head2 routing { ... } $r

Main wrapper, which sets the C<$routes> context for all operations inside.

=head2 route { ... }

Common route. Must have nested C<route> or C<call>

=head2 bridge { ... }

Bridge route. Should have nested routes. Otherwise useless.

=head2 waypoint { ... }

Waypoint route (bridge, that could be an endpoint). For endpoint to work C<call> should be defined.

=head2 path '/some/path'

Part of path

=head2 call 'controller#action', ... (See L<Mojolicious::Routes/to>)

Which action should be called for this route

=head2 via @methods

Define accepted methods for given route  (See L<Mojolicious::Routes/via>)

=head2 name

Define a name of route. (See L<Mojolicious::Routes/name>)

=head2 over ...

Apply condition parameters to this route. (See L<Mojolicious::Routes/over>)

=head2 websocket

Generate route matching only C<WebSocket> handshakes

=cut

sub route (&);
sub bridge (&);
sub waypoint (&);

sub routing (&$) {
    my $code = shift;
    local $PARENT = pop;
    $code->();
    #_walk $_, 0 for @{ $PARENT->children };
    return $PARENT;
};


sub import {
    no strict 'refs';
    *{ caller().'::'.$_ } = \&$_
        for @EXPORT;
}


=head1 AUTHOR

Mons Anderson, C<< <mons at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Mons Anderson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

=cut

1; # End of MojoX::Routes::DSL
