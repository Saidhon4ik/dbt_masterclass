select 
id,
customer_id,
order_date,
total_amount,
quantity,
discount_amount
from {{ source('ecommerce', 'orders') }}