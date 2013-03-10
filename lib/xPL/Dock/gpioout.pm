package xPL::Dock::gpioout;

=head1 NAME

xPL::Dock::gpioout - xPL::Dock plugin for a Linux GPIO lines

=head1 SYNOPSIS

  use xPL::Dock qw/gpioout/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This script is an xPL client that interfaces with Linux GPIO output
lines. It supports the use of control.basic messages with current
fields set to 'high', 'low', 'pulse' or 'toggle' with devices of the
form 'gpioNN' where NN is a number from 0 to 127.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use Time::HiRes qw/sleep/;
use xPL::IOHandler;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

our %state_map =
  (
   Active => 'high', Inactive => 'low',
   high   => 'high', low      => 'low',
   1      => 'high', 0        => 'low',
  );

__PACKAGE__->make_readonly_accessor($_) foreach (qw/baud device/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_verbose} = 0;
  return (
          'gpio-verbose+' => \$self->{_verbose},
         );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);

  # Add a callback to receive incoming xPL messages
  $xpl->add_xpl_callback(id => 'gpioout', callback => \&xpl_in,
                         arguments => $self,
                         filter => {
                                    message_type => 'xpl-cmnd',
                                    schema => 'control.basic',
                                    type => 'output',
                                   });
  return $self;
}

=head2 C<xpl_in(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
the incoming control.basic schema messages.

=cut

sub xpl_in {
  my %p = @_;
  my $msg = $p{message};
  my $self = $p{arguments};
  my $fd;

  return 1 unless ($msg->field('device') =~ /^(gpio\d+)$/);
  my $line = $LAST_PAREN_MATCH;
  open $fd, "<", "/sys/class/gpio/$line/direction" or do {
    warn "Failed to open $line direction: $!\n" if ($self->verbose);
    return;
  };
  my $dir = <$fd>;
  close $fd;
  if ($dir ne "out\n") {
    warn "$line not an output: $!\n" if ($self->verbose);
    return;
  };

  my $command = lc $msg->field('current');

  if ($command eq "high") {
    open $fd, ">", "/sys/class/gpio/$line/value";
    print $fd '1';
    close $fd;    
  } elsif ($command eq "low") {
    open $fd, ">", "/sys/class/gpio/$line/value";
    print $fd '0';
    close $fd;
  } elsif ($command eq "pulse") {
    open $fd, ">", "/sys/class/gpio/$line/value";
    print $fd '1';
    close $fd;
    sleep(0.15); # TOFIX 
    open $fd, ">", "/sys/class/gpio/$line/value";
    print $fd '0';
    close $fd;
  } elsif ($command eq "toggle") {
    open $fd, "+>", "/sys/class/gpio/$line/value";
    my $level = <$fd>;
    if ($level eq "0\n") {
      print $fd '1';
    } else {
      print $fd '0';
    }
    close $fd;
  } else {
    warn "Unsupported setting: $command\n" if ($self->verbose);
  }
  return 1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
