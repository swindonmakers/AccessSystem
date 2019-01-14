package AccessSystem::Form::Person;

use strict;
use warnings;

use DateTime;

use HTML::FormHandler::Moose;
use HTML::FormHandlerX::Field::noCAPTCHA;
extends 'HTML::FormHandler::Model::DBIC';
with 'HTML::FormHandler::Widget::Theme::ASBootstrap3';
#has '+widget_wrapper' => ( default => 'ASBootstrap3' );
# with 'HTML::FormHandler::Widget::Theme::BootstrapFormMessages';
has '+item_class' => ( default => 'Person' );
sub build_form_element_attr {
   return { id => 'register-form' };
}

## See: https://github.com/gshank/html-formhandler/blob/master/t/bootstrap3/horiz.t
sub build_form_tags {
    return {
        'layout_classes' => {
            label_class => ['col-md-3'],
            element_wrapper_class => ['col-md-5'],
            no_label_element_wrapper_class => ['col-md-offset-3'],
        },
    };
}

# no idea what goes here, as this isnt the database, the item object
# hasnt got the values in yet, so we cant just call item->dues .. ??
# dont care too much as the system wont use one thats too low anyway?

sub validate {
    my $self = shift;
    # temp person obj:
    my $temp = $self->item->result_source->resultset->new_result({});
    if($self->item->dob()) {
        $temp->dob($self->item->dob);
    } else {
        $temp->dob($self->field('dob')->value());
    }
    $temp->concessionary_rate_override($self->field('concessionary_rate_override')->value());
    $temp->member_of_other_hackspace(1) if $self->field('member_of_other_hackspace')->value();
    $self->field('payment_override')
        ->add_error('Voluntary payment amount must be more than suggested amount (' . $temp->normal_dues / 100 . ')')
        if($self->field('payment_override')->is_active()  && $self->field('payment_override')->value() < $temp->normal_dues);
}

sub field_add_defaults {
    my ($attrs) = @_;
    my $help_string = $attrs->{help_string} || '';
    ## This wants to be "after element control wrapper" .. doesnt exist??
    $attrs->{tags}{after_element_wrapper} //= "<div class='col-md-4'>$help_string</div>";
#    $attrs->{tags}{after_wrapper} //= "<div class='col-md-4'>$help_string</div>";
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
    label => 'Name *',
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
    label => 'Email *',
    required => 1,
    unique => 1,
    maxlength => 255,
    wrapper_attr => { id => 'field-email', },
    tags         => { no_errors => 1 },
    messages => {
        required => 'Please enter an email we can use to contact you',
    },
    unique_message => "That email address is already registered, did you do submit twice?",
    help_string => 'An email address we can contact you on. Your membership payment details will be sent to it.',
};

has_field opt_in => field_add_defaults {
    type => 'Checkbox',
    label => 'Add me to the mailing list (infrequent makerspace information)',
    wrapper_attr => { id => 'field-mailing-list-opt-in', },
    tags         => { no_errors => 1 },
    messages => {
#       required => 'Please read and agree to the Membership Guide',
    },
    help_string => 'Free puppies and kittens! Occassionally we send out updates about thngs happening at the Makerspace, opt_in to get these non-membership specific emails..',
};

has_field analytics_use => field_add_defaults {
    type => 'Checkbox',
    label => 'Use my name/login data in GM reports',
    wrapper_attr => { id => 'field-analytics-use', },
    tags         => { no_errors => 1 },
    help_string => 'General Meeting presentations include "use of the space" graphs, with a most-used-by ranking. If you allow, we will include your name, otherwise the graph will instead read "anonymous member" by your data.',
};
    
## Child members only?
has_field dob => field_add_defaults {
    type => 'Date',
    format => '%Y-%m',
    end_date => DateTime->now->clone()->subtract(years => 17)->ymd,
    start_date => DateTime->now->clone()->subtract(years => 120)->ymd,
    required => 1,
    wrapper_attr => { id => 'field-dob', class => 'payment' },
    tags         => { no_errors => 1 },
    messages => {
        required => 'Please enter your date of birth',
    },
    label => 'Date of Birth *',
    help_string => 'YYYY-MM, only Year/Month accuracy is required. We use this to ensure that you are old enough to be an adult member, or if you are elgiable for OAP concessions.',
};

