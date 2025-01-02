#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use DBI;
use lib '/svc/yamenu/perl-lib';
use poop qw(simple_preproc number_lines load_config url_filter);
use CiscoPhone qw(render_icon_file_menu render_login_form render_message render_messages render_phone_menu render_redirect);

my $log_file = "/svc/yamenu/logs/cisco-auth.log";
open our $log_fh, '>>', $log_file or die "Cannot open log file: $!";
open STDERR, '>&', $log_fh or die "Cannot redirect STDERR to log file: $!";
my $cfg = load_config($log_fh, '/svc/yamenu/config.yml');

my $base_url = $cfg->{base_url};
my $cgi_base = $cfg->{cgi_base};
my $img_base = $cfg->{img_base};

my $cgi = CGI->new;
my $ip_address = $cgi->remote_addr;

print $log_fh "cisco-auth: Logout request from IP: $ip_address at " . localtime() . "\n";

my $dbh = DBI->connect("dbi:SQLite:dbname=../db/yamenu.db", "", "", { RaiseError => 1, AutoCommit => 1 });
my $delete_stmt = $dbh->prepare("DELETE FROM user_sessions WHERE ip_address = ?");
eval {
    $delete_stmt->execute($ip_address);
};
$delete_stmt->finish();
if ($@) {
    print $log_fh "cisco-auth: Failed to delete session for IP: $ip_address. Error: $@\n";
}

render_redirect($cgi, 'Key:Services');

$dbh->disconnect;
close $log_fh;
