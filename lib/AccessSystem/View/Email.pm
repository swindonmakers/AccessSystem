package AccessSystem::View::Email;

use strict;
use base 'Catalyst::View::Email';

__PACKAGE__->config(
    stash_key => 'email'
);

=head1 NAME

AccessSystem::View::Email - Email View for AccessSystem

=head1 DESCRIPTION

View for sending email from AccessSystem. 

=head1 AUTHOR

A clever guy

=head1 SEE ALSO

L<AccessSystem>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