has_field address => field_add_defaults {
    type => 'TextArea',
    label => 'Address *',
    required => 1,
    rows => 6,
    maxlength => 1024,
    wrapper_attr => { id => 'field-address', },
    tags         => { no_errors => 1 },
    messages => {
        required => 'Please enter your full street address',
    },
    help_string => 'As it would appear on an envelope, for the membership register.',
};

has_field github_user => field_add_defaults {
    type => 'Text',
    required => 0,
    maxlength => 255,
    wrapper_attr => { id => 'field-github-user', },
    tags         => { no_errors => 1 },
    messages => {
        required => 'Please enter a github username',
    },
    help_string => 'A github username, this will allow us to give you access to our code repositories and wiki.',
};

has_field google_id => field_add_defaults {
    type => 'Text',
    required => 0,
    maxlength => 255,
    wrapper_attr => { id => 'field-google-id', },
    tags         => { no_errors => 1 },
    messages => {
        required => 'Please enter a google id/email address',
    },
    help_string => 'Your google account email address, (even if the same as your usual email address) - this will be used for access to our Google Drive documents.',
};

has_field payment_button => (
    type => 'Button',
    value => 'Change/Show Payment Details',
    label => '',
    element_attr => { style => 'background-color: #eabf83;' },
    );

# https://metacpan.org/pod/HTML::FormHandler::Field::Select
# https://www.gov.uk/financial-help-disabled
# https://www.gov.uk/universal-credit
has_field concessionary_rate_override => field_add_defaults {
    type => 'Select',
    required => 0,
    widget => 'RadioGroup',
    options => [ { value => '', label => 'None' },
                 { value => 'legacy', label => 'Yes' },
                 { value => 'twigs', label => 'Referred by Twigs' },
                 { value => 'student', label => 'Student' },
                 { value => 'universal credit', label => 'Universal Credit' },
                 { value => 'disability', label => 'Disbaility Benefits' },
                 { value => 'job seeking', label => 'Job Seeking' },
        ],
    label => 'Concessionary Rate',
    wrapper_attr => { id => 'field-concessionary-rate-override', class => 'payment payment_hide', style => "display:none"  },
    tags => { no_errors => 1 },
    help_string => 'Do you qualify for our reduced payment rate? Choose what best matches your situation, you will need to show documentation to a director to prove your status.',
};

has_field member_of_other_hackspace => field_add_defaults {
    type => 'Checkbox',
    required => 0,
    wrapper_attr => { id => 'field-member-of-other-hackspace', class => 'payment payment_hide', style => "display:none" },
    tags => { no_errors => 1},
    label => 'I am mainly a member of another hackspace/makerspace',
    help_string => 'Just visiting or only in Swindon part of the year? If you are a member of another hackspace somewhere, you can join us for only &pound;5/month.',
};

has_field payment_override => field_add_defaults {
    type => 'Money',
#    currency_symbol => '&pound;',
    required => 0,
    label => 'Payment Override',
    wrapper_attr => { id => 'field-payment-override', class => 'payment_hide', style => "display:none" },
#    tags => { no_errors => 1 },
    deflation => sub { return $_[0] / 100 },
    apply => [ { transform => sub { return $_[0] * 100 } } ],
    help_string => 'You are welcome to overpay for use of the space, indicate here how much you would like to pay monthly.',
};

## required checks if this is true as well as set, defaults to 0/1
has_field membership_guide => field_add_defaults {
    type => 'Checkbox',
    required => 1,
    label => 'I have read and agree to comply with the Membership Guide *',
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
    help_string => 'Named children can also access the Makerspace, one is included in your fee, more are &pound;5 per child.',
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
  label => "I am a person *",
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

has_field 'submit_edit' => ( type => 'Submit', value => 'Update', inactive => 1 );

no HTML::FormHandler::Moose;

1;
