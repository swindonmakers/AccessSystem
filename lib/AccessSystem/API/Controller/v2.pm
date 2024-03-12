package AccessSystem::API::Controller::v2;

use Moose;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => 'accesssystem');

=encoding utf-8

=head1 NAME

AccessSystem::API::Controller::v2 - API v2 Controller

=head1 DESCRIPTION

This one should have some sorta auth protection on it, and should log all uses. 

(Move all non-UI methods here from Root)

=head1 METHODS

=cut

sub authenticated :Chained('/') :PathPart('v2') :CaptureArgs(0) {
}

sub remove_ex_member_inductions: Chained('authenticated'): PathPart('remove_ex_member_inductions'): Args(1) {
    my ($self, $c, $num_months) = @_;

    # Magic number, should probably be in a config file...
    my $induction_expiry_months = 3;

    if($num_months =~ /\D/) {
        $c->stash(json => {
            error => 'remove_ex_member_inductions takes a number parameter',
                  }
            );
        return $c->forward('View::JSON');
    }
    
    my $ex_members = $c->model('AccessDB::Person')->ex_members($num_months, {}, $induction_expiry_months);

    # inductions, all of em (door will get re-added when they rejoin, see PR:90
    # $ex_members->as_subselect_rs->related_resultset('allowed')->count;
    $ex_members->related_resultset('allowed')->delete;


    $c->stash(json => {
        success => 1,
              }
        );
    return $c->forward('View::JSON');
}

=head1 AUTHOR

Jess Robinson

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
