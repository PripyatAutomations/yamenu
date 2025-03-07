#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use YAML qw(LoadFile);
use URI::Escape qw(uri_escape);
use DBI;
use Data::Dumper;
use File::Slurp;
use lib '/svc/yamenu/perl-lib';
use poop qw(simple_preproc load_config url_filter);
use CiscoPhone qw(render_icon_file_menu render_login_form render_message render_messages render_phone_menu render_redirect);

my $log_file = "/svc/yamenu/logs/mail.log";
open our $log_fh, '>>', $log_file or die "Cannot open log file: $!";
open STDERR, '>&', $log_fh or die "Cannot redirect STDERR to log file: $!";
my $cfg = load_config('/svc/yamenu/config.yml');
my $base_url = $cfg->{base_url};
my $cgi_base = $cfg->{cgi_base};
my $img_base = $cfg->{img_base};

# Initialize CGI
my $cgi = CGI->new;

# Get the IP address of the request
my $ip_address = $cgi->remote_addr;

# Get the menu ID from the URL parameter
print $log_fh "mail: Request from IP: $ip_address at " . localtime() . "\n";

render_messages($cgi, $cfg);
close $log_fh;
