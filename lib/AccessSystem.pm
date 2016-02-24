package AccessSystem;
use Moose;
use namespace::autoclean;

use RapidApp 1.1005;

use Catalyst qw/
    -Debug
    RapidApp::RapidDbic
    RapidApp::TabGui
    RapidApp::AuthCore
    RapidApp::CoreSchemaAdmin
    RapidApp::NavCore
/;

extends 'Catalyst';

our $VERSION = '0.01';

__PACKAGE__->config(
    name => 'AccessSystem',

    'Plugin::RapidApp::RapidDbic' => {
     dbic_models => ['AccessDB'],
      
     # All custom configs optional...
     configs => {
       DB => {
         grid_params => {
           # ...
         },
         TableSpecs => {
           # ...
         }
       },
       OtherModel => {
         # ...
       }
     }
   },
    # The TabGui plugin mounts the standard ExtJS explorer interface as the 
    # RapidApp root module (which is at the root '/' of the app by default)
    'Plugin::RapidApp::TabGui' => {
      title => "AccessSystem v$VERSION",
      nav_title => 'Administration',
      # Templates with the *.md extension render as simple Markdown:
      dashboard_url => '/tple/site/dashboard.md',
      # Make all templates in site/ (root/templates/site/) browsable in nav tree:
      template_navtree_regex => '^site/'
    },

    # The general 'RapidApp' config controls aspects of the special components that
    # are globally injected/mounted into the Catalyst application dispatcher:
    'RapidApp' => {
      ## To change the root RapidApp module to be mounted someplace other than
      ## at the root (/) of the Catalyst app (default is '' which is the root)
      #module_root_namespace => 'adm',

      ## To load additional, custom RapidApp modules (under the root module):
      #load_modules => { somemodule => 'Some::RapidApp::Module::Class' }
    },

    # Customize the behaviors of the built-in "Template Controller" which is used
    # to serve template files application-wide. Locally defined Templates, if present,
    # are served from 'root/templates' (relative to the application home directory)
    'Controller::RapidApp::Template' => {
      # Templates ending in *.html can be accessed without the extension:
      default_template_extension => 'html',

      # Params to be supplied to the Template Access class:
      access_params => {
        # Make all template paths under site/ (root/templates/site/) editable:
        writable_regex      => '^site/',
        creatable_regex     => '^site/',
        deletable_regex     => '^site/',

        ## To declare templates under site/public/ (root/templates/site/public/)
        ## to be 'external' (will render in an iframe in the TabGui):
        #external_tpl_regex  => '^site/public/',
      },

      ## To declare a custom template access class instead of the default (which 
      ## is RapidApp::Template::Access). The Access class is used to determine
      ## exactly what type of access is allowed for each template/user, as well as
      ## which template variables should be available when rendering each template
      ## (Note: the access_params above are still supplied to ->new() ):
      #access_class => 'AccessSystem::Template::Access',

      ## To directly serve templates from the application root (/) namespace for
      ## easy, public-facing content:
      #root_template_prefix  => 'site/public/page/',
      #root_template         => 'site/public/page/home',
    },

    # The AuthCore plugin automatically configures standard Catalyst Authentication,
    # Authorization and Session plugins, using the RapidApp::CoreSchema database
    # to store session and user databases. Opon first initialization, the default
    # user 'admin' is created with default password 'pass'. No options are required
    'Plugin::RapidApp::AuthCore' => {
      #passphrase_class => 'Authen::Passphrase::BlowfishCrypt',
      #passphrase_params => {
      #  cost        => 14,
      #  salt_random => 1,
      #}
    },

    # The CoreSchemaAdmin plugin automatically configures RapidDbic to provide access
    # the system CoreSchema database. No options are required
    'Plugin::RapidApp::CoreSchemaAdmin' => {
      #
    },

    # The NavCore plugin automatically configures saved searches/views for
    # RapidDbic sources. When used with AuthCore, each user has their own saved
    # views in addition to system-wide saved views. No options are required.
    'Plugin::RapidApp::NavCore' => {
      # 
    },

);

# Start the application
__PACKAGE__->setup();

1;

__END__

=head1 NAME

AccessSystem - Catalyst/RapidApp based application

=head1 SYNOPSIS

    script/accesssystem_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<RapidApp>, L<Catalyst>

=head1 AUTHOR

Catalyst developer

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
