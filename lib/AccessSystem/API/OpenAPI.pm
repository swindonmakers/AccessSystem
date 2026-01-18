package AccessSystem::API::OpenAPI;

use strict;
use warnings;
use Data::Dumper;
use JSON;
use File::Find;
use File::Spec;

our $VERSION = '1.0.0';

# Tag descriptions for OpenAPI spec
my %TAG_DESCRIPTIONS = (
    'Access Control' => 'Endpoints for IoT devices and access controllers',
    'Member Registration' => 'Endpoints for member registration and profile management',
    'Authentication' => 'Login and logout endpoints',
    'Transactions' => 'Member transaction/balance endpoints',
    'Admin' => 'Administrative endpoints',
    'Telegram' => 'Telegram bot integration endpoints',
    'Documentation' => 'API documentation endpoints',
);

# Caches for parsed POD metadata
my %_pod_cache;  # Stores { params => [...], tag => '...', methods => [...] }

=head1 NAME

AccessSystem::API::OpenAPI - Generate OpenAPI spec from Catalyst app

=head1 SYNOPSIS

    use AccessSystem::API::OpenAPI;
    
    # From a controller
    my $spec = AccessSystem::API::OpenAPI->generate_spec($c);
    
    # From a script
    my $spec = AccessSystem::API::OpenAPI->generate_spec_from_app('AccessSystem::API');

=head1 DESCRIPTION

This module generates an OpenAPI 3.1 specification by introspecting
Catalyst dispatchers and parsing POD documentation from controller files.

=cut

sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
}

=head2 generate_spec($c)

Generate OpenAPI spec from a Catalyst context object.

=cut

sub generate_spec {
    my ($class, $c) = @_;
    
    my $base_url = $c->request->base;
    $base_url =~ s{/$}{};
    
    return $class->_build_spec(
        dispatcher => $c->dispatcher,
        base_url => $base_url,
        app_class => ref($c) || $c,
    );
}

=head2 generate_spec_from_app($app_class)

Generate OpenAPI spec by loading a Catalyst app class.

=cut

sub generate_spec_from_app {
    my ($class, $app_class) = @_;
    
    eval "require $app_class" or die "Cannot load $app_class: $@";
    $app_class->setup_finalize() if $app_class->can('setup_finalize');
    
    return $class->_build_spec(
        dispatcher => $app_class->dispatcher,
        base_url => 'http://localhost:3000',
        app_class => $app_class,
    );
}

sub _build_spec {
    my ($class, %args) = @_;
    
    my $dispatcher = $args{dispatcher};
    my $base_url = $args{base_url};
    my $app_class = $args{app_class};
    
    my $spec = {
        openapi => '3.1.0',
        info => {
            title => 'Swindon Makerspace Access System API',
            description => 'A (semi-)automated access system for registering new members and giving them access to the physical space.
It provides:
- A registration form for new members to sign up
- The ability to match RFID tokens to members
- An API for controllers (e.g., the Door) to verify if an RFID token is valid

## Security Note

The database stores an expected IP for each Thing controller. These are assigned as fixed IPs 
to the controllers by the main network router. The API verifies that the IP of an incoming 
request matches the expected IP for the claimed thing controller ID.',
            version => $VERSION,
            contact => {
                name => 'Swindon Makerspace',
                url => 'https://www.swindon-makerspace.org',
            },
        },
        servers => [
            { url => $base_url, description => 'Current server' },
            { url => 'https://inside.swindon-makerspace.org', description => 'Production server' },
        ],
        paths => {},
        components => {
            schemas => {},
            securitySchemes => {
                cookieAuth => {
                    type => 'apiKey',
                    in => 'cookie',
                    name => 'accesssystem_cookie',
                },
            },
        },
        tags => [],
    };
    
    my %tags;
    
    # Parse POD from all controller files
    $class->_parse_all_controller_pods($app_class);
    
    # Process dispatch types
    for my $dispatch_type (@{$dispatcher->dispatch_types}) {
        my $type = ref($dispatch_type);
        
        if ($type eq 'Catalyst::DispatchType::Path') {
            my $paths = $dispatch_type->_paths || {};
            for my $path (keys %$paths) {
                for my $action (@{$paths->{$path}}) {
                    $class->_add_path_from_action($spec, $path, $action, \%tags);
                }
            }
        }
        elsif ($type eq 'Catalyst::DispatchType::Chained') {
            my $endpoints = $dispatch_type->_endpoints || [];
            for my $action (@$endpoints) {
                my $path = $class->_build_chained_path($dispatch_type, $action);
                $class->_add_path_from_action($spec, $path, $action, \%tags, { no_args => 1 }) if $path;
            }
        }
    }
    
    # Build tags array with descriptions
    for my $tag (sort keys %tags) {
        push @{$spec->{tags}}, { 
            name => $tag,
            ($TAG_DESCRIPTIONS{$tag} ? (description => $TAG_DESCRIPTIONS{$tag}) : ()),
        };
    }
    
    return $spec;
}

