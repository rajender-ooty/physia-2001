##############################################################################
package App::Dialog::Appointment;
##############################################################################

use strict;
use Carp;

use App::Universal;
use CGI::Validator::Field;
use CGI::Dialog;
use App::Dialog::Field::Person;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Person;
use vars qw(@ISA);
use Date::Manip;
use Date::Calc qw(:all);

use App::Dialog::Field::RovingResource;
use App::Dialog::Field::Organization;
use App::Dialog::Field::Scheduling;

use App::Schedule::Utilities;
use vars qw(@ISA %RESOURCE_MAP);

@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'appointment' => {
		_class => 'App::Dialog::Appointment',
		_arl_add => ['person_id', 'resource_id', 'facility_id', 'start_stamp', 'patient_type', 'visit_type'],
		_arl_modify => ['event_id'],
		_arl_cancel => ['event_id'],
		_arl_noshow => ['event_id'],
		_arl_reschedule => ['event_id'],
		_modes => ['add', 'update', 'remove', 'noshow', 'cancel', 'reschedule'],
	},
);

use constant DUMMY_EVENT_TYPE => 100;

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'appointment', heading => '$Command Appointment');

	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	my $findAvailSlotHint = qq{&nbsp;
		<a href="javascript:doFindLookup(this.form, document.dialog._f_appt_date,
			'/lookup/apptslot/' + document.dialog._f_resource_id.value +	','
			+ document.dialog._f_facility_id.value + ',,' + document.dialog._f_duration.value
			+ ',' + document.dialog._f_patient_type.value + ',' + document.dialog._f_visit_type.value
			+ ',' + document.dialog._f_appt_type_id.value
			+ '/1', null, false, 'location, status, width=700,height=600,scrollbars,resizable',
			null, document.dialog._f_appt_time);">
			Find Next Available Slot</a>
	};

	my $waitingListHint = qq{
		Select Patient to fill this Appointment Slot. &nbsp
		<a href="javascript:doFindLookup(this.form, document.dialog._f_waiting_patients,
			'/schedule-p/handleWaitingList/' + document.dialog._f_event_id.value)">View Details</a>
	};

	my $physField = new App::Dialog::Field::Person::ID(caption => 'Physician ID',
		name => 'resource_id',
		types => ['Physician'],
		hints => 'Physician ID or select a Roving Physician',
		options => FLDFLAG_REQUIRED,
		size => 32,
		maxLength => 64,
	);
	$physField->clearFlag(FLDFLAG_IDENTIFIER); # because we can have roving resources, too.

	$self->addContent(
		# the following hidden fields are needed in the "execute" phase
		new CGI::Dialog::Field(type => 'hidden', name => 'event_id'),

		new App::Dialog::Field::Person::ID(caption => 'Patient ID',
			name => 'attendee_id',
			types => ['Patient'],
			size => 25,
			useShortForm => 1,
			hints => 'Leave blank to use ID autosuggestion feature for new patients',
			#options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field(caption => 'Patient Type',
			type => 'enum',
			enum => 'appt_attendee_type',
			name => 'patient_type',
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field(caption => 'Visit Type',
			name => 'visit_type',
			type => 'select',
			fKeyDisplayCol => 1,
			fKeyValueCol => 0,
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selVisitTypesDropDown',
		),
		
		new CGI::Dialog::Field(caption => 'Reason for Visit',
			name => 'subject',
			size => 40,
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field(caption => 'Symptoms',
			type => 'memo', name => 'remarks'
		),

		new CGI::Dialog::Field(type => 'hidden', name => 'appt_type_id'),
		new App::Dialog::Field::Scheduling::ApptType(caption => 'Appointment Type',
			name => 'appt_type_caption',
			findPopup => '/lookup/appttype',
			secondaryFindField => '_f_appt_type_id',
			#hints => $findAvailSlotHint,
			size => 30,
			hints => 'You must use the lookup to specify Appointment Type',
		),

		new CGI::Dialog::MultiField (caption => 'Appointment Date / Time',
			name => 'appt_date_time',
			fields => [
				new App::Dialog::Field::Scheduling::Date(
					name => 'appt_date',
					options => FLDFLAG_REQUIRED,
				),
				new CGI::Dialog::Field(
					name => 'appt_time',
					type => 'time',
					options => FLDFLAG_REQUIRED,
					postHtml => $findAvailSlotHint,
				),
			],
		),
		#new App::Dialog::Field::Scheduling::Hours(
		#	caption => 'Appt Time Hour',
		#	name => 'appt_hour',
		#	timeField => '_f_appt_time'
		#),
		new CGI::Dialog::MultiField (
			name => 'minutes_util',
			fields => [
				new App::Dialog::Field::Scheduling::Minutes(
					caption => 'Appt Time Minute',
					name => 'appt_minute',
					timeField => '_f_appt_time'
				),
				new App::Dialog::Field::Scheduling::AMPM(
					caption => 'AM PM',
					name => 'appt_am',
					timeField => '_f_appt_time'
				),
			],
		),
		new CGI::Dialog::Field(caption => 'Check for Conflicts',
			name => 'conflict_check',
			type => 'bool', style => 'check', value => 1,
		),

		new CGI::Dialog::Field(name => 'duration',	type => 'hidden',),

		$physField,

		new App::Dialog::Field::RovingResource(physician_field => '_f_resource_id',
			name => 'roving_physician',
			caption => 'Roving Physician',
			type => 'foreignKey',
			fKeyDisplayCol => 0,
			fKeyValueCol => 0,
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selRovingPhysicianTypes',
		),
		new App::Dialog::Field::OrgType(
			caption => 'Facility',
			name => 'facility_id',
			types => qq{'CLINIC','HOSPITAL','FACILITY/SITE','PRACTICE'},
		),
		new CGI::Dialog::Field(caption => '$Command Remarks',
		 	type => 'memo', name => 'discard_remarks'
		),
		new CGI::Dialog::Field(caption => "Rescheduled By",
		 	type => 'select',
			selOptions => 'Patient;Office',
			name => 'rescheduled',
			options => FLDFLAG_REQUIRED
		),
		new CGI::Dialog::Field(
			name => 'waiting_patients',
			caption => 'Waiting List',
			type => 'foreignKey',
			fKeyDisplayCol => 0,
			fKeyValueCol => 1,
			fKeyStmtMgr => $STMTMGR_SCHEDULING,
			fKeyStmt => 'selWaitingPatients',
			fKeyStmtBindFields => ['event_id'],
			hints => $waitingListHint,
		),

	);
	$self->{activityLog} =
	{
		scope =>'event',
		key => "#field.attendee_id#",
		data => "appointment '#field.attendee_id#' <a href='/person/#field.attendee_id#/profile'>#field.attendee_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons);

	return $self;
}

sub setPhysicianFields
{
	my ($self, $page, $command, $flags) = @_;
	my $personId = $page->param('attendee_id') || $page->field('attendee_id');
	my $orgId = $page->session('org_internal_id');
	my $physicianData = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selPrimaryPhysician', $orgId, $personId);
	my $physicianId = $physicianData->{phy};
	$page->field('resource_id', $physicianId) unless $page->field('resource_id');
}

###############################
# makeStateChanges functions
###############################

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);

	$self->updateFieldFlags('discard_remarks', FLDFLAG_INVISIBLE, $command =~ m/^(add|update)$/);
	$self->updateFieldFlags('rescheduled', FLDFLAG_INVISIBLE, $command =~ m/^(add|cancel|noshow|update)$/);
	$self->updateFieldFlags('resource_id', FLDFLAG_READONLY, $command =~ m/^(cancel|noshow|update)$/);
	$self->updateFieldFlags('conflict_check', FLDFLAG_INVISIBLE, $command =~ m/^(cancel|noshow)$/);
	$self->updateFieldFlags('roving_physician', FLDFLAG_INVISIBLE, $command =~ m/^(cancel|noshow|update)$/);
	$self->updateFieldFlags('waiting_patients', FLDFLAG_INVISIBLE, $command =~ m/^(add)$/);
}

