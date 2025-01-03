package CiscoPhone;
use strict;
use warnings;
use Exporter 'import';
use CGI;
use JSON;
use lib '/srv/www/cgi-bin/lib';
use poop qw(url_filter);

our @EXPORT_OK = ( 'render_icon_file_menu', 'render_login_form',
'render_message', 'render_messages',
'render_phone_menu', 'render_redirect');

sub render_message {
    my ($cgi, $title, $prompt, $text, $url, $timeout) = @_;

    if (defined($url) && defined($timeout)) {
       print $cgi->header(-type => 'text/xml', -expires => '-1', -refresh => "$timeout; URL=$url");
    } else {
       print $cgi->header('text/xml');
    }
    print <<XML;
<CiscoIPPhoneText>
 <Title>$title</Title>
 <Prompt>$prompt</Prompt>
 <Text>$text</Text>
</CiscoIPPhoneText>
XML
}

# Subroutine to generate PhoneMenu XML
sub render_phone_menu {
    my ($cgi, $cfg, $menu) = @_;
    my $xml = "<CiscoIPPhoneMenu>\n";
    $xml .= "  <Title>$menu->{title}</Title>\n";
    $xml .= "  <Prompt>$menu->{prompt}</Prompt>\n";

    my $menu_name = $cgi->param('menu');
    my $cgi_base = $cfg->{'cgi_base'};
    my $url = "$cgi_base/cisco-menu.pl?menu=$menu_name";
    print $cgi->header(-type => 'text/xml', -expires => '-1', -refresh => "60; URL=$url");

    my $cgi_base = $cfg->{cgi_base};

    # Add menu items
    for my $item (@{$menu->{items}}) {
        $xml .= "  <MenuItem>\n";
        $xml .= "    <Name>$item->{name}</Name>\n";
        if ($item->{link}) {
            # Link to another menu
            $xml .= "    <URL>$cgi_base/cisco-menu.pl?menu=$item->{link}</URL>\n";
        } else {
            my $url = url_filter($cfg, $item->{url});
            $xml .= "    <URL>$url</URL>\n";
        }
        $xml .= "  </MenuItem>\n";
    }

    # Add softkeys
    if ($menu->{softkeys}) {
        for my $softkey (@{$menu->{softkeys}}) {
            $xml .= "  <SoftKeyItem>\n";
            $xml .= "    <Name>$softkey->{name}</Name>\n";
            if ($softkey->{link}) {
                # Link to another menu
                $xml .= "    <URL>$cgi_base/cisco-menu.pl?menu=$softkey->{link}</URL>\n";
            } else {
                my $url = $softkey->{url};
                $url =~ s/&/&amp;/g;
                $xml .= "    <URL>$url</URL>\n";
            }
            $xml .= "    <Position>$softkey->{position}</Position>\n";
            $xml .= "  </SoftKeyItem>\n";
        }
    }

    $xml .= "</CiscoIPPhoneMenu>\n";
    return $xml;
}

sub invert_state {
    my ($state) = @_;
    my $rv;

    if ($state eq 'off') {
       return 'on';
    } else {
       return 'off';
    }
}

sub parse_json {
    my ($json_string) = @_;
    my $json = JSON->new;
    my $data = $json->decode($json_string);

    return $data;
}

sub get_and_parse_json {
    my ($args) = @_;

    my $log_file = "/svc/yamenu/logs/cpm.log";
    open our $log_fh, '>>', $log_file or die "Cannot open log file: $!";
    open STDERR, '>&', $log_fh or die "Cannot redirect STDERR to log file: $!";
    # Set auto-flush on the file handle
    select($log_fh);
    $| = 1;  # Enable auto-flush
    select(STDOUT);  # Restore original default file handle

    # Ensure $args is a hash reference
    die "Expected a hash reference" unless ref($args) eq 'HASH';

    # Construct the argument string
    my @arg_list = map { "$_=$args->{$_}" } keys %$args;
    my $arg_string = join(' ', @arg_list);
    
    # Map the query string so we can simulate a CGI call without involving httpd
    my $query_string = join('&', map { "$_=$args->{$_}" } keys %$args);
    $ENV{'QUERY_STRING'} = $query_string; 

    # Execute the CGI script with the arguments and capture the output
    my $raw_output = `/svc/yamenu/cgi-bin/hass.pl $arg_string`;
#    print $log_fh "[cgi] Query: $arg_string got result: $raw_output\n";

    # Check if the command was successful
    if ($? == 0) {
       my ($headers, $json_string) = split(/\r?\n\r?\n/, $raw_output, 2);
       print $log_fh "[cgi] Query: $arg_string got result $json_string\n";
       return parse_json($json_string);
    } else {
       die "Failed to execute CGI script: $?";
    }
    close $log_fh;
}