sub _add_path_from_action {
    my ($class, $spec, $path, $action, $tags, $opts) = @_;
    $opts ||= {};
    
    $path = '/' . $path unless $path =~ m{^/};
    $path =~ s{/+}{/}g;
    
    # Skip internal actions
    return if $action->name =~ /^(auto|begin|end|default|index)$/;
    return if $action->attributes->{Private};
    
    my $method_name = $action->name;
    
    # Get metadata from POD documentation
    my $tag = $class->_get_tag($method_name);
    
    # Skip undocumented endpoints
    return if $tag eq 'Uncategorised';
    
    # Handle Args at end (only if not already handled by chained path builder)
    my $args = $action->attributes->{Args};
    if (!$opts->{no_args} && $args && @$args && $args->[0] ne '' && $args->[0] =~ /^\d+$/) {
        for (1..$args->[0]) {
            $path .= "/{arg$_}";
        }
    }
    
    # Get tag from POD
    $tags->{$tag} = 1;
    
    # Rename {argN} using signature parameters
    my $sig_params = $class->_get_signature_params($method_name);
    if ($sig_params && @$sig_params) {
        $path =~ s/\{arg(\d+)\}/ $sig_params->[$1-1] ? "{" . $sig_params->[$1-1] . "}" : "{arg$1}" /ge;
    }

    # Determine HTTP methods from POD or source analysis
    my @methods = $class->_get_http_methods($method_name);
    
    for my $http_method (@methods) {
        my $operation = {
            operationId => $method_name . ($http_method eq 'post' ? '_post' : ''),
            summary => $class->_humanize_name($method_name),
            tags => [$tag],
            responses => {
                '200' => { description => 'Successful response' },
            },
        };
        
        # Add description from POD
        my $desc = $class->_get_description($method_name);
        $operation->{description} = $desc if $desc;
        
        # Adjust operation details based on method
        if ($http_method eq 'post') {
            $operation->{requestBody} = {
                required => JSON::true,
                content => {
                    'application/x-www-form-urlencoded' => {
                        schema => { type => 'object' }
                    }
                }
            };
        }
        
        # Add parameters from POD
        my @path_params = ($path =~ /\{(\w+)\}/g);
        my %path_params_seen;
        if (@path_params) {
            $operation->{parameters} = [];
            
            # Fetch POD params to augment path params
            my $pod_params = $class->_get_query_params($method_name) || [];
            my %pod_params_map = map { $_->{name} => $_ } @$pod_params;
            
            for my $param (@path_params) {
                $path_params_seen{$param} = 1;
                my $param_def = {
                    name => $param,
                    in => 'path',
                    required => JSON::true,
                    schema => { type => 'string' },
                };
                
                # Merge details from POD if available
                if ($pod_params_map{$param}) {
                    $param_def->{description} = $pod_params_map{$param}->{description};
                    $param_def->{schema} = $pod_params_map{$param}->{schema};
                }
                
                push @{$operation->{parameters}}, $param_def;
            }
        }
        
        # Add query parameters from POD (excluding those used in path)
        my $query_params = $class->_get_query_params($method_name);
        if ($query_params && @$query_params) {
            $operation->{parameters} ||= [];
            for my $p (@$query_params) {
                next if $path_params_seen{$p->{name}};
                push @{$operation->{parameters}}, $p;
            }
        }
        
        $spec->{paths}{$path} ||= {};
        $spec->{paths}{$path}{$http_method} = $operation;
    }
}

