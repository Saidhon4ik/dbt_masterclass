# dbt Incremental Models --- Complete Practical Workflow

**Environment:** dbt Core + dbt-duckdb + DuckDB\
**Project:** `dbt_masterclass`\
**Model:** `int_orders_incremental`

This guide documents our exercise from preparing the DuckDB source table
through the initial load and the successful test that inserted one new
order.

## 1. What we built

The goal was to load all existing orders on the first run, then process
records whose `order_date` is later than the latest date already in the
target.

  Setting           Value
  ----------------- --------------------------
  Database          `warehouse.duckdb`
  Source schema     `incremental_practice`
  Source table      `incremental_orders`
  Target schema     `main`
  Target model      `int_orders_incremental`
  Materialization   `incremental`
  Unique key        `id`
  Strategy          `merge`
  Filter column     `order_date`

``` text
warehouse.duckdb
├── main
│   └── int_orders_incremental
├── raw
│   ├── customers
│   ├── orders
│   └── payments
├── crm
│   └── contacts
└── incremental_practice
    └── incremental_orders
```

## 2. Prepare the source data in DuckDB

We started with `raw.orders`, which contained 600 records.

Inspect sample rows:

``` sql
SELECT * FROM raw.orders LIMIT 10;
```

Check row count and date range:

``` sql
SELECT
    COUNT(*) AS total_orders,
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS latest_order_date
FROM raw.orders;
```

Observed: 600 rows, earliest `2021-01-01 16:43:45`, latest
`2023-01-01 09:18:13`.

Check candidate key uniqueness:

``` sql
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT id) AS unique_ids
FROM raw.orders;
```

Observed: 600 rows and 600 distinct IDs. This made `id` a suitable
candidate for `unique_key` in this exercise. The dbt `unique_key`
setting does not itself create or enforce a database primary-key
constraint.

Create a separate practice schema and copy the data:

``` sql
CREATE SCHEMA incremental_practice;

CREATE TABLE incremental_practice.incremental_orders AS
SELECT *
FROM raw.orders;
```

Verify the copy:

``` sql
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT id) AS unique_ids
FROM incremental_practice.incremental_orders;
```

Expected: 600 rows and 600 distinct IDs. We used a separate table so
test inserts would not modify the original `raw.orders` table.

## 3. Declare the source in dbt

Open `models/staging/sources.yml`. The complete source file used in the
exercise was:

``` yaml
version: 2

sources:
  - name: ecommerce
    schema: raw
    tables:
      - name: customers
      - name: orders
      - name: payments

  - name: crm_system
    schema: crm
    tables:
      - name: contacts

  - name: incremental_practice
    schema: incremental_practice
    tables:
      - name: incremental_orders
```

Remember: `name` is the logical source name used by dbt; `schema` is the
physical DuckDB schema; `tables` lists tables in that schema. Logical
source name and physical schema do not have to match, though we made
them match here.

## 4. Create the incremental SQL model

Create `models/intermediate/int_orders_incremental.sql`.

### Configure the model

At the top of the file:

``` sql
{{
    config(
        materialized='incremental',
        unique_key='id',
        incremental_strategy='merge'
    )
}}
```

-   `materialized='incremental'` tells dbt to use incremental
    materialization.
-   `unique_key='id'` tells dbt which key to use when matching incoming
    records to target records.
-   `incremental_strategy='merge'` specifies how selected records are
    written: matching records can be updated and new records can be
    inserted.

### Add the SELECT and incremental filter

``` sql
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
```

-   `is_incremental()` checks whether this execution is an incremental
    run.
-   `{{ this }}` refers to the current model's target relation.
-   `MAX(order_date)` finds the latest order date already in the target.
-   The `WHERE` clause selects source records with a later `order_date`.

On the first run, the target does not exist, so `is_incremental()` is
false and the filter is omitted. On a later incremental run, the target
exists and the filter is applied.

### Complete model file

``` sql
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
```

## 5. Parse the project

From the dbt project directory, run:

``` powershell
uv run dbt parse
```

Purpose: parse and validate project configuration and definitions,
including YAML and model files. Parsing does not execute SQL or load
data. Our parse completed successfully.

## 6. Compile the model

Run:

``` powershell
uv run dbt compile --select int_orders_incremental
```

Purpose: resolve Jinja expressions and generate SQL. We confirmed that
the source reference compiled to:

``` sql
FROM "warehouse"."incremental_practice"."incremental_orders"
```

Because this was the first execution and the target did not exist,
`is_incremental()` evaluated to false. The compiled SQL therefore did
not contain the incremental `WHERE` clause. Compilation generates SQL;
it does not insert records into the target.

## 7. Execute the initial load

Run:

``` powershell
uv run dbt run --select int_orders_incremental
```

The execution succeeded and created `main.int_orders_incremental`.
Because the target did not exist, dbt performed the initial full load
and selected all 600 source records.

## 8. Verify the initial target

In DBeaver, run:

