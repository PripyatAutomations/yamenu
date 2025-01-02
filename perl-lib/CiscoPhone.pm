package CiscoPhone;
use strict;
use warnings;
use Exporter 'import';
use CGI;
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
    my ($cfg, $menu) = @_;
    my $xml = "<CiscoIPPhoneMenu>\n";
    $xml .= "  <Title>$menu->{title}</Title>\n";
    $xml .= "  <Prompt>$menu->{prompt}</Prompt>\n";

    # Add menu items
    for my $item (@{$menu->{items}}) {
        $xml .= "  <MenuItem>\n";
        $xml .= "    <Name>$item->{name}</Name>\n";
        if ($item->{link}) {
            # Link to another menu
            $xml .= "    <URL>$cfg->{cgi_base}/cisco-menu.pl?menu=$item->{link}</URL>\n";
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
                $xml .= "    <URL>$cfg->{cgi_base}/cisco-menu.pl?menu=$softkey->{link}</URL>\n";
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

# Subroutine to generate IconFileMenu XML
sub render_icon_file_menu {
    my ($cfg, $menu) = @_;
    my $xml = "<CiscoIPPhoneIconFileMenu>\n";
    my $title_ico = $menu->{title_icon};

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

        if ($item->{link}) {
            # Link to another menu
            $xml .= "    <URL>$cfg->{cgi_base}/cisco-menu.pl?menu=$item->{link}</URL>\n";
        } else {
            my $url = url_filter($cfg, $item->{url});
            $xml .= "    <URL>$url</URL>\n";
        }

        my $icon = $item->{icon};
        if (defined($icon) && length($icon)) {
           $xml .= "    <IconIndex>" . ($item->{icon} || 0) . "</IconIndex>\n";
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
            $xml .= "  <SoftKeyItem>\n";
            $xml .= "    <Name>$softkey->{name}</Name>\n";
            if ($softkey->{link}) {
                # Link to another menu
                $xml .= "    <URL>$cfg->{cgi_base}/cisco-menu.pl?menu=$softkey->{link}</URL>\n";
            } else {
                my $url = url_filter($cfg, $softkey->{url});
                $xml .= "    <URL>$url</URL>\n";
            }
            $xml .= "    <Position>$softkey->{position}</Position>\n";
            $xml .= "  </SoftKeyItem>\n";
        }
    }

    $xml .= "</CiscoIPPhoneIconFileMenu>\n";
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
    my ($cfg, $cgi) = @_;
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
    my ($cfg, $cgi, $reason) = @_;

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
