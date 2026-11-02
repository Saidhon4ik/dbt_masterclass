select
p.id as payment_id,
p.order_id,
o.order_date,
p.payment_date,
p.payment_method,
p.transaction_fee,
o.total_amount,
o.customer_id,
o.customer_name

from {{ref('stg_payments')}} as p
left join {{ref('int_orders_enriched')}} as o
    on p.order_id = o.order_id