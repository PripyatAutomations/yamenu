#!/usr/bin/perl
use strict;
use warnings;
use AnyEvent::WebSocket::Client;
use IO::Socket::UNIX;
use JSON;
use LWP::UserAgent;
use HTTP::Request;
use AnyEvent;
use YAML;
use lib '/svc/yamenu/perl-lib';
use poop qw(simple_preproc load_config url_filter);

my $log_file = "/svc/yamenu/logs/hap.log";
open our $log_fh, '>>', $log_file or die "Cannot open log file: $!";
open STDERR, '>&', $log_fh or die "Cannot redirect STDERR to log file: $!";
# Set auto-flush on the file handle
select($log_fh);
$| = 1;  # Enable auto-flush
select(STDOUT);  # Restore original default file handle

my $cfg = load_config('/svc/yamenu/config.yml');
my $hass_cfg = $cfg->{'integrations'}{'hass'};
my $ha_ws_url = $hass_cfg->{'ha_ws_url'};
my $secrets = $cfg->{secrets};
my $ha_token = $secrets->{ha_token};
my $socket_path = $hass_cfg->{'backend_socket'};

# State storage (could be an in-memory hash, or a database)
my %entity_state;

# Establish WebSocket connection
my $client = AnyEvent::WebSocket::Client->new();
my $cv = AnyEvent->condvar;

# Function to handle WebSocket connection and subscribe to events
sub connect_to_ha {
    print $log_fh "[hass-proxy]: Connecting to $ha_ws_url\n";

    my $ws = $client->connect($ha_ws_url)->cb(sub {
        my $ws = shift->recv;

        # Authenticate on connection
        my $auth_msg = {
            type => 'auth',
            access_token => $ha_token,
        };
        print $log_fh "[hass-proxy]: Sending auth\n";
        $ws->send(encode_json($auth_msg));

        # Handle incoming messages
        $ws->on(each_message => sub {
            my ($ws, $message) = @_;
            my $msg = decode_json($message->body);

            # Handle state updates for entities
            if ($msg->{type} eq 'state_changed') {
                my $entity = $msg->{event}{data}{entity_id};
                my $state = $msg->{event}{data}{new_state}{state};
                my $last_changed = $msg->{event}{data}{new_state}{last_changed};

                # Store entity state
                $entity_state{$entity} = {
                    state       => $state,
                    last_changed => $last_changed,
                };
            }

            # Handle initial state response (from get_states request)
            if ($msg->{type} eq 'states') {
                foreach my $entity (@{$msg->{result}}) {
                    $entity_state{$entity->{entity_id}} = {
                        state        => $entity->{state},
                        last_changed => $entity->{last_changed},
                    };
                }
            }
        });

        # Subscribe to all events
        my $subscribe_msg = {
            type => 'subscribe_events',
        };
        $ws->send(encode_json($subscribe_msg));

        # Query initial state of all entities
        get_initial_states($ws);
    });

    $cv->wait;
}

# Function to query initial states of all entities
sub get_initial_states {
    my $ws = shift;

    # Send a message to get all states (you may need to adjust the API endpoint)
    my $initial_state_msg = {
        type => 'get_states',
    };
    $ws->send(encode_json($initial_state_msg));
}

# Function to handle Unix socket commands from CGI
sub handle_unix_socket {
    my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $socket_path,
    ) or die "Can't connect to Unix socket: $!\n";

    while (my $line = <$socket>) {
        chomp($line);
        my @commands = split /\s+/, $line;

        if (@commands == 1 && $commands[0] =~ /^GET/) {
            # Batch query multiple entities (GET entity1 GET entity2 GET entity3)
            my @entities_to_query = @commands[1..$#commands];

            # Process each entity in parallel using AnyEvent
            my @watches;
            foreach my $entity (@entities_to_query) {
                push @watches, AnyEvent->timer(after => 0, cb => sub {
                    query_entity_state($entity);
                });
            }

            # Wait for all queries to complete
            $_->recv for @watches;
        } else {
            print $socket "Invalid command: $line\n";
        }
    }
}

# Function to query the state of a single entity
sub query_entity_state {
    my $entity = shift;

    # Query the state using WebSocket (you could adjust the message structure)
    my $ws_msg = {
        type => 'get_state',
        entity_id => $entity,
    };

    # Send the query over WebSocket
    $client->connect($ha_ws_url)->cb(sub {
        my $ws = shift->recv;
        $ws->send(encode_json($ws_msg));

        # Wait for the response and print state when received
        $ws->on(each_message => sub {
            my ($ws, $message) = @_;
            my $msg = decode_json($message->body);

            if ($msg->{type} eq 'state') {
                my $state = $msg->{state};
                my $last_changed = $msg->{last_changed};
                $entity_state{$entity} = {
                    state        => $state,
                    last_changed => $last_changed,
                };
                print "State of $entity: $state\n";
            } else {
                print "Error: Unable to get state of $entity\n";
            }
        });
    });
}

# Start the WebSocket connection
connect_to_ha();

# Start listening for Unix socket commands
handle_unix_socket();

# Block the main thread (since AnyEvent is asynchronous)
AnyEvent->condvar->recv;

