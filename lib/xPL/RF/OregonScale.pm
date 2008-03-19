package xPL::RF::OregonScale;

# $Id: OregonScale.pm 407 2007-11-19 18:00:09Z beanz $

=head1 NAME

xPL::RF::OregonScale - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF::OregonScale;

=head1 DESCRIPTION

This is a module contains a module for handling the decoding of RF
messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use xPL::Message;
use xPL::Utils qw/:all/;
use Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
our $SVNVERSION = qw/$Revision: 407 $/[1];

=head2 C<parse( $parent, $message, $bytes, $bits )>

This method is called via the main C<xPL::RF> decode loop and it
determines whether the bytes match the format of any supported OregonScale
Scientific sensors.  It returns a list reference of containing xPL
messages corresponding to the sensor readings.

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  return unless (scalar @$bytes == 7);
  return unless (($bytes->[0]&0xf0) == ($bytes->[5]&0xf0) &&
                 ($bytes->[1]&0xf) == ($bytes->[6]&0xf));
  my $weight =
    sprintf "%x%02x%x", $bytes->[5]&0x1, $bytes->[4], hi_nibble($bytes->[3]);
  return unless ($weight =~ /^\d+$/);
  $weight /= 10;
  my $dev_str = sprintf 'bwr102.%02x', hi_nibble($bytes->[1]);
  my $unknown = sprintf "%x%x", lo_nibble($bytes->[3]), hi_nibble($bytes->[2]);
  return [xPL::Message->new(
                            message_type => 'xpl-trig',
                            class => 'sensor.basic',
                            head => { source => $parent->source, },
                            body => {
                                     device => $dev_str,
                                     type => 'weight',
                                     current => $weight,
                                     unknown => $unknown,
                                    }
                           )];
}

1;
__END__

=head1 EXPORT

None by default.

=head1 THANKS

Special thanks to RFXCOM, L<http://www.rfxcom.com/>, for their
excellent documentation and for giving me permission to use it to help
me write this code.  I own a number of their products and highly
recommend them.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
