package AccessSystem::HTTPApis;

use strict;
use warnings;
use LWP::UserAgent;
use JSON 'decode_json';
use Moo;

has ua => (is => 'ro', default => sub { LWP::UserAgent->new(); });

=head2 park

Param: Car reg string.

=cut

sub park {
    my ($self, $reg) = @_;

    return {
        error => 'Missing reg',
        success => 0,
    } if !$reg;

    # spaces and non-word chars
    $reg =~ s/\W+//;

    my $resp = $self->ua->post('https://ccp-apim-qrcodeexemption.azure-api.net/CCPFunctionQrCodeExemption/site/22959/exemption/' . $reg, Content => '');
    if($resp->is_success) {
        my $cont = decode_json($resp->decoded_content);
        if($cont->{success}) {
            my $msg = $cont->{message};
            return {
                message => $msg,
                success => 1,
            };
        }
    }

    # Failed (somehow)
    return {
        success => 0,
        error => "Failed to park $reg",
    };
}

1;