sub _build_chained_path {
    my ($class, $dispatch_type, $action) = @_;
    
    my @parts;
    my $current = $action;
    my %seen;
    
    while ($current && !$seen{$current}++) {
        my $path_part = $current->attributes->{PathPart};
        if ($path_part && @$path_part && $path_part->[0] ne '') {
            unshift @parts, $path_part->[0];
        }
        
        my $capture = $current->attributes->{CaptureArgs};
        if ($capture && @$capture && $capture->[0] > 0) {
            for (1..$capture->[0]) {
                push @parts, "{capture_$_}";
            }
        }
        
        my $parent = $current->attributes->{Chained};
        last unless $parent && @$parent;
        
        my $parent_action = $dispatch_type->_actions->{$parent->[0]};
        last unless $parent_action;
        $current = $parent_action;
    }
    
    my $args = $action->attributes->{Args};
    if ($args && @$args && $args->[0] ne '' && $args->[0] =~ /^\d+$/) {
        for (1..$args->[0]) {
            push @parts, "{arg$_}";
        }
    }
    
    my $path = '/' . join('/', @parts);
    $path =~ s{/+}{/}g;
    
    return $path;
}

sub _get_http_methods {
    my ($class, $name) = @_;
    
    # Check POD-defined methods first
    if (exists $_pod_cache{$name} && $_pod_cache{$name}{methods}) {
        return @{$_pod_cache{$name}{methods}};
    }
    
    # Fall back to source code analysis
    if (exists $_pod_cache{$name} && $_pod_cache{$name}{detected_methods}) {
        return @{$_pod_cache{$name}{detected_methods}};
    }
    
    # Default to GET
    return ('get');
}

# Infer tag from method name patterns
sub _infer_tag {
    my ($method_name) = @_;
    
    return 'Authentication' if $method_name =~ /login|logout|auth|token/i;
    return 'Member Registration' if $method_name =~ /register|signup|member|profile/i;
    return 'Tools' if $method_name =~ /tool/i;
    return 'Vehicles' if $method_name =~ /vehicle/i;
    return 'Transactions' if $method_name =~ /transaction|payment/i;
    return 'Admin' if $method_name =~ /admin/i;
    
    return 'Uncategorised';
}

sub _get_tag {
    my ($class, $name) = @_;
    
    # Check POD-defined tag first
    if (exists $_pod_cache{$name} && $_pod_cache{$name}{tag}) {
        return $_pod_cache{$name}{tag};
    }
    
    # Fall back to 'Uncategorised'
    return 'Uncategorised';
}

# Default categorization for endpoints without POD Tags
sub _categorize_action_default {
    return 'Uncategorised';
}

sub _get_description {
    my ($class, $name) = @_;
    return $_pod_cache{$name}{description};
}

sub _get_signature_params {
    my ($class, $name) = @_;
    return $_pod_cache{$name}{signature_params};
}

sub _humanize_name {
    my ($class, $name) = @_;
    $name =~ s/_/ /g;
    return ucfirst($name);
}

sub _get_query_params {
    my ($class, $name) = @_;
    return $_pod_cache{$name}{params} || [];
}

# Parse POD from all controller files in the app
sub _parse_all_controller_pods {
    my ($class, $app_class) = @_;
    
    return if %_pod_cache;  # Already parsed
    
    # Find the lib directory
    my $app_file = $app_class;
    $app_file =~ s{::}{/}g;
    $app_file .= '.pm';
    
    my $lib_dir;
    for my $inc (@INC) {
        if (-f "$inc/$app_file") {
            $lib_dir = $inc;
            last;
        }
    }
    
    return unless $lib_dir;
    
    # Find all Controller .pm files
    my @controller_files;
    my $wanted = sub {
        return unless /\.pm$/;
        return unless $File::Find::name =~ /Controller/;
        push @controller_files, $File::Find::name;
    };
    
    File::Find::find($wanted, $lib_dir);
    
    # Parse each controller file
    for my $file (@controller_files) {
        $class->_parse_controller_pod($file);
    }
}

