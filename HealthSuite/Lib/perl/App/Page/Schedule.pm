##############################################################################
package App::Page::Schedule;
##############################################################################

use strict;
use Date::Manip;
use Date::Calc qw(:all);

use App::Page;
use App::Schedule::Analyze;
use App::Schedule::ApptSheet;
use App::Schedule::Utilities;
use App::ImageManager;
use Devel::ChangeLog;

use DBI::StatementManager;
use App::Statements::Scheduling;
use App::Statements::Search::Appointment;

use vars qw(@ISA @CHANGELOG);
@ISA = qw(App::Page);

# ------------------------------------------------------------------------------------------

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	$self->param('_pm_view', $pathItems->[0] || 'apptsheet');
	$self->param('_dialogreturnurl', '/schedule');

	# see if the ARL points to showing a dialog, panel, or some other standard action
	unless($self->arlHasStdAction($rsrc, $pathItems, 0))
	{
		if (my $handleMethod = $self->can("handleARL_" . $self->param('_pm_view'))) {
			&{$handleMethod}($self, $arl, $params, $rsrc, $pathItems);
		}
	}

	$self->printContents();

	# return 0 for success (or error code for failure)
	return 0;
}

sub handleARL_apptsheet
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	# in the ARL, the date will come in as mm-dd-yyyy we need it like mm/dd/yyyy
	$pathItems->[1] =~ s/\-/\//g if defined $pathItems->[1];
	if(my $firstPathItem = $pathItems->[1])
	{
		if($firstPathItem eq 'customize') {
			$self->param('dialog', "customize");
			$self->param('dialogcommand', $pathItems->[2]);

			if ($pathItems->[2] =~ /update/i) {
				my ($column, $resource_id, $date, $facility_id) = split(/,/, $pathItems->[3]);
				$self->param('column', $column);
				$self->param('resource_id', $resource_id);
				$self->param('facility_id', $facility_id);
				$self->param('selDate', $date);
				$self->param('dialogcommand', 'update');
			}

		}	elsif ($firstPathItem =~ /encounter/i) {
			$self->param('dialog', $pathItems->[1]);
			$self->param('event_id', $pathItems->[2]);

		}	elsif ($firstPathItem =~ /savepref/i) {
			$self->param('savePref', 1);
			my ($preferIndex, $date) = split(/,/, $pathItems->[2]);
			$self->param('preferIndex', $preferIndex);
			$date =~ s/\-/\//g;
			$self->param('_seldate', $date);

		}	elsif ($firstPathItem =~ /view/i) {
			my ($view, $date, $resource_id, $facility_id) = split(/,/, $pathItems->[2]);
			$self->param('view', $view);
			$date =~ s/\-/\//g;
			$self->param('_seldate', $date);
			$self->param('resource_id', $resource_id);
			$self->param('facility_id', $facility_id);
			$self->param('saveViewPref', 1);

		}	else {
			$self->param('_seldate', $pathItems->[1]);
		}
	}
}

sub handleARL_apptcol
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	my ($resource_id, $facility_id, $date) = split(/,/, $pathItems->[1]);

	$date =~ s/\-/\//g;
	$self->param('resource_id', $resource_id);
	$self->param('facility_id', $facility_id);
	$self->param('date', $date);
}

sub handleARL_appointment
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->param('dialog', $pathItems->[0]);
	$self->param('dialogcommand', $pathItems->[1]);

	if ($pathItems->[1] =~ /add/i) {
		my ($resource_id, $start_stamp, $duration) = split(/,/, $pathItems->[2]);
		$start_stamp =~ s/\-/\//g;
		$start_stamp =~ s/_/ /g;
		$self->param('resource_id', $resource_id);
		$self->param('start_stamp', $start_stamp);
		$self->param('duration', $duration);
	} else {
		$self->param('event_id', $pathItems->[2]);
	}
}

