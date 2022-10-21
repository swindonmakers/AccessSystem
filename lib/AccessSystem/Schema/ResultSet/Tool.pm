package AccessSystem::Schema::ResultSet::Tool;
use strict;
use warnings;

use Try::Tiny;

use base 'DBIx::Class::ResultSet';

sub find_tool {
    my ($self, $input, $args, $rc_class) = @_;

    $self->result_class($rc_class);
    my $tool = $self->find({ 'me.name' => $input }, $args);
    if ($tool) {
        return ($tool, $self);
    }
    my $tools = $self->search_rs({ 'me.name' => { '-like' => "%$input%" }}, $args);
    $tools->result_class($rc_class);
    if ($tools->count == 1) {
        $tool = $tools->first;
    }
    return ($tool, $tools) if $tool;
    try {
        # Pg syntax, but not other databases, sigh
        my $pgtools = $self->search_rs({ 'me.name' => { '-ilike' => "%$input%" }}, $args);
        if ($pgtools->count) {
            $tools = $pgtools;
            $tools->result_class($rc_class);
        }
        if ($tools->count == 1) {
            $tool = $tools->first;
        }
    } catch {
        print "This is not Pg: $_\n";
    };
    return ($tool, $tools) if $tool;
    
    warn "Add more tools-finding magic here: $input failed\n";
    return (undef, $tools);
}

1;
