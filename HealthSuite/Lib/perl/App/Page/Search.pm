##############################################################################
package App::Page::Search;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use Exporter;
use App::ImageManager;

use enum qw(BITMASK:SEARCHFLAG_ LOOKUPWINDOW SEARCHBAR);

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter App::Page);
@EXPORT = qw(SEARCHFLAG_LOOKUPWINDOW SEARCHFLAG_SEARCHBAR);

sub prepare_page_content_header
{
	my $self = shift;
	my $flags = 0;
	$flags |= SEARCHFLAG_LOOKUPWINDOW if $self->param('_islookup');
	my ($heading, $searchForm) = $self->getForm($flags);
	if(($flags & SEARCHFLAG_LOOKUPWINDOW) && $searchForm)
	{
		push(@{$self->{page_content_header}}, qq{
		<STYLE>
			body { margin: 0; }
			select { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
			input { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
		</STYLE>
		<TABLE BGCOLOR=LIGHTSTEELBLUE BORDER=0 CELLSPACING=1 CELLPADDING=5 WIDTH=100%>
			<TR>
			<FORM NAME="search_form" METHOD=POST>
			<TD>
			<CENTER><B><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=NAVY>$heading</FONT></B></CENTER>
			<FONT FACE='Verdana,Arial,Helvetica' SIZE=2>
			$searchForm
			</FONT>
			</TD>
			</FORM>
			</TR>
		</TABLE>
		});
		return 1;
	}

	$self->SUPER::prepare_page_content_header(@_);
	my ($colors, $fonts) = ($self->getThemeColors(), $self->getThemeFontTags());
	my $urlPrefix = "/search";
	my $functions = $self->getMenu_ComboBox(App::Page::MENUFLAG_SELECTEDISLARGER,
		'_pm_view',
		[
			['Lookup...'],
			['People', "$urlPrefix/person", 'person'],
			['Claims', "$urlPrefix/claim", 'claim'],
			['Appointments', "$urlPrefix/appointment", 'appointment'],
			['Appointment Types', "$urlPrefix/appttype", 'appttype'],
			['Available Slots', "$urlPrefix/apptslot", 'apptslot'],
			['Organizations', "$urlPrefix/org", 'org'],
			['Insurance Plans', "$urlPrefix/insurance", 'insurance'],
			['Fee Schedules', "$urlPrefix/catalog", 'catalog'],
			['ICD', "$urlPrefix/icd", 'icd'],
			['CPT', "$urlPrefix/cpt", 'cpt'],
			['HCPCS', "$urlPrefix/cpt", 'hcpcs'],
			['Service Type', "$urlPrefix/servicetype", 'servicetype'],
			['Schedule Template', "$urlPrefix/template", 'template'],
			['User Sessions', "$urlPrefix/session", 'session'],
		]);

	my $formHtml = $searchForm ? qq{
		<TABLE BGCOLOR='#EEEEEE' BORDER=0 CELLSPACING=1 CELLPADDING=5 WIDTH=100%>
			<TR>
			<FORM NAME="search_form" METHOD=POST>
			<TD ><FONT FACE='Arial,Helvetica' SIZE=2>
			<INPUT TYPE="HIDDEN" NAME="arl" VALUE="@{[$self->param('arl')]}">
			$searchForm
			</FONT>
			</TD>
			</FORM>
			</TR>
		</TABLE>
		} : '';

	push(@{$self->{page_content_header}}, qq{
		<STYLE>
			select { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
			input { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
		</STYLE>
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE BORDER=0 CELLPADDING=0 CELLSPACING=1>
		<TR><TD BGCOLOR=BEIGE>
		<TABLE WIDTH=100% BGCOLOR=LIGHTSTEELBLUE CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TR>
			<TD>
				<FONT FACE="Arial,Helvetica" SIZE=4 COLOR=DARKRED>
					$IMAGETAGS{'icon-l/search'} <B>$heading</B>
				</FONT>
			</TD>
			<TD ALIGN=RIGHT>
				<FONT FACE="Arial,Helvetica" SIZE=2>
				$functions
				</FONT>
			</TD>
			</TR>
		</TABLE>
		$formHtml
		</TD></TR>
		</TABLE>
		<FONT SIZE=1>&nbsp;<BR></FONT>
		});

	return 1;
}

sub getForm
{
	my ($self, $flags) = @_;
	$self->abstract();
}

sub execute
{
	my ($self, $type, $expression) = @_;
	$self->abstract();
}

sub prepare
{
	my $self = shift;
	if($self->param('execute'))
	{
		#my $subType = $self->param('search_subtype');
		if($self->param('search_type') eq 'detail')
		{
			$self->execute_detail($self->param('search_expression'));
		}
		else
		{
			$self->execute($self->param('search_type') || 'code', $self->param('search_expression') || '*');
		}
	}
	else
	{
		$self->addContent('Please enter a search value.');
	}

	return 1;
}

sub initialize
{
	my $self = shift;
	$self->SUPER::initialize(@_);
	$self->addLocatorLinks(
			['Search', '/search'],
		);
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems, $handleExec) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;
	$handleExec = 1 unless defined $handleExec;

	$self->param('_islookup', 1) if $rsrc eq 'lookup';
	$self->param('_pm_view', $pathItems->[0]);
	$self->param('search_type', $pathItems->[1]) unless $self->param('search_type');
	$self->param('search_expression', $pathItems->[2]) unless $self->param('search_expression');
	$self->param('search_compare', 'contains') unless $self->param('search_compare');
	$self->param('execute', 'Go') if $handleExec && $pathItems->[2];  # if an expression is given, do the find immediately

	$self->printContents();

	return 0;
}

# STATIC FUNCTION

sub getSearchBar
{
	my ($page, $dirARLSuffix) = @_;
	my @pathItems = split(/\//, $dirARLSuffix);

	my $class = $App::ResourceDirectory::SEARCH_CLASSES->{$pathItems[0]};
	my $flags = SEARCHFLAG_SEARCHBAR;
	my ($heading, $searchForm) = &{\&{"$class\::getForm"}}($page, $flags);
	return qq{
		<STYLE>
			select { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
			input { font-size:8pt; font-family: Tahoma, Arial, Helvetica }
		</STYLE>
		<TABLE BGCOLOR=BBBBBB BORDER=0 CELLSPACING=1 CELLPADDING=2 WIDTH=100%>
			<TR>
			<FORM NAME="search_form" METHOD=POST ACTION="/search/$dirARLSuffix">
			<TD BGCOLOR=EEEEEE>
			<CENTER><B><FONT FACE="Arial,Helvetica" SIZE=2 COLOR=999999>$heading</FONT></B></CENTER>
			<FONT FACE='Verdana,Arial,Helvetica' SIZE=2>
			$searchForm
			</FONT>
			</TD>
			</FORM>
			</TR>
		</TABLE>
	};
}

1;
