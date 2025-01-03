#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use LWP::UserAgent;
use JSON;
use YAML qw(LoadFile);
use URI::Escape qw(uri_escape);
use DBI;
use Data::Dumper;
use File::Slurp;
use lib '/svc/yamenu/perl-lib';
use poop qw(simple_preproc load_config);
use CiscoPhone qw(render_redirect);

my $log_file = "/svc/yamenu/logs/hass-proxy.log";
open our $log_fh, '>>', $log_file or die "Cannot open log file: $!";
my $cfg = load_config('/svc/yamenu/config.yml');
my $ha_url = $cfg->{'integrations'}{'hass'}{'ha_url'};
my $secrets = $cfg->{secrets};
my $ha_token = $secrets->{ha_token};
my $base_url = $cfg->{base_url};

# Initialize CGI
my $cgi = CGI->new;
my $message;

# Get parameters
my $act = $cgi->param('act');
my $area = $cgi->param('area');
my $entity = $cgi->param('entity');
my $state = $cgi->param('state');
my $referrer = $cgi->param('referrer');

# Validate required parameters
if (!$act || (!$entity && !$area)) {
    print to_json({ success => 0, message => "Missing 'act' or 'entity'/'area' parameter" });
    exit;
}

# HTTP Client
my $ua = LWP::UserAgent->new;
$ua->timeout(10);

# Perform the action based on 'act' parameter
if ($act eq 'get') {
    print $cgi->header('text/json');
    if ($entity eq 'areas') {
        # Enumerate areas and entities for Cisco IP Phone XML menu
        my $message = get_areas_and_entities($ua);
        print $message;  # Output the XML menu directly
    } elsif ($area) {
        # Fetch entities for a specific area
        my $message = get_entities_for_area($ua, $area);
        print $message;  # Output the entities for the area as an XML menu
    } else {
        # Fetch state of a specific entity
        my $message = get_entity_state($ua, $entity);
        print $message;  # Fetch state of a single entity
    }
} elsif ($act eq 'set') {
    print $cgi->header('text/xml');
    if ($state eq 'toggle') {
        print $log_fh "hass-proxy: Toggling entity $entity\n";
        $message = toggle_entity_state($ua, $entity);
        if (defined($referrer) && length($referrer)) {
           render_redirect($cgi, $referrer);
        } else {
           render_redirect($cgi, 'Key:NavBack');
        }
    } elsif ($state) {
        print $log_fh "hass-proxy: Setting entity $entity to state $state\n";
        $message = set_entity_state($ua, $entity, $state);
        if (defined($referrer) && length($referrer)) {
           render_redirect($cgi, $referrer);
        } else {
           render_redirect($cgi, 'Key:NavBack');
        }
    } else {
        print $log_fh "hass-proxy: Invalid state '$state' for set on $entity\n";
        $message = to_json({ success => 0, message => "Invalid 'state' for 'set' action" });
    }
} else {
    print $log_fh "hass-proxy: Invalid action '$act' on entity '$entity'\n";
    $message = to_json({ success => 0, message => "Invalid 'act' value. It should be 'get' or 'set'" });
}

sub get_areas_and_entities {
    my ($ua) = @_;

    # Fetch all states (entities) from Home Assistant
    my $req = HTTP::Request->new(GET => "$ha_url/states");
    $req->header('Authorization' => "Bearer $ha_token");
    my $res = $ua->request($req);
    
    if ($res->is_success) {
        my $entities_data = decode_json($res->decoded_content);
        
        # Build a list of areas from the entities
        my %areas;
        foreach my $entity (@{$entities_data}) {
            if (exists $entity->{attributes}{area_id}) {
                my $area_id = $entity->{attributes}{area_id};
                my $area_name = get_area_name($area_id);  # Assume you have a way to resolve area names
                $areas{$area_id}{name} = $area_name;
                push @{$areas{$area_id}{entities}}, $entity;
            }
        }
        
        return render_areas_menu(\%areas);
    } else {
        return "<CiscoIPPhoneText>
                    <Text>Failed to fetch areas: " . $res->status_line . "</Text>
                 </CiscoIPPhoneText>";
    }
}

