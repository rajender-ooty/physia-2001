##############################################################################
package App::Dialog::Person::Staff;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Person;
use App::Dialog::Field::Person;
use App::Dialog::Field::Address;
use DBI::StatementManager;
use App::Statements::Insurance;
use App::Statements::Org;
use App::Statements::Person;

use App::Universal;
use Date::Manip;
use Devel::ChangeLog;

use vars qw(@ISA @CHANGELOG);

@ISA = qw(App::Dialog::Person);

#sub new
#{
	#my $self = App::Dialog::Person::new(@_, id => 'staff', heading => '$Command Staff', postHtml => "<a href=\"javascript:doActionPopup('/lookup/person');\">Lookup existing staff</a>");

sub initialize
{
	my $self = shift;

	my $postHtml = "<a href=\"javascript:doActionPopup('/lookup/person');\">Lookup existing person</a>";

	#$self->heading('$Command Staff');
	$self->addContent(
			new App::Dialog::Field::Person::ID::New(caption => 'Staff ID',
							name => 'person_id',
							options => FLDFLAG_REQUIRED,
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						postHtml => $postHtml),
			);
	$self->SUPER::initialize();
	$self->addContent(
		new CGI::Dialog::MultiField(caption =>'Employee ID/Exp Date',
			fields => [
				new CGI::Dialog::Field(caption => 'Employee ID', name => 'emp_id'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'emp_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Certification/Number/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Certification1', name => 'cert1'),
				new CGI::Dialog::Field(caption => 'Certification Number1', name => 'cert_num1'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'cert1_exp_date', defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Certification/Number/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Certification2', name => 'cert2'),
				new CGI::Dialog::Field(caption => 'Certification Number2', name => 'cert_num2'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'cert2_exp_date', defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Certification/Number/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Certification3', name => 'cert3'),
				new CGI::Dialog::Field(caption => 'Certification Number3', name => 'cert_num3'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'cert3_exp_date', defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Certification/Number/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Certification4', name => 'cert4'),
				new CGI::Dialog::Field(caption => 'Certification Number4', name => 'cert_num4'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'cert4_exp_date', defaultValue => ''),
				]),
		new CGI::Dialog::Field(
						type => 'bool',
						name => 'delete_record',
						caption => 'Delete record?',
						style => 'check',
						invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
						readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE),
	);

	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions_add => [
							['View Staff Summary', "/person/%field.person_id%/profile", 1],
							['Add Another Staff Member', '/org/#session.org_id#/dlg-add-staff'],
							['Go to Search', "/search/person/id/%field.person_id%"],
							['Return to Create Record', '/search'],
							['Go to Work List', "person/worklist"],
							],
						cancelUrl => $self->{cancelUrl} || undef)
	);

	return $self;
}

sub makeStateChanges
{
	my ($self, $page, $command, $dlgFlags) = @_;

	$self->updateFieldFlags('acct_chart_num', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('nurse_title', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('physician_type', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('misc_notes', FLDFLAG_INVISIBLE, 1);
	my $personId = $page->param('person_id');

	if($command eq 'remove')
	{
		my $deleteRecord = $self->getField('delete_record');
		$deleteRecord->invalidate($page, "Are you sure you want to delete Staff Member '$personId'?");
	}

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}

sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');
	my $member = 'Staff';

	$self->SUPER::handleRegistry($page, $command, $flags, $member);

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id')  || undef,
			item_name => 'Employee',
			value_type => App::Universal::ATTRTYPE_LICENSE || undef,
			value_text => $page->field('emp_id')  || undef,
			value_dateA=> $page->field('emp_exp_date') || undef,
			_debug => 0
	) if $page->field('emp_id') ne '';

	$self->handleContactInfo($page, $command, $flags, 'staff');
}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'staff';

	$self->SUPER::handleRegistry($page, $command, $flags, $member);

}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Staff';

	$self->SUPER::execute_remove($page, $command, $flags, $member);

}

#
# change log is an array whose contents are arrays of
# 0: one or more CHANGELOGFLAG_* values
# 1: the date the change/update was made
# 2: the person making the changes (usually initials)
# 3: the category in which change should be shown (user-defined) - can have '/' for hierarchies
# 4: any text notes about the actual change/action
#

use constant STAFF_DIALOG => 'Dialog/Staff';

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/14/1999', 'MAF',
		STAFF_DIALOG,
		'Added entries for certification in the Staff dialog.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/23/1999', 'RK',
		STAFF_DIALOG,
		'Made a validation for the field ssn not to add an existing ssn while creating a new nurse record. ']
);

1;
