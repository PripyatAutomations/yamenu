#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use DBI;
use lib '/svc/yamenu/perl-lib';
use poop qw(simple_preproc load_config url_filter);
use CiscoPhone qw(render_icon_file_menu render_login_form render_message render_messages render_phone_menu render_redirect);
use YAML;

my $log_file = "/svc/yamenu/logs/cisco-auth.log";
open our $log_fh, '>>', $log_file or die "Cannot open log file: $!";
open STDERR, '>&', $log_fh or die "Cannot redirect STDERR to log file: $!";
my $cfg = load_config('/svc/yamenu/config.yml');

my $cgi = CGI->new;
my $use_biff = $cfg->{'use_biff'};
my $base_url = $cfg->{'base_url'};
render_redirect($cgi, "$base_url/cgi-bin/cisco-menu.pl");
my $cgi_base = $cfg->{'cgi_base'};
my $img_base = $cfg->{'img_base'};
my $req_ip = $cgi->remote_addr;
my $req_name = $cgi->param('name');
my $req_pin = $cgi->param('pin');

print $log_fh "cisco-auth: Login request from IP: $req_ip at " . localtime() . "\n";

# Temporarily disabled, as it's uneeded and broken - will fix when implement need_login: attribute on menus/items later
exit;

#print $log_fh "cgi-login: headers: " . $cgi->header_dump() . "\n";
my $dbh = DBI->connect("dbi:SQLite:dbname=../db/yamenu.db", "", "", { RaiseError => 1, AutoCommit => 1 });

# Expire inactive sessions (15 min) and in-progress logins (60 sec)
my $expire_stmt = $dbh->prepare(
    "DELETE FROM user_sessions 
     WHERE (last_active < datetime('now', '-900 seconds')) 
     OR (last_active < datetime('now', '-60 seconds') AND user IS NULL)"
);
$expire_stmt->execute;

# how many rows we touched?
my $del_rows = $expire_stmt->rows;
if ($del_rows > 0 ) {
   print $log_fh "cisco-auth: Expired $del_rows items\n";
}
$expire_stmt->finish();

# Check if a session exists in any state
my $session_query = "SELECT user, id, dev_name FROM user_sessions WHERE $req_ip = ?";
my $session_stmt = $dbh->prepare($session_query);
$session_stmt->execute($req_ip);
my $session_rows = $session_stmt->rows;
print $log_fh "Checking session ($session_rows rows)\n";

# No records exist, create the pre-auth and send them to login form
if ($session_stmt->rows == 0) {
   if (defined($req_name) && defined($req_ip)) {
      print $log_fh "cisco-auth: Saving pre-auth for ip $req_ip with dev_name $req_name\n";
      my $insert_stmt = $dbh->prepare("INSERT INTO user_sessions ($req_ip, dev_name) VALUES (?, ?)");
      my $rv = $insert_stmt->execute($req_ip, $req_name);
      $insert_stmt->finish();
      print $log_fh "cisco-auth session rv: $rv\n";

      # Re-execute the query to get our sid (XXX: can we get it from the query???)
      $session_stmt->execute($req_ip);
      print $log_fh "cisco-auth: Empty PIN! Sending login form to $req_ip\n";
      render_login_form($cfg, $cgi, "Login Required");
   }
} elsif ($session_stmt->rows >= 1) {
   my ($session_user, $session_id, $session_dev_name) = $session_stmt->fetchrow_array;

   print $log_fh "Checking PIN/session type: ";
   # If a user is set, this is an active session, send them to the menu
   if (defined($req_pin) && length($req_pin)) {
      print $log_fh " PIN!\n";
      # Otherwise, if present, validate the provided PIN
      my $req_pin_check_stmt = $dbh->prepare("SELECT name FROM users WHERE pin = ?");
      $req_pin_check_stmt->execute($req_pin);
      my ($user_name) = $req_pin_check_stmt->fetchrow_array;

      # It's a match!
      if (defined($user_name)) {
         print $log_fh "cisco-auth: Got valid PIN\n";
         # Update the session to nclude the device and user name
         my $update_stmt = $dbh->prepare("UPDATE user_sessions SET dev_name = ?, user = ?, last_active = datetime('now') WHERE $req_ip = ?");
         my $rv = $update_stmt->execute($req_name, $user_name, $req_ip);
         my $update_rows = $update_stmt->rows;
         $update_stmt->finish();
         print $log_fh "Finished update query with rv $rv and $update_rows affected\n";

         # Check if the insertion was successful
         if ($rv) {
            # Redirect to biff or main menu as configured
            print $log_fh "cisco-auth: Login successful for user ($user_name) by PIN from IP: $req_ip\n";
            if ($use_biff == 1) {
               render_redirect($cgi, "$base_url/cgi-bin/cisco-biff.pl");
            } else {
               render_redirect($cgi, "$base_url/cgi-bin/cisco-menu.pl");
            }
         } else {
            print $log_fh "cisco-auth: Failed to insert session for PIN: $req_pin from IP: $req_ip. DB error: " . $dbh->errstr . "\n";
            render_redirect($cgi, '$base_url/cgi-bin/cisco-login.pl?err=DB+Error');
         }
      }
   } elsif (defined($session_user) && length($session_user)) {
      print $log_fh " Session with ID $session_id for user '$session_user' on ip $req_ip with dev_name $session_dev_name\n";
      # Update the last_active field for the given IP address and user
      my $update_stmt = $dbh->prepare("UPDATE user_sessions SET last_active = datetime('now') WHERE id = ?");
      my $rv = $update_stmt->execute($session_id);
      $update_stmt->finish();
      render_redirect($cgi, '$base_url/cgi-bin/cisco-menu.pl');
   }
}

# Close the database connection
$session_stmt->finish();
$dbh->disconnect;

# Close the log file
close $log_fh;
