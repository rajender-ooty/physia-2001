##############################################################################
package App::Dialog::Person::Nurse;
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
use App::Page::Search::Session;
use App::Universal;
use Date::Manip;

use vars qw(@ISA %RESOURCE_MAP);
%RESOURCE_MAP = (
	'nurse' => {
		heading => '$Command Nurse', 
		_arl => ['person_id'], 
		_arl_modify => ['person_id'], 
		_idSynonym => 'Nurse',
		},
	);
@ISA = qw(App::Dialog::Person);

sub initialize
{
	my $self = shift;

	my $postHtml = "<a href=\"javascript:doActionPopup('/lookup/person');\">Lookup existing person</a>";

	$self->heading('$Command Nursing Staff');
	$self->addContent(
			new App::Dialog::Field::Person::ID::New(caption => 'Nurse ID',
							name => 'person_id',
							options => FLDFLAG_REQUIRED,
							readOnlyWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
						postHtml => $postHtml),
			);
	$self->SUPER::initialize();
	$self->addContent(
		new CGI::Dialog::Field(type => 'hidden', name => 'nurse_title_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'nurse_license_item_id'),
		new CGI::Dialog::Field(type => 'hidden', name => 'nurse_title_item_id'),

		new CGI::Dialog::Subhead(heading => 'Certification', name => 'cert_for_nurse'),

		new CGI::Dialog::MultiField(caption =>'Nursing License/Exp Date', name=> 'nurse_license', hints => "'Exp Date' and 'License Required' should be entered if there is a 'Nursing License'.",
			fields => [
				new CGI::Dialog::Field(caption => 'RN #', name => 'rn_number'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'rn_number_exp_date', defaultValue => ''),
				new CGI::Dialog::Field(type => 'bool', name => 'check_license', caption => 'License Required',	style => 'check'),
				]),
		new CGI::Dialog::MultiField(caption =>'Specialty Certification/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Specialty1', name => 'specialty1'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'specialty1_exp_date', defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Specialty Certification/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Specialty2', name => 'specialty2'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'specialty2_exp_date', defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Specialty Certification/Exp Date', invisibleWhen => CGI::Dialog::DLGFLAG_UPDORREMOVE,
			fields => [
				new CGI::Dialog::Field(caption => 'Specialty3', name => 'specialty3'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'specialty3_exp_date', defaultValue => ''),
				]),
		new CGI::Dialog::MultiField(caption =>'Employee ID/Exp Date',
			fields => [
				new CGI::Dialog::Field(caption => 'Employee ID', name => 'emp_id'),
				new CGI::Dialog::Field(type=> 'date', caption => 'Date of Expiration', name => 'emp_exp_date', futureOnly => 1, defaultValue => ''),
				]),
		new CGI::Dialog::Field(caption => 'Associated Physician Name',
												#type => 'foreignKey',
												name => 'value_text',
												#fKeyTable => 'person p, person_org_category pcat',
												#fKeySelCols => "distinct p.person_id, p.complete_name",
												#fKeyDisplayCol => 1,
												#fKeyValueCol => 0,
												fKeyStmtMgr => $STMTMGR_PERSON,
												fKeyStmt => 'selAssocNurse',
												fKeyDisplayCol => 1,
												fKeyValueCol => 0
												#fKeyStmtBindPageParams => "$sessOrgId"
												),
												#fKeyWhere => "p.person_id=pcat.person_id and pcat.org_id='$sessOrg' and category='Physician'",

		new CGI::Dialog::Field(
						type => 'bool',
						name => 'delete_record',
						caption => 'Delete record?',
						style => 'check',
						invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
						readOnlyWhen => CGI::Dialog::DLGFLAG_REMOVE)
	);

	$self->addFooter(new CGI::Dialog::Buttons(
						nextActions_add => [
							['View Nurse Summary', "/person/%field.person_id%/profile", 1],
							['Add Another Nurse', '/org/#session.org_id#/dlg-add-nurse'],
							['Go to Search', "/search/person/id/%field.person_id%"],
							['Return to Home', "/person/#session.user_id#/home"],
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
	$self->updateFieldFlags('physician_type', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('misc_notes', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('blood_type', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('ethnicity', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('party_name', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('relation', FLDFLAG_INVISIBLE, 1);
	$self->updateFieldFlags('license_num_state', FLDFLAG_INVISIBLE, 1);


	my $personId = $page->param('person_id');


	if($command eq 'remove')
	{
		my $deleteRecord = $self->getField('delete_record');
		$deleteRecord->invalidate($page, "Are you sure you want to delete Nurse '$personId'?");
	}

	my $sessOrgId = $page->session('org_id');

	$self->getField('value_text')->{fKeyStmtBindPageParams} = "$sessOrgId";

	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
}

sub customValidate
{
	my ($self, $page) = @_;

	my $licenseNum = $self->getField('nurse_license')->{fields}->[0];
	my $licenseDate = $self->getField('nurse_license')->{fields}->[1];
	my $licenseCheck = $self->getField('nurse_license')->{fields}->[2];

	if($page->field('rn_number') ne '' && ($page->field('check_license') eq '' || $page->field('rn_number_exp_date') eq ''))
	{
		$licenseNum->invalidate($page, "'Exp Date' and 'License Required' should be entered when 'Nursing License' is entered");
	}
	elsif($page->field('check_license') ne '' && ($page->field('rn_number') eq '' || $page->field('rn_number_exp_date') eq ''))
	{
		$licenseNum->invalidate($page, "'Nursing License' and 'Exp Date' should be entered when 'Exp Date' is entered");
	}
	elsif($page->field('rn_number_exp_date') ne '' && ($page->field('rn_number') eq '' || $page->field('check_license') eq ''))
	{
		$licenseNum->invalidate($page, "'Nursing License' and 'License Required' should be entered when 'Exp Date' is entered");
	}


}



sub execute_add
{
	my ($self, $page, $command, $flags) = @_;

	my $personId = $page->field('person_id');
	my $member = 'Nurse';

	$self->SUPER::handleRegistry($page, $command, $flags, $member);

	$page->schemaAction(
			'Person_Attribute',	$command,
			parent_id => $page->field('person_id'),
			item_name => 'Physician',
			value_type => App::Universal::ATTRTYPE_RESOURCEPERSON,
			value_text => $page->field('value_text') || undef,
			#parent_org_id => $page->session('org_id') || undef,
			_debug => 0
	);

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id'),
			item_name => 'Specialty',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('specialty1')  || undef,
			value_dateA => $page->field('specialty1_exp_date') || undef,
			_debug => 0
	) if $page->field('specialty1') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id'),
			item_name => 'Specialty',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('specialty2')  || undef,
			value_dateA => $page->field('specialty2_exp_date') || undef,
			_debug => 0
	) if $page->field('specialty2') ne '';

	$page->schemaAction(
			'Person_Attribute', $command,
			parent_id => $page->field('person_id'),
			item_name => 'Specialty',
			value_type => App::Universal::ATTRTYPE_LICENSE,
			value_text => $page->field('specialty3')  || undef,
			value_dateA => $page->field('specialty3_exp_date') || undef,
			_debug => 0
	) if $page->field('specialty3') ne '';

	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->field('person_id'),
		item_name => 'Physician',
		value_type => App::Universal::ATTRTYPE_RESOURCEPERSON || undef,
		value_text => $page->field('value_text') || undef,
		parent_org_id => $page->session('org_id') || undef,
		_debug => 0
	);

	$self->handleContactInfo($page, $command, $flags, 'nurse');

}

sub execute_update
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Nurse';

	$self->SUPER::handleRegistry($page, $command, $flags, $member);

}

sub execute_remove
{
	my ($self, $page, $command, $flags) = @_;

	my $member = 'Nurse';

	$self->SUPER::execute_remove($page, $command, $flags, $member);

}


1;
