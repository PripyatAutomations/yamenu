#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use DBI;
use lib '/svc/yamenu/perl-lib';
use poop qw(simple_preproc number_lines load_config url_filter);
use CiscoPhone qw(render_icon_file_menu render_login_form render_message render_messages render_phone_menu render_redirect);

my $cfg = load_config('/svc/yamenu/config.yml');
my $base_url = $cfg->{base_url};
my $cgi_base = $cfg->{cgi_base};
my $img_base = $cfg->{img_base};
my $log_dir = $cfg->{log_dir};
my $log_file = "$log_dir/mail.log";
open my $log_fh, '>>', $log_file or die "Cannot open log file: $!";
open STDERR, '>&', $log_fh or die "Cannot redirect STDERR to log file: $!";

my $cgi = CGI->new;

my $ip_address = $cgi->remote_addr;
print $log_fh "cisco-biff: Request from IP: $ip_address at " . localtime() . "\n";

# Database connection
my $dbh = DBI->connect("dbi:SQLite:dbname=../db/cisco.db", "", "", { RaiseError => 1, AutoCommit => 1 });

# Get the user's name from the database
my $user_check_stmt = $dbh->prepare("SELECT user, ip_address, dev_name FROM user_sessions WHERE ip_address = ?");
$user_check_stmt->execute($ip_address);
my ($name, $session_ip_address, $dev_name) = $user_check_stmt->fetchrow_array;

# Display a hello dialog to the user
if (defined($name)) {
    render_message($cgi, "Hello, $name!", "Hello, $name", "You have no new messages.", "$base_url/cgi-bin/cisco-menu.pl", 60);
} else {
    render_message($cgi, "Login Required", "Please log in to continue.", "Your session has expired or you are not logged in.");
}

$user_check_stmt->finish();
$dbh->disconnect;
close $log_fh;