# Parse POD documentation from a controller file to extract parameters
sub _parse_controller_pod {
    my ($class, $file) = @_;
    
    open my $fh, '<', $file or return;
    my $content = do { local $/; <$fh> };
    close $fh;
    
    # Find all POD blocks with parameters followed by sub definitions
    # Pattern: =head2 name ... =item param = description ... =cut ... sub name
    while ($content =~ m{
        =head2\s+(\w+)          # Capture the endpoint name
        (.*?)                    # Capture POD content
        =cut\s*\n               # End of POD
        \s*sub\s+\1             # Sub definition with same name
    }gxs) {
        my ($endpoint_name, $pod_content) = ($1, $2);
        
        # Initialize cache entry
        $_pod_cache{$endpoint_name} ||= {};
        
        # Parse Tags: line with validation
        if ($pod_content =~ /^Tags?:\s*(.+)$/m) {
            my $tag = $1;
            $tag =~ s/\s+$//;
            
            # Validate tag: reasonable length and no weird characters
            if (length($tag) > 50) {
                warn "WARNING: Tag '$tag' for $endpoint_name is very long (>50 chars)\n";
            }
            if ($tag =~ /[^\w\s\-&]/) {
                warn "WARNING: Tag '$tag' for $endpoint_name contains unusual characters\n";
            }
            
            $_pod_cache{$endpoint_name}{tag} = $tag;
        } else {
            # Smart default: infer from method name
            my $inferred_tag = _infer_tag($endpoint_name);
            warn "INFO: No tag specified for $endpoint_name, using inferred tag '$inferred_tag'\n" 
                if $ENV{OPENAPI_DEBUG};
            $_pod_cache{$endpoint_name}{tag} = $inferred_tag;
        }
        
        # Parse Methods: line with validation
        if ($pod_content =~ /^Methods?:\s*(.+)$/m) {
            my $methods_str = $1;
            $methods_str =~ s/\s+$//;
            my @methods = map { lc($_) } split /[,\s]+/, $methods_str;
            
            # Validate HTTP methods
            my @valid_methods = qw(get post put delete patch options head);
            my @invalid = grep { my $m = $_; !grep { $_ eq $m } @valid_methods } @methods;
            if (@invalid) {
                warn "ERROR: Invalid HTTP method(s) for $endpoint_name: " . join(', ', @invalid) . "\n";
                @methods = grep { my $m = $_; grep { $_ eq $m } @valid_methods } @methods;
            }
            
            $_pod_cache{$endpoint_name}{methods} = \@methods if @methods;
        } else {
            # Default will be inferred by source code analysis later
            warn "INFO: No methods specified for $endpoint_name, will use source code analysis\n"
                if $ENV{OPENAPI_DEBUG};
        }

        # Extract description (everything that is not Tags, Methods, or param blocks)
        my $desc = $pod_content;
        $desc =~ s/^Tags:.*$//mg;
        $desc =~ s/^Methods:.*$//mg;
        $desc =~ s/=over.*//sg;
        $desc =~ s/^\s+|\s+$//g;
        $_pod_cache{$endpoint_name}{description} = $desc if length($desc);
        
        # Parse =item entries for parameters
        my @params;
        while ($pod_content =~ m{=item\s+(\w+)\s*(?:\(([^)]*)\))?\s*[=-]\s*(.+?)(?=\n\n|\n=|$)}gs) {
            my ($param_name, $modifiers, $description) = ($1, $2 // '', $3);
            $description =~ s/\s+$//;
            
            # Parse modifiers like "required", "uuid", "integer", etc.
            my $required = ($modifiers =~ /required/i) ? JSON::true : JSON::false;
            my $type = 'string';
            my $format;
            
            if ($modifiers =~ /\binteger\b/i) {
                $type = 'integer';
            } elsif ($modifiers =~ /\bnumber\b/i) {
                $type = 'number';
            } elsif ($modifiers =~ /\bboolean\b/i) {
                $type = 'boolean';
            }
            
            if ($modifiers =~ /\buuid\b/i) {
                $format = 'uuid';
            } elsif ($modifiers =~ /\bemail\b/i) {
                $format = 'email';
            }
            
            my $param = {
                name => $param_name,
                in => 'query',
                required => $required,
                schema => { type => $type },
                description => $description,
            };
            $param->{schema}{format} = $format if $format;
            
            push @params, $param;
        }
        
        $_pod_cache{$endpoint_name}{params} = \@params if @params;
    }
    
    # Source code analysis: detect HTTP methods from subroutine implementations
    $class->_analyze_controller_methods($content);
}

