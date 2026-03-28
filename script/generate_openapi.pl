#!/usr/bin/env perl
#
# generate_openapi.pl - Generate OpenAPI 3.1 spec from Catalyst app introspection
#
# Usage:
#   CATALYST_HOME=$PWD carton exec perl script/generate_openapi.pl > openapi.yaml
#   CATALYST_HOME=$PWD carton exec perl script/generate_openapi.pl --json > openapi.json
#
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Cwd qw(getcwd);
use Getopt::Long;
use JSON;

# Set CATALYST_HOME if not already set
$ENV{CATALYST_HOME} ||= getcwd();

# Command line options
my $output_json = 0;
my $help = 0;
GetOptions(
    'json' => \$output_json,
    'help' => \$help,
) or die "Error in command line arguments\n";

if ($help) {
    print <<'USAGE';
Usage: generate_openapi.pl [OPTIONS]

Generate an OpenAPI 3.1 specification from the Catalyst application.

Options:
    --json      Output JSON instead of YAML
    --help      Show this help message

USAGE
    exit 0;
}

# Load the OpenAPI module
use AccessSystem::API::OpenAPI;

# Load the Catalyst app
require AccessSystem::API;
AccessSystem::API->setup_finalize();

# Generate the spec using the centralized module
my $spec = AccessSystem::API::OpenAPI->generate_spec_from_app('AccessSystem::API');

# Output
if ($output_json) {
    print JSON->new->pretty->canonical->encode($spec);
} else {
    print_yaml($spec);
}

# Simple YAML output (avoiding YAML::XS dependency)
sub print_yaml {
    my ($data, $indent) = @_;
    $indent //= 0;
    
    my $prefix = '  ' x $indent;
    
    if (ref $data eq 'HASH') {
        for my $key (sort keys %$data) {
            my $value = $data->{$key};
            if (!ref $value) {
                if (!defined $value) {
                    print "${prefix}${key}: null\n";
                } elsif ($value =~ /^[\d.]+$/ && $value !~ /^0\d/) {
                    print "${prefix}${key}: $value\n";
                } elsif ($value eq 'true' || $value eq 'false') {
                    print "${prefix}${key}: $value\n";
                } else {
                    # Quote strings that need it
                    if ($value =~ /[:[\]{}&#!|>'"%@`#,]/ || $value =~ /^\s/ || $value =~ /\s$/ || $value eq '') {
                        $value =~ s/'/\\'/g;
                        print "${prefix}${key}: '$value'\n";
                    } else {
                        print "${prefix}${key}: $value\n";
                    }
                }
            } elsif (ref $value eq 'ARRAY' && @$value == 0) {
                print "${prefix}${key}: []\n";
            } elsif (ref $value eq 'HASH' && keys(%$value) == 0) {
                print "${prefix}${key}: {}\n";
            } else {
                print "${prefix}${key}:\n";
                print_yaml($value, $indent + 1);
            }
        }
    } elsif (ref $data eq 'ARRAY') {
        for my $item (@$data) {
            if (!ref $item) {
                print "${prefix}- $item\n";
            } elsif (ref $item eq 'HASH' && keys(%$item) <= 2) {
                # Compact format for small hashes
                my @pairs;
                for my $k (sort keys %$item) {
                    my $v = $item->{$k};
                    if (!ref $v) {
                        push @pairs, "$k: $v";
                    }
                }
                if (@pairs == keys(%$item)) {
                    print "${prefix}- { " . join(', ', @pairs) . " }\n";
                } else {
                    print "${prefix}-\n";
                    print_yaml($item, $indent + 1);
                }
            } else {
                print "${prefix}-\n";
                print_yaml($item, $indent + 1);
            }
        }
    } elsif (ref $data eq 'JSON::PP::Boolean' || ref $data eq 'JSON::XS::Boolean') {
        print $data ? 'true' : 'false';
    }
}

__END__

=head1 NAME

generate_openapi.pl - Generate OpenAPI specification from Catalyst app

=head1 SYNOPSIS

    # Generate YAML (default)
    CATALYST_HOME=$PWD carton exec perl script/generate_openapi.pl > openapi.yaml
    
    # Generate JSON
    CATALYST_HOME=$PWD carton exec perl script/generate_openapi.pl --json > openapi.json

=head1 DESCRIPTION

This script uses the AccessSystem::API::OpenAPI module to generate an OpenAPI
3.1 specification by introspecting the Catalyst application's dispatcher and
parsing POD documentation from controller files.

=head1 OPTIONS

=over 4

=item --json

Output JSON instead of YAML

=item --help

Show help message

=back

=cut
