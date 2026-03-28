#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Cwd qw(getcwd);
use JSON;

# Set CATALYST_HOME so config is loaded correctly
$ENV{CATALYST_HOME} = getcwd();

# Use Catalyst::Test to ensure the app is loaded
use Catalyst::Test 'AccessSystem::API';

# Load the OpenAPI module
use_ok('AccessSystem::API::OpenAPI');

# Load the app context to get the Catalyst instance
my $app = AccessSystem::API->new();

# Generate OpenAPI spec using the app's dispatcher
my $spec = AccessSystem::API::OpenAPI->generate_spec($app);

# Basic spec structure tests
ok($spec, "OpenAPI spec generated");
ok($spec->{openapi}, "Spec has openapi version");
ok($spec->{info}, "Spec has info section");
ok($spec->{paths}, "Spec has paths");
ok($spec->{components}, "Spec has components");

# Count endpoints
my $endpoint_count = scalar keys %{$spec->{paths}};
cmp_ok($endpoint_count, '>', 0, "Has at least one endpoint");
diag("Testing $endpoint_count endpoints");

# Track validation issues
my @warnings;
my @errors;

# Test each endpoint
for my $path (sort keys %{$spec->{paths}}) {
    for my $method (sort keys %{$spec->{paths}{$path}}) {
        my $op = $spec->{paths}{$path}{$method};
        my $endpoint_id = "$method $path";
        
        # Required fields
        ok($op->{operationId}, "$endpoint_id has operationId")
            or push @errors, "$endpoint_id missing operationId";
        ok($op->{summary}, "$endpoint_id has summary")
            or push @errors, "$endpoint_id missing summary";
        ok($op->{tags} && ref($op->{tags}) eq 'ARRAY', "$endpoint_id has tags array")
            or push @errors, "$endpoint_id missing/invalid tags";
        ok($op->{responses}, "$endpoint_id has responses")
            or push @errors, "$endpoint_id missing responses";
        
        # Tag validation (sanity checks)
        if ($op->{tags} && @{$op->{tags}}) {
            my $tag = $op->{tags}[0];
            if (length($tag) > 50) {
                push @warnings, "$endpoint_id tag is very long (>50 chars): $tag";
            }
            if ($tag =~ /[^\w\s\-&]/) {
                push @warnings, "$endpoint_id tag contains unusual characters: $tag";
            }
        }
        
        # HTTP method validation
        ok($method =~ /^(get|post|put|delete|patch|options|head)$/i, 
            "$endpoint_id has valid HTTP method")
            or push @errors, "$endpoint_id has invalid method: $method";
        
        # Parameter validation
        if ($op->{parameters}) {
            ok(ref($op->{parameters}) eq 'ARRAY', 
                "$endpoint_id parameters is an array")
                or next;
                
            for my $param (@{$op->{parameters}}) {
                # Required parameter fields
                ok($param->{name}, "$endpoint_id parameter has name")
                    or push @errors, "$endpoint_id has parameter without name";
                    
                ok($param->{in}, "$endpoint_id parameter '$param->{name}' has 'in' field")
                    or push @errors, "$endpoint_id parameter $param->{name} missing 'in'";
                    
                ok(exists $param->{required}, 
                    "$endpoint_id parameter '$param->{name}' has 'required' field")
                    or push @warnings, "$endpoint_id parameter $param->{name} missing 'required'";
                
                ok($param->{schema}, "$endpoint_id parameter '$param->{name}' has schema")
                    or push @errors, "$endpoint_id parameter $param->{name} missing schema";
                
                # Validate 'in' values
                if ($param->{in}) {
                    ok($param->{in} =~ /^(query|path|header|cookie)$/, 
                        "$endpoint_id parameter '$param->{name}' has valid 'in' value")
                        or push @errors, "$endpoint_id parameter $param->{name} has invalid 'in': $param->{in}";
                }
                
                # Path parameters must be required
                if ($param->{in} && $param->{in} eq 'path') {
                    ok($param->{required}, 
                        "$endpoint_id path parameter '$param->{name}' is required")
                        or push @errors, "$endpoint_id path param $param->{name} not marked required";
                }
            }
        }
        
        # Check for description (optional but recommended)
        if (!$op->{description}) {
            push @warnings, "$endpoint_id missing description";
        }
    }
}

# Report validation issues
if (@errors) {
    diag("\n=== ERRORS ===");
    diag("  $_") for @errors;
}

if (@warnings) {
    diag("\n=== WARNINGS ===");
    diag("  $_") for @warnings;
}

# Summary
diag("\n=== SUMMARY ===");
diag("Endpoints: $endpoint_count");
diag("Errors: " . scalar(@errors));
diag("Warnings: " . scalar(@warnings));

# Fail if there are errors, but warnings are OK
is(scalar(@errors), 0, "No validation errors");

done_testing();
