{{
    config(
        materialized='incremental',
        unique_key='id',
        incremental_strategy='merge'
    )
}}

SELECT
    id,
    customer_id,
    order_date,
    total_amount,
    quantity,
    discount_amount
FROM {{ source('incremental_practice', 'incremental_orders') }}

{% if is_incremental() %}

    WHERE order_date > (
        SELECT MAX(order_date)
        FROM {{ this }}
    )

{% endif %}