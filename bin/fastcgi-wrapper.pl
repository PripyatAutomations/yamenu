#!/usr/bin/perl

use FCGI;
use Socket;
use POSIX qw(setsid);
use IO::Handle;  # For buffering STDERR to a log file

require 'syscall.ph';

# Open the log file for writing (appending)
open my $log_fh, '>>', '/svc/yamenu/log/fastcgi-perl.error.log' or die "Cannot open logfile: $!";
# Redirect STDERR to the log file
open STDERR, '>&', $log_fh or die "Can't redirect STDERR to log file: $!";

&daemonize;

# This keeps the program alive or something after exec'ing perl scripts
END() { }
BEGIN() { }
*CORE::GLOBAL::exit = sub { die "fakeexit\nrc=".shift()."\n"; }; 
eval q{exit}; 
if ($@) { 
    exit unless $@ =~ /^fakeexit/; 
};

&main;

sub daemonize() {
    chdir '/'                 or die "Can't chdir to /: $!";
    defined(my $pid = fork)   or die "Can't fork: $!";
    exit if $pid;
    setsid                    or die "Can't start a new session: $!";
    umask 0;
}

sub main {
    $socket = FCGI::OpenSocket( "127.0.0.1:8999", 10 ); #use IP sockets
    $request = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, \%req_params, $socket );
    if ($request) { request_loop() };
    FCGI::CloseSocket( $socket );
}

sub request_loop {
    while( $request->Accept() >= 0 ) {
        
        # Processing any STDIN input from WebServer (for CGI-POST actions)
        $stdin_passthrough = '';
        $req_len = 0 + $req_params{'CONTENT_LENGTH'};
        if (($req_params{'REQUEST_METHOD'} eq 'POST') && ($req_len != 0)) { 
            my $bytes_read = 0;
            while ($bytes_read < $req_len) {
                my $data = '';
                my $bytes = read(STDIN, $data, ($req_len - $bytes_read));
                last if ($bytes == 0 || !defined($bytes));
                $stdin_passthrough .= $data;
                $bytes_read += $bytes;
            }
        }

        # Running the CGI app
        if ( (-x $req_params{SCRIPT_FILENAME}) &&  # Can I execute this?
             (-s $req_params{SCRIPT_FILENAME}) &&  # Is this file empty?
             (-r $req_params{SCRIPT_FILENAME})     # Can I read this file?
        ){
            pipe(CHILD_RD, PARENT_WR);
            my $pid = open(KID_TO_READ, "-|");
            unless(defined($pid)) {
                print("Content-type: text/plain\r\n\r\n");
                print "Error: CGI app returned no output - ";
                print "Executing $req_params{SCRIPT_FILENAME} failed !\n";
                print STDERR "Error: Failed to execute CGI app: $req_params{SCRIPT_FILENAME}\n";  # Log the error
                next;
            }
            if ($pid > 0) {
                close(CHILD_RD);
                print PARENT_WR $stdin_passthrough;
                close(PARENT_WR);

                while(my $s = <KID_TO_READ>) { print $s; }
                close KID_TO_READ;
                waitpid($pid, 0);
            } else {
                foreach $key ( keys %req_params){
                    $ENV{$key} = $req_params{$key};
                }
                # cd to the script's local directory
                if ($req_params{SCRIPT_FILENAME} =~ /^(.*)\/[^\/]+$/) {
                    chdir $1;
                }

                close(PARENT_WR);
                close(STDIN);
                #fcntl(CHILD_RD, F_DUPFD, 0);
                syscall(&SYS_dup2, fileno(CHILD_RD), 0);
                #open(STDIN, "<&CHILD_RD");
                exec($req_params{SCRIPT_FILENAME});
                print STDERR "Error: exec failed for $req_params{SCRIPT_FILENAME}\n";  # Log if exec fails
                die("exec failed");
            }
        } 
        else {
            print("Content-type: text/plain\r\n\r\n");
            print "Error: No such CGI app - $req_params{SCRIPT_FILENAME} may not ";
            print "exist or is not executable by this process.\n";
            print STDERR "Error: No such CGI app - $req_params{SCRIPT_FILENAME} may not exist or is not executable.\n";  # Log the error
        }
    }
}
