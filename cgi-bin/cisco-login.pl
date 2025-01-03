#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use DBI;
use lib '/svc/yamenu/perl-lib';
use poop qw(simple_preproc load_config url_filter);
use CiscoPhone qw(render_icon_file_menu render_login_form render_message render_messages render_phone_menu render_redirect);
use YAML;

##########
# XXX: This needs rewritten as a library
##########
# Check for cookie: confirm matching session is valid
#	- Not expired
#	- Same IP
#	VALID: Redirect to main menu, ignoring below
#
# Lookup if a session exists in db
# - If none: store pre-auth
#     - Give it a unique token (hash)
#      - Store devname (MAC) & IP
# - If found & complete (uid set):
#     - Check if expired & delete / redirect to login if so
#     - Update last_active time to now
#     - Set cookie to the token in db
# If arguments:
#	After auth, redirect to the target URL that was given
#	If failed auth, redirect back to referrer, maybe with 
#	  a page explaining that the area is for authorized
#         users and to contact the administrator if need access.

my $log_file = "/svc/yamenu/logs/cisco-auth.log";
open our $log_fh, '>>', $log_file or die "Cannot open log file: $!";
open STDERR, '>&', $log_fh or die "Cannot redirect STDERR to log file: $!";
my $cfg = load_config('/svc/yamenu/config.yml');

my $cgi = CGI->new;
my $use_biff = $cfg->{'use_biff'};
my $base_url = $cfg->{'base_url'};
my $cgi_base = $cfg->{'cgi_base'};
my $img_base = $cfg->{'img_base'};

# For now, just redirect to the main menu when queried
render_redirect($cgi, "$cgi_base/cisco-menu.pl");

#my $req_ip = $cgi->remote_addr;
#my $req_name = $cgi->param('name');
#my $req_pin = $cgi->param('pin');

# Close the log file
close $log_fh;
