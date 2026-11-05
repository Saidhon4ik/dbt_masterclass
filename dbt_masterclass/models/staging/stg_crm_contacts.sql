select 
contact_id,
contact_name,
email,
COALESCE('city', 'Unknown') AS city,
from {{ source('crm_system', 'contacts') }}