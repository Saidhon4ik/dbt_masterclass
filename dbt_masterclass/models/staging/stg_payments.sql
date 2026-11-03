select
id,
order_id,
payment_method,
payment_date,
transaction_fee
from {{ source('ecommerce', 'payments') }}