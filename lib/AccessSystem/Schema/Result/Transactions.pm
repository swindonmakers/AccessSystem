package AccessSystem::Schema::Result::Transactions;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('transactions');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    fitid => {
        # date + id? unsure if these repeat
        # eg: +202608100000001
        data_type => 'varchar',
        size => 20,
        set_on_create => 1,
    },
    posted_on => {
        data_type => 'timestamp',
    },
    name => {
        data_type => 'varchar',
        size => 50,
    },
    amount_p => {
        data_type => 'integer',
    },
    type => {
        data_type => 'varchar',
        size => 50,
    },
    category => {
        data_type => 'varchar',
        size => 1024,
    }
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint('trn' => ['fitid']);

1;
