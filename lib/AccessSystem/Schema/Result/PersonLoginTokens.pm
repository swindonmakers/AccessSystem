package AccessSystem::Schema::Result::PersonLoginTokens;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('login_tokens');
__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
    },
    login_token => {
        data_type => 'varchar',
        size => 36,
    }
);

__PACKAGE__->set_primary_key('person_id', 'login_token');
__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');

1;

