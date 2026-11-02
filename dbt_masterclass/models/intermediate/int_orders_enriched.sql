select o.id as order_id,
       o.customer_id,
       o.order_date,
       o.total_amount,
       o.quantity,
       o.discount_amount,
       c.full_name as customer_name,
       c.email as customer_email,
       c.city as customer_city
       
from {{ref('stg_orders')}} as o
left join {{ref('stg_customers')}} as c
    on o.customer_id = c.id