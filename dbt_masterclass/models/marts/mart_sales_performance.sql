select 
COALESCE(customer_city, 'Unknown') AS customer_city,
count(*) as total_orders,
COALESCE(SUM(total_amount), 0) AS total_revenue,
COALESCE(SUM(quantity), 0) AS total_quantity

from {{ref('int_orders_enriched')}}

group by COALESCE(customer_city, 'Unknown')