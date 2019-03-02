package AccessSystem;
use Moose;
use namespace::autoclean;

use RapidApp 1.1005;

use Catalyst qw/
    -Debug
    ConfigLoader
    RapidApp::RapidDbic
    RapidApp::TabGui
    RapidApp::AuthCore
    RapidApp::CoreSchemaAdmin
    RapidApp::NavCore

    StatusMessage
    Static::Simple

/;

extends 'Catalyst';

our $VERSION = '0.01';

__PACKAGE__->config(
    name => 'AccessSystem',

    # The general 'RapidApp' config controls aspects of the special components that
    # are globally injected/mounted into the Catalyst application dispatcher:
    'RapidApp' => {
      ## To change the root RapidApp module to be mounted someplace other than
      ## at the root (/) of the Catalyst app (default is '' which is the root)
      module_root_namespace => 'admin',

      ## To load additional, custom RapidApp modules (under the root module):
      #load_modules => { somemodule => 'Some::RapidApp::Module::Class' }
    },

    'Plugin::RapidApp::RapidDbic' => {
     dbic_models => ['AccessDB'],
      
     # All custom configs optional...
     configs => {
         AccessDB => {
             grid_params => {
                 '*defaults' => { # Defaults for all Sources
                     updatable_colspec => ['*','!id', '!person_id', '!accessible_thing_id',],
                     creatable_colspec => ['*','!id', '!person_id', '!accessible_thing_id',],
                     destroyable_relspec => ['*'],
                 }, # ('*defaults')
                 'AccessToken' => {
                     creatable_colspec => ['*', '!person_id'],
                 },
                 'Person' => {
                     include_colspec => ['*', 'payments.expiry_date'],
                 },
             },
             TableSpecs => {
                 'Person' => {
                     display_column => 'name',
                 },
                 'AccessibleThing' => {
                     display_column => 'name',
                 },
             },
             virtual_columns => {
                 'Person' => {
                     'valid_until' => {
                         data_type => 'datetime',
                         is_nullable => 1,
                         sql => 'SELECT max(dues.expires_on_date) FROM dues WHERE dues.person_id = self.id',
                     },
                     is_valid => {
                         data_type => 'boolean',
                         is_nullable => 0,
                         sql => 'SELECT CASE WHEN max_valid >= CURRENT_TIMESTAMP THEN 1 ELSE 0 END FROM (SELECT max(dues.expires_on_date) as max_valid FROM dues WHERE dues.person_id=self.id) as valid',
                     },
                         
                 },
                 'MessageLog' => {
                   'token' => {
                     data_type => 'varchar',
                     sql => "SELECT substr(message, 24) as token FROM message_log WHERE message_log.accessible_thing_id = self.accessible_thing_id and message_log.written_date = self.written_date AND message like 'Permission granted to: %'",
                     }
                  }
             }
           # ...
         }
       },
       OtherModel => {
         # ...
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

    'View::TT' => {
        INCLUDE_PATH =>  [ 
            __PACKAGE__->path_to( 'root', 'users' ),
            __PACKAGE__->path_to( 'root', 'src' ), 
            ],
#                          Path::Class::dir(RapidApp->share_dir)->stringify ],
    },
    'View::Email' => {
        stash_key => 'email',
        default => {
            content_type => 'text/plain',
            charset => 'utf-8',
        },
        sender => {
            mailer => 'SMTP',
            mailer_args => {
                host => 'localhost', 
		debug => 1,
            },
        },
    },
#     'Controller::Users' => {
# #        form_handler => 'HTML::FormHandlerX::Form::Login',
#         form_handler => 'AccessSystem::Form::Person',
#         register_fields => ['email', 'name', 'dob', 'password', 'confirm_password' ],
#         view => 'TT',
#         model => 'RapidApp::CoreSchema::User',
#         login_id_field => 'email',
#         login_id_db_field => 'email',
#         enable_register => 1,
#         enable_sending_register_email => 1,

#         register_template =>                   'register.tt',
#         login_template    =>                   'users/login.tt',
#         change_password_template =>            'users/change-password.tt',
#         forgot_password_template =>            'users/forgot-password.tt',
#         reset_password_template  =>            'users/reset-password.tt',

        
#         auto_login_after_register => 0,
#         action_after_register => '/auth/login',
#         action_after_login => '/admin/approot',
#         action_after_change_password => '/admin/approot',
#     },

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