# Subroutine to generate IconFileMenu XML
sub render_icon_file_menu {
    my ($cgi, $cfg, $menu) = @_;
    my $xml = "<CiscoIPPhoneIconFileMenu>\n";
    my $title_ico = $menu->{title_icon};
    my $cgi_base = $cfg->{cgi_base};

    my $log_file = "/svc/yamenu/logs/cpm.log";
    open our $log_fh, '>>', $log_file or die "Cannot open log file: $!";
    open STDERR, '>&', $log_fh or die "Cannot redirect STDERR to log file: $!";
    # Set auto-flush on the file handle
    select($log_fh);
    $| = 1;  # Enable auto-flush
    select(STDOUT);  # Restore original default file handle

    if (defined($title_ico) && length($title_ico)) {
       $xml .= "  <Title IconIndex=\"$title_ico\">$menu->{title}</Title>\n";
    } else {
       $xml .= "  <Title>$menu->{title}</Title>\n";
    }

    $xml .= "  <Prompt>$menu->{prompt}</Prompt>\n";

    # Add menu items with icons
    for my $item (@{$menu->{items}}) {
        $xml .= "  <MenuItem>\n";
        $xml .= "    <Name>$item->{name}</Name>\n";

        my $icon_off = $item->{icon};
        my $icon_on = $item->{icon_on};
        # Default to the off (default) icon
        my $icon = $icon_off;
        # Query the entity
        my $state = 'off';
        my $entity = $item->{entity};
        my $menu = $cgi->param('menu') || 'menu-hass';

        # If entity property set, prefer it.
        if (defined($entity) && length($entity)) {
           my $args = { act => 'get', entity => $entity };

           # Launch the query
           my $data = get_and_parse_json($args);
           if (defined($data->{state}) && length($data->{state})) {
              $state = $data->{state};
           }

           # And render the XML...
           my $new_state = invert_state($state);

           print $log_fh "[json] state: $state (toggle state: $new_state)\n";

           # prefer an actual state to using toggle
           if (defined($icon_on) && length($icon_on)) {
              $xml .= "    <URL>" . url_filter($cfg, "%%cgi%%/hass.pl?act=set&entity=$entity&state=$new_state&referrer=$menu") . "</URL>\n";
           } else {
              $xml .= "    <URL>" . url_filter($cfg, "%%cgi%%/hass.pl?act=set&entity=$entity&state=toggle`&referrer=$menu") . "</URL>\n";
           }
        } else {
           # If no entity, try link then url attributes
           if ($item->{link}) {
               # Link to another menu
               $xml .= "    <URL>$cgi_base/cisco-menu.pl?menu=$item->{link}</URL>\n";
           } else {
               my $url = url_filter($cfg, $item->{url});
               $xml .= "    <URL>$url</URL>\n";
           }
        }

        # There's an on icon defined
        if (defined($icon_on) && length($icon_on)) {
           # if it's ON, replace the icon index with the icon_on image
           if ($state eq 'on') {
              $icon = $icon_on;
              print $log_fh "[icon] set to on: $icon_on\n";
            } else {
              print $log_fh "[icon] left at off: $icon_off\n";
            }
        }

        # did we end up with an icon?
        if (defined($icon) && length($icon)) {
           $xml .= "    <IconIndex>" . $icon . "</IconIndex>\n";
        }
        $xml .= "  </MenuItem>\n";
    }

    # Add icon items
    for my $icon (@{$menu->{icons}}) {
        $xml .= "  <IconItem>\n";
        $xml .= "    <Index>" . $icon->{index} . "</Index>\n";
        my $url = url_filter($cfg, $icon->{url});
        $xml .= "    <URL>" . $url . "</URL>\n";
        $xml .= "  </IconItem>\n";
    }

    # Add softkeys
    if ($menu->{softkeys}) {
       for my $softkey (@{$menu->{softkeys}}) {
          my $entity = $softkey->{entity};
          $xml .= "  <SoftKeyItem>\n";
          $xml .= "    <Name>$softkey->{name}</Name>\n";
          if (defined($entity) && length($entity)) {
             $xml .= "    <URL>$cgi_base/hass.pl?act=set&state=toggle&entity=$entity</URL>\n";
          } elsif ($softkey->{link}) {
             # Link to another menu
             $xml .= "    <URL>$cgi_base/cisco-menu.pl?menu=$softkey->{link}</URL>\n";
          } else {
             my $url = url_filter($cfg, $softkey->{url});
             $xml .= "    <URL>$url</URL>\n";
          }
          $xml .= "    <Position>$softkey->{position}</Position>\n";
          $xml .= "  </SoftKeyItem>\n";
      }
    }
 
    $xml .= "</CiscoIPPhoneIconFileMenu>\n";
    close $log_fh;
    return $xml;
}

sub render_redirect {
    my ($cgi, $url) = @_;
    print $cgi->header('text/xml');
    print <<XML;
<CiscoIPPhoneExecute>
    <ExecuteItem URL="$url"/>
</CiscoIPPhoneExecute>
XML
}

sub render_messages {
    my ($cgi, $cfg) = @_;
    print $cgi->header('text/xml');
    print <<XML;
<Messages>
    <Message>
        <Number>3</Number>
        <New>2</New>
        <Saved>1</Saved>
        <Urgent>0</Urgent>
        <VoiceMailURL>$cfg->{cgi_base}/cisco-menu.pl?menu=messages</VoiceMailURL>
        <MessageStatus>Unread</MessageStatus>
    </Message>
</Messages>
XML
   exit;
}

# XXX: We should store Enter PIN ... and replace with the error from last try if set
sub render_login_form {
    my ($cgi, $cfg, $reason) = @_;

    print $cgi->header('text/xml');
    print <<XML;
<CiscoIPPhoneInput>
  <Title>RESTRICTED ACCESS</Title>
  <Prompt>Enter PIN to continue</Prompt>
  <URL>$cfg->{base_url}/cgi-bin/cisco-login.pl</URL>
  <InputItem>
    <DisplayName>PIN</DisplayName>
    <QueryStringParam>pin</QueryStringParam>
    <DefaultValue></DefaultValue>
    <InputFlags>N</InputFlags>
  </InputItem>
</CiscoIPPhoneInput>
XML
}

1;
