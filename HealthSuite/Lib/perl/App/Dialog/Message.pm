##############################################################################
package App::Dialog::Message;
##############################################################################

use strict;
use SDE::CVS ('$Id: Message.pm,v 1.1 2000-11-27 03:20:30 robert_jenks Exp $', '$Name:  $');
use CGI::Validator::Field;
use CGI::Dialog;
use base qw(CGI::Dialog);

use CGI::Carp qw(fatalsToBrowser);

use App::Dialog::Field::Person;
use DBI::StatementManager;
use App::Statements::Document;
use Date::Manip;
use Text::Autoformat;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'message' => {
			_arl => ['message_id'],
			_modes => ['send', 'trash', 'read', 'forward', 'reply_to', 'reply_to_all',],
			_idSynonym => 'message_' . App::Universal::MSGSUBTYPE_MESSAGE,
		},
);

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'message', heading => '$Command Message');
	
	my $toField = new App::Dialog::Field::Person::ID(
			name => 'to',
			caption => 'To',
			size => 40,
			maxLength => 255,
			findPopupAppendValue => ',',
			options => FLDFLAG_REQUIRED,
	);
	$toField->clearFlag(FLDFLAG_IDENTIFIER);
	
	my $ccField = new App::Dialog::Field::Person::ID(
			name => 'cc',
			caption => 'CC',
			size => 40,
			maxLength => 255,
			findPopupAppendValue => ',',
	);
	$ccField->clearFlag(FLDFLAG_IDENTIFIER);


	$self->addContent(
		new CGI::Dialog::Subhead(
			heading => 'Message',
			name => 'message_subhead',
			options => FLDFLAG_INVISIBLE,
		),
		new CGI::Dialog::Field(
			name => 'message_id',
			type => 'hidden',
		),
		new CGI::Dialog::Field(
			name => 'from',
			caption => 'From',
			options => FLDFLAG_READONLY,
		),
		$toField,
		$ccField,
		new App::Dialog::Field::Person::ID(
			name => 'patient_id',
			caption => 'Regarding Patient',
			types => ['Patient'],
			postHtml => ' #field.patient_name#',
		),
		new CGI::Dialog::Field(
			name => 'patient_name',
			type => 'hidden',
		),
		$self->addExtraFields(),
		#new CGI::Dialog::Field(
		#	name => 'deliver_records',
		#	caption => 'Deliver with medical record?',
		#	type => 'bool',
		#	style => 'check',
		#),
		new CGI::Dialog::Field(
			name => 'subject',
			caption => 'Subject',
			size => 50,
			maxLength => 255,
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(
			name => 'message',
			caption => 'Message',
			type => 'memo',
			cols => 85,
			rows => 10,
		),
		new CGI::Dialog::Subhead(
			heading => 'Notes',
			name => 'notes_subhead',
			options => FLDFLAG_INVISIBLE,
		),
		new App::Dialog::Message::Notes(
			name => 'existing_notes',
			caption => '',
		),
		new CGI::Dialog::Field(
			name => 'notes',
			caption => 'Add Notes',
			type => 'memo',
			cols => 85,
			rows => 10,
			options => FLDFLAG_INVISIBLE,
		),
		new CGI::Dialog::Field(
			name => 'notes_private',
			caption => 'Keep notes private?',
			type => 'bool',
			style => 'check',
			options => FLDFLAG_INVISIBLE,
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons());

	return $self;
}


sub addExtraFields
{
	my $self = shift;
	
	my @fields = ();
	return @fields;
}


sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
	
	if ($command eq 'read')
	{
		foreach (keys %{$self->{fieldMap}})
		{
			next if $_ eq 'notes';
			next if $_ eq 'notes_private';
			
			$self->setFieldFlags($_, FLDFLAG_READONLY);
		}
		
		$self->clearFieldFlags('message_subhead', FLDFLAG_INVISIBLE);
		$self->clearFieldFlags('notes_subhead', FLDFLAG_INVISIBLE);
		$self->clearFieldFlags('notes', FLDFLAG_INVISIBLE);
		$self->clearFieldFlags('notes_private', FLDFLAG_INVISIBLE);		
	}
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	
	my $existingMsg = {};
	if ($command ne 'send')
	{
		# Load existing message data
		my $messageId = $page->param('message_id');
		die "Message ID Required" unless $messageId;
		
		$existingMsg = $STMTMGR_DOCUMENT->getRowAsHash($page, STMTMGRFLAG_NONE, 'selMessage', $messageId);
		$existingMsg->{to} = $STMTMGR_DOCUMENT->getSingleValueList($page, STMTMGRFLAG_NONE, 'selMessageToList', $messageId);
		$existingMsg->{cc} = $STMTMGR_DOCUMENT->getSingleValueList($page, STMTMGRFLAG_NONE, 'selMessageCCList', $messageId);
	}
	$self->{existing_message} = $existingMsg;

	if ($command eq 'send')
	{
		# We're creating an entirely new message
		$page->field('from', $page->session('person_id'));
	}
	elsif (grep {$_ eq $command} ('trash', 'read'))
	{
		# We're displaying an existing message
		$page->field('from', $existingMsg->{'from_id'});
		$page->field('to', join(',', @{$existingMsg->{'to'}}));
		$page->field('cc', join(',', @{$existingMsg->{'cc'}})) if defined $existingMsg->{'cc'};
		my $patientId = defined $existingMsg->{'repatient_id'} ? $existingMsg->{'repatient_id'} : '';
		#$patientId = $existingMsg->{'repatient_name'} . qq{ (<a target="regarding_patient" href="/person/$patientId/chart">$patientId</a>)} if $patientId;
		$page->field('patient_id', $patientId);
		$page->field('patient_name', $existingMsg->{'repatient_name'}) if defined $existingMsg->{'repatient_name'};
		$page->field('deliver_records', $existingMsg->{'deliver_records'}) if defined $existingMsg->{'deliver_records'};
		$page->field('subject', $existingMsg->{'subject'});
		$page->field('message', $existingMsg->{'message'}) if defined $existingMsg->{'message'};
	}
	elsif (grep {$_ eq $command} ('reply_to', 'reply_to_all', 'forward'))
	{
		# We're creating a new message based on the existing message
		$page->field('from', $page->session('person_id'));
		
		if ($command eq 'reply_to' || $command eq 'reply_to_all')
		{
			$page->field('to', $existingMsg->{'from_id'});
		}
		
		if ($command eq 'reply_to_all')
		{
			$page->field('cc', join(',', @{$existingMsg->{'to'}}, @{$existingMsg->{'cc'}}));
		}
		
		# We should be safe to assume that it's still regarding the same patient
		$page->field('patient_id', $existingMsg->{'repatient_id'});
		
		# Create an appropriate new subject
		my $prefix = $command eq 'forward' ? 'FW: ' : 'RE: ';
		$page->field('subject', $prefix . $existingMsg->{subject});
		
		# Quote the existing message
		my $quotedMsg = autoformat $self->quoteMsg($existingMsg->{'message'}, $existingMsg->{'from_id'});
		$page->field('message', $quotedMsg);
	}
}


