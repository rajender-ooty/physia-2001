##############################################################################
package App::ResourceDirectory;
##############################################################################

use strict;
use App::Universal;
use Devel::ChangeLog;

##############################################################################
# Directory of all available StatementManager Objects
##############################################################################

use App::Statements::Component;
use App::Statements::Component::Person;
use App::Statements::Component::Org;
use App::Statements::Component::Scheduling;

use App::Statements::Catalog;
use App::Statements::Insurance;
use App::Statements::IntelliCode;
use App::Statements::Invoice;
use App::Statements::Org;
use App::Statements::Person;
use App::Statements::Scheduling;
use App::Statements::Transaction;

##############################################################################
# Directory of all available primary Page Objects
##############################################################################

use App::Page;
use App::Page::Catalog;
use App::Page::ChangeLog;
use App::Page::Component;
use App::Page::Construct;
use App::Page::Dialog;
use App::Page::Error;
use App::Page::Home;
use App::Page::Help;
use App::Page::Invoice;
use App::Page::Org;
use App::Page::Person;
use App::Page::Schedule;
use App::Page::Report;
use App::Page::WorkList;

##############################################################################
# Directory of all available Search Page Objects
##############################################################################

use App::Page::Search;
use App::Page::Search::Home;
use App::Page::Search::Auto;
use App::Page::Search::Person;
use App::Page::Search::Org;
use App::Page::Search::ICD;
use App::Page::Search::CPT;
use App::Page::Search::HCPCS;
use App::Page::Search::ServiceType;
use App::Page::Search::ServicePlace;
use App::Page::Search::Claim;
use App::Page::Search::Insurance;
use App::Page::Search::Catalog;
use App::Page::Search::EnvoyPayer;
use App::Page::Search::ApptSlot;
use App::Page::Search::Appointment;
use App::Page::Search::Template;
use App::Page::Search::Session;
use App::Page::Search::Drug;
use App::Page::Search::AdhocQuery;
use App::Page::Search::ApptType;

##############################################################################
# Directory of all available Components - components are auto-registering
##############################################################################

use CGI::Component;
use App::Component::Functions;
use App::Component::News;
use App::Component::Navigate::FileSys;
use App::Component::WorkList;
use App::Component::ResourceSelector;
use App::Component::FacilitySelector;

##############################################################################
# Directory of all available Dialog Objects
##############################################################################


use App::Dialog::Adjustment;
use App::Dialog::Appointment;
use App::Dialog::Attribute::Association::CareProvider;
use App::Dialog::Attribute::Association::Emergency;
use App::Dialog::Attribute::Association::Employment;
use App::Dialog::Attribute::Association::Family;
use App::Dialog::Attribute::Allergy;
use App::Dialog::Attribute::AttachInsurance;
use App::Dialog::Attribute::AssociatedResource::Nurse;
use App::Dialog::Attribute::AssociatedResource::SessionPhysicians;
use App::Dialog::Attribute::AssociatedResource::Org;
use App::Dialog::Attribute::AssociatedResource::OrgEmployee;
use App::Dialog::Attribute::Authorization::InfoRelease;
use App::Dialog::Attribute::Authorization::PatientSign;
use App::Dialog::Attribute::Authorization::ProviderAssign;
use App::Dialog::Attribute::Certificate::Accreditation;
use App::Dialog::Attribute::Certificate::Affiliation;
use App::Dialog::Attribute::Certificate::License;
use App::Dialog::Attribute::Certificate::State;
use App::Dialog::Attribute::Attendance;
use App::Dialog::Attribute::Address;
use App::Dialog::Attribute::Default;
use App::Dialog::Attribute::Credential;
use App::Dialog::Attribute::Directive;
use App::Dialog::Attribute::Directive::Patient;
use App::Dialog::Attribute::Directive::Physician;
use App::Dialog::Attribute::EmploymentBenefit;
use App::Dialog::Attribute::PreventiveCare;
use App::Dialog::Catalog;
use App::Dialog::CatalogItem;
use App::Dialog::ClaimProblem;
use App::Dialog::Customize;
use App::Dialog::Diagnoses;
use App::Dialog::Encounter;
use App::Dialog::Encounter::Checkin;
use App::Dialog::Encounter::CreateClaim;
use App::Dialog::Encounter::Checkout;
use App::Dialog::InsurancePlan::Product;
use App::Dialog::InsurancePlan::Plan;
use App::Dialog::InsurancePlan::PersonalCoverage;
use App::Dialog::InsurancePlan::PersonExistsPlan;
use App::Dialog::InsurancePlan::PersonUniquePlan;
use App::Dialog::InsurancePlan::NewPlan;
use App::Dialog::Login;
use App::Dialog::OnHold;
use App::Dialog::Organization;
use App::Dialog::Organization::Department;
use App::Dialog::Person::Nurse;
use App::Dialog::Person::Patient;
use App::Dialog::Person::Physician;
use App::Dialog::Person::Staff;
use App::Dialog::Procedure;
#use App::Dialog::Slot;
use App::Dialog::Template;
use App::Dialog::Transaction::ActiveProblems;
use App::Dialog::Transaction::Alert;
use App::Dialog::Transaction::Hospitalization;
use App::Dialog::Transaction::Medication;
use App::Dialog::Transaction::TestsMeasurements;
use App::Dialog::Transaction::Immunization;
#use App::Dialog::UserProblems;
use App::Dialog::WorkersComp;
use App::Dialog::AttachWorkersComp;
use App::Dialog::HealthMaintenance;
use App::Dialog::ApptType;
use App::Dialog::Training;
use App::Dialog::ResponsibleParty;
use App::Dialog::Attribute::MiscNotes;

