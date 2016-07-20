#
# Copyright (C) 2006-2008  Georgia Public Library Service
#
# Author: David J. Fiander
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public
# License as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA 02111-1307 USA
#
# An object to handle checkout status
#

package ILS::Transaction::Checkout;

use warnings;
use strict;

use POSIX qw(strftime);
use Sip::Constants qw(SIP_DATETIME);


use ILS;
use ILS::Transaction;

our @ISA = qw(ILS::Transaction);

our $debug;

use Sys::Syslog qw(syslog);

use Inline Python => <<'END';

from invenio.libSIP_join2 import checkout

END

# Most fields are handled by the Transaction superclass
my %fields = (
		security_inhibit => 0,
		due => undef,
		renew_ok => 0,
		);

sub new {
	my $class = shift;;
	my $self = $class->SUPER::new();
	my $element;

	foreach $element (keys %fields) {
	$self->{_permitted}->{$element} = $fields{$element};
	}
	@{$self}{keys %fields} = values %fields;
	$debug and warn "new ILS::Transaction::Checkout : " . Dumper $self;
	return bless $self, $class;
}

sub do_checkout {
	my $self = shift;
	my $barcode = $self->{item}->id;	 # item barcode
	my $patron_id = $self->{patron}->id; # patron barcode

	syslog('LOG_DEBUG', "ILS::Transaction::Checkout for $patron_id: $barcode");
	# Why do we die if we add the following line?
	my $due_date = checkout($patron_id, $barcode);
	syslog('LOG_DEBUG', "ILS::Transaction::Checkout due: $due_date...");
	if ($due_date == -1) {
		syslog('LOG_DEBUG', "ILS::Transaction::Checkout Unknown patron $patron_id");
		$self->ok(0);
	}
	elsif ($due_date == -2) {
		syslog('LOG_DEBUG', "ILS::Transaction::Checkout Item already on loan: $barcode");
		$self->ok(0);
	}
	elsif ($due_date == -3) {
		syslog('LOG_DEBUG', "ILS::Transaction::Checkout Duplicate / unknown barcode");
		$self->ok(0);
	}
	elsif ($due_date == 0) {
		# item is on loan, do not loan it again
		$self->ok(0);
	}
	else {
		push(@{$self->{patron}->{hold}}, $barcode);
		$self->{'due'} = $due_date;
		$self->ok(1);
	}
	return $self;
}

1;
