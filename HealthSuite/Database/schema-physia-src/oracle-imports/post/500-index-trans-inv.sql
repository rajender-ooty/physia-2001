create index trans_owner_id_trans_type on transaction (trans_owner_id, trans_type) tablespace ts_indexes;
create index invoice_client_id_type on invoice (client_id, client_type) tablespace ts_indexes;