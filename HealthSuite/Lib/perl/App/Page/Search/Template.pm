##############################################################################
package App::Page::Search::Template;
##############################################################################

use strict;
use App::Page::Search;
use App::Universal;
use DBI::StatementManager;
use App::Statements::Scheduling;

use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(App::Page::Search);
%RESOURCE_MAP = (
	'search/template' => {},
	);

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->param('_pm_view', $pathItems->[0]);

	unless ($self->param('searchAgain')) {
		my $r_ids = $pathItems->[2];
		my $facility_id = $pathItems->[3];
		my $template_type = $pathItems->[4];

		$self->param('r_ids', $r_ids);
		$self->param('facility_id', $facility_id);
		$self->param('searchAgain', 1);
	}

	$self->param('execute', 'Go') if $pathItems->[1];  # Auto-execute
	return $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems);
}

sub getForm
{
	my ($self, $flags) = @_;

	my $createFns = '';
	unless($flags & SEARCHFLAG_LOOKUPWINDOW)
	{
		$createFns = qq{
			|
			<font size=2 face='Tahoma'>&nbsp &nbsp
			<a href="/schedule/dlg-add-template?_dialogreturnurl=/search/template">Add Template</a>
			</font>
		};
	}

	my ($selected0, $selected1, $selected2);
	my $selected;

	my @available = split (/,/, $self->param('template_type'));

	return ('Lookup a scheduling template', qq{
		<CENTER>
		<NOBR>
		<font size=2 face='Tahoma'>	Search for </font>
		<select name="template_type" style="color: darkred">
			<option value="0,1" $selected0>All Templates</option>
			<option value="1,1" $selected1>Positive Templates</option>
			<option value="0,0" $selected2>Negative Templates</option>
		</select>
		<select name="template_active" style="color: navy">
			<option value="1">Active</option>
			<option value="0">Inactive</option>
		</select>
		<script>
			setSelectedValue(document.search_form.template_type, '@{[$self->param('template_type')]}');
			setSelectedValue(document.search_form.template_active, '@{[$self->param('template_active')]}');
		</script>

		<input name='r_ids' size=17 maxlength=32 value="@{[$self->param('r_ids')]}"
			title='Resource ID'>
			<a href="javascript:doFindLookup(this.form, search_form.r_ids, '/lookup/person/id');">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Resource ID"></a>

		<input name='facility_id' size=17 maxlength=32 value="@{[$self->param('facility_id')]}" title='Facility ID'>
			<a href="javascript:doFindLookup(this.form, search_form.facility_id, '/lookup/org/id');">
		<img src='/resources/icons/arrow_down_blue.gif' border=0 title="Lookup Facility ID"></a>

		<input type=hidden name='searchAgain' value="@{[$self->param('searchAgain')]}">
		<input type=submit name="execute" value="Go">
		</NOBR>
		$createFns
		</CENTER>
	});
}

sub execute
{
	my ($self, $type, $expression) = @_;

	my @available = split (/,/, $self->param('template_type'));
	@available = (0,1) unless @available;
	my $template_active = defined $self->param('template_active') ? 
		$self->param('template_active') : 1;
	
	my @bindCols = ($self->session('org_internal_id'), $self->param('r_ids').'%', 
		$self->param('facility_id').'%', @available, $template_active);

	$self->param('_dialogreturnurl', '/search/template');
	
	$self->addContent(
	'<CENTER>',
		$STMTMGR_SCHEDULING->createHtml($self, STMTMGRFLAG_NONE, 'selTemplateInfo', \@bindCols,
		),
		'</CENTER>'
	);

	return 1;
}

1;