# Retrieve area name from area ID (could be defined in your YAML or based on your system setup)
sub get_area_name {
    my ($area_id) = @_;
    
    # This should map area_id to area name, either from a YAML file or other source
    # For example:
    my %area_names = (
        'living_room' => 'Living Room',
        'kitchen' => 'Kitchen',
        'bedroom'  => 'Bedroom',
    );
    
    return $area_names{$area_id} || "Unknown Area";  # Return a default name if not found
}

# Render areas as Cisco IP Phone menu
sub render_areas_menu {
    my ($areas_data) = @_;
    my $xml = "<CiscoIPPhoneMenu>";

    foreach my $area_id (keys %$areas_data) {
        my $area_name = $areas_data->{$area_id}{name};
        my $area_url = "$base_url?act=get&area=$area_id";
        
        $xml .= "<MenuItem>
                    <Name>$area_name</Name>
                    <URL>$area_url</URL>
                 </MenuItem>";
    }
    
    $xml .= "</CiscoIPPhoneMenu>";
    return $xml;
}

# Render entities for a specific area
sub render_entities_menu {
    my ($entities_data, $area_id) = @_;
    my $xml = "<CiscoIPPhoneMenu>";
    
    foreach my $entity (@$entities_data) {
        my $entity_name = $entity->{attributes}{friendly_name};
        my $entity_id = $entity->{entity_id};
        
        # Construct the full URL to access the entity state or toggle
        my $entity_url = "$base_url?act=get&entity=$entity_id";
        
        $xml .= "<MenuItem>
                    <Name>$entity_name</Name>
                    <URL>$entity_url</URL>
                 </MenuItem>";
    }
    
    $xml .= "</CiscoIPPhoneMenu>";
    return $xml;
}

# Fetch the state of an entity
sub get_entity_state {
    my ($ua, $entity) = @_;
    my $req = HTTP::Request->new(GET => "$ha_url/states/$entity");
    $req->header('Authorization' => "Bearer $ha_token");

    my $res = $ua->request($req);
    if ($res->is_success) {
        my $data = decode_json($res->decoded_content);
        return to_json({ success => 1, entity => $entity, state => $data->{state} });
    } else {
        return to_json({ success => 0, message => "Failed to fetch entity state: " . $res->status_line });
    }
}

# Set the state of an entity
sub set_entity_state {
    my ($ua, $entity, $state) = @_;
    my $req = HTTP::Request->new(POST => "$ha_url/services/homeassistant/turn_$state");
    $req->header('Authorization' => "Bearer $ha_token");
    $req->header('Content-Type' => "application/json");
    $req->content(to_json({ entity_id => $entity }));

    my $res = $ua->request($req);
    if (!$res->is_success) {
        return to_json({ success => 1, message => "Entity state updated successfully" });
    } else {
        return to_json({ success => 0, message => "Failed to set entity state: " . $res->status_line });
    }
}

# Toggle the state of an entity
sub toggle_entity_state {
    my ($ua, $entity) = @_;
    
    # First, get the current state of the entity
    my $current_state = get_entity_state($ua, $entity);
    my $current_state_data = decode_json($current_state);
    
    if ($current_state_data->{success}) {
        my $new_state = ($current_state_data->{state} eq 'on') ? 'off' : 'on';
        return set_entity_state($ua, $entity, $new_state);
    } else {
        return to_json({ success => 0, message => "Failed to fetch entity state for toggle" });
    }
}

# Fetch entities for a specific area
sub get_entities_for_area {
    my ($ua, $area_id) = @_;

    # Fetch all states (entities) from Home Assistant
    my $req = HTTP::Request->new(GET => "$ha_url/states");
    $req->header('Authorization' => "Bearer $ha_token");
    my $res = $ua->request($req);
    
    if ($res->is_success) {
        my $entities_data = decode_json($res->decoded_content);
        
        # Filter entities by area_id
        my @entities_for_area;
        foreach my $entity (@{$entities_data}) {
            if (exists $entity->{attributes}{area_id} && $entity->{attributes}{area_id} eq $area_id) {
                push @entities_for_area, $entity;
            }
        }
        
        return render_entities_menu(\@entities_for_area, $area_id);
    } else {
        return "<CiscoIPPhoneText>
                    <Text>Failed to fetch entities for area $area_id: " . $res->status_line . "</Text>
                 </CiscoIPPhoneText>";
    }
}
close $log_fh;