sub handleARL_template
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	if ($pathItems->[1]) {
		$self->param('dialog', $pathItems->[0]);
		$self->param('dialogcommand', $pathItems->[1]);
		if ($pathItems->[1] =~ /update/i) {
			$self->param('template_id', $pathItems->[2]);
		}	elsif ($pathItems->[1] =~ /add/i) {
			my ($resource_id, $template_id) = split(/,/, $pathItems->[2]);
			$self->param('resource_id', $resource_id);
			$self->param('template_id', $template_id);
		}
	}
}

sub handleARL_assign
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->param('dialog', $pathItems->[0]);
	$self->param('fromDate', $pathItems->[1]);
	$self->param('toDate', $pathItems->[2]);
}

sub handleARL_handleWaitingList
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->param('curEventId', $pathItems->[1]);
}

# ------------------------------------------------------------------------------------------
sub getContentHandlers
{
	return ('prepare_view_$_pm_view=apptsheet$');
}

sub prepare_view_dialogs
{
	my $self = shift;

	if (my $dialog = $self->param('dialog'))
	{
		if(my $method = $self->can("prepare_dialog_$dialog"))
		{
			return &{$method}($self);
		}
		else
		{
			$self->addError("Can't find prepare_dialog_$dialog method");
		}
		return 1;
	}
}

sub prepare_view_appointment
{
	my $self = shift;
	$self->prepare_view_dialogs();
}

sub prepare_view_template
{
	my $self = shift;
	$self->prepare_view_dialogs();
}

sub prepare_view_assign
{
	my $self = shift;
	$self->prepare_view_dialogs();
}

sub prepare_view_handleWaitingList
{
	my $self = shift;

	my $eventId = $self->param('curEventId');

	$self->addContent(
		'<CENTER>',
		$STMTMGR_APPOINTMENT_SEARCH->createHtml($self, STMTMGRFLAG_NONE, 'sel_conflict_appointments',
			[$eventId],
		),
		'</CENTER>'
	);
}

sub prepare_view_apptcol
{
	my ($self) = @_;

	my $date = ParseDate($self->param('date')) || "today";
	my $formattedDate = UnixDate ($date, '%m/%d/%Y');
	$self->param('dialog', 'fake');

	my @column = ($formattedDate, $self->param('resource_id'), $self->param('facility_id'));

	my @inputSpec = ();
	push (@inputSpec, \@column);

	my $apptSheet = new App::Schedule::ApptSheet(
		inputSpec => \@inputSpec
	);

	my ($apptSheetStartTime, $apptSheetEndTime) = $self->getApptSheetTimes();

	my $content = qq{
		<TABLE cellpadding=5>
			<TR valign=top>
				<TD>
					<TABLE BGCOLOR='#DDDDDD' BORDER=0 CELLSPACING=1 CELLPADDING=0>
						<TR>
							<TD>@{[$apptSheet->getHtml($self, $apptSheetStartTime, $apptSheetEndTime, APPTSHEET_HEADER|APPTSHEET_BODY|APPTSHEET_BOOKCOUNT)]}</TD>
						</TR>
					</TABLE>
				</TD>
			</TR>
		</TABLE>
	};

	$self->addContent($content);

	return 1;
}

sub getApptSheetTimes
{
	my ($self) = @_;
	
	my $apptsheetTimes = $STMTMGR_SCHEDULING->getRowAsHash($self, STMTMGRFLAG_NONE,
		'selApptSheetTimes', $self->session('user_id'));
	
	my ($apptSheetStartTime, $apptSheetEndTime);

	if(defined $apptsheetTimes->{start_time})
	{
		$apptSheetStartTime = $apptsheetTimes->{start_time};
		$apptSheetEndTime   = $apptsheetTimes->{end_time};
	}
	else
	{
		$apptSheetStartTime = 6;
		$apptSheetEndTime   = 21;
	}	
	
	return ($apptSheetStartTime, $apptSheetEndTime);
}

