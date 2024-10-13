package AccessSystem::Schema::ResultSet::Tool;
use strict;
use warnings;

use Try::Tiny;

use base 'DBIx::Class::ResultSet';

sub find_tool {
    my ($self, $input, $args, $rc_class) = @_;

#    my $tools = $self->active->search_rs({ 'me.name' => $input }, $args);
    my $tools = $self->search_rs({ 'me.name' => $input }, $args);
    $tools->result_class($rc_class) if $rc_class;
    if ($tools->count == 1) {
        return ($tools->first, $tools);
    }
#    $tools = $self->active->search_rs({ 'me.name' => { '-like' => "%$input%" }}, $args);
    $tools = $self->search_rs({ 'me.name' => { '-like' => "%$input%" }}, $args);
    $tools->result_class($rc_class) if $rc_class;
    my $tool;
    if ($tools->count == 1) {
        $tool = $tools->first;
    }
    return ($tool, $tools) if $tool;
    try {
        # Pg syntax, but not other databases, sigh
#        my $pgtools = $self->active->search_rs({ 'me.name' => { '-ilike' => "%$input%" }}, $args);
        my $pgtools = $self->search_rs({ 'me.name' => { '-ilike' => "%$input%" }}, $args);
        if ($pgtools->count) {
            $tools = $pgtools;
            $tools->result_class($rc_class) if $rc_class;
        }
        if ($tools->count == 1) {
            $tool = $tools->first;
        }
    } catch {
        print "This is not Pg: (no ILIKE)\n";
    };
    return ($tool, $tools) if $tool;
    
    warn "Add more tools-finding magic here: $input failed\n";
    return (undef, $tools);
}

sub active {
    my ($self) = @_;

    return $self->search_rs(
        [
         'statuses.status' => { '-not_in' => [qw/dead test psuedotool/] },
         'statuses.status' => undef,
        ],
        {
            join => 'statuses',
            order_by => 'me.name'
        });
}

1;
