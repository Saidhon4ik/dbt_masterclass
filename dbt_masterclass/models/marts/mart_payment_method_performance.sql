select
payment_method,
COALESCE(SUM(transaction_fee), 0) AS total_transaction_fees,
COUNT(*) AS total_payments

FROM {{ ref('int_payments_enriched') }}
group by payment_method