sub prepare_view_apptsheet
{
	my ($self) = @_;

	if (my $dialog = $self->param('dialog'))
	{
		if(my $method = $self->can("prepare_dialog_$dialog"))
		{
			return &{$method}($self);
		}
		else
		{
			$self->addError("Can't find prepare_dialog_$dialog method");
		}
		return 1;
	}

	my $selectedDate = ParseDate($self->param('_seldate')) || "today";
	my $formattedDate = UnixDate ($selectedDate, '%m/%d/%Y');

	my @inputSpec = ();

	my $preference = $self->readPreferences('Preference/Schedule/CurrentView');
	my $currentView = $preference->{resource_id} || 'Day'; # value_text is aliased as 'resource_id'
	$self->param('view', $currentView);

	if ($currentView =~ /week/i)
	{
		my $preference = $self->readPreferences('Preference/Schedule/WeekView');
		my $resource_id = $preference->{resource_id};
		my $facility_id = $preference->{facility_id};
		my @startDate = Decode_Date_US($formattedDate);
		my $weekDays = 7;

		for my $i (0..$weekDays-1) {
			my @date = Add_Delta_Days(@startDate, $i);
			my @columnSpec = (sprintf("%02d/%02d/%04d", $date[1],$date[2],$date[0]), $resource_id, $facility_id);
			push (@inputSpec, \@columnSpec);
		}
	}
	else # Day View
	{
		my $preferences = $self->readPreferences('Preference/Schedule/DayView/Column', 1);
		$preferences = $self->createDayViewPreferences() if (@$preferences < 1);

		if (@{$preferences}) {
			for my $pref (@{$preferences})
			{
				my @baseDate = Decode_Date_US($formattedDate);
				my @columnDate = Add_Delta_Days (@baseDate, $pref->{offset});
				my $date = sprintf("%02d/%02d/%04d", $columnDate[1],$columnDate[2],$columnDate[0]);

				my @column = ($date, $pref->{resource_id}, $pref->{facility_id});
				push (@inputSpec, \@column);
			}
		}
	}

	my $apptSheet = new App::Schedule::ApptSheet(
		inputSpec => \@inputSpec
	);
	
	my ($apptSheetStartTime, $apptSheetEndTime) = $self->getApptSheetTimes();
	
	my $flags = APPTSHEET_ALL;
	my $addColumn_legend;
	
	if ($self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP))
	{
		$flags &= ~APPTSHEET_TEMPLATE;
		$flags &= ~APPTSHEET_CUSTOMIZE;
	}
	else
	{
		$addColumn_legend = qq{
			<TD>
				<img src='/resources/icons/arrow_right_red.gif'>
				<a href="javascript: location = '/schedule/apptsheet/customize/add';" style='font-size:8pt; font-family: Tahoma'>
				<b><nobr>Add Column</nobr></b></a>
				<br>
				@{[$apptSheet->getLegendHtml($self)]}
			</TD>
		};
	}

	my $content = qq{
		<TABLE cellpadding=5>
			<TR valign=top>
				<TD>
					<TABLE BGCOLOR='#DDDDDD' BORDER=0 CELLSPACING=1 CELLPADDING=0>
						<TR>
							<TD>@{[$apptSheet->getHtml($self, $apptSheetStartTime, $apptSheetEndTime, $flags)]}</TD>
						</TR>
					</TABLE>
				</TD>
				
				$addColumn_legend
			</TR>

		</TABLE>
	};

	$self->addContent($content);

	# important
	return 1;
}

sub prepare_dialog_customize
{
	my ($self) = @_;

	use App::Dialog::Customize;
	my $dialog = new App::Dialog::Customize(schema => $self->getSchema());
	$dialog->handle_page($self, $self->param('dialogcommand'));
	return 1;
}

sub prepare_dialog_appointment
{
	my ($self) = @_;

	use App::Dialog::Appointment;
	my $dialog = new App::Dialog::Appointment(schema => $self->getSchema());
	$dialog->handle_page($self, $self->param('dialogcommand'));
	return 1;
}

sub prepare_dialog_template
{
	my ($self) = @_;

	use App::Dialog::Template;
	my $dialog = new App::Dialog::Template(schema => $self->getSchema());
	$dialog->handle_page($self, $self->param('dialogcommand'));
	return 1;
}

