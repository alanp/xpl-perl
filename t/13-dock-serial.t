#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 28;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','Serial');
use_ok('xPL::BinaryMessage');

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp serial client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

my $read = '';
my $written = '';
sub device_reader {
  my ($plugin, $buf, $last) = @_;
  $read .= $buf;
  $written = $last;
  return '123';
}
{
  local $0 = 'dingus';
  local @ARGV = ('-v', '--baud', '9600', '--device', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0, hubless => 1,
                        reader_callback => \&device_reader,
                        discard_buffer_timeout => 5,
                        name => 'dungis');
}
ok($xpl, 'created dock serial client');
is($xpl->device_id, 'dungis', 'device_id set correctly');
ok($sel->can_read, 'serial device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Serial', 'plugin has correct type');
$plugin->write(xPL::BinaryMessage->new(raw => 'test',
                                                  desc => 'test'));

my $client_sel = IO::Select->new($client);
ok($client_sel->can_read, 'serial device ready to read');

my $buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size');
is($buf, 'test', 'content is correct');

print $client 'sent';

$xpl->main_loop(1);

is($read, 'sent', 'returned content is correct');
is(ref $written, 'xPL::BinaryMessage',
   'last sent data is correct type');
is($written, '74657374: test', 'last sent data is correct');

is($plugin->buffer, '123', 'returned buffer content is correct');

$plugin->write(xPL::BinaryMessage->new(hex => '31',
                                                     data => 'data'));
$plugin->write('2');

is((sysread $client, $buf, 64), 1, 'read is correct size');
is($buf, '1', 'content is correct');

print $client 'sent again';
$read = '';
$plugin->{_last_read} -= 10; # trigger discard timeout
is(test_output(sub { $xpl->main_loop(1); }, \*STDERR),
   "Discarding: 313233\n", 'correctly discarded old buffer');

is($read, 'sent again', 'returned content is correct');
is(ref $written, 'xPL::BinaryMessage',
   'last sent data is correct type');
is($written, '31', 'last sent data is correct');
is($written->data, 'data', 'last sent data has correct data value');

is($plugin->buffer, '123', 'returned buffer content is correct');

$xpl->{_last_read} = time + 2;
$plugin->discard_buffer_check();
is($plugin->buffer, '123', 'buffer content not discarded');

$client->close;

is(test_error(sub { $xpl->main_loop(); }),
   'xPL::Dock::Serial->serial_read: failed: Connection reset by peer',
   'dies on close');

ok(!defined xPL::BinaryMessage->new(desc => 'duff message'),
   'binary message must have either hex or raw supplied');

$device->close;
{
  local $0 = 'dingus';
  local @ARGV = ('-v');
  is(test_error(sub {
                  $xpl = xPL::Dock->new(port => 0, hubless => 1,
                                       device => '127.0.0.1:'.$port)
                }),
     q{xPL::Dock::Serial->device_open: TCP connect to '127.0.0.1:}.$port.
     q{' failed: Connection refused}, 'connection refused');
}
