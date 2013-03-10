package xPL::Dock::smstool3;

=head1 NAME

xPL::Dock::smstool3 - xPL::Dock plugin for SMSTool3

=head1 SYNOPSIS

  use xPL::Dock::smstool3;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This module creates an xPL client for a serial port-based device.  There
are several usage examples provided by the xPL Perl distribution.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use File::Copy;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  return
    (
     'smstool3-verbose+' => \$self->{_verbose},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);

  # Add a callback to receive all incoming xPL messages
  $xpl->add_xpl_callback(id => 'sms',callback => sub { $self->xpl_in(@_) },
                         filter => {
                                    message_type => 'xpl-cmnd',
                                    schema => 'sendmsg.basic',
                                   });

  # Add a callback to check for incomming SMS messages
  $xpl->add_timer(id => 'sms-read', timeout => 15,
                  callback => sub { $self->sms_reader(@_); 1; });

  return $self;
}


sub xpl_in {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};

  my $body = $msg->field('body');

  # check for empty body
  unless ($body) {
    $self->xpl->send(message_type => 'xpl-trig',
                schema => 'sendmsg.confirm',
                body => [ status => "error", error => "null body"] );
    return 1;
  }

  print "Processed: ", $msg->summary, "\n" if ($self->verbose);

  my $to = $msg->field('to');
  # Match a min of 10 digits from end of number 
  unless ($to =~ /[0-9]{10,}$/) {
    $self->xpl->send(message_type => 'xpl-trig',
               	schema => 'sendmsg.confirm',
  		body => [ status => "error", error => "invalid number, '$to', in 'to' field"] );
    return 1;
  }

  # Create a tmp file for txt
  my $random = int(rand 100000);
  my $filename = "sms-$random";
  open my $fhtmp, ">/tmp/$filename";
  print $fhtmp "To: $to\n\n";
  print $fhtmp $body;
  close($fhtmp);
  # Move tmp file into SMSTool3 outgoing directory
  move("/tmp/$filename","/var/spool/sms/outgoing/$filename");

  return 1;
}


sub sms_reader {
  my $self = shift;
  my $smsdir = '/var/spool/sms/incoming/';

  my $dh;
  my $fh;

  opendir($dh, $smsdir) or do {
    warn "Failed to open sms dir, $smsdir: $!\n" if ($self->verbose);
    return 1;
  };
  my @smsfile = readdir($dh);
  closedir($dh);

  my $sms;
  foreach $sms (@smsfile) {
    if ($sms =~ /^GSM[1-9]\..+/) {
      open $fh, "<", $smsdir.$sms or do {
        warn "Failed to open sms file, $sms: $!\n";
        return;
      };
      my $number = "";
      my $body = "";
      while (my $line = <$fh>) {
        if ($line =~ /^From: ([0-9]*?)$/) {
	  $number = $1;
        }
        #last line we read should be the message
	$body = $line;
      };
      close $fh;
      unlink $smsdir.$sms;
      print "Incoming: $number $body\n" if ($self->verbose);

      $self->xpl->send(message_type => 'xpl-trig',
               	schema => 'recvmsg.basic',
  		body => [ from => $number, body => $body] );
    }
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

Alan Pagr

=head1 COPYRIGHT

Copyright (C) 2013 by Alan Page

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