sub prepare_dialog_assign
{
	my ($self) = @_;

	use App::Dialog::Assign;
	my $dialog = new App::Dialog::Assign(schema => $self->getSchema());
	$dialog->handle_page($self);
	return 1;
}

sub prepare_dialog_encounterCheckin
{
	my ($self) = @_;

	#my $content = qq{
	#	<script>
	#		alert("YO");
	#		history.back();
	#	</script>
	#};

	#$self->addContent($content);
	#return 1;

	use App::Dialog::Encounter;
	my $dialog = new App::Dialog::Encounter::Checkin(schema => $self->getSchema());
	$dialog->handle_page($self);
	return 1;
}

sub prepare_dialog_encounterCheckout
{
	my ($self) = @_;

	use App::Dialog::Encounter;
	my $dialog = new App::Dialog::Encounter::Checkout(schema => $self->getSchema());
	$dialog->handle_page($self);
	return 1;
}

sub prepare_page_content_footer
{
	my $self = shift;
	#return 1 if $self->param('_ispopup');
	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	push(@{$self->{page_content_footer}}, '<P>', App::Page::Search::getSearchBar($self, 'apptslot'));
	$self->SUPER::prepare_page_content_footer(@_);
	return 1;
}

sub prepare_page_content_header
{
	my $self = shift;

	return 1 if $self->flagIsSet(App::Page::PAGEFLAG_ISPOPUP);

	$self->SUPER::prepare_page_content_header(@_);
	#push(@{$self->{page_content_header}}, new App::Pane::Schedule::Heading()->as_html($self));

	my $today = UnixDate('today', '%m-%d-%Y');
	my $nextweek = UnixDate('nextweek', '%m-%d-%Y');

	my $heading = ($self->param('_pm_view') =~ /template/) ? 'Schedule' : 'Appointments';

	my $urlPrefix = "/schedule";
	my $functions = $self->getMenu_Simple(App::Page::MENUFLAG_SELECTEDISLARGER,
		'_pm_view',
		[
			['Schedule', "$urlPrefix/apptsheet", 'apptsheet'],
			#['CheckIn', "/search/appointment/,,2,$today,$today,0/1", 'checkin'],
			#['CheckOut', "/search/appointment/,,3,,$today,1/1", 'checkout'],
			#['Confirm', "/search/appointment/,,0,$today,$nextweek,0/1", 'confirm'],
			['Assign', "$urlPrefix/assign/$today/$today", 'assign'],
		], ' | ');

	push(@{$self->{page_content_header}},
	qq{
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE BORDER=0 CELLPADDING=0 CELLSPACING=1>
		<TR><TD>
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TD>
				<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
					$IMAGETAGS{'icon-m/schedule'} <B>$heading</B>
				</FONT>
			</TD>
			<TD ALIGN=RIGHT>
				<FONT FACE="Arial,Helvetica" SIZE=2>
				$functions
				</FONT>
			</TD>
		</TABLE>
		</TD></TR>
		</TABLE>
	}, @{[ $self->param('dialog') ? '<p>' : '' ]});

	#$html .= '<p>' if $page->param('dialog');

	if ($self->param('_pm_view') =~ /apptsheet/ && ! $self->param('dialog')) {
		my $apptSheetHeader = $self->getApptSheetHeaderHtml();
		push(@{$self->{page_content_header}}, $apptSheetHeader);
	}

	return 1;
}

