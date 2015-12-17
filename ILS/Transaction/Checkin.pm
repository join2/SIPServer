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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA 02111-1307 USA
#
# An object to handle checkin status
#

package ILS::Transaction::Checkin;

use warnings;
use strict;

use POSIX qw(strftime);

use ILS;
use ILS::Transaction;

our @ISA = qw(ILS::Transaction);

my %fields = (
	      magnetic => 0,
	      sort_bin => undef,
	      );

use Sys::Syslog qw(syslog);

use Inline Python => <<'END';

from invenio.bibcirculation_dblayer import 	update_item_status, \
											update_loan_info
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

sub do_checkin {
	my $self = shift;
	my $current_loc = shift;
	my $sc_return_date = shift; # Note, this is SC format
	$sc_return_date =~  /(\d\d\d\d)(\d\d)(\d\d)    (\d\d)(\d\d)(\d\d)/;
	my $return_date = "$1-$2-$3"; # INVENIO needs YYYY-MM-DD
	
	my $barcode = $self->{item}->id;
	update_item_status('available',$barcode );
    update_loan_info($return_date, 'returned',$barcode);
    syslog("LOG_DEBUG", "ILS::Transaction::Checkin: Item %s returned at %s",
                    $barcode,$return_date);
}



sub resensitize {
    my $self = shift;

    return !$self->{item}->magnetic;
}

1;
