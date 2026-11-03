select
id,
full_name,
email,
registration_date,
city
from {{ source('ecommerce', 'customers') }}