sub getApptSheetHeaderHtml
{
	my ($self) = @_;

	my $selectedDate = $self->param('_seldate') || 'today';
	$selectedDate = 'today' unless ParseDate($selectedDate);
	my $fmtDate = UnixDate($selectedDate, '%m/%d/%Y');

	my $optionIndex = $self->getPreferIndex('Preference/Schedule/Action');

	my $javascripts = $self->getJavascripts();
	my $chooseDateOptsHtml = $self->getChooseDateOptsHtml($fmtDate);

	my @actionOptions = (
		{arl => '/person/%itemValue%/profile', caption => 'View Summary'},
		{arl => '/person/%itemValue%/account', caption => 'View Account'},
		{arl => '/person/%itemValue%/dlg-add-claim', caption => 'Create Claim'},
		{arl => '/schedule/apptsheet/encounterCheckin/%itemValue%', caption => 'Check In'},
		{arl => '/schedule/apptsheet/encounterCheckout/%itemValue%', caption => 'Check Out'},
		{arl => '/schedule/appointment/cancel/%itemValue%', caption => 'Cancel'},
		{arl => '/schedule/appointment/noshow/%itemValue%', caption => 'No Show'},
		{arl => '/schedule/appointment/reschedule/%itemValue%', caption => 'Reschedule'},
		{arl => '/schedule/appointment/update/%itemValue%', caption => 'Edit Appointment'},
	);

	my $actionOptionsHtml = '';
	for (@actionOptions) {
		$actionOptionsHtml .= qq{
			<option value="$_->{arl}">$_->{caption}</option>
		};
	}

	my $nextDay = UnixDate(DateCalc($selectedDate, "+1 day"), '%m-%d-%Y');
	my $prevDay = UnixDate(DateCalc($selectedDate, "-1 day"), '%m-%d-%Y');
	my $nDay = $nextDay; $nDay =~ s/\-/\//g;
	my $pDay = $prevDay; $pDay =~ s/\-/\//g;

	return qq{
	<TABLE bgcolor='#EEEEEE' cellpadding=3 cellspacing=0 border=0 width=100%>
		$javascripts
		<STYLE>
			select { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
			input  { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
		</STYLE>

		<tr>
			<FORM name='dateForm' method=POST onsubmit="updatePage(document.dateForm.selDate.value); return false;">
			<td ALIGN=LEFT>
					<SELECT onChange="document.dateForm.selDate.value = this.options[this.selectedIndex].value;
						updatePage(document.dateForm.selDate.value); return false;">
						$chooseDateOptsHtml
					</SELECT>
					<A HREF="javascript: showCalendar(document.dateForm.selDate);">
						<img src='/resources/icons/calendar2.gif' title='Show calendar' BORDER=0></A>

					&nbsp
					<input name=left  type=button value='<' onClick="updatePage('$prevDay')" title="Goto $pDay">
					<INPUT size=13 name="selDate" type="text" value="$fmtDate">
					<input name=right type=button value='>' onClick="updatePage('$nextDay')" title="Goto $nDay">
			</td>
			</FORM>
			
			<!--- 
			<TD align=center>
				<img src='/resources/icons/arrow_right_red.gif'>
				<a href="javascript:doActionPopup('/schedule-p/apptsheet', null, 'toolbar,scrollbars,resizable');" style='font-size:8pt; font-family: Tahoma'>
				<b><nobr>Print</nobr></b></a>
			</TD>
			--->
			
			<FORM name="actionForm" method=POST>
			<td ALIGN=RIGHT>
				<input type="hidden" name="patient_id">
				<input type="hidden" name="appt_id">

			<font size=2 face="Arial">
			On Select:
			</font>
				<SELECT name="item_action_arl_select" onChange="savePref(selectedIndex)">
					$actionOptionsHtml
				</SELECT>
				<script>
					setSelectedValue(actionForm.item_action_arl_select, '@{[$actionOptions[$optionIndex]->{arl}]}');
				</script>

				<SELECT name="item_action_arl_dest_select">
					<option>In this window</option>
					<option>In new window</option>
				</SELECT>
			</td>
			</FORM>

		</tr>
	</TABLE>
	<br>
	};
}

sub getChooseDateOptsHtml
{
	my ($self, $date) = @_;

	# Choose Date drop down list
	my @quickChooseItems =
		(
			{ caption => 'Choose Day', value => '' },
			{ caption => 'Today', value => 'today' },
			{ caption => 'Previous Day', value => DateCalc($date, '- 1 business days') },
			{ caption => 'Previous Week', value => DateCalc($date, '- 7 days') },
			{ caption => 'Previous Month', value => DateCalc($date, '- 1 month') },
			{ caption => 'Previous Year', value => DateCalc($date, '- 1 year') },
			{ caption => 'Next Day', value => DateCalc($date, '+ 1 business days') },
			{ caption => 'Next Week', value => DateCalc($date, '+ 7 days') },
			{ caption => 'Next Month', value => DateCalc($date, '+ 1 month') },
			{ caption => 'Next Year', value => DateCalc($date, '+ 1 year') },
			{ caption => 'Tomorrow', value => DateCalc('today', '+ 1 business days') },
			{ caption => 'Day after Tomorrow', value => DateCalc('today', '+ 2 business days') },
			{ caption => '1 Week from Today', value => DateCalc('today', '+ 1 week') },
		);
	for(my $week = 2; $week <= 12; $week++)	{
		push(@quickChooseItems, { caption => "$week Weeks from Today", value => DateCalc('today', "+ $week weeks") });
	}

	my $quickChooseDateOptsHtml = '';
	foreach (@quickChooseItems)
	{
		my $formatDate = UnixDate($_->{value}, '%m/%d/%Y');
		$quickChooseDateOptsHtml .=  qq{
			<option value="$formatDate">$_->{caption}</option>
		};
	}
	return $quickChooseDateOptsHtml;
}

sub getPreferIndex
{
	my ($self, $optionName) = @_;

	my $userID = $self->session('user_id');
	my $preferIndex = $self->param('preferIndex') || 0;
	my $command = 'update';
	my $item_id;

	if (! $self->param('preferIndex') || $self->param('savePref'))
	{
		my $preferenceHash = $STMTMGR_SCHEDULING->getRowAsHash($self, STMTMGRFLAG_NONE,
			'selActionOption', $userID, $optionName);

		if (defined $preferenceHash) {
			$item_id = $preferenceHash->{item_id} ;
			$preferIndex = $preferenceHash->{value_int} unless $self->param('savePref');

		}	else {
			$command = 'add';
		}
	}

	if ($self->param('savePref'))
	{
		my $newItemID = $self->schemaAction(
			'Person_Attribute', $command,
			item_id => $command eq 'add' ? undef : $item_id,
			value_int   => $preferIndex,
			parent_id   => $userID,
			item_name   => $optionName
		);

		$self->param('savePref', 0);
	}

	return $preferIndex;
}

sub readPreferences
{
	my ($self, $itemName, $multiple) = @_;

	my $preference;
	my $userID = $self->session('user_id');

	if ($multiple) {
		$preference = $STMTMGR_SCHEDULING->getRowsAsHashList($self, STMTMGRFLAG_NONE,
			'selSchedulePreferences', $userID, $itemName);
	} else {
		$preference = $STMTMGR_SCHEDULING->getRowAsHash($self, STMTMGRFLAG_NONE,
			'selSchedulePreferences', $userID, $itemName);
	}

	return $preference;
}

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);

	if ($self->param('saveViewPref')) {
		my $view = $self->param('view');
		my $resource_id = $self->param('resource_id');
		my $facility_id = $self->param('facility_id');

		$self->saveViewPreference($view, $resource_id, $facility_id);
	}

	$self->addLocatorLinks(
			['Schedule', '', undef, App::Page::MENUITEMFLAG_FORCESELECTED],
		);
}