##############################################################################
# Global variables that map (using a system-wide ID) unique text to specific
# page and dialog objects
##############################################################################

use vars qw(@CHANGELOG %PAGE_CLASSES $SEARCH_CLASSES %DIALOG_CLASSES %STATEMENTMGR_CLASSES %COMPONENT_CATALOG %PAGE_FLAGS);

%STATEMENTMGR_CLASSES = (
	'catalog' => $STMTMGR_CATALOG,
	'insurance' => $STMTMGR_INSURANCE,
	'intellicode' => $STMTMGR_INTELLICODE,
	'invoice' => $STMTMGR_INVOICE,
	'org' => $STMTMGR_ORG,
	'person' => $STMTMGR_PERSON,
	'scheduling' => $STMTMGR_SCHEDULING,
	'transaction' => $STMTMGR_TRANSACTION,
);

$SEARCH_CLASSES = {
	'_default' => 'App::Page::Search::Home',
	'auto' => 'App::Page::Search::Auto',
	'person' => 'App::Page::Search::Person',
	'org' => 'App::Page::Search::Org',
	'claim' => 'App::Page::Search::Claim',
	'insurance' => 'App::Page::Search::Insurance',
	'catalog' => 'App::Page::Search::Catalog',
	'envoypayer' => 'App::Page::Search::EnvoyPayer',
	'apptslot' => 'App::Page::Search::ApptSlot',
	'appointment' => 'App::Page::Search::Appointment',
	'template' => 'App::Page::Search::Template',
	'session' => 'App::Page::Search::Session',
	'drug' => 'App::Page::Search::Drug',
	'icd' => 'App::Page::Search::ICD',
	'cpt' => 'App::Page::Search::CPT',
	'hcpcs' => 'App::Page::Search::HCPCS',
	'servicetype' => 'App::Page::Search::ServiceType',
	'serviceplace' => 'App::Page::Search::ServicePlace',
	'adhocquery' => 'App::Page::Search::AdhocQuery',
	'appttype' => 'App::Page::Search::ApptType',
};

%PAGE_CLASSES = (
	'logout' => 'App::Page::Home',
	'help' => 'App::Page::Help',
	'home' => 'App::Page::Home',
	'homeorg' => 'App::Page::Home',
	'invoice' => 'App::Page::Invoice',
	'create' => 'App::Page::Construct',
	'modify' => 'App::Page::Construct',
	'delete' => 'App::Page::Construct',
	'dialog' => 'App::Page::Dialog',
	'error' => 'App::Page::Error',
	'org' => 'App::Page::Org',
	'person' => 'App::Page::Person',
	'report' => 'App::Page::Report',
	'schedule' => 'App::Page::Schedule',
	'search' => $SEARCH_CLASSES,
	'lookup' => $SEARCH_CLASSES,
	'changes' => 'App::Page::ChangeLog',
	'catalog' => 'App::Page::Catalog',
	'component' => 'App::Page::Component',
	'worklist' => 'App::Page::WorkList',
);