# Analyze controller source code to detect HTTP methods
sub _analyze_controller_methods {
    my ($class, $content) = @_;
    
    # Find all subs with attributes (controller actions)
    my @subs = $content =~ /^sub\s+(\w+)\s*:\s*[^\n]+/gm;
    
    for my $sub_name (@subs) {

        # Initialize cache entry
        $_pod_cache{$sub_name} ||= {};
        
        # Extract the subroutine body using a simple heuristic
        # Look for the sub definition and capture until we see the next sub or end
        my ($sub_body) = $content =~ /sub\s+$sub_name\s*:[^\n]+\{(.{1,3000}?)(?=\nsub\s+\w|\n__(?:END|DATA)__|$)/s;
        next unless $sub_body;

        # Extract Parameter Names from Signature
        if ($sub_body =~ /my\s*\(\s*\$self\s*,\s*\$c\s*(?:,\s*([^)]+))?\)\s*=\s*\@_/) {
            my $args_str = $1;
            if ($args_str) {
                my @arg_names = split /\s*,\s*/, $args_str;
                @arg_names = map { s/^[\$\@\%]//; $_ } @arg_names;
                # print STDERR "DEBUG: Found signature for $sub_name: @arg_names\n";
                $_pod_cache{$sub_name}{signature_params} = \@arg_names if @arg_names;
            }
        }
        
        # Skip method detection if already defined
        next if exists $_pod_cache{$sub_name} && $_pod_cache{$sub_name}{methods};
        
        # Detect POST-specific patterns
        my $has_post_patterns = 0;
        my $has_form_render = 0;
        
        # POST-only patterns (body params, method check, callbacks, db writes)
        $has_post_patterns = 1 if $sub_body =~ /->body_params/
            || $sub_body =~ /->method\s*eq\s*['"]POST['"]/i
            || $sub_body =~ /connection_token/
            || $sub_body =~ /->(?:txn_do|create|update|delete)/; # DB writes imply POST
        
        # Form rendering patterns (indicates GET for display)
        $has_form_render = 1 if $sub_body =~ /stash\s*\([^)]*template\s*=>/i
            || $sub_body =~ /\$form->/;
        
        # Determine methods based on detected patterns
        if ($has_form_render && $has_post_patterns) {
            # Form with both display and submit
            $_pod_cache{$sub_name}{detected_methods} = ['get', 'post'];
        } elsif ($has_form_render) {
            # Form display + submit pattern
            $_pod_cache{$sub_name}{detected_methods} = ['get', 'post'];
        } elsif ($has_post_patterns) {
            # POST-only (API endpoint, callback)
            $_pod_cache{$sub_name}{detected_methods} = ['post'];
        }
        # Otherwise, default to GET (handled in _get_http_methods)
    }
}

1;

__END__

=head1 POD DOCUMENTATION FORMAT

To document an endpoint, use this format in the controller:

    =head2 endpoint_name

    Description of the endpoint.

    Tags: Access Control

    Methods: GET, POST

    =over

    =item param_name (modifiers) - Description

    =back

    =cut

    sub endpoint_name ...

=head2 SUPPORTED FIELDS

=over

=item B<Tags:> (optional)

The OpenAPI tag/category for this endpoint.
If not specified, a default categorization is used.
Example: C<Tags: Access Control>

=item B<Methods:> (optional)

HTTP methods this endpoint accepts. Comma or space separated.
If not specified, defaults to GET.
Example: C<Methods: GET, POST> or C<Methods: POST>

=back

=head2 PARAMETER MODIFIERS

Use modifiers in parentheses after the parameter name:

=over

=item * C<required> - marks parameter as required

=item * C<uuid> - adds format: uuid

=item * C<email> - adds format: email  

=item * C<integer> - sets type to integer

=item * C<number> - sets type to number

=item * C<boolean> - sets type to boolean

=back

=head2 COMPLETE EXAMPLE

    =head2 park

    Parks a vehicle for a member identified by their token.

    Tags: Access Control

    Methods: GET

    =over

    =item token (required) - Access token ID of the member

    =item thing (required, uuid) - GUID of the parking controller

    =back

    =cut

    sub park : Chained('base') : PathPart('park') : Args(0) {
        ...
    }

=cut
