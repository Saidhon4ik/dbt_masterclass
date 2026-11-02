select 
customer_id,
customer_name,
COALESCE(customer_city, 'Unknown') AS customer_city,
COALESCE(SUM(total_amount), 0) AS total_spent,
count(*) as total_orders,
COALESCE(AVG(total_amount), 0) AS avg_order_value

from {{ref('int_orders_enriched')}}

group by customer_id, customer_name, customer_city