sub makeStateChanges_cancel
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;
	$self->updateFieldFlags('attendee_id', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('patient_type', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('visit_type', FLDFLAG_READONLY, 1);

	$self->updateFieldFlags('appt_date_time', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('minutes_util', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('appt_type_caption', FLDFLAG_READONLY, 1);

	$self->updateFieldFlags('subject', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('remarks', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('start_stamp', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('duration', FLDFLAG_READONLY, 1);
	$self->updateFieldFlags('facility_id', FLDFLAG_READONLY, 1);
}

sub makeStateChanges_noshow
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;
	$self->makeStateChanges_cancel($page, $command, $activeExecMode, $dlgFlags);
}

###############################
# populateData functions
###############################

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $startStamp;
	if ($startStamp = $page->param('start_stamp'))
	{
		$startStamp =~ s/\-/\//g;
		$startStamp =~ s/_/ /g;
	}
	else
	{
		$startStamp = $page->getTimeStamp();
	}

	$startStamp =~ /(.*?) (.*)/;
	my ($appt_date, $appt_time) = ($1, $2);

	$page->field('appt_date', $appt_date);
	$page->field('appt_time', $appt_time);

	$page->field('attendee_id', $page->param('person_id'));
	$page->field('resource_id', $page->param('resource_id'));
	$page->field('facility_id', $page->param('facility_id'));
	$page->field('patient_type', $page->param('patient_type'));
	$page->field('visit_type', $page->param('visit_type'));

	#$page->field('duration', $page->param('duration'));
	App::Dialog::Appointment::setPhysicianFields($self, $page, $command, $flags);
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	my $eventId = $page->param('event_id');
	$STMTMGR_SCHEDULING->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPopulateAppointmentDialog', $eventId);
}

sub populateData_cancel
{
	populateData_update(@_);
}

sub populateData_remove
{
	populateData_update(@_);
}

sub populateData_noshow
{
	populateData_update(@_);
}

sub populateData_reschedule
{
	populateData_update(@_);
}

sub customValidate
{
	my ($self, $page) = @_;
	
	return unless $page->field('resource_id');

	if ($page->field('attendee_id') eq '')
	{
		my $createPersonHref = "javascript:doActionPopup('/org-p/#session.org_id#/dlg-add-shortformPerson',null,null,['_f_person_id'],['_f_attendee_id']);" ;
		my $invMsg = qq{<a href="$createPersonHref">Create Patient</a> };
		my $attendee_id = $self->getField('attendee_id');
		$attendee_id->invalidate($page, $invMsg)
	}

	if ($page->field('conflict_check'))
	{
		unless ($self->validateMultiAppts($page))
		{
			$self->validateAvailTemplate($page);
		}
	}
	else
	{
		$page->delete('_f_parent_id');
	}
}

sub validateAvailTemplate
{
	my ($self, $page) = @_;
	
	my @resource_ids = ();
	push(@resource_ids, $page->field('resource_id'));
	
	my @internalOrgIds = ($page->field('facility_id'));
	my @search_start_date = Decode_Date_US($page->field('appt_date'));
	
	my $apptType = $page->property('apptTypeInfo');

	my $rIds = $apptType->{r_ids};
	push(@resource_ids, split(/\s*,\s*/, $rIds)) if $rIds;
	
	my $sa = new App::Schedule::Analyze (
		resource_ids      => \@resource_ids,
		facility_ids      => \@internalOrgIds,
		search_start_date => \@search_start_date,
		search_duration   => 1,
		patient_type      => defined $page->field('patient_type') ? $page->field('patient_type') : -1,
		visit_type        => defined $page->field('visit_type') ? $page->field('visit_type') : -1
	);
	
	my $flag = defined $rIds ? App::Schedule::Analyze::MULTIRESOURCESEARCH_PARALLEL
		: App::Schedule::Analyze::MULTIRESOURCESEARCH_SERIAL;

	my @available_slots = $sa->findAvailSlots($page, $flag);
	my $availSlot = $available_slots[0];
	
	my $apptBeginMinutes = hhmmAM2minutes($page->field('appt_time'));
	my $apptEndMinutes = $apptBeginMinutes + $page->field('duration');
	my $apptMinutesRange = "$apptBeginMinutes-$apptEndMinutes";

	my $field = $self->getField('appt_date_time')->{fields}->[0];
	my $personId = uc($page->field('attendee_id'));

	if (! $availSlot->{minute_set}->superset($apptMinutesRange) 
		&& $page->param('_f_whatToDo') ne 'cancel' && $page->param('_f_whatToDo') ne 'override')
	{
		$field->invalidate($page, qq{
			All of Part of this time slot is not available.<br>
			Please check @{[ join(', ', @resource_ids) ]} templates, patient types and visit types. <br>
			<u>Select action</u>: <br>
				<input name=_f_whatToDo type=radio value="override"
					onClick="document.dialog._f_whatToDo[0].checked=true">Override Template.  Make appointment anyway.<br>
				<input name=_f_whatToDo type=radio value="cancel"
					onClick="document.dialog._f_whatToDo[1].checked=true">Cancel
		});
	}
}

sub validateMultiAppts
{
	my ($self, $page) = @_;
	
	my $personId = uc($page->field('attendee_id'));

	my ($parentEventId, $patientId) = $self->findConflictEvent($page);
	if ($parentEventId)
	{
		unless ($page->field('processConflict'))
		{
			my $field = $self->getField('appt_date_time')->{fields}->[0];
			$field->invalidate($page, qq{This time slot is currently booked for $patientId.<br>
			<u>Select action</u>: <br>
				<input name=_f_whatToDo type=radio value="wl" CHECKED
					onClick="document.dialog._f_whatToDo[0].checked=true"> Place $personId on Waiting List <br>
				<input name=_f_whatToDo type=radio value="db"
					onClick="document.dialog._f_whatToDo[1].checked=true"> Over-Book $personId <br>
				<input name=_f_whatToDo type=radio value="cancel"
					onClick="document.dialog._f_whatToDo[2].checked=true"> Cancel

				<input name=_f_processConflict type=hidden value=1>
				<input name=_f_parent_id type=hidden value="$parentEventId">
			});
		}
	}
	else
	{
		$page->delete('_f_parent_id');
	}
	
	return $parentEventId;
}

sub findConflictEvent
{
	my ($self, $page) = @_;

	my $apptType = $STMTMGR_SCHEDULING->getRowAsHash($page, STMTMGRFLAG_NONE,
		'selApptTypeById', $page->field('appt_type_id')) if $page->field('appt_type_id');
	$page->property('apptTypeInfo', $apptType);

	$page->field('duration', $apptType->{duration} || 10);
	return (undef, undef) if $apptType->{multiple};

	my $start_time = $page->field('appt_date') . ' '  . $page->field('appt_time');
	my ($startDate, $startTime, $am) = split(/ /, $start_time);
	my $endDate   = UnixDate(DateCalc($startDate, "+1 day"), "%Y,%m,%d");
	$startDate = UnixDate($startDate, "%Y,%m,%d");

	my $day = Date_to_Days(split(/,/, $startDate));
	my $dayMinutes = $day * 24 * 60;

	my $startMinutes = hhmmAM2minutes("$startTime $am") + $dayMinutes +1;
	my $endMinutes   = $startMinutes + $page->field('duration') -2;
	my $minuteRange  = "$startMinutes-$endMinutes";
	my $apptSlot     = new Set::IntSpan($minuteRange);

	my $events = $STMTMGR_SCHEDULING->getRowsAsHashList($page, STMTMGRFLAG_NONE,
		'selAppointmentConflictCheck', $startDate, $endDate, $page->field('facility_id'),
			$page->field('resource_id'));

	for my $event (@$events)
	{
		my $day = Date_to_Days(split(/,/, $event->{start_day}));
		my $dayMinutes = $day * 24 * 60;

		my $start_minute = hhmm2minutes($event->{start_minute}) + $dayMinutes;
		my $end_minute = $start_minute + $event->{duration};
		my $minute_range =  $start_minute . "-" . $end_minute;
		my $slot = new Set::IntSpan("$minute_range");

		my $intersect = $apptSlot->intersect($slot);
		unless ($intersect->empty())
		{
			next if ($event->{patient_id} eq $page->field('attendee_id'));
			next if ($event->{parent_id});
			return ($event->{event_id}, $event->{patient_id});
		}
	}
	return (undef, undef);
}

sub handleWaitingList
{
	my ($self, $page, $thisEventId) = @_;

	# See if I'm a parent Event
	my $nextInLineEventID = $STMTMGR_SCHEDULING->getSingleValue($page, STMTMGRFLAG_NONE,
		'selNextInLineEventID', $thisEventId);

	if ($nextInLineEventID) # I'm a parent
	{
		if (my $replacementEventId = $page->field('waiting_patients'))
		{
			$STMTMGR_SCHEDULING->execute($page, STMTMGRFLAG_NONE, 'updParentEventToNULL', $replacementEventId);
			$STMTMGR_SCHEDULING->execute($page, STMTMGRFLAG_NONE, 'updSetNewParentEvent', $replacementEventId, $thisEventId);
		}
	}

	# if no longer conflict
	my ($parentEventId, $patientId) = $self->findConflictEvent($page);
	unless($parentEventId)
	{
		$STMTMGR_SCHEDULING->execute($page, STMTMGRFLAG_NONE, 'updParentEventToNULL', $thisEventId);
	}
}

###############################
# execute function
###############################

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $eventId = $page->field('event_id');
	my $timeStamp = $page->getTimeStamp();

	my $start_time = $page->field('appt_date') . ' '  . $page->field('appt_time');

	my $parentId = $page->field('parent_id');
	undef $parentId if $page->field('whatToDo') eq 'db';

	if ($page->field('whatToDo') ne 'cancel')
	{
		if ($command eq 'add')
		{
			my $apptID = $page->schemaAction(
				'Event', 'add',
				owner_id => $page->session('org_internal_id') || undef,
				event_type => DUMMY_EVENT_TYPE,
				event_status => 0,
				subject => $page->field('subject'),
				start_time => $start_time,
				duration => $page->field('duration') || 10,
				facility_id => $page->field('facility_id') || undef,
				remarks => $page->field('remarks') || undef,
				scheduled_stamp => $timeStamp,
				scheduled_by_id => $page->session('user_id') || undef,
				parent_id => $parentId || undef,
				appt_type => $page->field('appt_type_id') || undef,
				_debug => 0
			);
			if ($apptID gt 0)
			{
				$page->schemaAction(
					'Event_Attribute', 'add',
					parent_id => $apptID,
					item_name => 'Appointment/Attendee/Patient',
					value_type => App::Universal::EVENTATTRTYPE_PATIENT,
					value_text => $page->field('attendee_id') || undef,
					value_int => $page->field('patient_type') || 0,
					value_intB => $page->field('visit_type') || -1,
					_debug => 0
					);
				$page->schemaAction(
					'Event_Attribute', 'add',
					parent_id => $apptID,
					item_name => 'Appointment/Attendee/Physician',
					value_type => App::Universal::EVENTATTRTYPE_PHYSICIAN,
					value_text => $page->field('resource_id') || undef,
					_debug => 0
					);
			}
		}
		elsif ($command eq 'update')
		{
			$page->schemaAction(
				'Event', 'update',
				event_id => $eventId,
				event_type => DUMMY_EVENT_TYPE,
				event_status => 0,
				subject => $page->field('subject'),
				start_time => $start_time,
				duration => $page->field('duration') || 10,
				facility_id => $page->field('facility_id') || undef,
				remarks => $page->field('remarks') || undef,
				parent_id => $parentId || undef,
				appt_type => $page->field('appt_type_id') || undef,
				_debug => 0
			);

			$self->handleWaitingList($page, $eventId);
		}
		elsif ($command eq 'noshow' || $command eq 'cancel')
		{
			my $discardType = $command eq 'cancel' ? 0: 1;
			$page->schemaAction(
				'Event', 'update',
				event_id => $eventId,
				event_status => 3,
				discard_type => $discardType,
				discard_by_id => $page->session('user_id') || undef,
				discard_stamp => $timeStamp,
				discard_remarks => $page->field('discard_remarks') || undef,
				_debug => 0
			);

			$self->handleWaitingList($page, $eventId);
		}
		elsif ($command eq 'reschedule')
		{
			#First, update existing appt to discard, then add new appt w/2 property records
			my $discardType = $page->field('rescheduled') eq 'Patient' ? 2 : 3;
			$page->schemaAction(
				'Event', 'update',
				event_id => $eventId,
				event_status => 3,
				remarks => $page->field('remarks') || undef,
				discard_type => $discardType,
				discard_by_id => $page->session('user_id') || undef,
				discard_stamp => $timeStamp,
				discard_remarks => $page->field('discard_remarks') || undef,
				_debug => 0
			);
			my $apptID = $page->schemaAction(
				'Event', 'add',
				owner_id => $page->session('org_internal_id') || undef,
				event_type => DUMMY_EVENT_TYPE,
				event_status => 0,
				subject => $page->field('subject'),
				start_time => $start_time,
				duration => $page->field('duration') || 10,
				facility_id => $page->field('facility_id') || undef,
				remarks => $page->field('remarks') || undef,
				scheduled_stamp => $timeStamp,
				scheduled_by_id => $page->session('user_id') || undef,
				parent_id => $parentId || undef,
				appt_type => $page->field('appt_type_id') || undef,
				_debug => 0
			);
			if ($apptID gt 0)
			{
				$page->schemaAction(
					'Event_Attribute', 'add',
					parent_id => $apptID,
					item_name => 'Appointment/Attendee/Patient',
					value_type => App::Universal::EVENTATTRTYPE_PATIENT,
					value_text => $page->field('attendee_id') || undef,
					value_int => $page->field('patient_type') || 0,
					value_intB => $page->field('visit_type') || -1,
					_debug => 0
					);
				$page->schemaAction(
					'Event_Attribute', 'add',
					parent_id => $apptID,
					item_name => 'Appointment/Attendee/Physician',
					value_type => App::Universal::EVENTATTRTYPE_PHYSICIAN,
					value_text => $page->field('resource_id') || undef,
					_debug => 0
				);
			}

			$self->handleWaitingList($page, $eventId);
		}
	}

	$self->handlePostExecute($page, $command, $flags);
}

1;
