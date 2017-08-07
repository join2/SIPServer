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
# Status of a Renew Transaction
#

package ILS::Transaction::Renew;

use warnings;
use strict;

use ILS;
use ILS::Transaction;

our @ISA = qw(ILS::Transaction);

our $debug;

use Sys::Syslog qw(syslog);

my %fields = (
	renewal_ok => 0,
	);

use Inline Python => <<'END';

from invenio.libSIP_join2 import renew

END

sub new {
	my $class = shift;;
	my $self = $class->SUPER::new();
	my $element;

	foreach $element (keys %fields) {
	$self->{_permitted}->{$element} = $fields{$element};
	}

	@{$self}{keys %fields} = values %fields;

	return bless $self, $class;
}

sub do_renew {
	my $self = shift;
	my $barcode = $self->{item}->id;     # item barcode
	my $patron_id = $self->{patron}->id; # patron barcode

	syslog('LOG_DEBUG', "ILS::Transaction::Renew for $patron_id: $barcode");

	# call pythonic backend
	my $due_date = renew($patron_id, $barcode);

	$self->renewal_ok(0);
	$self->ok(0);
	syslog('LOG_DEBUG', "ILS::Transaction::Renew due: $due_date...");
	if ($due_date == -1) {
		$self->screen_msg("Invalid Patron");
		syslog('LOG_DEBUG', "ILS::Transaction::Renew Unknown patron $patron_id");
	}
	elsif ($due_date == -2) {
		$self->screen_msg("Item on loan");
		syslog('LOG_DEBUG', "ILS::Transaction::Renew Item already on loan: $barcode");
	}
	elsif ($due_date == -3) {
		$self->screen_msg("Unknown item");
		syslog('LOG_DEBUG', "ILS::Transaction::Renew Duplicate / unknown barcode");
	}
	elsif ($due_date == -4) {
		$self->screen_msg("Item requested by other patron");
		syslog('LOG_DEBUG', "ILS::Transaction::Renew item on hold");
	}
	elsif ($due_date == 0) {
		# item is on loan, do not loan it again
	}
	else {
		$self->desensitize(0);  # It's already checked out
		$self->renewal_ok(1);

		$self->{'due'} = $due_date;
		$self->{item}->{due_date} = $due_date;  # set new due, used date for display
		$self->ok(1);
	}
	return $self;

}

1;
