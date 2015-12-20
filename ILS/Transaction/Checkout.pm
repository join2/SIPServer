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

from invenio.bibcirculation_dblayer import 	is_on_loan, \
											new_loan,\
											update_item_status,\
											get_loan_period
											
END

# Most fields are handled by the Transaction superclass
my %fields = (
	      security_inhibit => 0,
	      due              => undef,
	      renew_ok         => 0,
	      );

sub new {
    my $class = shift;;
    my $self = $class->SUPER::new();
    my $element;

    foreach $element (keys %fields) {
	$self->{_permitted}->{$element} = $fields{$element};
    }

    @{$self}{keys %fields} = values %fields;
#    $self->{'due'} = strftime(SIP_DATETIME,
#                              localtime(time() + (60*60*24*14))); # two weeks hence
    $debug and warn "new ILS::Transaction::Checkout : " . Dumper $self;    
    return bless $self, $class;
}

sub do_checkout {
	my $self = shift;
	syslog('LOG_DEBUG', "ILS::Transaction::Checkout performing checkout...");
	my $barcode        = $self->{item}->id;
	my $recid = $self->{item}->recid;
	my $patron_id = $self->{patron}->internal_id; #
	if (is_on_loan($barcode)) {
		# Do not loan again
		$self->ok(0);
		return $self;	
	};
	my $note_format = {};
    #if note:
    #   note_format[time.strftime("%Y-%m-%d %H:%M:%S")] = str(note)
    my $loan_period = get_loan_period($barcode);
    # String like 4 weeks
    my $due_epoc = `date -d "now + $loan_period" +%s`;
    chomp($due_epoc); # Remove CR/LF
    my $due_date =  strftime '%Y-%m-%d',localtime($due_epoc);
	my $loaned_on = strftime '%Y-%m-%d',localtime(time()); # FIXME from SC??
    
    new_loan($patron_id, $recid, $barcode,
                $loaned_on, $due_date, 'on loan', 'normal', $note_format);
    update_item_status('on loan',$barcode );
    # Put $barcode in patron
    push(@{$self->{patron}->{hold}},$barcode);
    


	# available???
	# is_on_loan
	# is_requested
    $self->{due} = $due_epoc; # Must be epoc time
    # TO DO?
    # Add Due date in item?
    
	$self->ok(1);
	return $self;
}



1;
