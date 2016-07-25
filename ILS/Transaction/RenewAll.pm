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
# RenewAll: class to manage status of "Renew All" transaction

package ILS::Transaction::RenewAll;

use warnings;
use strict;

use ILS;
use ILS::Transaction;

our @ISA = qw(ILS::Transaction);

our $debug;

use Sys::Syslog qw(syslog);

my %fields = (
	renewed => [],
	unrenewed => [],
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


sub do_renew_all {
	my $self = shift;
	my $patron_id = $self->{patron}->id; # patron barcode
	my $item_id;

	syslog('LOG_DEBUG', "ILS::Transaction::Renew_all for $patron_id");

	# Loop over all items in the patrons loans and renew them. If
	# renew() returns a new due date in epoc (a number > 0) renewal
	# was successful. Add $item_id the the list `renewed`, else add it
	# to the list `unrenewed`. This causes the frontend to update data
	# accordingly.
	foreach $item_id (@{$self->{patron}->{items}}) {

		# call pythonic backend. This returns new due_date in epoc
		my $due_date = renew($patron_id, $item_id);

		if ($due_date > 0) {
			syslog("LOG_DEBUG", "ILS::renew_all: $item_id renewed");
			push @{$self->renewed}, $item_id;
		}
		else {
			syslog("LOG_DEBUG", "ILS::renew_all: $item_id NOT renewed");
			push @{$self->unrenewed}, $item_id;
		}
	}
	$self->ok(1);

}

1;
