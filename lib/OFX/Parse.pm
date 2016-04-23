#!/usr/bin/perl
package OFX::Parse;

use strictures 2;
# Jess prefers not Data::Printer
#use Data::Printer;
use Data::Dumper 'Dumper';
sub p {
  print Dumper $_[0];
}

use HTML::TreeBuilder;
use SGML::DTDParse;
use DateTime::Format::Strptime;
use File::Slurp 'read_file';
use 5.14.0;
$|=1;

my $dt_parser = DateTime::Format::Strptime->new(
    #          20160307000000[-5:EST]
    pattern => "%Y%m%d%H%M%S[-5:EST]",
    on_error => 'croak',
    time_zone => 'UTC',

);

sub read_ofx {
    my $filename = shift;
    open(my $fh, "<", $filename) or die "Can't open $filename for read";

    # References:
    #  OFXspec: Open Financial Exchange Specification 1.0.3 May 1, 2006   © 2006 CheckFree Corp., Intuit Inc., Microsoft Corp. All rights reserved

    my $ofxheader = {};
    # Parsing part 1: OFX headers, see ofxspec 2.2
    while (my $line = <$fh>) {
        # Remove both unix and dos-style newlines.
        $line =~ s/[\cM\cJ]+//;
        last if $line eq '';
        
        #print "Line: '$line'\n";
        
        my ($key, $value) = split /:/, $line, 2;
        $ofxheader->{lc $key} = lc $value;
    }

    # OFXHEADER version 100 current for ofxspec 1.0.3
    if ($ofxheader->{ofxheader} > 199) {
        die "OFXHEADER too new: $ofxheader->{ofxheader}";
    }

    if ($ofxheader->{data} ne 'ofxsgml') {
        die;
    }

    if ($ofxheader->{version} >= 199) {
        # Version 103 is current from spec, version 102 is the file I've got.
        die;
    }

    if ($ofxheader->{security} ne 'none') {
        die;
    }

    my $encoding;
    if ($ofxheader->{encoding} eq 'usascii' and $ofxheader->{charset} eq '1252') {
        $encoding = 'cp1252';
    } else {
        die "Unknown encoding/charset $ofxheader->{encoding}/$ofxheader->{charset}";
    }
    binmode $fh, ":encoding($encoding)";

    if ($ofxheader->{compression} ne 'none') {
        die;
    }

    # Ignore oldfileuid / newfileuid for now.

#    p $ofxheader;

    ### FUCK IT, OPENCODING A SGML PARSER.

    my $sgml;
    {
        local $/=undef;
        $sgml = <$fh>;
    }

    my $tag_info = {
                SIGNONMSGSRSV1 => {allowed_inside => {OFX => 1}},
                SONRS => {allowed_inside => {SIGNONMSGSRSV1 => 1}},
                STATUS => {allowed_inside => {SONRS => 1, TRNUID => 0, STMTTRNRS => 1}},
                CODE => {allowed_inside => {STATUS => 1}},
                SEVERITY => {allowed_inside => {STATUS => 1, CODE => 0}},
                DTSERVER => {allowed_inside => {SONRS => 1, STATUS => 0}},
                LANGUAGE => {allowed_inside => {SONRS => 1, DTSERVER => 0}},
                BANKMSGSRSV1 => {allowed_inside => {SIGNONMSGSRSV1 => 0, OFX => 1}},
                STMTTRNRS => {allowed_inside => {BANKMSGSRSV1 => 1}},
                TRNUID => {allowed_inside => {STMTTRNRS => 1}},
                STMTRS => {allowed_inside => {STMTTRNRS => 1, STATUS => 0}},
                CURDEF => {allowed_inside => {STMTRS => 1}},
                BANKACCTFROM => {allowed_inside => {STMTRS => 1, CURDEF => 0}},
                BANKTRANLIST => {allowed_inside => {STMTRS => 1, BANKACCTFROM => 0}},
                LEDGERBAL => {allowed_inside => {STMTRS => 1}},
                BANKID => {allowed_inside => {BANKACCTFROM => 1}},
                ACCTID => {allowed_inside => {BANKACCTFROM => 1, BANKID => 0}},
                ACCTTYPE => {allowed_inside => {BANKACCTFROM => 1, ACCTID => 0}},
                DTSTART => {allowed_inside => {BANKTRANLIST => 1}},
                DTEND => {allowed_inside => {BANKTRANLIST => 1, DTSTART => 0}},
               };
    $tag_info->{STMTTRN}{allowed_inside}{BANKTRANLIST} = 1;
    $tag_info->{TRNTYPE}{allowed_inside}{STMTTRN} = 1;
    $tag_info->{DTPOSTED}{allowed_inside}{STMTTRN} = 1;
    $tag_info->{TRNAMT}{allowed_inside}{STMTTRN} = 1;
    $tag_info->{FITID}{allowed_inside}{STMTTRN} = 1;
    $tag_info->{NAME}{allowed_inside}{STMTTRN} = 1;
    $tag_info->{BALAMT}{allowed_inside}{LEDGERBAL} = 1;
    $tag_info->{DTASOF}{allowed_inside}{LEDGERBAL} = 1;
    $tag_info->{DTPOSTED}{allowed_inside}{TRNTYPE} = 0;
    $tag_info->{FITID}{allowed_inside}{TRNAMT} = 0;
    $tag_info->{NAME}{allowed_inside}{FITID} = 0;
    $tag_info->{STMTTRN}{allowed_inside}{STMTTRN} = 0;
    $tag_info->{TRNAMT}{allowed_inside}{DTPOSTED} = 0;
    $tag_info->{DTASOF}{allowed_inside}{BALAMT} = 0;
    $tag_info->{LEDGERBAL}{allowed_inside}{BANKTRANLIST} = 0;
    $tag_info->{STMTTRN}{allowed_inside}{DTEND} = 0;

    my @parsed_stack;
    while (length $sgml) {
        my $prevsgml = $sgml;

        if ($sgml =~ s/^<([A-Z0-9]+)>//s) {
            my $tag = $1;
            while (@parsed_stack) {
                my $allowed = $tag_info->{$tag}{allowed_inside}{$parsed_stack[-1]{_tag}};
                if ($allowed) {
                    # This nesting is allowed
                    last;
                } elsif (defined $allowed) {
                    # If allowed is listed as 0, not allowed but do not warn (use where grand-allowed?)
                    pop @parsed_stack;
                } else {
                    p @parsed_stack;
                    #say "Disallowed nesting: $tag is not allowed inside of $parsed_stack[-1]{_tag}";
                    my $outer_tag = $parsed_stack[-1]{_tag};
                    #say "\$tag_info->{$tag}{allowed_inside}{$outer_tag} = ?;";
                    pop @parsed_stack;
                }
            }
            push @parsed_stack, {_tag => $tag};
            if (@parsed_stack > 1) {
                push @{$parsed_stack[-2]{_children}}, $parsed_stack[-1];
            }
        }
  
        if ($sgml =~ s!^</([A-Z0-9]+)>!!s) {
            my $tag = $1;
            while ($tag ne $parsed_stack[-1]{_tag}) {
                pop @parsed_stack;
            }
        }
  
        # FIXME: Are there any ofx tags where preceeding whitespace is important?
        $sgml =~ s/^\s+//s;
  
        if ($sgml =~ s/^([^<]+)//) {
            my $data = $1;
            $data =~ s/\s+$//s;
            $data =~ s/&(amp|lt|gt);/{'amp' => '&',
                              'lt' => '<',
                              'gt' => '>',
                             }->{$1}/sge;
            $parsed_stack[-1]{_content} .= $data;
        }
  
        my $prefix = substr($sgml, 0, 20);
        #say "Bottom of loop: '$prefix'";
        die "Nothing happened in parsing loop near '$prefix'" if $prevsgml eq $sgml;
    }

    #p @parsed_stack;

    my $root_tag = $parsed_stack[0];
    my $nicer = make_nice($root_tag);
    #p $nicer;

    my $list = $nicer->{bankmsgsrsv1}[0]{stmttrnrs}[0]{stmtrs}[0]{banktranlist}[0]{stmttrn};
    for my $t (@$list) {
        if ($t->{name} =~ m/^(.*) ON (\d\d) (...) BDC$/s) {
            $t->{name} = $1;
            $t->{trntype} = 'debit card';
            $t->{actual_date} = "$2 $3";
        }
        $t->{dtposted} = $dt_parser->parse_datetime($t->{dtposted});
        $t->{trntype} = lc $t->{trntype};
    }
#    p $list;
    return $list;
}

sub make_nice {
    my ($tag) = @_;
    my @children = @{$tag->{_children}};
    my $ret = {};
    for my $child (@children) {
        if (!$child->{_children}) {
            $ret->{lc $child->{_tag}} = $child->{_content};
        } else {
            push @{$ret->{lc $child->{_tag}}}, make_nice($child);
        }
    }
    return $ret;
}

# Further notes:
#  barclays seems to put several things into the name field:
#   -- name of other party
#   -- memo
#   -- date other then date posted
#   -- extra type code
#    -- BGC: bank giro credit
#    -- BBP: bill payment
#    -- BDC: bank debit card -- these come with an extra date, "<name> ON DD MMM BDC" (where DD and MMM are day/month).
#    -- TFR: Transfer

