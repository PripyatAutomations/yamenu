package poop;
use strict;
use warnings;
use File::Slurp;
use File::Spec;
use YAML;
use Exporter 'import';
our @EXPORT_OK = ('simple_preproc', 'number_lines', 'load_config',
                  'url_filter');

# Transform URLs 
sub url_filter {
   my ($cfg, $url) = @_;

   $url =~ s/&/&amp;/g;
   $url =~ s/%%baseurl%%/$cfg->{base_url}/g;
   $url =~ s/%%cgi%%/$cfg->{cgi_base}/g;
   $url =~ s/%%img%%/$cfg->{img_base}/g;

   return $url;
}

# This gives us a way to replace strings with others, allowing variable expansion
# AND include files via @include "path"
sub simple_preproc {
    my ($file, $replacements) = @_;

    my $file_text = read_file($file) or die "Cannot open file $file: $!";

    if ($replacements && ref($replacements) eq 'HASH') {
        for my $placeholder (keys %{$replacements}) {
            my $replacement = $replacements->{$placeholder};
            $file_text =~ s/\Q$placeholder\E/$replacement/g;
        }
    }

    while ($file_text =~ /\@include\s+"([^"]+)"/g) {
        my $include_file = $1;

        # If the include file path is relative, make it absolute
        if ($include_file !~ m{^/} && $include_file !~ m{^[a-zA-Z]:}) {
            my $abs_file = File::Spec->rel2abs($file);
            my ($volume, $directories, $filename) = File::Spec->splitpath($abs_file);
            $include_file = File::Spec->catpath($volume, $directories, $include_file);
        }

        my $included_content = load_file_and_process($include_file);
        $file_text =~ s/\@include\s+"[^"]+"/$included_content/s;
    }

    return $file_text;
}

sub load_file_and_process {
    my ($file) = @_;

    my $file_content = read_file($file) or die "Cannot open include file $file: $!";
    return $file_content;
}

sub number_lines {
    my ($input) = @_;
    
    # Split the text into lines
    my @lines = split("\n", $input);
    
    # Calculate the number of lines (for padding)
    my $num_lines = scalar @lines;  # Correctly count the number of lines
    my $num_digits = length($num_lines);  # Calculate the number of digits required for padding
    
    # Prepend line numbers with padding
    my @numbered_lines;
    for my $i (0 .. $#lines) {
        my $line_number = sprintf("%${num_digits}d", $i + 1);  # Format the line number with padding
        push @numbered_lines, "$line_number $lines[$i]";
    }
    
    # Join the numbered lines back into a single string
    return join("\n", @numbered_lines);
}

sub load_config {
   my ($yaml_file) = @_;
   my $config_yaml = simple_preproc($yaml_file);
   my $rv = YAML::Load($config_yaml) or invalid_yaml($config_yaml);
   return $rv;
}

1;
