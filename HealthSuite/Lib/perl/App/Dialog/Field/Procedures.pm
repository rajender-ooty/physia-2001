##############################################################################
package App::Dialog::Field::Procedures;
##############################################################################

use strict;
use Carp;
use CGI::Validator;
use CGI::Validator::Field;
use CGI::Dialog;
use DBI::StatementManager;

use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Catalog;
use App::Statements::Insurance;
use App::Universal;

use Date::Manip;
use Date::Calc qw(:all);

use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	$params{name} = 'procedures_list' unless exists $params{name};
	$params{type} = 'procedures';
	$params{lineCount} = 4 unless exists $params{count};
	$params{allowComments} = 1 unless exists $params{allowComments};
	$params{allowQuickRef} = 0 unless exists $params{allowQuickRef};

	return CGI::Dialog::Field::new($type, %params);
}

sub needsValidation
{
	return 1;
}

sub isValid
{
	my ($self, $page, $validator, $valFlags) = @_;

	my $sessUser = $page->session('user_id');
	my $sessOrg = $page->session('org_id');

	my $personId = $page->field('attendee_id');
	my $personInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $personId);
	my $gender = '';
	$gender = 'M' if $personInfo->{gender_caption} eq 'Male';
	$gender = 'F' if $personInfo->{gender_caption} eq 'Female';
	my $dateOfBirth = $personInfo->{date_of_birth};

	my $servicedatebegin = '';
	my $servicedateend = '';
	#my $serviceplace = '';
	my $servicetype = '';
	my $procedure = '';
	my $modifier = '';
	my $diags = '';
	my $units = '';
	my $charges = '';
	my $emergency = '';
	my %diagsSeen = ();
	my @feeSchedules = split(/\s*,\s*/, $page->param('_f_proc_default_catalog'));
	my @diagCodes = split(/\s*,\s*/, $page->field('proc_diags'));


	# GET FEE SCHEDULES FOR PRIMARY INSURANCE IF IT WAS SELECTED ----------------------------
	my $payer = $page->field('payer');
	my @singlePayer = split('\(', $payer);
	if($singlePayer[0] eq 'Primary')
	{
		my $primIns = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInsuranceByBillSequence', App::Universal::INSURANCE_PRIMARY, $personId);
		my $getFeeSchedsForInsur = $STMTMGR_INSURANCE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInsuranceAttr', $primIns->{parent_ins_id}, 'Fee Schedule');
		my @primaryInsFeeScheds = ();
		foreach my $fs (@{$getFeeSchedsForInsur})
		{
			push(@primaryInsFeeScheds, $fs->{value_text});
			#$page->addDebugStmt($fs->{value_text});
		}
		$page->param('_f_proc_insurance_catalogs', @primaryInsFeeScheds);
	}

	my @insFeeSchedules = split(/\s*,\s*/, $page->param('_f_proc_insurance_catalogs'));

	# ------------------------------------------------------------------------------------------------------------------------




	#munir's old icd validation for checking if the same icd code is entered in twice
	foreach (@diagCodes)
	{
		$diagsSeen{$_} = 1;
	}

	my $totalCodesEntered = @diagCodes;
	my $listTotal = keys %diagsSeen;

	if($totalCodesEntered != $listTotal)
	{
		$self->invalidate($page, 'Cannot enter the same ICD code more than once.');
	}


	my @errors = ();
	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		$servicedatebegin = $page->param("_f_proc_$line\_dos_begin");
		$servicedateend = $page->param("_f_proc_$line\_dos_end");
		#$serviceplace = $page->param("_f_proc_$line\_service_place");
		$servicetype = $page->param("_f_proc_$line\_service_type");
		$procedure = $page->param("_f_proc_$line\_procedure");
		$modifier = $page->param("_f_proc_$line\_modifier");
		$diags = $page->param("_f_proc_$line\_diags");
		$units = $page->param("_f_proc_$line\_units");
		$charges = $page->param("_f_proc_$line\_charges");
		$emergency = $page->param("_f_proc_$line\_emg");

		#$page->addDebugStmt("Detail dates: $servicedatebegin, $servicedateend, $servicetype, $procedure, emg is $emergency, charges are $charges");

		next if $servicedatebegin eq 'From' && $servicedateend eq 'To';
		next if $servicedatebegin eq '' && $servicedateend eq '';

		if($servicedatebegin !~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/)
		{
			$self->invalidate($page, "[<B>P$line</B>] Invalid Service Begin Date: $servicedatebegin");
		}
		if($servicedateend !~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/)
		{
			$self->invalidate($page, "[<B>P$line</B>] Invalid Service End Date: $servicedateend ");
		}
		#comparing the begin and end date to see if the begin date is less than the end date
		if ($servicedatebegin =~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/ && $servicedateend =~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/)
		{
			my $serviceBeginDate = ParseDate($servicedatebegin);
			my $serviceEndDate = ParseDate($servicedateend);
			my $flag = Date_Cmp($serviceBeginDate,$serviceEndDate);

			if($flag > 0)
			{
				# date2 is earlier
				$self->invalidate($page, "[<B>P$line</B>] Service begin date $servicedatebegin should be earlier than the end date $servicedateend");
			}
		}
		#if($serviceplace =~ m/^(\d+)$/)
		#{
		#	# $1 is the check to see if it is an integer
		#	if(not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericServicePlaceId', $1)))
		#	{
		#		$self->invalidate($page, "[<B>P$line</B>] The service place code $serviceplace is not valid. Please verify");
		#	}
		#}
		#elsif($serviceplace !~ m/^(\d+)$/)
		#{
		#	$self->invalidate($page, "[<B>P$line</B>] The service place code $serviceplace should be an integer. Please verify");
		#}
		if($servicetype =~ m/^(\d+)$/)
		{
			# $1 is the check to see if it is an integer
			if(not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericServiceTypeId', $1)))
			{
				$self->invalidate($page, "[<B>P$line</B>] The service type code $servicetype is not valid. Please verify");
			}
		}
		elsif($servicetype !~ m/^(\d+)$/ && $servicetype ne '')
		{
			$self->invalidate($page, "[<B>P$line</B>] The service type code $servicetype should be an integer. Please verify");
		}
		if($procedure =~ m/^(\d+)$/)
		{
			# $1 is the check to see if it is an integer
			if(not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericCPTCode', $1)))
			{
				#$self->invalidate($page, "[<B>P$line</B>] The CPT code $procedure is not valid. Please verify");
			}
		}
		#elsif($procedure !~ m/^(\d+)$/)
		#{
		#	$self->invalidate($page, "[<B>P$line</B>] The CPT code was not found.");
		#}

		if($modifier ne '')
		{
			if($modifier =~ m/^(\d+)$/)
		 	{
				# $1 is the check to see if it is an integer
				$self->invalidate($page, "[<B>P$line</B>] The modifier code $modifier is not valid. Please verify") unless $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericModifierCodeId', $1);
			}
		 	else
		 	{
				$self->invalidate($page, "[<B>P$line</B>] The modifier code $modifier should be an integer. Please verify");
		 	}
		}

		my @actualDiagCodes = ();
		if($diags ne '')
		{
			my @diagNumbers = split(/\s*,\s*/, $diags);
			foreach my $diagNumber (@diagNumbers)
			{
				if($diagNumber !~ /^(\d+)$/)
				{
					$self->invalidate($page, "[<B>P$line</B>] The diagnosis $diagNumber should be integer. Please verify");
				}
				elsif(($diagNumber > $totalCodesEntered) || ($diagNumber == 0))
				{
					$self->invalidate($page, "[<B>P$line</B>] The diagnosis $diagNumber is not valid. Please verify");
				}

				push(@actualDiagCodes, $diagCodes[$diagNumber-1]);
			}

			@actualDiagCodes = join(', ', @actualDiagCodes);
			$page->param("_f_proc_$line\_actual_diags", @actualDiagCodes);
		}
		elsif($diags eq '')
		{
			$self->invalidate($page, "[<B>P$line</B>] The diagnosis relationships are not valid. Please verify");
		}

		if($units !~ /^(\d+\.?\d*|\.\d+)$/)
		{
			$self->invalidate($page, "[<B>P$line</B>] The dollar amount $units is not valid. Please verify");
		}
		if($charges ne '' && $charges !~ /^(\d+\.?\d*|\.\d+)$/)
		{
			$self->invalidate($page, "[<B>P$line</B>] The dollar amount $charges is not valid. Please verify");
		}

		## INTELLICODE VALIDATION
		my @procs = ();
		push(@procs, [$procedure, $modifier || undef, @actualDiagCodes]);
		my @cptCodes = ($procedure);

		App::IntelliCode::incrementUsage($page, 'Cpt', \@cptCodes, $sessUser, $sessOrg);
		App::IntelliCode::incrementUsage($page, 'Icd', \@diagCodes, $sessUser, $sessOrg);
		#App::IntelliCode::incrementUsage($page, 'Hcpcs', \@cptCodes, $sessUser, $sessOrg);

		if( $charges eq '' && ($feeSchedules[0] ne '' || $insFeeSchedules[0] ne '') )
		{
			my @allFeeSchedules = @feeSchedules ? @feeSchedules : @insFeeSchedules;
			
			my $fsResults = App::IntelliCode::getItemCost($page, $procedure, $modifier || undef, \@allFeeSchedules);
			my $resultCount = scalar(@$fsResults);
			if($resultCount == 0)
			{
				$self->invalidate($page, "[<B>P$line</B>] No unit cost was found for code '$procedure' and modifier '$modifier'");
			}
			elsif($resultCount == 1)
			{
				foreach (@$fsResults)
				{
					my $fs = $_->[0];
					my $entry = $_->[1];
					my $unitCost = $entry->{unit_cost};
					$page->param("_f_proc_$line\_charges", $unitCost);
				}
			}
		}
		elsif($charges eq '' && ($feeSchedules[0] eq '' && $insFeeSchedules[0] eq '') )
		{
			$self->invalidate($page, "[<B>P$line</B>] 'Charge' is a required field. Cannot leave blank.");
		}

		@errors = App::IntelliCode::validateCodes
		(
			$page, App::IntelliCode::INTELLICODEFLAG_SKIPWARNING,
			sex => $gender,
			dateOfBirth => $dateOfBirth,
			diags => \@diagCodes,
			procs => \@procs,
		);

		foreach (@errors)
		{
			$self->invalidate($page, "[<B>P$line</B>] $_");
		}
	}

	return @errors || $page->haveValidationErrors() ? 0 : 1;
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;

	my $bgColorAttr = '';
	my $spacerHtml = '&nbsp;';
	my $textFontAttrs = 'SIZE=1 FACE="Tahoma,Arial,Helvetica" STYLE="font-family:tahoma; font-size:8pt"';
	my $cptOrgHtml = '';
	my $icdOrgHtml = '';
	my $cptPerHtml = '';
	my $icdPerHtml = '';

	my $placeHtml = '';
	my $serviceTypeHtml = '';

	#get service place code from service facility org
	my $svcFacility = $page->field('service_facility_id') || $page->session('org_id');
	my $svcPlaceCode = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $svcFacility, 'HCFA Service Place');
	my $cptOrgCodes = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selTop15CPTsByORG', $page->session('org_id'));
	my $icdOrgCodes = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selTop15ICDsByORG', $page->session('org_id'));
	my $cptPerCodes = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selTop15CPTsByPerson', $page->session('person_id'));
	my $icdPerCodes = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selTop15ICDsByPerson', $page->session('person_id'));
	my $servicePlaceIds = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAllServicePlaceId');
	my $serviceTypeIds = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAllServiceTypeId');

	foreach my $cptOrgCode (@{$cptOrgCodes})
		{
			$cptOrgHtml = $cptOrgHtml . qq{ <OPTION>$cptOrgCode->{parent_id}</OPTION> };
		}
	foreach my $icdOrgCode (@{$icdOrgCodes})
		{
			$icdOrgHtml = $icdOrgHtml . qq{ <OPTION>$icdOrgCode->{parent_id}</OPTION> };
		}
	foreach my $cptPerCode (@{$cptPerCodes})
		{
			$cptPerHtml = $cptPerHtml . qq{ <OPTION>$cptPerCode->{parent_id}</OPTION> };
		}
	foreach my $icdPerCode (@{$icdPerCodes})
		{
			$icdPerHtml = $icdPerHtml . qq{ <OPTION>$icdPerCode->{parent_id}</OPTION> };
		}
	foreach my $placeId (@{$servicePlaceIds})
		{
			$placeHtml = $placeHtml . qq{ <OPTION>$placeId->{id}</OPTION> };
		}
	foreach my $serviceTypeId (@{$serviceTypeIds})
		{
			$serviceTypeHtml = $serviceTypeHtml . qq{ <OPTION>$serviceTypeId->{id}</OPTION> };
		}



	my @lineMsgs = ();
	if(my @messages = $page->validationMessages($self->{name}))
	{
		foreach (@messages)
		{
			if(m/\[\<B\>P(\d+)\<\/B\>\]/)
			{
				push(@{$lineMsgs[$1]}, $_);
			}
			else
			{
				push(@{$lineMsgs[0]}, $_);
			}
		}
	}

	my $readOnly = '';
	my $invoiceFlags = '';
	my $attrDataFlag = '';
	if(my $invoiceId = $page->param('invoice_id'))
	{
		$invoiceFlags = $page->field('invoice_flags');
		$attrDataFlag = App::Universal::INVOICEFLAG_DATASTOREATTR;

		$readOnly = $invoiceFlags & $attrDataFlag ? 'READONLY' : '';
	}


	my ($dialogName, $lineCount, $allowComments, $allowQuickRef, $allowRemove) = ($dialog->formName(), $self->{lineCount}, $self->{allowComments}, $self->{allowQuickRef}, $dlgFlags & CGI::Dialog::DLGFLAG_UPDATE);
	my ($linesHtml, $numCellRowSpan, $removeChkbox) = ('', $allowComments ? 'ROWSPAN=2' : '', '');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		$removeChkbox = $allowRemove && ! $invoiceFlags & $attrDataFlag ? qq{<TD ALIGN=CENTER $numCellRowSpan><INPUT TYPE="CHECKBOX" NAME='_f_proc_$line\_remove'></TD>} : '';
		my $errorMsgsHtml = '';
		if(ref $lineMsgs[$line] eq 'ARRAY' && @{$lineMsgs[$line]})
		{
			$errorMsgsHtml = "<font $dialog->{bodyFontErrorAttrs}>" . join("<br>", @{$lineMsgs[$line]}) . "</font>";
			$numCellRowSpan = $allowComments ? 'ROWSPAN=3' : 'ROWSPAN=2';
		}
		else
		{
			$numCellRowSpan = $allowComments ? 'ROWSPAN=2' : '';
		}

		my $emg = $page->param("_f_proc_$line\_emg");
		my $emgHtml = '';
		if($invoiceFlags & $attrDataFlag)
		{
			$emgHtml = $emg eq 'on' ? "<INPUT CLASS='procinput' NAME='_f_proc_$line\_emg' VALUE='on' TYPE='CHECKBOX' CHECKED><FONT $textFontAttrs/>Emergency</FONT>" : '';		
		}
		else
		{
			my $checked = $emg eq 'on' ? 'CHECKED' : '';
			$emgHtml = "<INPUT CLASS='procinput' NAME='_f_proc_$line\_emg' TYPE='CHECKBOX' VALUE='on' $checked><FONT $textFontAttrs/>Emergency</FONT>";
		}

		$linesHtml .= qq{
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_item_id" VALUE='@{[ $page->param("_f_proc_$line\_item_id")]}'/>
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_actual_diags" VALUE='@{[ $page->param("_f_proc_$line\_actual_diags")]}'/>
			<TR VALIGN=TOP>
				<SCRIPT>
					function onChange_dosBegin_$line(event, flags)
					{
						if(event.srcElement.value == 'From')
							event.srcElement.value = '0';
						event.srcElement.value = validateDate(event.srcElement.name, event.srcElement.value);
						if(document.$dialogName._f_proc_$line\_dos_end.value == '' || document.$dialogName._f_proc_$line\_dos_end.value == 'To')
							document.$dialogName._f_proc_$line\_dos_end.value = event.srcElement.value;
						if(event.srcElement.value != '')
						{
							if(document.$dialogName._f_proc_$line\_service_type.value == '')
								document.$dialogName._f_proc_$line\_service_type.value = '01';
							if(document.$dialogName._f_proc_$line\_units.value == '')
								document.$dialogName._f_proc_$line\_units.value = 1;
						}
					}
					function onChange_procedure_$line(event, flags)
					{
						if(document.$dialogName._f_proc_$line\_modifier.value == 'Modf')
							document.$dialogName._f_proc_$line\_modifier.value = '';
					}
				</SCRIPT>
				<TD ALIGN=RIGHT $numCellRowSpan><FONT $textFontAttrs COLOR="#333333"/><B>$line</B></FONT></TD>
				$removeChkbox
				<TD><INPUT CLASS='procinput' NAME='_f_proc_$line\_dos_begin' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_dos_begin") || ($line == 1 ? 'From' : '')]}' ONBLUR="onChange_dosBegin_$line(event)"><BR>
					<INPUT CLASS='procinput' NAME='_f_proc_$line\_dos_end' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_dos_end") || ($line == 1 ? 'To' : '') ]}' ONBLUR="validateChange_Date(event)"></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><NOBR><INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_service_type' TYPE='text' VALUE='@{[ $page->param("_f_proc_$line\_service_type") ]}' size=2>
					<A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_$line\_service_type, '/lookup/servicetype', '');"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><NOBR><INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_procedure' TYPE='text' size=8 VALUE='@{[ $page->param("_f_proc_$line\_procedure") || ($line == 1 ? 'Procedure' : '') ]}' ONBLUR="onChange_procedure_$line(event)">
					<A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_$line\_procedure, '/lookup/cpt', '', false);"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR><BR>
					<INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_modifier' TYPE='text' size=4 VALUE='@{[ $page->param("_f_proc_$line\_modifier") || ($line == 1 && $command eq 'add' ? '' : '') ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT CLASS='procinput' NAME='_f_proc_$line\_diags' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_diags")]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_units' TYPE='text' size=3 VALUE='@{[ $page->param("_f_proc_$line\_units") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_charges' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_charges") ]}'></TD>
				<TD><nobr>$emgHtml</nobr></TD>
			</TR>
		};
		$linesHtml .= qq{
			<TR>
				<TD COLSPAN=4 ALIGN=RIGHT><FONT $textFontAttrs><I>Comments:</I></FONT></TD>
				<TD COLSPAN=8><INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_comments' TYPE='text' size=50 VALUE='@{[ $page->param("_f_proc_$line\_comments") ]}'></TD>
			</TR>
		} if $allowComments;

		$linesHtml .= qq{
			<TR>
				<TD COLSPAN=12>$errorMsgsHtml</TD>
			</TR>
		} if $errorMsgsHtml;
	}

	my $lineZeroErrMsgs = '';
	if(ref $lineMsgs[0] eq 'ARRAY' && @{$lineMsgs[0]})
	{
		$lineZeroErrMsgs = "<font $dialog->{bodyFontErrorAttrs}>" . join("<br>", @{$lineMsgs[0]}) . "</font>";
	}

	my $nonLinesHtml = qq{
		<TR>
			<TD COLSPAN=5>$lineZeroErrMsgs</TD>
		</TR>
	} if $lineZeroErrMsgs;

	my $quickRefHtml = qq{
			<TD>
				<TABLE CELLSPACING=0 CELLPADDING=2 BORDER=1>
					<TR VALIGN=TOP>
						<TD BGCOLOR=#DDDDDD><FONT $textFontAttrs>My ICDs</FONT><BR>
						<NOBR><SELECT SIZE=5 NAME="_f_myproc_diags_static" >@{[ $icdPerHtml ]} </SELECT></NOBR></TD>
						<TD BGCOLOR=#DDDDDD><FONT $textFontAttrs>Our ICDs</FONT><BR>
						<NOBR><SELECT SIZE=5 NAME="_f_ourproc_diags_static" >@{[ $icdOrgHtml ]} </SELECT></NOBR></TD>
					</TR>
					<TR VALIGN=TOP>
						<TD BGCOLOR=#DDDDDD><FONT $textFontAttrs>My CPTs</FONT><BR>
						<NOBR><SELECT SIZE=5 NAME="_f_myproc_cpts_static" >@{[ $cptPerHtml ]} </SELECT></NOBR></TD>
						<TD BGCOLOR=#DDDDDD><FONT $textFontAttrs>Our CPTs</FONT><BR>
						<NOBR><SELECT SIZE=5 NAME="_f_ourproc_cpts_static" >@{[ $cptOrgHtml ]} </SELECT></NOBR></TD>
					</TR>
					<TR VALIGN=TOP>
						<TD BGCOLOR=#DDDDDD COLSPAN=2><FONT $textFontAttrs>Service Places/Types</FONT><BR>
						<NOBR><SELECT SIZE=5 NAME="_f_places_static" >@{[ $placeHtml ]} </SELECT></NOBR>
						<NOBR><SELECT SIZE=5 NAME="_f_types_static" >@{[ $serviceTypeHtml ]} </SELECT></NOBR>
						</TD>
					</TR>
				</TABLE>
			</TD>
	} if $allowQuickRef;

	my $removeHd = $allowRemove && ! $invoiceFlags & $attrDataFlag ? qq{<TD ALIGN=CENTER><FONT $textFontAttrs><IMG SRC="/resources/icons/action-edit-remove-x.gif"></FONT></TD>} : '';
	return qq{
		<TR valign=top $bgColorAttr>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
			<TD COLSPAN=2>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<INPUT TYPE="HIDDEN" NAME="_f_proc_insurance_catalogs" VALUE='@{[ $page->param("_f_proc_insurance_catalogs") ]}'/>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD><FONT $textFontAttrs>Diagnoses (ICD-9s)</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><FONT $textFontAttrs>Service Place</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><FONT $textFontAttrs>Default Fee Schedule(s)</FONT></TD>
					</TR>
					<TR VALIGN=TOP>
						<TD><NOBR><INPUT TYPE="TEXT" SIZE=20 NAME="_f_proc_diags"  VALUE='@{[ $page->param("_f_proc_diags") ]}'>
							<A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_diags, '/lookup/icd', ',', false);"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><NOBR><INPUT $readOnly TYPE="TEXT" SIZE=20 NAME="_f_proc_service_place"  VALUE='@{[ $page->param("_f_proc_service_place") || $svcPlaceCode->{value_text} ]}'> 
							<A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_service_place, '/lookup/serviceplace', ',');"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><INPUT $readOnly TYPE="TEXT" SIZE=20 NAME="_f_proc_default_catalog"  VALUE='@{[ $page->param("_f_proc_default_catalog") ]}'>
							<A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_default_catalog, '/lookup/catalog', ',', false);"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR></TD>
					</TR>
					$nonLinesHtml
				</TABLE>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<INPUT TYPE="HIDDEN" NAME="_f_line_count" VALUE="$lineCount"/>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>&nbsp;</FONT></TD>
						$removeHd
						<TD ALIGN=CENTER><FONT $textFontAttrs>Dates</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Svc Type</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>CPT/Modf</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Diagnoses</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Units</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Charge</FONT></TD>
					</TR>
					$linesHtml
				</TABLE>
			</TD>
			$quickRefHtml
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
		</TR>
	};
}

1;
