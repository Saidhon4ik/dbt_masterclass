{% snapshot customers_snapshot %}

{{
        config(
                target_schema = 'snapshot_practice',
                unique_key = 'id',
                invalidate_hard_deletes=True,
                strategy = 'check',
                check_cols=['full_name', 'email', 'city']
        )
}}

select
    id,
    full_name,
    email,
    registration_date,
    city
from {{ source('snapshot_practice', 'customers') }}

{% endsnapshot %}