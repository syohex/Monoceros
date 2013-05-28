use strict;
use warnings;

use LWP::UserAgent;
use Plack::Runner;
use Test::More;
use Test::TCP;

{
    no warnings 'redefine';
    *Test::TCP::wait_port = sub {
        my $port = shift;
        Net::EmptyPort::wait_port($port, 0.1, 40) 
                or die "cannot open port: $port";
    };
}

test_tcp(
    server => sub {
        my $port = shift;
        my $runner = Plack::Runner->new;
        $runner->parse_options(
            qw(--server Monoceros --max-workers 1 --port), $port,
        );
        $runner->run(
            sub {
                my $env = shift;
                my $buf = '';
                        while (length($buf) != $env->{CONTENT_LENGTH}) {
                    my $rlen = $env->{'psgi.input'}->read(
                        $buf,
                        $env->{CONTENT_LENGTH} - length($buf),
                        length($buf),
                    );
                    last unless $rlen > 0;
                }
                return [
                    200,
                    [ 'Content-Type' => 'text/plain' ],
                    [ $buf ],
                ];
            },
        );
        exit;
    },
    client => sub {
        my $port = shift;
        note 'send a broken request';
        my $sock = IO::Socket::INET->new(
            PeerAddr => "127.0.0.1:$port",
            Proto    => 'tcp',
        ) or die "failed to connect to server:$!";
        $sock->print(<< "EOT");
POST / HTTP/1.0\r
Content-Length: 6\r
\r
EOT
        undef $sock;
        note 'send next request';
        my $ua = LWP::UserAgent->new;
        $ua->timeout(10);
        my $res = $ua->post("http://127.0.0.1:$port/", { a => 1 });
        ok $res->is_success;
        is $res->code, 200;
        is $res->content, 'a=1';
    },
);

done_testing;
