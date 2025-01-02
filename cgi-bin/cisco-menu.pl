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
use poop qw(simple_preproc number_lines load_config url_filter);
use CiscoPhone qw(render_icon_file_menu render_login_form render_message render_messages render_phone_menu render_redirect);

my $log_file = "/svc/yamenu/logs/cisco-menu.log";
open our $log_fh, '>>', $log_file or die "Cannot open log file: $!";
open STDERR, '>&', $log_fh or die "Cannot redirect STDERR to log file: $!";
my $cfg = load_config($log_fh, '/svc/yamenu/config.yml');
my $base_url = $cfg->{base_url};
my $cgi_base = $cfg->{cgi_base};
my $img_base = $cfg->{img_base};
my $cgi = CGI->new;
my $ip_address = $cgi->remote_addr;
my $menu_id = $cgi->param('menu') || 'menu-main';
print $log_fh "cisco-menu: Request from IP: $ip_address at " . localtime() . " for $menu_id\n";

# Does menu exist?
unless (exists $cfg->{$menu_id}) {
    print $cgi->header('text/plain');
    print "Menu not found: $menu_id\n";
    exit;
}

######### Authentication ##########
my $cookie;
my $cookie_value = $cgi->cookie('AUTH');

if ($cookie_value) {
   print $log_fh "Cookie 'AUTH' exists with value: $cookie_value\n";
} else {
   print $log_fh "Cookie 'AUTH' doesn't exist!\n";
   $cookie = $cgi->cookie(-name=>'AUTH',
			 -value=>'TOKEN=1234abcd',
			 -expires=>'+14m',
			 -path=>'/');
}

# send header with cookie if we are setting it
if (defined($cookie)) {
   print $log_fh "Setting AUTH cookie\n";
   print $cgi->header(
       -type    => 'text/xml',
       -cookie  => $cookie
   );
} else {
   print $log_fh "No AUTH cookie to set\n";
   print $cgi->header(
       -type    => 'text/xml',
   );
}

###### XXX: disabled for now
# Database connection
#my $dbh = DBI->connect("dbi:SQLite:dbname=../db/yamenu.db", "", "", { RaiseError => 1, AutoCommit => 1 });
# Check if a session exists for the given IP address
#my $session_check_stmt = $dbh->prepare("SELECT user, last_active FROM user_sessions WHERE ip_address = ?");
#$session_check_stmt->execute($ip_address);
#my ($session_name, $session_last_active) = $session_check_stmt->fetchrow_array;

#if (defined($session_name)) {
#    # Session exists, update the last_active field
#    my $update_stmt = $dbh->prepare("UPDATE user_sessions SET last_active = datetime('now') WHERE ip_address = ?");
#    my $rv = $update_stmt->execute($ip_address);
#
#    if ($rv) {
#        # Session updated, continue with the biff or menu script
#        print $log_fh "cisco-menu: Session found for IP: $ip_address. Last active: " . $session_last_active . "\n";
#    } else {
#        print $log_fh "cisco-menu: Failed to update session for IP: $ip_address. Redirecting to login form.\n";
#        render_redirect($cgi, "$cgi_base/cisco-login.pl");
#    }
#} else {
#    # No session exists, redirect to login
#    print $log_fh "cisco-menu: No session found for IP: $ip_address. Redirecting to login form.\n";
#    render_redirect($cgi, "$cgi_base/cisco-login.pl");
#}
######### Authentication ##########

# Select the appropriate menu from template and render it
my $menu = $cfg->{$menu_id};
if ($menu->{type} eq 'PhoneMenu') {
    print render_phone_menu($cfg, $menu);
} elsif ($menu->{type} eq 'IconMenu') {
    print render_icon_file_menu($cfg, $menu);
} else {
    print "<CiscoIPPhoneError><Number>4</Number><Message>Unsupported menu type</Message></CiscoIPPhoneError>";
}

close $log_fh;