sub saveViewPreference
{
	my ($self, $view, $resource_id, $facility_id) = @_;

	my $userID = $self->session('user_id');
	my $itemName = 'Preference/Schedule/CurrentView';
	my $currentView = $self->readPreferences($itemName, 0);
	my $command = (defined $currentView) ? 'update' : 'add';
	my $itemID = $currentView->{item_id};

	my $newItemID = $self->schemaAction(
		'Person_Attribute', $command,
		item_id    => $command eq 'add' ? undef : $itemID,
		parent_id  => $userID,
		item_name  => $itemName,
		value_text => $view
	);

	if ($view =~ /week/i)
	{
		$itemName = 'Preference/Schedule/WeekView';
		my $weekViewPref = $self->readPreferences($itemName);
		$command = (defined $weekViewPref) ? 'update' : 'add';
		$itemID = $weekViewPref->{item_id};

		$newItemID = $self->schemaAction(
			'Person_Attribute', $command,
			item_id     => $command eq 'add' ? undef : $itemID,
			parent_id   => $userID,
			item_name   => $itemName,
			value_text  => $resource_id,
			value_textB => $facility_id
		);
	}
}

sub createDayViewPreferences
{
	my ($self) = @_;

	my $userID = $self->session('user_id');
	my $orgID  = $self->session('org_id');
	my $itemName = 'Preference/Schedule/DayView/Column';

	my $assocResources = $STMTMGR_SCHEDULING->getRowsAsHashList($self, STMTMGRFLAG_NONE,
		'selAssociatedResources', $userID);

	my $col = 0;
	for (@$assocResources)
	{
		my $newItemID = $self->schemaAction(
			'Person_Attribute', 'add',
			item_id     => undef,
			parent_id   => $userID,
			item_name   => $itemName,
			value_text  => $_->{resource_id},
			value_int   => $col++,
			value_textB => $_->{facility_id} || $orgID
		);
	}

	return $self->readPreferences($itemName, 1);
}