sub quoteMsg
{
	my $self = shift;
	my ($message, $from_id) = @_;
	
	$message =~ s/\n/\n\> /g;
	$message = "> " . $message;
	
	return $message;
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	unless ($command eq 'send')
	{
		$self->updateRecipientFlags($page, $command, $flags);
	}
	
	unless ($command eq 'trash' || $command eq 'read')
	{
		my $messageId = $self->saveMessage($page,
			doc_mime_type => 'text/plain',
			doc_orig_stamp => $page->getTimeStamp(),
			doc_spec_type => App::Universal::DOCSPEC_INTERNAL,
			doc_spec_subtype => App::Universal::MSGSUBTYPE_MESSAGE,
			doc_source_id => $page->session('person_id'),
			doc_source_type => App::Universal::DOCSRCTYPE_PERSON,
			doc_name => $page->field('subject'),
			doc_content_small => $page->field('message'),
		);
		
		# Add the To recipients
		my @toRecipients = split /\,\s*/, $page->field('to');
		foreach my $toRecipient (@toRecipients)
		{
			$self->saveToRecipients($page,
				parent_id => $messageId,
				item_name => 'To',
				value_type => App::Universal::ATTRTYPE_PERSON_ID,
				value_int => 0,
				value_text => $toRecipient,
			);
		}

		# Add the CC recipients
		my @ccRecipients = split /\,\s*/, $page->field('cc');
		foreach my $ccRecipient (@ccRecipients)
		{
			$self->saveCCRecipients($page,
			parent_id => $messageId,
			item_name => 'CC',
			value_type => App::Universal::ATTRTYPE_PERSON_ID,
			value_int => 0,
			value_text => $ccRecipient,
			);
		}
		
		$self->saveRegardingPatient($page,
			parent_id => $messageId,
			item_name => 'Regarding Patient',
			value_type => App::Universal::ATTRTYPE_PATIENT_ID,
			value_text => $page->field('patient_id'),
			value_int => $page->field('deliver_records') ? 1 : 0,
		);	
	}
	else
	{
		if (my $notes = $page->field('notes'))
		{
			$self->saveNotes($page,
				parent_id => $page->param('message_id'),
				value_type => App::Universal::ATTRTYPE_TEXT,
				item_name => 'Notes',
				person_id => $page->session('person_id'),
				value_int => $page->field('notes_private') ? 1 : 0,
				value_text => $notes,
			);
		}		
	}
	
	$self->handlePostExecute($page, $command, $flags);
	
	return '';
}


