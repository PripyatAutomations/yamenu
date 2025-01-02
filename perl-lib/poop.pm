package poop;
use strict;
use warnings;
use File::Slurp;
use File::Spec;
use YAML;
use Exporter 'import';
our @EXPORT_OK = ('simple_preproc','load_config',
                  'url_filter');


my $debug = 1;
# my $debug = 0;
my $log_file = "/svc/yamenu/logs/preproc.log";
open our $ppl_fh, '>>', $log_file or die "Cannot open log file: $!";
open STDERR, '>&', $ppl_fh or die "Cannot redirect STDERR to log file: $!";

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

    print $ppl_fh "Starting to process file: $file\n";

    if ($replacements && ref($replacements) eq 'HASH') {
        for my $placeholder (keys %{$replacements}) {
            my $replacement = $replacements->{$placeholder};
            $file_text =~ s/$placeholder/$replacement/g;
        }
    }

    # Loop to process @include directives
    while ($file_text =~ /\@include\s+"([^"]+)"/g) {
        my $include_pattern = $1;
        print $ppl_fh "Found include pattern: $include_pattern\n";

        # Check if this is a wildcard include
        if ($include_pattern =~ /[*?]/) {
            print $ppl_fh "Wildcard include detected: $include_pattern\n";

            # Handle relative paths by converting them to absolute paths
            if ($include_pattern !~ m{^/} && $include_pattern !~ m{^[a-zA-Z]:}) {
                my $abs_file = File::Spec->rel2abs($file);
                my ($volume, $directories, $filename) = File::Spec->splitpath($abs_file);
                $include_pattern = File::Spec->catpath($volume, $directories, $include_pattern);
                print $ppl_fh "Expanding to absolute path: $include_pattern\n";
            }

            # Now use glob to expand wildcard patterns
            my @included_files = glob($include_pattern);
            print $ppl_fh "Wildcard include files found: " . join(", ", @included_files) . "\n";

            # Process each file matched by the wildcard
            if (@included_files) {
                for my $include_file (@included_files) {
                    print $ppl_fh "Including file: $include_file\n";
                    my $included_content = load_file_and_process($include_file);
                    print $ppl_fh "Replacing include with content from $include_file\n";

                    # Replace the @include directive with the content from the included file
                    $file_text =~ s/\@include "$include_pattern"/$included_content/s;
                }
            } else {
                print $ppl_fh "warn: No files matched for wildcard include: $include_pattern\n";
            }
        }
        else {
            # Handle regular includes (without wildcards)
            print $ppl_fh "Regular include detected: $include_pattern\n";

            # Handle the include path as usual
            if ($include_pattern !~ m{^/} && $include_pattern !~ m{^[a-zA-Z]:}) {
                my $abs_file = File::Spec->rel2abs($file);
                my ($volume, $directories, $filename) = File::Spec->splitpath($abs_file);
                $include_pattern = File::Spec->catpath($volume, $directories, $include_pattern);
            }

            # Process the regular include
            my $include_file = $include_pattern;
            my $included_content = load_file_and_process($include_file);
            print $ppl_fh "Replacing include with content from $include_file\n";
            $file_text =~ s/\@include "$include_pattern"/$included_content/s;
        }

        # Debugging line to show intermediate content after replacement
#        print $ppl_fh "File content after include replacement:\n$file_text\n";
    }


    print $ppl_fh "[preproc]\n";
    print $ppl_fh $file_text;
    print $ppl_fh "\n-------\n";
    return $file_text;
}

 sub load_file_and_process {
    my ($file) = @_;

    my $file_content = read_file($file) or die "Cannot open include file $file: $!";
    return $file_content;
}

sub load_config {
   my ($yaml_file) = @_;
   my $config_yaml = simple_preproc($yaml_file);
   print $ppl_fh "--- final ---\n";
   print $ppl_fh $config_yaml . "\n";
   print $ppl_fh "--- final ---\n";

   my $rv = YAML::Load($config_yaml) or invalid_yaml($config_yaml);
   return $rv;
}

1;
