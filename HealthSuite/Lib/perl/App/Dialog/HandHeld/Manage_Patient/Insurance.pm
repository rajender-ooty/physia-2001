##############################################################################
package App::Dialog::HandHeld::Insurance;
##############################################################################

use strict;
use Carp;

use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::HandHeld;
use App::Statements::HandHeld;
use App::Universal;

use vars qw(@ISA $INSTANCE);

@ISA = qw(App::Dialog::HandHeld);

sub new
{
	my $class = shift;
	my $self = App::Dialog::HandHeld::new($class, id => 'demographics', heading => 'Insurance', @_);
	$self->{sqlStmtId} = 'sel_patientInsurance';
	
	return $self;
}

sub getHtml
{
	my $self = shift;
	my $page = shift;
	
	my $html = '';
	if(my $sth = $STMTMGR_HANDHELD->execute($page, 0, $self->{sqlStmtId}, 
		$page->session('active_person_id')))
	{
		if (my $row = $sth->fetch())
		{
			$html = getRowHtml($row);

			while($row = $sth->fetch())
			{
				$html .= getRowHtml($row);
			}
		}
		else
		{
			$html = "No Data Found.";
		}
	}
	return $html;
}

sub getRowHtml
{
	my ($row) = @_;	
	
	return qq{
		@{[ $row->[2] ? $row->[2] . ': ' . $row->[5] : $row->[4] . ' ' . $row->[3] ]}<br>
		@{[ $row->[2] ? $row->[4] : '' ]}<br>
	};
}

$INSTANCE = new __PACKAGE__;

1;