package AccessSystem::Schema::ResultSet::Tool;
use strict;
use warnings;

use Try::Tiny;

use base 'DBIx::Class::ResultSet';

sub find_tool {
    my ($self, $input, $args, $rc_class) = @_;

    my $tools = $self->search_rs({ 'me.name' => $input }, $args);
    $tools->result_class($rc_class) if $rc_class;
    if ($tools->count == 1) {
        return ($tools->first, $tools);
    }
    $tools = $self->search_rs({ 'me.name' => { '-like' => "%$input%" }}, $args);
    $tools->result_class($rc_class) if $rc_class;
    my $tool;
    if ($tools->count == 1) {
        $tool = $tools->first;
    }
    return ($tool, $tools) if $tool;
    try {
        # Pg syntax, but not other databases, sigh
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

    my $recent_statuses = $self->search_rs({
        'statuses.id' => [{
            '=' => $self->result_source->schema->
                resultset('ToolStatus')->search_rs(
                    { 'tool_id' => { '-ident' => 'me.id' } },
                    { 'alias'   => 'sub_query' }
            )->get_column('id')->max_rs->as_query },
                          undef],
             'statuses.status' => [{'-not_in' => [qw/dead test psuedotool/] }, undef],
            
        },
        {
            join => 'statuses',
            order_by => 'me.name'
        });
}

1;
