##############################################################################
package App::Statements::BillingStatement;
##############################################################################

use strict;
use Exporter;
use DBI::StatementManager;

use vars qw(@EXPORT $STMTMGR_STATEMENTS);

use base qw(Exporter DBI::StatementManager);
@EXPORT = qw($STMTMGR_STATEMENTS);

my $SELECT_OUTSTANDING_CLAIMS = qq{
	SELECT Invoice.invoice_id, bill_to_id, billing_facility_id, provider_id, care_provider_id,
		client_id, total_cost, total_adjust, balance,
		to_char(invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT') as invoice_date, bill_party_type,
		(select nvl(sum(net_adjust), 0)
			from Invoice_Item_Adjust
			where parent_id in (select item_id from Invoice_Item where parent_id = Invoice.invoice_id)
				and adjustment_type = 0
				and payer_type != 0
		) as insurance_receipts,
		(select nvl(sum(net_adjust), 0)
			from Invoice_Item_Adjust
			where parent_id in (select item_id from Invoice_Item where parent_id = Invoice.invoice_id)
				and adjustment_type = 0
				and payer_type = 0
		) as patient_receipts,
		Person.complete_name AS patient_name,
		Person.name_last AS patient_name_last
	FROM Transaction, Invoice_Billing, Invoice, Person
	WHERE
		Person.person_id = Invoice.client_id
		AND Invoice.owner_id = ?
		AND Invoice.invoice_status > 3
		AND Invoice.invoice_status != 15
		AND Invoice.invoice_status != 16
		AND Invoice.balance > 0
		AND Invoice.invoice_subtype in (0, 7)
		AND Invoice_Billing.bill_id = Invoice.billing_id
		AND Invoice_Billing.bill_party_type != 3
		AND Invoice_Billing.bill_to_id IS NOT NULL
		AND Transaction.trans_id = Invoice.main_transaction
		%ProviderClause%
	UNION
	SELECT plan_id * (-1) as invoice_id, pp.person_id as bill_to_id, billing_org_id as 
		billing_facility_id, 'Payment Plan' as provider_id, null as care_provider_id,
		pp.person_id as client_id, 0 as total_cost, 0 as total_adjust, pp.balance,
		to_char(first_due, 'SQLSTMT_DEFAULTDATEFORMAT') as invoice_date, 0 as bill_party_type,
		0 as insurance_receipts, sum(payments) as patient_receipts, p.complete_name AS 
		patient_name, p.name_last AS patient_name_last
	FROM Person p, Payment_Plan pp
	WHERE pp.next_due > sysdate
		and pp.balance > 0
		and p.person_id = pp.person_id
		and not exists (select 'x' from Statement where)
	
	ORDER BY Invoice.invoice_id
};

$STMTMGR_STATEMENTS = new App::Statements::BillingStatement(

	'sel_statementClaims_perOrg' => {
		sqlStmt => $SELECT_OUTSTANDING_CLAIMS,
		ProviderClause => qq{AND not exists (select 'x' from person_attribute pa
			where pa.parent_id = Transaction.provider_id
				and pa.value_type = 960
				and pa.value_intb = 1
			)
		},
	},

	'sel_statementClaims_perOrg_perProvider' => {
		sqlStmt => $SELECT_OUTSTANDING_CLAIMS,
		ProviderClause => qq{AND Transaction.provider_id = ?},
	},

	'sel_BillingIds' => qq{
		select org.org_internal_id, org.org_id, org_attribute.value_text as billing_id,
			org_attribute.value_int as nsf_type, null as provider_id
		from org_attribute, org
		where org.parent_org_id is null
			and org.org_internal_id != 1
			and org_attribute.parent_id = org.org_internal_id
			and org_attribute.value_type = @{[ App::Universal::ATTRTYPE_BILLING_INFO ]}
			and org_attribute.item_name = 'Organization Default Clearing House ID'
			and org_attribute.value_intb = 1
		UNION
		select person_org_category.org_internal_id, org.org_id, person_attribute.value_text
			as billing_id, person_attribute.value_int as nsf_type, person_id as provider_id
		from org, person_org_category, person_attribute
		where person_attribute.value_type = @{[ App::Universal::ATTRTYPE_BILLING_INFO ]}
			and person_attribute.item_name = 'Physician Clearing House ID'
			and person_attribute.value_intb = 1
			and person_org_category.person_id = person_attribute.parent_id
			and person_org_category.category = 'Physician'
			and org.org_internal_id = person_org_category.org_internal_id
	},

	'sel_internalStatementId' => qq{
		select int_statement_id from statement where statement_id = :1
	},

	'sel_daysBillingEvents' => qq{
		SELECT item_id, parent_id, value_int AS day, value_text AS name_begin, value_textb AS name_end,
			value_intb AS balance_condition, value_float AS balance_criteria
		FROM org_attribute
		WHERE parent_id = :1
			AND value_int = :2
			AND value_type = @{[ App::Universal::ATTRTYPE_BILLINGEVENT ]}
	},

	'sel_aging' => qq{
		SELECT nvl(sum(balance), 0)
		FROM Invoice_Billing, Invoice
		WHERE client_id = :1
			and invoice_date > trunc(sysdate) - :2
			and invoice_date <= trunc(sysdate) - :3
			and invoice_status > 3
			and invoice_status != 15
			and invoice_status != 16
			and invoice_subtype in (0, 7)
			and bill_id = billing_id
			and bill_to_id = :4
	},

	'sel_orgAddress' => qq{
		SELECT name_primary, line1, line2, city, state, replace(zip, '-', null) as zip
		FROM Org_Address, Org
		WHERE org_internal_id = :1
			and Org_Address.parent_id = Org.org_internal_id
	},

	'sel_orgAddressByName' => qq{
		SELECT name_primary, line1, line2, city, state, replace(zip, '-', null) as zip
		FROM org_address, org
		WHERE org_internal_id = :1
			AND org_address.parent_id = org.org_internal_id
			AND org_address.address_name = :2
	},

	'sel_personAddress' => qq{
		SELECT complete_name, line1, line2, city, State, replace(zip, '-', null) as zip
		FROM Person_Address, Person
		WHERE person_id = ?
			and Person_Address.parent_id = Person.person_id
	},

	'sel_submittedClaims_perOrg' => qq{
		select invoice_id
		from Transaction, Invoice
		where invoice_status in (
				@{[ App::Universal::INVOICESTATUS_SUBMITTED]},
				@{[ App::Universal::INVOICESTATUS_APPEALED]}
			)
			and owner_id = ?
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_SELFPAY]}
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_CLIENT]}
			and Transaction.trans_id = Invoice.main_transaction
			and not exists (select 'x' from person_attribute pa
				where pa.parent_id = Transaction.provider_id
					and pa.value_type = 960
					and pa.value_intb = 1)
		order by invoice_id
	},

	'sel_submittedClaims_perOrg_perProvider' => qq{
		select invoice_id
		from Transaction, Invoice
		where invoice_status in (
				@{[ App::Universal::INVOICESTATUS_SUBMITTED]},
				@{[ App::Universal::INVOICESTATUS_APPEALED]}
			)
			and Invoice.owner_id = :1
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_SELFPAY]}
			and invoice_subtype != @{[ App::Universal::CLAIMTYPE_CLIENT]}
			and Transaction.trans_id = Invoice.main_transaction
			and Transaction.provider_id = :2
		order by invoice_id
	},

	'sel_billingPhone' => qq{
		select value_text
		from Org_Attribute
		where parent_id = :1
			and value_type = @{[ App::Universal::ATTRTYPE_BILLING_PHONE ]}
	},

	'sel_outstandingInvoices' => qq{
		select Invoice.invoice_id, Invoice.invoice_id || ' - ' || to_char(invoice_date, '$SQLSTMT_DEFAULTDATEFORMAT')
			|| ' - \$' || to_char(Invoice.balance, '99999.99') as caption
		from Invoice_Billing, Invoice
		where Invoice.owner_id = :2
			and Invoice.balance > 0
			and Invoice.invoice_status > 3
			and Invoice.invoice_status != 15
			and Invoice.invoice_status != 16
			and Invoice.invoice_subtype in (0, 7)
			and Invoice_Billing.bill_id = Invoice.billing_id
			and Invoice_Billing.bill_party_type < 2
			and Invoice_Billing.bill_to_id = :1
		order by invoice_id desc
	},

	'sel_paymentPlan' => qq{
		select plan_id, person_id, payment_cycle, payment_min, to_char(first_due, '$SQLSTMT_DEFAULTDATEFORMAT')
			as first_due, balance, to_char(next_due, '$SQLSTMT_DEFAULTDATEFORMAT') as next_due,
			lastpay_amount, to_char(lastpay_date, '$SQLSTMT_DEFAULTDATEFORMAT' ) as lastpay_date, 
			billing_org_id, inv_ids
		from Payment_Plan
		where person_id = :1
			and owner_org_id = :2
	},
	
);

1;
