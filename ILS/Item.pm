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
# ILS::Item.pm
# 
# A Class for hiding the ILS's concept of the item from the OpenSIP
# system
#

package ILS::Item;

use strict;
use warnings;

use Encode;
use POSIX qw(strftime);
use Date::Parse;
use Sip::Constants qw(SIP_DATETIME);

use Sys::Syslog qw(syslog);

use ILS::Transaction;
use ILS::Patron; 

use Inline Python => <<'END';

from invenio.bibcirculation_dblayer import 	get_recid, \
											get_queue_request,\
											get_loan_due_date,\
											is_item_on_loan,\
											get_borrower_id, \
											get_borrower_details
											
from invenio.search_engine_utils import get_fieldvalues

from invenio.libILS_join2 import *

END

sub new {
    my ($class, $item_id) = @_;
    my $type = ref($class) || $class;
    my $self;
    
    my $recid = sprintf("%d",get_recid($item_id)); # Make sure its an int


    if ($recid == 0) {
	syslog("LOG_DEBUG", "new ILS::Item('%s'): not found", $item_id);
	return undef;
    };
    
    my $loan_id = is_item_on_loan($item_id); # Retrieve the loan_id
    my $due_date = get_loan_due_date($loan_id); # Invenio format yyyy-mm-dd
    $due_date = str2time($due_date); # Epoc Format
    # If it is on loan retrieve Borrower (Patron)
    my $patron;
    my $borrower_id = get_borrower_id($item_id);
    if ($borrower_id) {
    	my $borrower_barcode = get_borrower_details($borrower_id)->[5];
    	$patron = ILS::Patron->new($borrower_barcode);
    };

    my  $book_title     = join(" ",get_fieldvalues($recid, "245__a"),
                          get_fieldvalues($recid, "245__b"),
                          get_fieldvalues($recid, "245__n"), 
                          get_fieldvalues($recid, "245__p"));
    
	my $h_queue = get_queue_request($recid);
	# This is an array of borrower ids e.g.  [['5'],['6']];
	# We flatten this
	my @hold_queue = map  {@$_} @$h_queue; # ['5','6'] or ''
	# Make sure its an array
	@hold_queue = [] unless (@hold_queue);

  $self =  {
				 title => decode_utf8($book_title),
				 id => $item_id,
				 recid => $recid,
				 sip_media_type => '001',
				 magnetic_media => 0,
				 hold_queue => @hold_queue,
				 due_date => $due_date,
         #patron => $patron->id,          
				 #patron => $patron,
			 };
    if ($patron) {
       $self->{patron}=$patron->id;
    };
    
    bless $self, $type;

    syslog("LOG_DEBUG", "new ILS::Item('%s'): found with title '%s'",
	   $item_id, encode_utf8($self->{title}));

    return $self;
}

sub recid {
    my $self = shift;
    return $self->{recid};
}

# Is this needed?
sub magnetic {
    my $self = shift;
    return $self->{magnetic_media};
}

sub magnetic_media {
    my $self = shift;
    return $self->{magnetic_media};
}
sub sip_media_type {
    my $self = shift;
    return $self->{sip_media_type};
}
sub sip_item_properties {
    my $self = shift;
    return $self->{sip_item_properties};
}

sub status_update {
    my ($self, $props) = @_;
    my $status = new ILS::Transaction;

    $self->{sip_item_properties} = $props;
    $status->{ok} = 1;

    return $status;
}

    
sub id {
    my $self = shift;
    return $self->{id};
}
sub title_id {
    my $self = shift;
    return $self->{title};
}
sub permanent_location {
    my $self = shift;
    return $self->{permanent_location} || '';
}
sub current_location {
    my $self = shift;
    return $self->{current_location} || '';
}

sub sip_circulation_status {
    my $self = shift;

    if ($self->{patron}) {
	return '04';
    } elsif (scalar @{$self->{hold_queue}}) {
	return '08';
    } else {
	return '03';
    }
}

sub sip_security_marker {
    return '02';
}

sub sip_fee_type {
    return '01';
}

sub fee {
    my $self = shift;
    return $self->{fee} || 0;
}

sub fee_currency {
    my $self = shift;
    return $self->{currency} || 'EUR';
}

sub owner {
    my $self = shift;
    return 'DESY'; # FIXME
}

sub hold_queue {
    my $self = shift;
    return $self->{hold_queue};
}

sub hold_queue_position {
    my ($self, $patron_id) = @_;
    my $i;

    for ($i = 0; $i < scalar @{$self->{hold_queue}}; $i += 1) {
	if ($self->{hold_queue}[$i]->{patron_id} eq $patron_id) {
	    return $i + 1;
	}
    }
    return 0;
}

sub due_date {
    my $self = shift;

    if ($self->{due_date}) {
    	# Due date is Epoc
        return strftime("%d-%m-%Y",localtime($self->{due_date}));  #    DD-MM-YYYY 21-01-2015
        return Sip::timestamp($self->{due_date}); # Epoc time!
    } else {
        return 0;
    }
}

sub recall_date {
    my $self = shift;
    return $self->{recall_date} || 0;
}
sub hold_pickup_date {
    my $self = shift;
    return $self->{hold_pickup_date} || 0;
}
sub screen_msg {
    my $self = shift;
    return $self->{screen_msg} || '';
}
sub print_line {
     my $self = shift;
     return $self->{print_line} || '';
}

# An item is available for a patron if
# 1) It's not checked out and (there's no hold queue OR patron
#    is at the front of the queue)
# OR
# 2) It's checked out to the patron and there's no hold queue
sub available {
     my ($self, $for_patron) = @_;

     return ((!defined($self->{patron_id}) && (!scalar @{$self->{hold_queue}}
					       || ($self->{hold_queue}[0] eq $for_patron)))
	     || ($self->{patron_id} && ($self->{patron_id} eq $for_patron)
		 && !scalar @{$self->{hold_queue}}));
}

sub collection_code {
	 my $self = shift;
	return $self->{collection_code} || '';
}

sub call_number {
	 my $self = shift;
	return $self->{call_number} || '';
}

sub destination_loc {
	 my $self = shift;
	return $self->{destination_loc} || '';
}

sub hold_patron_bcode {
	 my $self = shift;
	return $self->{hold_patron_bcode} || '';
}

sub hold_patron_name {
	 my $self = shift;
	return $self->{hold_patron_name} || '';
}



1;