``` sql
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT id) AS unique_ids,
    MIN(order_date) AS first_order,
    MAX(order_date) AS latest_order
FROM main.int_orders_incremental;
```

Observed result:

  Metric                              Result
  -------------- ---------------------------
  Total rows                             600
  Unique IDs                             600
  First order      `2021-01-01 16:43:45.000`
  Latest order     `2023-01-01 09:18:13.000`

This verified the initial load.

## 9. Test incremental loading with a new order

### Insert a new record into the source

Important: insert into the **source table**, not the dbt target.

``` sql
INSERT INTO incremental_practice.incremental_orders (
    id, customer_id, order_date, total_amount, quantity, discount_amount
)
VALUES (
    601, 15, TIMESTAMP '2023-01-02 10:00:00', 250.00, 2, 10.00
);
```

We chose January 2 because the latest order in the target was January 1.
The new record's date was later, so it should pass the incremental
filter.

Verify the source:

``` sql
SELECT COUNT(*)
FROM incremental_practice.incremental_orders;
```

Observed result: `601`. The source now contained 601 records; the target
still contained 600 at this point.

### Run dbt again

``` powershell
uv run dbt run --select int_orders_incremental
```

This time:

1.  The target table already existed.
2.  `is_incremental()` evaluated to true.
3.  The incremental `WHERE` condition was applied.
4.  Order `601` had an `order_date` later than the target's maximum
    date.
5.  The new record was selected and passed to the merge operation.
6.  The merge inserted the new record into the target.

### Verify the target again

``` sql
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT id) AS unique_ids,
    MAX(order_date) AS latest_order
FROM main.int_orders_incremental;
```

Observed result:

  Metric                              Result
  -------------- ---------------------------
  Total rows                             601
  Unique IDs                             601
  Latest order     `2023-01-02 10:00:00.000`

**The test passed:** the target increased from 600 to 601 records after
the second dbt execution.

## 10. What we learned

### The three dbt commands

  ------------------------------------------------------------------------------------------
  Command                                                Purpose
  ------------------------------------------------------ -----------------------------------
  `uv run dbt parse`                                     Parse and validate project
                                                         configuration and definitions

  `uv run dbt compile --select int_orders_incremental`   Resolve Jinja and generate SQL

  `uv run dbt run --select int_orders_incremental`       Execute the model against DuckDB
  ------------------------------------------------------------------------------------------

We ran parse and compile as separate learning and inspection steps. They
do not have to be run manually before every `dbt run`.

### Incremental filter versus merge strategy

-   **Incremental filter:** determines which source records are selected
    for processing.
-   **Merge strategy:** determines how those selected records are
    written to the target.

A merge strategy cannot update a source record that the incremental
filter excludes.

### Limitation of the current filter

Our filter is:

``` sql
WHERE order_date > (
    SELECT MAX(order_date)
    FROM {{ this }}
)
```

It works for new records with later `order_date` values. Suppose order
`100` is updated but its `order_date` remains `2022-01-10`:

  Column             Existing value   Updated value
  ---------------- ---------------- ---------------
  `id`                          100             100
  `total_amount`                150             200
  `order_date`           2022-01-10      2022-01-10

The updated row will not pass the filter. It will not reach the merge
operation, even though `merge` can update matching records. Production
pipelines often use a reliable `updated_at` column, a lookback window,
or another change-detection approach. Each has trade-offs.

## 11. Command reference

Run these from the dbt project directory:

``` powershell
# Parse the project
uv run dbt parse

# Compile only this model
uv run dbt compile --select int_orders_incremental

# Execute only this model
uv run dbt run --select int_orders_incremental

# Rebuild this incremental model from the full source
uv run dbt run --select int_orders_incremental --full-refresh

# List the selected model
uv run dbt ls --select int_orders_incremental
```

`--full-refresh` rebuilds the incremental target from the full model
query. Use it deliberately: it replaces the incremental target rather
than simply adding rows.

## 12. Exercise completion checklist

-   [x] Inspected the original `raw.orders` data.
-   [x] Checked row count and candidate unique-key values.
-   [x] Created the `incremental_practice` schema.
-   [x] Created `incremental_orders` as a separate source table.
-   [x] Declared the source in `sources.yml`.
-   [x] Created `int_orders_incremental.sql`.
-   [x] Configured incremental materialization.
-   [x] Configured `unique_key='id'`.
-   [x] Configured `incremental_strategy='merge'`.
-   [x] Added the `is_incremental()` filter.
-   [x] Parsed the dbt project successfully.
-   [x] Compiled the model and inspected the generated SQL.
-   [x] Executed the initial load of 600 records.
-   [x] Inserted order `601` into the source table.
-   [x] Executed the incremental model again.
-   [x] Verified that the target contained 601 records.

**Result:** The initial load and the new-record incremental test both
succeeded.

## Suggested next exercise

Extend this model to handle updates to existing records and
late-arriving data. Investigate a reliable `updated_at` column or a
lookback window, then verify that the merge strategy updates existing
target rows without creating duplicates.