%DIALOG_CLASSES = (
	'activeproblems-trans' => {_class => 'App::Dialog::Transaction::ActiveProblems',
					transType => App::Universal::TRANSTYPEDIAG_TRANSIENT,
					heading => '$Command Transient Diagnosis',
					_arl_add => ['person_id'],
					_arl_remove => ['trans_id'],
					_idSynonym => 'trans-' . App::Universal::TRANSTYPEDIAG_TRANSIENT() },
	'activeproblems-surgical' => {_class => 'App::Dialog::Transaction::ActiveProblems',
					transType => App::Universal::TRANSTYPEDIAG_SURGICAL,
					heading => '$Command Surgical Procedure',
					_arl_add => ['person_id'],
					_arl_remove => ['trans_id'],
					_idSynonym => 'trans-' . App::Universal::TRANSTYPEDIAG_SURGICAL() },
	'activeproblems-icd' => {_class => 'App::Dialog::Transaction::ActiveProblems',
					transType => App::Universal::TRANSTYPEDIAG_ICD,
					heading => '$Command Diagnosis',
					_arl_add => ['person_id'],
					_arl_remove => ['trans_id'],
					_idSynonym => 'trans-' . App::Universal::TRANSTYPEDIAG_ICD() },
	'activeproblems-perm' => {_class => 'App::Dialog::Transaction::ActiveProblems',
					transType => App::Universal::TRANSTYPEDIAG_PERMANENT,
					heading => '$Command Permanent Diagnosis',
					_arl_add => ['person_id'],
					_arl_remove => ['trans_id'],
					_idSynonym => 'trans-' . App::Universal::TRANSTYPEDIAG_PERMANENT()  },
	'activeproblems-notes' => {_class => 'App::Dialog::Transaction::ActiveProblems',
					transType => App::Universal::TRANSTYPEDIAG_NOTES,
					heading => '$Command Notes',
					_arl => ['person_id'],
					_arl_remove => ['trans_id'],
					_idSynonym => 'trans-' . App::Universal::TRANSTYPEDIAG_NOTES()  },
	'medication-prescribe' => {_class => 'App::Dialog::Transaction::Medication', transType => App::Universal::TRANSTYPE_PRESCRIBEMEDICATION, heading => '$Command Prescribe Medication',  _arl => ['person_id'], _arl_modify => ['trans_id'] , _idSynonym => 'trans-' . App::Universal::TRANSTYPE_PRESCRIBEMEDICATION() },
	'medication-current' => {_class => 'App::Dialog::Transaction::Medication', transType => [App::Universal::TRANSTYPE_CURRENTMEDICATION_OTC,App::Universal::TRANSTYPE_CURRENTMEDICATION_HOMEO], heading => '$Command Current Medication',  _arl => ['person_id'], _arl_modify => ['trans_id'],
								_idSynonym => [
											'trans-' . App::Universal::TRANSTYPE_CURRENTMEDICATION_OTC(),
											'trans-' . App::Universal::TRANSTYPE_CURRENTMEDICATION_HOMEO()
											]
							},
	#'alert-org' => {_class => 'App::Dialog::Transaction::Alert', transType => App::Universal::TRANSTYPE_ALERTORG, heading => '$Command Alert',  _arl => ['org_id'], _arl_modify => ['trans_id'] , _idSynonym => 'trans-' . App::Universal::TRANSTYPE_ALERTORG() },
	'alert-person' => {_class => 'App::Dialog::Transaction::Alert', transType => App::Universal::TRANSTYPE_ALERTORG, heading => '$Command Alert',  _arl => ['person_id'], _arl_modify => ['trans_id'] ,
							_idSynonym => [
											'trans-' .App::Universal::TRANSTYPE_ALERTORG(),
											'trans-' .App::Universal::TRANSTYPE_ALERTORGFACILITY(),
											'trans-' .App::Universal::TRANSTYPE_ALERTPATIENT(),
											'trans-' .App::Universal::TRANSTYPE_ALERTINSURANCE(),
											'trans-' .App::Universal::TRANSTYPE_ALERTMEDICATION(),
											'trans-' .App::Universal::ATTRTYPE_STUDENTPART(),
											'trans-' .App::Universal::TRANSTYPE_ALERTACTION()
											]
						},
	'alert-org' => {_class => 'App::Dialog::Transaction::Alert', transType => App::Universal::TRANSTYPE_ALERTORG, heading => '$Command Alert',  _arl => ['org_id'], _arl_modify => ['trans_id'] ,
								_idSynonym => [
											'trans-' .App::Universal::TRANSTYPE_ALERTORG(),
											'trans-' .App::Universal::TRANSTYPE_ALERTORGFACILITY(),
											'trans-' .App::Universal::TRANSTYPE_ALERTPATIENT(),
											'trans-' .App::Universal::TRANSTYPE_ALERTINSURANCE(),
											'trans-' .App::Universal::TRANSTYPE_ALERTMEDICATION(),
											'trans-' .App::Universal::ATTRTYPE_STUDENTPART(),
											'trans-' .App::Universal::TRANSTYPE_ALERTACTION()
											]
						},
	#'alert-facility' => {_class => 'App::Dialog::Transaction::Alert', transType => App::Universal::TRANSTYPE_ALERTORGFACILITY, heading => '$Command Alert',  _arl => ['person_id'], _arl_modify => ['trans_id'] , _idSynonym => 'trans-' . App::Universal::TRANSTYPE_ALERTORGFACILITY() },
	#'alert-patient' => {_class => 'App::Dialog::Transaction::Alert', transType => App::Universal::TRANSTYPE_ALERTPATIENT, heading => '$Command Alert',  _arl => ['person_id'], _arl_modify => ['trans_id'] , _idSynonym => 'trans-' . App::Universal::TRANSTYPE_ALERTPATIENT() },
	#'alert-insurance' => {_class => 'App::Dialog::Transaction::Alert', transType => App::Universal::TRANSTYPE_ALERTINSURANCE, heading => '$Command Alert',  _arl => ['person_id'], _arl_modify => ['trans_id'] , _idSynonym => 'trans-' . App::Universal::TRANSTYPE_ALERTINSURANCE() },
	#'alert-medication' => {_class => 'App::Dialog::Transaction::Alert', transType => App::Universal::TRANSTYPE_ALERTMEDICATION, heading => '$Command Alert',  _arl => ['person_id'], _arl_modify => ['trans_id'] , _idSynonym => 'trans-' . App::Universal::TRANSTYPE_ALERTMEDICATION() },
	#'alert-action' => {_class => 'App::Dialog::Transaction::Alert', transType => App::Universal::TRANSTYPE_ALERTACTION, heading => '$Command Alert',  _arl => ['person_id'], _arl_modify => ['trans_id'] , _idSynonym => 'trans-' . App::Universal::TRANSTYPE_ALERTACTION() },

	'hospitalization' => {_class => 'App::Dialog::Transaction::Hospitalization', transType => [App::Universal::TRANSTYPE_ADMISSION, App::Universal::TRANSTYPE_SURGERY,App::Universal::TRANSTYPE_THERAPY ], heading => '$Command Hospitalization',  _arl => ['person_id'], _arl_modify => ['trans_id'],
							_idSynonym => [
										'trans-' . App::Universal::TRANSTYPE_ADMISSION(),
										'trans-' . App::Universal::TRANSTYPE_SURGERY(),
										'trans-' . App::Universal::TRANSTYPE_THERAPY()
										]
						},
	'tests' => {_class => 'App::Dialog::Transaction::TestsMeasurements', transType => App::Universal::TRANSTYPE_TESTSMEASUREMENTS, heading => '$Command Tests/Measurements',  _arl_add => ['person_id'], _idSynonym => 'trans-' . App::Universal::TRANSTYPE_TESTSMEASUREMENTS() },
	'directive-patient' => {_class => 'App::Dialog::Attribute::Directive::Patient', valueType => App::Universal::DIRECTIVE_PATIENT,  _arl_add => ['person_id'], _arl_remove => ['item_id'], _idSynonym => 'attr-' .App::Universal::DIRECTIVE_PATIENT() },
	'directive-physician' => {_class => 'App::Dialog::Attribute::Directive::Physician', valueType => App::Universal::DIRECTIVE_PHYSICIAN,  _arl_add => ['person_id'], _arl_remove => ['item_id'], _idSynonym => 'attr-' .App::Universal::DIRECTIVE_PHYSICIAN()},
	'address-person' => {_class => 'App::Dialog::Attribute::Address', valueType => App::Universal::ATTRTYPE_FAKE_ADDRESS, tableId => 'Person_Contact_Addrs', heading => '$Command Address', table => 'Person_Address', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-person-' .App::Universal::ATTRTYPE_FAKE_ADDRESS() },
	'address-org' => {_class => 'App::Dialog::Attribute::Address', valueType => App::Universal::ATTRTYPE_FAKE_ADDRESS, tableId => 'Org_Contact_Addrs', heading => '$Command Address', table => 'Org_Address', _arl => ['org_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-org-' .App::Universal::ATTRTYPE_FAKE_ADDRESS() },
	'benefit-insurance' => {_class => 'App::Dialog::Attribute::EmploymentBenefit', valueType => App::Universal::BENEFIT_INSURANCE, heading => '$Command Insurance Benefit', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::BENEFIT_INSURANCE() },
	'benefit-retirement' => {_class => 'App::Dialog::Attribute::EmploymentBenefit', valueType => App::Universal::BENEFIT_RETIREMENT, heading => '$Command Retirement Benefit',  _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::BENEFIT_RETIREMENT() },
	'benefit-other' => {_class => 'App::Dialog::Attribute::EmploymentBenefit', valueType => App::Universal::BENEFIT_OTHER, heading => '$Command Other Benefit', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::BENEFIT_OTHER() },
	'credential' => {_class => 'App::Dialog::Attribute::Credential', valueType => App::Universal::ATTRTYPE_CREDENTIALS, heading => '$Command Credentils', _arl => ['org_id'] , _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_CREDENTIALS()},
	'certificate-accreditation' => {_class => 'App::Dialog::Attribute::Certificate::Accreditation', valueType => App::Universal::ATTRTYPE_ACCREDITATION, heading => '$Command Accreditation', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_ACCREDITATION() },
	'affiliation' => {_class => 'App::Dialog::Attribute::Certificate::Affiliation', valueType => App::Universal::ATTRTYPE_AFFILIATION, heading => '$Command Affiliation', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_AFFILIATION() },
	'certificate-license' => {_class => 'App::Dialog::Attribute::Certificate::License', valueType => App::Universal::ATTRTYPE_LICENSE, heading => '$Command License', _arl => ['person_id'] , _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_LICENSE() },
	'certificate-state' => {_class => 'App::Dialog::Attribute::Certificate::State', valueType => App::Universal::ATTRTYPE_STATE, heading => '$Command State License', _arl => ['person_id'] , _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_STATE() },
	'preventivecare' => {_class => 'App::Dialog::Attribute::PreventiveCare', valueType => App::Universal::PREVENTIVE_CARE, heading => '$Command Measure', _arl => ['person_id'] , _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::PREVENTIVE_CARE() },
	'allergy-medication' => {_class => 'App::Dialog::Attribute::Allergy', valueType => App::Universal::MEDICATION_ALLERGY, group => 'Medication Allergy', heading => '$Command Medication Allergy', _arl => ['person_id'] , _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::MEDICATION_ALLERGY() },
	'allergy-environmental' => {_class => 'App::Dialog::Attribute::Allergy', valueType => App::Universal::ENVIRONMENTAL_ALLERGY, group => 'Environmental Allergy', heading => '$Command Environmental Allergy', _arl => ['person_id'] , _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ENVIRONMENTAL_ALLERGY() },
	'allergy-intolerance' => {_class => 'App::Dialog::Attribute::Allergy', valueType => App::Universal::MEDICATION_INTOLERANCE, group => 'Medication Intolerance', heading => '$Command Medication Intolerance', _arl => ['person_id'] , _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::MEDICATION_INTOLERANCE() },
	'assoc-employment' => {_class => 'App::Dialog::Attribute::Association::Employment',  heading => '$Command Employment', _arl => ['person_id'] , _arl_modify => ['item_id'],
							_idSynonym => [
											'attr-' .App::Universal::ATTRTYPE_EMPLOYEDFULL(),
											'attr-' .App::Universal::ATTRTYPE_EMPLOYEDPART(),
											'attr-' .App::Universal::ATTRTYPE_SELFEMPLOYED(),
											'attr-' .App::Universal::ATTRTYPE_RETIRED(),
											'attr-' .App::Universal::ATTRTYPE_STUDENTFULL(),
											'attr-' .App::Universal::ATTRTYPE_STUDENTPART(),
											'attr-' .App::Universal::ATTRTYPE_EMPLOYUNKNOWN()
										]

							},
	'assoc-provider' => {_class => 'App::Dialog::Attribute::Association::CareProvider', valueType => App::Universal::ATTRTYPE_PROVIDER, heading => '$Command Care Provider', _arl => ['person_id'] , _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_PROVIDER() },
	'assoc-family' => {_class => 'App::Dialog::Attribute::Association::Family', valueType => App::Universal::ATTRTYPE_FAMILY,  heading => '$Command Family Contact', _arl => ['person_id'] , _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_FAMILY() },
	'assoc-emergency' => {_class => 'App::Dialog::Attribute::Association::Emergency', valueType => App::Universal::ATTRTYPE_EMERGENCY,  heading => '$Command Emergency Contact', _arl => ['person_id'] , _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_EMERGENCY() },

	'resource-nurse' => {_class => 'App::Dialog::Attribute::AssociatedResource::Nurse', valueType => App::Universal::ATTRTYPE_RESOURCEPERSON,  heading => '$Command Associated Physician', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_RESOURCEPERSON() },
	'resource-session-physicians' => {_class => 'App::Dialog::Attribute::AssociatedResource::SessionPhysicians', valueType => App::Universal::ATTRTYPE_RESOURCEPERSON,  heading => '$Command Session Set Of Physicians', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_RESOURCEPERSON() },
	'resource-org' => {_class => 'App::Dialog::Attribute::AssociatedResource::Org', valueType => App::Universal::ATTRTYPE_RESOURCEORG,  heading => '$Command Associated Organization', _arl => ['org_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_RESOURCEORG()  },
	'resource-orgemp' => {_class => 'App::Dialog::Attribute::AssociatedResource::OrgEmployee', valueType => App::Universal::ATTRTYPE_RESOURCEOTHER,  heading => '$Command Associated Employee', _arl => ['org_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_RESOURCEOTHER()  },
	'auth-inforelease' => {_class => 'App::Dialog::Attribute::Authorization::InfoRelease', valueType => App::Universal::ATTRTYPE_AUTHINFORELEASE,  heading => '$Command Information Release Indicator', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_AUTHINFORELEASE()  },
	'auth-patientsign' => {_class => 'App::Dialog::Attribute::Authorization::PatientSign', valueType => App::Universal::ATTRTYPE_AUTHPATIENTSIGN,  heading => '$Command Patient Signature Authorization', _arl => ['[person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_AUTHPATIENTSIGN()  },
	'auth-providerassign' => {_class => 'App::Dialog::Attribute::Authorization::ProviderAssign', valueType => App::Universal::ATTRTYPE_AUTHPROVIDERASSIGN,  heading => '$CommandProvider Assignment Indicator', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_AUTHPROVIDERASSIGN()  },
	'attendance' => {_class => 'App::Dialog::Attribute::Attendance', valueType => App::Universal::ATTRTYPE_EMPLOYEEATTENDANCE,  heading => '$Command Attendance', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_EMPLOYEEATTENDANCE()  },
	'employment-empinfo' => {_class => 'App::Dialog::Attribute::Default', entityType => 'person', valueType => App::Universal::ATTRTYPE_EMPLOYMENTRECORD, propNameCaption => 'Property Name', propValueCaption => 'Property Value', heading => '$Command Employment Information', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_EMPLOYMENTRECORD()  },
	'employment-salinfo' => {_class => 'App::Dialog::Attribute::Default', entityType => 'person', valueType => App::Universal::ATTRTYPE_EMPLOYMENTRECORD, propNameCaption => 'Property Name', propValueCaption => 'Property Value', heading => '$Command Salary Information', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_TEXT()  },
	'person-additional' => {_class => 'App::Dialog::Attribute::Default', entityType => 'person', propNameCaption => 'Property Name', valueType => App::Universal::ATTRTYPE_PERSONALGENERAL, attrNameFmt => 'General/Personal', propValueCaption => 'Property Value', heading => '$Command Additional Data', _arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-' . App::Universal::ATTRTYPE_PERSONALGENERAL()  },
	'contact-personphone' => {_class => 'App::Dialog::Attribute::Default', heading => '$Command Telephone',
				propNameCaption => 'Name',
				propNameLookup => 'Person_Contact_Phones',
				propValueCaption => 'Telephone',
				propValueType => 'phone',
				propValueSize => 24,
				prefFlgCaption => 'Preferred phone',
				entityType => 'person',
				#attrNameFmt => 'Contact Method/Telephone',
				valueType => App::Universal::ATTRTYPE_PHONE,
				_arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-Person-' .App::Universal::ATTRTYPE_PHONE() },
	'contact-personfax' => {_class => 'App::Dialog::Attribute::Default', heading => '$Command Fax',
				propNameCaption => 'Name',
				propNameLookup => 'Person_Contact_Phones',
				propValueCaption => 'Fax',
				propValueType => 'phone',
				propValueSize => 24,
				prefFlgCaption => 'Preferred fax',
				entityType => 'person',
				#attrNameFmt => 'Contact Method/Fax',
				valueType => App::Universal::ATTRTYPE_FAX,
				_arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-Person-' .App::Universal::ATTRTYPE_FAX() },
	'contact-personpager' => {_class => 'App::Dialog::Attribute::Default', heading => '$Command Pager',
				propNameCaption => 'Name',
				propNameLookup => 'Person_Contact_Order',
				propValueCaption => 'Pager',
				propValueType => 'pager',
				propValueSize => 24,
				prefFlgCaption => 'Preferred pager',
				entityType => 'person',
				#attrNameFmt => 'Contact Method/Pager',
				valueType => App::Universal::ATTRTYPE_PAGER,
				_arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-Person-' .App::Universal::ATTRTYPE_PAGER() },
	'contact-personemail' => {_class => 'App::Dialog::Attribute::Default', heading => '$Command E-mail',
				propNameCaption => 'Name',
				propNameLookup => 'Person_Contact_Order',
				propValueCaption => 'E-mail',
				propValueType => 'email',
				propValueSize => 24,
				prefFlgCaption => 'Preferred email',
				entityType => 'person',
				#attrNameFmt => 'Contact Method/EMail',
				valueType => App::Universal::ATTRTYPE_EMAIL,
				_arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-Person-' .App::Universal::ATTRTYPE_EMAIL() },

	'contact-personinternet' => {_class => 'App::Dialog::Attribute::Default', heading => '$Command URL',
				propNameCaption => 'Name',
				propNameLookup => 'Person_Contact_Order',
				propValueCaption => 'URL',
				propValueType => 'url',
				propValueSize => 24,
				prefFlgCaption => 'Preferred internet address',
				entityType => 'person',
				#attrNameFmt => 'Contact Method/Internet',
				valueType => App::Universal::ATTRTYPE_URL,
				_arl => ['person_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-Person-' .App::Universal::ATTRTYPE_URL() },

	'contact-orgphone' => {_class => 'App::Dialog::Attribute::Default', heading => '$Command Telephone',
				propNameCaption => 'Name',
				propNameLookup => 'Org_Contact_Name',
				propValueCaption => 'Telephone',
				propValueType => 'phone',
				propValueSize => 24,
				prefFlgCaption => 'Preferred phone',
				entityType => 'org',
				#attrNameFmt => 'Contact Method/Telephone',
				valueType => App::Universal::ATTRTYPE_PHONE,
				_arl => ['org_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-Org-' .App::Universal::ATTRTYPE_PHONE() },
	'contact-orgfax' => {_class => 'App::Dialog::Attribute::Default', heading => '$Command Fax',
				propNameCaption => 'Name',
				propNameLookup => 'Org_Contact_Name',
				propValueCaption => 'Fax',
				propValueType => 'phone',
				propValueSize => 24,
				prefFlgCaption => 'Preferred fax',
				entityType => 'org',
				#attrNameFmt => 'Contact Method/Fax',
				valueType => App::Universal::ATTRTYPE_FAX,
				_arl => ['org_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-Org-' .App::Universal::ATTRTYPE_FAX() },
	'contact-orgemail' => {_class => 'App::Dialog::Attribute::Default', heading => '$Command E-mail',
				propNameCaption => 'Name',
				propNameLookup => 'Org_Contact_Name',
				propValueCaption => 'E-mail',
				propValueType => 'email',
				propValueSize => 24,
				prefFlgCaption => 'Preferred email',
				entityType => 'org',
				#attrNameFmt => 'Contact Method/EMail',
				valueType => App::Universal::ATTRTYPE_EMAIL,
				_arl => ['org_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-Org-' .App::Universal::ATTRTYPE_EMAIL() },
	'contact-orginternet' => {_class => 'App::Dialog::Attribute::Default', heading => '$Command URL',
				propNameCaption => 'Name',
				propNameLookup => 'Org_Contact_Name',
				propValueCaption => 'URL',
				propValueType => 'url',
				propValueSize => 24,
				prefFlgCaption => 'Preferred internet address',
				entityType => 'org',
				#attrNameFmt => 'Contact Method/Internet',
				valueType => App::Universal::ATTRTYPE_URL,
				_arl => ['org_id'], _arl_modify => ['item_id'], _idSynonym => 'attr-Org-' .App::Universal::ATTRTYPE_URL() },

	'nurse' => {_class => 'App::Dialog::Person::Nurse', heading => '$Command Nurse', _arl => ['person_id'], _arl_modify => ['person_id'], _idSynonym => 'Nurse' },
	'patient' => {_class => 'App::Dialog::Person::Patient',heading => '$Command Patient/Person', _arl => ['person_id'], _arl_modify => ['person_id'], _idSynonym => 'Patient'},
	'responsibleparty' => {_class => 'App::Dialog::ResponsibleParty',heading => '$Command Responsible Party', _arl => ['party_name'], _arl_modify => ['party_name'], _idSynonym => 'ResponsibleParty'},
	'physician' => {_class => 'App::Dialog::Person::Physician', heading => '$Command Physician/Provider', _arl => ['person_id'], _arl_modify => ['person_id'], _idSynonym => 'Physician' },
	'staff' => {_class => 'App::Dialog::Person::Staff', heading => '$Command Staff Member', _arl => ['person_id'], },
	'org-main' => {_class => 'App::Dialog::Organization',
				heading => '$Command Main Organization',
				orgtype => 'main',
				_arl => ['org_id'], },
	'org-dept' => {_class => 'App::Dialog::Organization',
				heading => '$Command Department Organization',
				orgtype => 'dept',
				_arl => ['org_id'], },
	'org-provider' => {_class => 'App::Dialog::Organization',
				heading => '$Command Associated Provider Organization',
				orgtype => 'provider',
				_arl => ['org_id'], },
	'org-employer' => {_class => 'App::Dialog::Organization',
				heading => '$Command Employer Organization',
				orgtype => 'employer',
				_arl => ['org_id'], },
	'org-insurance' => {_class => 'App::Dialog::Organization',
				heading => '$Command Insurance Organization',
				orgtype => 'insurance',
				_arl => ['org_id'], },
	'org-ipa' => {_class => 'App::Dialog::Organization',
				heading => '$Command IPA Organization',
				orgtype => 'ipa',
				_arl => ['org_id'], },
	'dept' => {_class => 'App::Dialog::Organization::Department', _arl => ['dept_id'], },
	'appointment' => {
		_class => 'App::Dialog::Appointment',
		_arl_add => ['person_id'],
		_arl_modify => ['event_id'],
		_arl_cancel => ['event_id'],
		_arl_noshow => ['event_id'],
		_arl_reschedule => ['event_id'],
	},
	'catalog' => {_class => 'App::Dialog::Catalog', _arl_add => ['parent_catalog_id'], _arl_modify => ['catalog_id'] },
	'catalog-item' => {_class => 'App::Dialog::CatalogItem', _arl_add => ['catalog_id', 'parent_entry_id'], _arl_modify => ['entry_id'] },
	'catalog-copy' => {_class => 'App::Dialog::Catalog::Copy', _arl_add => ['parent_catalog_id'] },
	'customize' => 'App::Dialog::Customize',
	'diagnoses' => 'App::Dialog::Diagnoses',
	'checkin' => {_class => 'App::Dialog::Encounter::Checkin', _arl => ['event_id'] },
	'claim' => {_class => 'App::Dialog::Encounter::CreateClaim', _arl_add => ['person_id'], _arl_modify => ['invoice_id'] },
	'claim-hold' => {_class => 'App::Dialog::OnHold', _arl_add => ['invoice_id'] },
	'claim-problem' => 'App::Dialog::ClaimProblem',
	'checkout' => {_class => 'App::Dialog::Encounter::Checkout', _arl => ['event_id'] },
	'ins-product' => {_class => 'App::Dialog::InsurancePlan::Product',
				heading => '$Command Insurance Product',
				_arl_add => ['product_name'],
				_arl_modify => ['ins_internal_id'],
				 _idSynonym => 'ins-' . 'product' },
	'ins-plan' => {_class => 'App::Dialog::InsurancePlan::Plan',
				heading => '$Command Insurance Plan',
				productName => ['product_name'],
				_arl_add => ['plan_name'],
				_arl_modify => ['ins_internal_id'],
			    _idSynonym => 'ins-' . 'plan' },
	'ins-coverage' => {_class => 'App::Dialog::InsurancePlan::PersonalCoverage',
					heading => '$Command Personal Insurance Coverage',
					_arl_add => ['plan_name'],
					_arl_modify => ['ins_internal_id'],
			    _idSynonym => 'ins-' . App::Universal::RECORDTYPE_PERSONALCOVERAGE },
	'ins-newplan' => {_class => 'App::Dialog::InsurancePlan::NewPlan',
				heading => '$Command Insurance Plan',
				_arl_add => ['ins_id'],
				_arl_modify => ['ins_internal_id'],
				_idSynonym => 'ins-' . App::Universal::RECORDTYPE_INSURANCEPLAN },
	'ins-exists' => {_class => 'App::Dialog::InsurancePlan::PersonExistsPlan',
				_arl_add => ['ins_id'],
				_arl_modify => ['ins_internal_id'],
				_idSynonym => 'ins-' . App::Universal::RECORDTYPE_PERSONALCOVERAGE },
	'ins-unique' => {_class => 'App::Dialog::InsurancePlan::PersonUniquePlan',
				_arl_add => ['ins_id'],
				_arl_modify => ['ins_internal_id'],
				_idSynonym => 'ins-' . App::Universal::RECORDTYPE_PERSONALCOVERAGE },
	'ins-workerscomp' => {_class => 'App::Dialog::WorkersComp',
				heading => '$Command Workers Compensation Plan'	,
				_arl_add => ['ins_id'],
				_arl_modify => ['ins_internal_id'],
				_idSynonym => 'ins-' . App::Universal::RECORDTYPE_INSURANCEPLAN },
	'org-attachinsurance' => {_class => 'App::Dialog::Attribute::AttachInsurance',
				_arl_add => ['ins_id'],
				_arl_modify => ['item_id'],
				id => 'attachinsplan',
				heading => '$Command Insurance Plan',
				valueType => App::Universal::ATTRTYPE_INSGRPINSPLAN,
				_idSynonym => 'attr-' . App::Universal::ATTRTYPE_INSGRPINSPLAN },
	'org-attachworkerscomp' => {_class => 'App::Dialog::Attribute::AttachInsurance',
					_arl_add => ['ins_id'],
					_arl_modify => ['item_id'],
					id => 'attachworkerscomp',
					heading => '$Command Workers Compensation Plan',
					valueType => App::Universal::ATTRTYPE_INSGRPWORKCOMP,
					_idSynonym => 'attr-' . App::Universal::ATTRTYPE_INSGRPWORKCOMP },
	'person-attachworkerscomp' => {_class => 'App::Dialog::AttachWorkersComp',
					_arl_add => ['ins_id'],
					_arl_modify => ['ins_internal_id'],
					_idSynonym => 'ins-' . App::Universal::RECORDTYPE_PERSONALCOVERAGE },
	'health-rule' => {_class => 'App::Dialog::HealthMaintenance', heading => '$Command Health Maintenance Rule', _arl => ['rule_id']},
	'misc-notes' => {_class => 'App::Dialog::Attribute::MiscNotes', valueType => App::Universal::ATTRTYPE_TEXT, heading => '$Command Misc Notes', _arl => ['person_id'] , _arl_modify => ['item_id'], _idSynonym => 'attr-' .App::Universal::ATTRTYPE_TEXT() },

	'procedure' => 'App::Dialog::Procedure',
	'adjustment' => 'App::Dialog::Adjustment',
	#'slot' => 'App::Dialog::Slot',
	'template' => {_class => 'App::Dialog::Template', _arl_modify => ['template_id'],},
	'userproblem' => 'App::Dialog::UserProblems',
	'appttype' => {_class=>'App::Dialog::ApptType', _arl=>['appt_type_id'],},
	'assign' => {_class=>'App::Dialog::Assign'},
	'training' => 'App::Dialog::Training',

);

# see if we want to create some id synonyms for any of our dialogs
#
my %CREATE_DLG_SYNONYMS = ();
while(my ($dlgId, $dlgInfo) = each %DIALOG_CLASSES)
{
	if(ref($dlgInfo) eq 'HASH')
	{
		if(my $idSynonym = $dlgInfo->{_idSynonym})
		{
			if(ref $idSynonym eq 'ARRAY') {
				foreach (@$idSynonym) { $CREATE_DLG_SYNONYMS{$_} = $dlgInfo; }
			}
			else {
				$CREATE_DLG_SYNONYMS{$idSynonym} = $dlgInfo;
			}
		}
	}
}

# since we couldn't modify the DIALOG_CLASSES hash inside the "each"
# we need to do the assignments now
#
while(my ($dlgId, $dlgInfo) = each %CREATE_DLG_SYNONYMS)
{
	$DIALOG_CLASSES{$dlgId} = $dlgInfo;
}

#
# st-* are the default statement components
# stp-* are the statement panel components
# stpe-* are the statement panelEdit components
#

%COMPONENT_CATALOG = (
	_autoCreate => [
		{ type => 'stmtMgr', stmtMgr => $STMTMGR_COMPONENT_PERSON },
		{ type => 'stmtMgr', stmtMgr => $STMTMGR_COMPONENT_ORG },
	],
);

foreach (@{$COMPONENT_CATALOG{_autoCreate}})
{
	if(my $stmtMgr = $_->{stmtMgr})
	{
		my $compId = undef;
		while(my($key, $value) = each %$stmtMgr)
		{
			# the "dpc" keys are the "data publish component callback" functions
			next unless $key =~ m/^_dpc_(\w+?)\_(.*)$/;

			$compId = "$1-$2";
			die "Statement '$key' creates a duplicate component ID" if exists $COMPONENT_CATALOG{$compId};
			$COMPONENT_CATALOG{$compId} = $value;
		}
	}
}

while(my($key, $value) = each %CGI::Component::DIRECTORY)
{
	die "Duplicate component ID '$key'" if exists $COMPONENT_CATALOG{$key};
	$COMPONENT_CATALOG{$key} = $value;
}

##############################################################################
# Utility functions
##############################################################################

sub handlePage
{
	my ($pageClass, $flags, $arl, $params, $resource, $pathItems) = @_;
	if(ref $pageClass eq 'HASH')
	{
		my $subPageClasses = $pageClass;
		if(my $subPage = $pathItems->[0])
		{
			return 'ARL-000200' unless $pageClass = $subPageClasses->{$subPage};
		}
		else
		{
			return 'ARL-000210' unless $pageClass = $subPageClasses->{'_default'};
		}
	}

	my $page = new $pageClass;

	#
	# some pages will need their own ARLs for calling themselves as popups, so set it up now
	#
	my $arlAsPopup = $arl;
	$arlAsPopup =~ s/^$resource/$resource\-\p/;

	$page->param('arl', $arl);
	$page->param('arl_asPopup', $arlAsPopup);
	$page->param('arl_resource', $resource);
	$page->param('arl_pathItems', @$pathItems) if $pathItems;
	$page->setFlag($flags);
	$page->parse_params($params);
	$page->property('PAGE_CLASSES', \%PAGE_CLASSES);
	#$page->addContent('<HR>COMPONENT_CATALOG<HR>', join('<BR>', sort keys %COMPONENT_CATALOG));
	return $page->handleARL($arl, $params, $resource, $pathItems);
}

%PAGE_FLAGS =
(
	'f'  => PAGEFLAG_ISFRAMESET,
	'fh' => PAGEFLAG_ISFRAMEHEAD,
	'fb' => PAGEFLAG_ISFRAMEBODY,
	'p'  => PAGEFLAG_ISPOPUP,
	'a'  => PAGEFLAG_ISADVANCED,
);

sub handleARL
{
	my ($arl) = @_;

	my($resPath, $params) = split(/\?/, $arl);
	my $errorCode = 'ARL-000100'; # invalid ARL
	my $flags = 0;

	#
	# if a resource name ends in -p it is assumed to be a popup window
	#

	my ($resource, $path) = ($resPath, '');
	($resource, $path) = ($1, $2) if $resPath =~ m/^(.*?)\/(.*)/;

	if($resource =~ s/\-(.+)$//)
	{
		$flags |= $PAGE_FLAGS{$1};

		# translate the ARL so that the resource doesn't have -p or -a or -xxx
		$arl =~ s/^$resource\-$1/$resource/;
	}
	if(my $class = $PAGE_CLASSES{$resource})
	{
		my @pathItems = split(/\//, $path);
		$errorCode = handlePage($class, $flags, $arl, $params, $resource, \@pathItems);
	}
	if($errorCode)
	{
		my $page = new App::Page::Error;
		$page->param('errorcode', $errorCode);
		$page->printContents();
	}
}

##############################################################################
# Change-log management functions/declarations
##############################################################################

use constant DIRECTORY_SEARCH => 'Directory/Search';
use constant DIRECTORY_DIALOGCLASSES => 'Directory/classes';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/05/1999', 'RK',
		DIRECTORY_SEARCH,
		'Added Catalogitem in $SEARCH_CLASSES. '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/28/1999', 'RK',
		DIRECTORY_DIALOGCLASSES,
		'Added assoc-family in %DIALOG_CLASSES. And updated the dialog names ( ie, dialog path from App::Dialog::Encounter for claim to App::Dialog:: Encounter::Createcalim and so on) for  claim, checkin, checkout in %DIALOG_CLASSES.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/07/1999', 'RK',
		DIRECTORY_SEARCH,
		'Updated the _class names in %DIALOG_CLASSES for the association related dialogs like employment, caraprovider etc.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/07/1999', 'RK',
		DIRECTORY_SEARCH,
		'Added differnt types of alerts in %DIALOG_CLASSES according to the trans_type.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '03/24/2000', 'TVN',
		DIRECTORY_SEARCH,
		'Added Appointment Type in $SEARCH_CLASSES. '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '04/01/2000', 'TVN',
		DIRECTORY_SEARCH,
		'Added ResourceSelector, WorkList components and WorkList page. '],
);

1;
