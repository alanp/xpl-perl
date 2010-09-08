package xPL::Dock::HDDTemp;

=head1 NAME

xPL::Dock::HDDTemp - xPL::Dock plugin for dawn and dusk reporting

=head1 SYNOPSIS

  use xPL::Dock qw/HDDTemp/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds dawn and dusk reporting.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use xPL::Dock::Plug;
use IO::Socket::INET;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/interval server/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_interval} = 120;
  $self->{_server} = '127.0.0.1:7634';
  return
    (
     'hddtemp-verbose+' => \$self->{_verbose},
     'hddtemp-poll-interval=i' => \$self->{_interval},
     'hddtemp-server=s' => \$self->{_server},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->SUPER::init($xpl, @_);

  # Add a timer to the xPL Client event loop to generate the
  # "hddtemp.update" messages.  The negative interval causes the timer to
  # trigger immediately rather than waiting for the first interval.
  $xpl->add_timer(id => 'hddtemp',
                  timeout => -$self->interval,
                  callback => sub { $self->poll(); 1 });

  $self->{_buf} = '';
  $self->{_state} = {};

  return $self;
}

=head2 C<poll( )>

This method is the timer callback that polls the hddtemp daemon.

=cut

sub poll {
  my $self = shift;
  my $sock = IO::Socket::INET->new($self->server);
  unless ($sock) {
    warn "Failed to contact hddtemp daemon at ", $self->server, ": $!\n";
    return 1;
  }
  $self->xpl->add_input(handle => $sock,
                        callback => sub { $self->read(@_); 1; });
  return 1;
}

=head2 C<read( )>

This is the input callback that reads the data from the hddtemp daemon
and sends appropriate C<sensor.basic> messages.

=cut

sub read {
  my ($self, $sock) = @_;
  my $bytes = $sock->sysread($self->{_buf}, 512, length($self->{_buf}));
  unless ($bytes) {
    $self->{_buf} = "";
    $self->xpl->remove_input($sock);
    $sock->close;
  }
  while ($self->{_buf} =~ s/^\|([^\|]+)\|([^\|]+)\|([^\|]+)\|([^\|]+)\|//) {
    my $device = $1;
    my $temp = $3;
    my $unit = $4;

    # sometimes temp isn't numeric - value is 'SPL'
    # avoid reporting these
    next if ($temp =~ /[^\d\.]/);

    $device =~ s!/dev/!!;
    $device = $self->xpl->instance_id."-".$device;
    my $old = $self->{_state}->{$device};
    $self->{_state}->{$device} = $temp;
    my $type;
    if (!defined $old || $temp != $old) {
      $type = 'xpl-trig';
      $self->info("$device $temp $unit\n");
    } else {
      $type = 'xpl-stat';
    }
    $self->xpl->send(message_type => $type, class => 'sensor.basic',
                     body =>
                     [ device => $device, type => 'temp', current => $temp ]);
  }
  return 1;
}


1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), hddtemp(8)

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
