package AccessSystem::Schema::Result::PersonTransactions;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('person_transactions');
__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
        is_foreign_key => 1,
    },
    transaction_id => {
        data_type => 'integer',
        is_foreign_key => 1,
        is_nullable => 1,
    },
    amount_p => {
         data_type => 'integer',
     },
    added_on => {
        data_type => 'timestamp',
        set_on_create => 1,
    },
    reason => {
        data_type => 'varchar',
        size => 255,
    },
);

__PACKAGE__->set_primary_key('person_id', 'added_on', 'amount_p');
__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');
# Optional/nullable transaction_id
__PACKAGE__->belongs_to('transaction', 'AccessSystem::Schema::Result::Transactions', 'transaction_id', { join_type => 'left'});

1;
