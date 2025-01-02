package poop;
use strict;
use warnings;
use File::Slurp;
use File::Spec;
use YAML;
use Exporter 'import';
our @EXPORT_OK = ('simple_preproc', 'number_lines', 'load_config',
                  'url_filter');

my $log_fh;

# Transform URLs 
sub url_filter {
   my ($cfg, $url) = @_;

   $url =~ s/&/&amp;/g;
   $url =~ s/%%baseurl%%/$cfg->{base_url}/g;
   $url =~ s/%%cgi%%/$cfg->{cgi_base}/g;
   $url =~ s/%%img%%/$cfg->{img_base}/g;

   return $url;
}

sub simple_preproc {
    my ($file, $replacements) = @_;
    my $file_text = read_file($file) or die "Cannot open file $file: $!";

    # Debugging line for initial file content
#    print $log_fh "Starting to process file: $file\n";
#    print $log_fh "Initial file content: $file_text\n";

    if ($replacements && ref($replacements) eq 'HASH') {
        for my $placeholder (keys %{$replacements}) {
            my $replacement = $replacements->{$placeholder};
#            print $log_fh "Performing replacement: $placeholder -> $replacement\n";
            $file_text =~ s/\Q$placeholder\E/$replacement/g;
        }
    }

    # Loop to process @include directives
    while ($file_text =~ /\@include\s+"([^"]+)"/g) {
        my $include_pattern = $1;
        print $log_fh "Found \@include pattern: $include_pattern\n";

        # If the include pattern contains a wildcard, expand to absolute path before globbing
        if ($include_pattern =~ /[*?]/) {
            # If the include file path is relative, make it absolute first
            if ($include_pattern !~ m{^/} && $include_pattern !~ m{^[a-zA-Z]:}) {
                my $abs_file = File::Spec->rel2abs($file);
                my ($volume, $directories, $filename) = File::Spec->splitpath($abs_file);
                $include_pattern = File::Spec->catpath($volume, $directories, $include_pattern);
                print $log_fh "Expanding to absolute path: $include_pattern\n";
            }

            # Now use glob to expand wildcard patterns into actual file paths
            my @included_files = glob($include_pattern);
            print $log_fh "Wildcard include files found: " . join(", ", @included_files) . "\n";

            if (@included_files) {
                for my $include_file (@included_files) {
                    print $log_fh "Including file: $include_file\n";
                    my $included_content = load_file_and_process($include_file);
                    # Replace the current @include directive with the included content
#                    print $log_fh "Replacing \@include with content from $include_file\n";
                    $file_text =~ s/\@include\s+"[^"]+"/$included_content/s;
                }
            } else {
                print $log_fh "warn: No files matched for wildcard include: $include_pattern\n";
            }
        } else {
            # Handle the case without wildcard (previous behavior)
            my $include_file = $include_pattern;

            # If the include file path is relative, make it absolute
            if ($include_file !~ m{^/} && $include_file !~ m{^[a-zA-Z]:}) {
                my $abs_file = File::Spec->rel2abs($file);
                my ($volume, $directories, $filename) = File::Spec->splitpath($abs_file);
                $include_file = File::Spec->catpath($volume, $directories, $include_file);
            }

            print $log_fh "Including direct path: $include_file\n";
            my $included_content = load_file_and_process($include_file);
            # Replace the current @include directive with the included content
#            print $log_fh "Replacing \@include with content from $include_file\n";
            $file_text =~ s/\@include\s+"[^"]+"/$included_content/s;
        }

        # Debugging line to show intermediate content after replacement
#        print $log_fh "File content after include replacement:\n$file_text\n";
    }

    return $file_text;
}

sub load_file_and_process {
    my ($file) = @_;

    my $file_content = read_file($file) or die "Cannot open include file $file: $!";
    return $file_content;
}

# XXX: fix this. it works sometimes
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
   my ($log, $yaml_file) = @_;
   $log_fh = $log;
   my $config_yaml = simple_preproc($yaml_file);
   my $rv = YAML::Load($config_yaml) or invalid_yaml($config_yaml);
   return $rv;
}

1;
