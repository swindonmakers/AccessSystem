package AccessSystem::Form::Person;

use strict;
use warnings;

use DateTime;

use HTML::FormHandler::Moose;
use HTML::FormHandlerX::Field::noCAPTCHA;
extends 'HTML::FormHandler::Model::DBIC';
with 'HTML::FormHandler::Widget::Theme::Bootstrap3';
# has '+widget_wrapper' => ( default => 'Bootstrap3' );
# with 'HTML::FormHandler::Widget::Theme::BootstrapFormMessages';
has '+item_class' => ( default => 'Person' );
#sub build_form_element_attr {
#    return { class => 'form-horizontal' };
#}

## See: https://github.com/gshank/html-formhandler/blob/master/t/bootstrap3/horiz.t
sub build_form_tags {
    return {
        'layout_classes' => {
            label_class => ['col-md-3'],
            element_wrapper_class => ['col-md-5'],
            no_label_element_wrapper_class => ['col-md-offset-2'],
        },
    };
}


sub field_add_defaults {
    my ($attrs) = @_;
    my $help_string = $attrs->{help_string} || '';
    ## This wants to be "after element control wrapper" .. doesnt exist??
    $attrs->{tags}{after_element_wrapper} //= "<div class='col-md-4'>$help_string</div>";
#    $attrs->{tags}{after_element} //= "<div class='col-md-4'>$help_string</div>";
#    $attrs->{wrapper_class} ||= 'form-wrapper form-group';
#    $attrs->{label_class} ||= 'control-label col-md-3';
#    $attrs->{element_class} ||= 'form-control col-md-5';

#    $attrs->{wrapper_class} ||= 'form-wrapper form-group';

#    $attrs->{label_class} ||= 'col-md-3';
#    $attrs->{no_label_element_wrapper_class} = ['col-lg-offset-3'];
    ## This one wants to be "element wrapper attributes" !? see https://metacpan.org/source/GSHANK/HTML-FormHandler-0.40064/lib/HTML/FormHandler/Widget/Wrapper/Bootstrap3.pm#L44
#    $attrs->{element_wrapper_class} = ['col-md-5'];

    return %$attrs;
}

#has_field parent_id => (
#    type => 'Hidden',
#);
    
has_field name => field_add_defaults {
    type => 'Text',
    required => 1,
    maxlength => 255,
    wrapper_attr => { id => 'field-name', },
    tags         => { no_errors => 1 },
    messages => {
        required => 'Please enter your name (forename and surname)',
    },
    help_string => 'Forename and surname, as it should appear on tree-mail'
};

has_field email => field_add_defaults {
    type => 'Email',
    required => 1,
    maxlength => 255,
    wrapper_attr => { id => 'field-email', },
    tags         => { no_errors => 1 },
    messages => {
        required => 'Please enter an email we can use to contact you',
    },
};

## Child members only?
has_field dob => field_add_defaults {
    type => 'Date',
    format => '%Y-%m-%d',
    end_date => DateTime->now->ymd,
    required => 1,
    wrapper_attr => { id => 'field-dob', },
    tags         => { no_errors => 1 },
    messages => {
        required => 'Please enter your date of birth',
    },
    label => 'Date of Birth',
    help_string => 'YYYY-MM-DD, we can tell if you get youth or OAP concessions',
};

has_field address => field_add_defaults {
    type => 'TextArea',
    required => 1,
    rows => 6,
    maxlength => 1024,
    wrapper_attr => { id => 'field-address', },
    tags         => { no_errors => 1 },
    messages => {
        required => 'Please enter your full street address, this is necessary for our insurance',
    },
    help_string => 'As it would appear on an envelope, for insurance purposes',
};

## required checks if this is true as well as set, defaults to 0/1
has_field membership_guide => field_add_defaults {
    type => 'Checkbox',
    required => 1,
    label => 'I have read and agree to comply with the Membership Guide',
    wrapper_attr => { id => 'field-membership-guide', },
    tags         => { no_errors => 1 },
    messages => {
       required => 'Please read and agree to the Membership Guide',
    },
    help_string => '<a target="_blank" href="https://docs.google.com/document/d/1ruqYeKe7kMMnNzKh_LLo2aeoFufMfQsdX987iU6zgCI/edit?usp=sharing">Membership Guide</a>'
};

## required checks if this is true as well as set, defaults to 0/1
has_field has_children => field_add_defaults {
    type => 'Boolean',
    required => 0,
    label => 'Add named children to this account?',
    wrapper_attr => { id => 'field-has-children', },
    tags         => { no_errors => 1 },
#    help_string => 'If you have children aged under 18 you want to be under this account',
};

## required checks if this is true as well as set, defaults to 0/1
has_field more_children => field_add_defaults {
    type => 'Boolean',
    required => 0,
    wrapper_attr => { id => 'field-more-children', },
    tags         => { no_errors => 1 },
    label => 'Add more named children to this account?',
    inactive => 1,
};


has_field capcha => => field_add_defaults {
  type => 'noCAPTCHA',
  required => 1,
  help_string => 'Sorry, membership is only open to people capable of passing a Turing test',
  wrapper_attr => { id => 'field-recapcha' },
  label => "I am a person",
};


# has_field children => (
#     type => 'Repeatable',
# );

# ## Infinite loop! Oops
# # has_field 'children.contains' => (
# #     type => '+AccessSystem::Form::Person'
# # );

# has_field 'children.name' => ( type => 'Text' );
# has_field 'children.email' => ( type => 'Email' );
# has_field 'children.dob' => ( type => 'Date', end_date => DateTime->now->ymd, label => 'Date of Birth',);


has_field 'submit' => ( type => 'Submit', value => 'Sign Up' );

no HTML::FormHandler::Moose;

1;
