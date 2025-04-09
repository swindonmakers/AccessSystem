package AccessSystem::Schema::Result::Transactions;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('transactions');
__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
        is_foreign_key => 1,
    },
    added_on => {
        data_type => 'timestamp',
        set_on_create => 1,
    },
    amount_p => {
        data_type => 'integer',
    },
    reason => {
        data_type => 'varchar',
        size => 255,
    },
);

__PACKAGE__->set_primary_key('person_id', 'added_on', 'amount_p');
__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');

1;