sub getJavascripts
{
	my ($self) = @_;

	return qq{

		<SCRIPT SRC='/lib/calendar.js'></SCRIPT>

		<SCRIPT>
			function updatePage(selectedDate)
			{
				var dashDate = selectedDate.replace(/\\//g, "-");
				location.href = '/schedule/apptsheet/' + dashDate;
			}

			function savePref(preferIndex)
			{
				var selectedDate = dateForm.selDate.value;
				var dashDate = selectedDate.replace(/\\//g, "-");
				location.href = '/schedule/apptsheet/savePref/'+ preferIndex + ',' + dashDate;
			}

			function performAction(patient_id, event_id)
			{
				curSelection = actionForm.item_action_arl_select.selectedIndex;

				if (curSelection < 3) {
					chooseEntry(patient_id, document.actionForm.item_action_arl_select, document.actionForm.item_action_arl_dest_select);
				} else {
					chooseEntry(event_id, document.actionForm.item_action_arl_select, document.actionForm.item_action_arl_dest_select);
				}
			}

		</SCRIPT>
	};
}

#
# change log is an array whose contents are arrays of
# 0: one or more CHANGELOGFLAG_* values
# 1: the date the change/update was made
# 2: the person making the changes (usually initials)
# 3: the category in which change should be shown (user-defined) - can have '/' for hiearchies
# 4: any text notes about the actual change/action
#
# ALL OF THE CHANGELOGFLAG_* values are specified in Devel::ChangeLog
#
@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/25/2000', 'TVN',
		'Page/Schedule',
		'Added /schedule/apptcol to pop up a single column of the appointment sheet.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/16/2000', 'TVN',
		'Page/Schedule',
		'Developed sub to auto-create preferences of associated Resources in no preferences found.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/16/1999', 'TVN',
			'Page/Schedule',
		'Developed sub initialize to incorporate new security features.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/11/1999', 'TVN',
		'Schedule/Analyze',
		'Completed modifications for finding slots for multiple resources.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/11/1999', 'TVN',
		'Schedule/Analyze',
		'Finished Finding available slots for Facility, not knowing resources.  The resulting available slots are times when ALL resources who have templates at that facility are available at that facility at the same time. No attempt is made to handle inconsistent data, like having templates defining availability at 2 different facilities at the same time, or having appointments in the "red zone" (the unavailable times) or the no-template-info times, etc...  But appointments are properly taken into account when computing available slots. '],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '12/13/1999', 'TVN',
		'Schedule/Analyze2',
		'Begin developing Analyze version 2, capable of more robust slot search.'],
);


1;
