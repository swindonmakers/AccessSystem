package AccessSystem::Schema::Result::Person;

use strict;
use warnings;

use DateTime;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('people');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    parent_id => {
        data_type => 'integer',
        is_nullable => 1,
    },
    name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0,
    },
    email => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    opt_in => {
        data_type => 'boolean',
        default_value => 0,
        is_nullable => 0,
    },
    dob => {
        data_type => 'datetime',
        is_nullable => 0,
    },
    address => {
        data_type => 'varchar',
        size => 1024,
        is_nullable => 0,
    },
    github_user => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    concessionary_rate_override => {
        data_type => 'varchar',
        size => 255,
        default_value => '',
        is_nullable => 1,
    },
    member_of_other_hackspace => {
        data_type => 'boolean',
        default_value => 0,
        is_nullable => 0,
    },
    created_date => {
        data_type => 'datetime',
        set_on_create => 1,
        is_nullable => 0,
    },
    end_date => {
        data_type => 'datetime',
        is_nullable => 1,
    },
);

__PACKAGE__->set_primary_key('id');
# __PACKAGE__->add_unique_constraint('email' => ['email']);

__PACKAGE__->has_many('communications', 'AccessSystem::Schema::Result::Communication', 'person_id');
__PACKAGE__->has_many('payments', 'AccessSystem::Schema::Result::Dues', 'person_id');
__PACKAGE__->has_many('allowed', 'AccessSystem::Schema::Result::Allowed', 'person_id');
__PACKAGE__->has_many('tokens', 'AccessSystem::Schema::Result::AccessToken', 'person_id');
__PACKAGE__->has_many('children', 'AccessSystem::Schema::Result::Person', 'parent_id');
__PACKAGE__->belongs_to('parent', 'AccessSystem::Schema::Result::Person', 'parent_id', { 'join_type' => 'left'} );

sub is_valid {
    my ($self, $date) = @_;
    $date ||= DateTime->today()->add(days => 1);

    my $dtf = $self->result_source->schema->storage->datetime_parser;
    my $date_str = $dtf->format_datetime($date);

    my $is_paid;

    if(!$self->parent) {
        $is_paid = $self->payments_rs->search({
            paid_on_date => { '<=' => $date_str },
            expires_on_date => { '>=' => $date_str },
                                          })->count;
    } else {
        return $self->parent->is_valid;
    }

    return $is_paid > 0;
}

sub last_payment {
    my ($self) = @_;

    ## Fail if there are none at all?
    my $last = $self->payments_rs->search(
        {},
        {
            order_by => [{ '-desc' => 'paid_on_date' }],
            rows => 1,
        })->single;

    return $last;
}

sub bank_ref {
    my ($self) = @_;

    return sprintf("SM%04d", $self->id);
}

## basic = 25/mo
## reduced to 5/mo if member is marked as a member of another hack/makerspace
## add 5 for each child beyond first one
## divide by 2 for concessions (applies also to children!?)
## returns whole pence

sub dues {
    my ($self) = @_;

    my $dues = 2500;
    if($self->member_of_other_hackspace) {
        $dues = 500;
    }
    if($self->children_rs->search({ end_date => { '!=' => undef } })->count > 1) {
        $dues += 500 * ($self->children_rs->count-1);
    }

    if($self->concessionary_rate) {
        $dues /= 2;
    }

    return $dues;
}

sub valid_until {
    my ($self) = @_;

    my $dtf = $self->result_source->schema->storage->datetime_parser;
    my $valid_until = $self->payments_rs->search(
        {},
        {
            columns => [ { 'valid_until' => { 'max' => 'expires_on_date' } }],
            group_by => ['person_id'],
        })->first;
    if($valid_until) {
        return $dtf->parse_datetime($valid_until->get_column('valid_until'));
    }

    return undef;
}

sub concessionary_rate {
    my ($self) = @_;

    if ($self->concessionary_rate_override) {
        return 1;
    }

    # FIXME: This is a bit iffy, since it checks your current age, and not the age when the payment was made, or ... something.
    # $age is a DateTime::Duration
    my $age = DateTime->now - $self->dob;

    # It's a nice round number, anyway.
    if ($age->years >= 65) {
        return 1;
    }

    # Children don't actually pay dues, they increase the dues of
    # their parents.  Because of that, and because we are nice like
    # that, we give anybody who has at least one concessionary child a
    # concession, which lowers their rate, including what they pay for that child (if anything).
#    if($self->children_rs->search({
#                                   end_date => { '!=' => undef },
#                                   concessionary_rate_override => { '!=' => undef },
    #                                  })->count) {
    my $children = $self->children_rs;
    while (my $child = $children->next) {
        if ($child->concessionary_rate) {
            print "concession child\n";
            return 1;
        }
    }

    return 0;
}

1;
