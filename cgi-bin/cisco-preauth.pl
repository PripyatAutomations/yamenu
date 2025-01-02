#!/usr/bin/perl
# Here we deal with the initial auth request the phone sends.
# It's the only time the phone will present it's name/MAC to us
# We store MAC/name & IP in the database for tracking sessions
# Users logging in should update the entry with the userid of the active user.
# CONSTRAINT: Only one user can be active per IP/mac but a user may be active on multiple devices

use strict;
use warnings;
use CGI;
use DBI;
use lib '/svc/yamenu/perl-lib';
use poop qw(simple_preproc load_config);

my $log_file = "/svc/yamenu/logs/cisco-auth.log";
open our $log_fh, '>>', $log_file or die "Cannot open log file: $!";
open STDERR, '>&', $log_fh or die "Cannot redirect STDERR to log file: $!";
my $cfg = load_config($log_fh, '/svc/yamenu/config.yml');

# Initialize CGI object
my $cgi = CGI->new;
print $cgi->header('text/xml');
my $ip_address = $cgi->remote_addr;

# Database connection
my $dbh = DBI->connect("dbi:SQLite:dbname=../db/yamenu.db", "", "", { RaiseError => 1, AutoCommit => 1 });

print $log_fh "cisco-auth: Pre-auth from $ip_address\n";
print "1";

# Close the database connection
$dbh->disconnect;

# Close the log file
close $log_fh;
