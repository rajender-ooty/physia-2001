##############################################################################
package App::Dialog::Report::Org::General::Scheduling::PatientActivity;
##############################################################################

use strict;
use Carp;
use App::Dialog::Report;
use App::Universal;

use CGI::Dialog;
use CGI::Validator::Field;

use DBI::StatementManager;
use App::Statements::Report::Scheduling;
use App::Statements::Search::Appointment;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::Report);

sub new
{
	my $self = App::Dialog::Report::new(@_, id => 'patientActivity', heading => 'Patient Activity');

	$self->addContent(

		new CGI::Dialog::Field::Duration(name => 'report',
			caption => 'Report Dates',
			options => FLDFLAG_REQUIRED
		),

		new App::Dialog::Field::Person::ID(name => 'resource_id',
			caption => 'Resource ID',
			types => ['Physician'],
			options => FLDFLAG_REQUIRED
		),

		new App::Dialog::Field::Organization::ID(name => 'facility_id',
			caption => 'Facility ID',
			types => ['Facility'],
			options => FLDFLAG_REQUIRED
		),

	);

	$self->addFooter(new CGI::Dialog::Buttons);
	$self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	my $startDate = $page->getDate();
	$page->field('report_begin_date', $startDate);
	$page->field('report_end_date', $startDate);
	$page->field('resource_id', $page->session('user_id'));
	$page->field('facility_id', $page->session('org_id'));
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $resource_id = $page->field('resource_id');
	my $facility_id = $page->field('facility_id');
	my $startDate   = $page->field('report_begin_date');
	my $endDate     = $page->field('report_end_date');

	my $html = qq{
	<table cellpadding=10>
		<tr align=center valign=top>
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Appointments</b>
			@{[$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_appointments_byStatus',
				[$resource_id, $facility_id, $startDate, $endDate]) ]}
		</td>
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Patients Seen By Physician</b>
			@{[ $STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_patientsSeen',
				[$resource_id, $facility_id, $startDate, $endDate]) ]}
		</td>
		<td>
			<b style="font-size:8pt; font-family:Tahoma">Patients Seen By Patient Type</b>
			@{[ $STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_patientsSeen_byPatientType',
				[$resource_id, $facility_id, $startDate, $endDate]) ]}
		</td>
		</tr>
	</table>
	};

	return $html;
}

sub getDrillDownHandlers
{
	return ('prepare_detail_$detail$');
}

sub prepare_detail_physician
{
	my ($self, $page) = @_;
	my $facility_id = $page->param('_f_facility_id');
	my $startDate   = $page->param('_f_report_begin_date');
	my $endDate     = $page->param('_f_report_end_date');
	my $physician   = $page->param('physician');

	$page->addContent("<b>Patients Seen by $physician</b><br><br>",
		$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 
			'sel_detailPatientsSeenByPhysician', [$physician, $facility_id, $startDate, $endDate])
	);
}

sub prepare_detail_appointments
{
	my ($self, $page) = @_;
	my $facility_id  = $page->param('_f_facility_id');
	my $startDate    = $page->param('_f_report_begin_date') . ' 12:00 AM';
	my $endDate      = $page->param('_f_report_end_date')   . ' 11:59 PM';
	my $event_status = $page->param('event_status');
	my $caption      = $page->param('caption');

	$page->addContent("<b>'$caption' Appointments</b><br><br>",
		$STMTMGR_APPOINTMENT_SEARCH->createHtml($page, STMTMGRFLAG_NONE, 'sel_appointment',
			[$facility_id, $startDate, $endDate, '%', $event_status, 
			$event_status, $page->session('org_id')],
		),
	);
}

sub prepare_detail_patient_type
{
	my ($self, $page) = @_;
	my $facility_id = $page->param('_f_facility_id');
	my $startDate   = $page->param('_f_report_begin_date');
	my $endDate     = $page->param('_f_report_end_date');
	my $patient_type_id  = $page->param('patient_type_id');
	my $patient_type_caption = $page->param('patient_type_caption');

	$page->addContent(
		$STMTMGR_REPORT_SCHEDULING->createHtml($page, STMTMGRFLAG_NONE, 'sel_detailPatientsSeenByPatientType',
			[$facility_id, $startDate, $endDate, $patient_type_id])
	);
}


# create a new instance which will automatically add it to the directory of
# reports
#
$INSTANCE = new __PACKAGE__;