sub updateRecipientFlags
{
	my $self = shift;
	my ($page, $command, $flags) = @_;
	
	my $messageId = $page->param('message_id');
	my $personId = $page->session('person_id');
	my $item_id = $STMTMGR_DOCUMENT->getSingleValue($page, STMTMGRFLAG_NONE, 'selMessageRecipientAttrId', $messageId, $personId);
	$page->schemaAction('Document_Attribute', 'update',
		item_id => $item_id,
		value_int => 1,
	);
}


sub saveMessage
{
	my $self = shift;
	my $page = shift;
	
	return $page->schemaAction('Document', 'add', @_);
}


sub saveToRecipients
{
	my $self = shift;
	my $page = shift;

	return $page->schemaAction('Document_Attribute', 'add', @_);
}


sub saveCCRecipients
{
	my $self = shift;
	my $page = shift;

	return $page->schemaAction('Document_Attribute', 'add', @_);
}


sub saveRegardingPatient
{
	my $self = shift;
	my $page = shift;
	my %data = @_;

	# Add the regarding patent
	if (defined $data{value_text})
	{
		return $page->schemaAction('Document_Attribute', 'add', %data);
	}
}


sub saveNotes
{
	my $self = shift;
	my $page = shift;
	
	return $page->schemaAction('Document_Attribute', 'add', @_);
}


##############################################################################
package App::Dialog::Message::Notes;
##############################################################################

use strict;
use SDE::CVS ('$Id: Message.pm,v 1.1 2000-11-27 03:20:30 robert_jenks Exp $', '$Name:  $');
use CGI::Dialog;
use base qw(CGI::Dialog::ContentItem);

use DBI::StatementManager;
use App::Statements::Document;
use Data::Publish;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP=();


sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags, $mainData) = @_;
	
	return '' unless $command eq 'read';
	
	my $noteRows = $STMTMGR_DOCUMENT->getRowsAsArray($page, STMTMGRFLAG_NONE, 'selMessageNotes', $page->param('message_id'), $page->session('person_id'));
	my $html = '';
	foreach my $note (@$noteRows)
	{
		my $date = Data::Publish::fmt_stamp($page, $note->[0]);
		my $private = $note->[3] ? '<b>(privately)</b>' : '';
		
		$html .= "<p><b>$note->[1]</b> on $date wrote: $private<br>$note->[2]</p>";
	}
	
	return qq{<tr><td colspan="2">&nbsp;</td><td style="font-size: 10pt; font-family: Tahoma, Ariel, Helvetica;">$html<br></td><td>&nbsp;</td></tr>};
}


1;
