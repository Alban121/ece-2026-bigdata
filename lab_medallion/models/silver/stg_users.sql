with source as (
    select * from {{ source('bronze', 'users') }}
),

-- Date of the first order of each user, read from the bronze layer to keep stg_users independent of stg_orders
first_orders as (
    select
        cast(user_uuid as uuid) as user_id,
        min(cast(date as timestamptz)) as first_ordered_at
    from {{ source('bronze', 'orders') }}
    group by 1
),

typed as (
    select
        cast(uuid as uuid) as user_id,
        trim(username) as username,
        lower(trim(username)) as username_normalized,
        trim(name) as name,
        upper(trim(sex)) as sex,
        lower(trim(mail)) as email,
        cast(birthdate as date) as birthdate_raw,
        -- The address spans 2 lines: the street, then the city, the state and the zip code
        split_part(address, chr(10), 1) as street,
        split_part(address, chr(10), 2) as address_line_2
    from source
),

validated as (
    select
        typed.*,
        -- A birthdate is invalid when it is later than the first order of the user
        coalesce(typed.birthdate_raw <= f.first_ordered_at, true) as birthdate_is_valid
    from typed
    left join first_orders f on typed.user_id = f.user_id
)

select
    user_id,
    username,
    username_normalized,
    name,
    sex,
    email,
    case when birthdate_is_valid then birthdate_raw end as birthdate,
    birthdate_is_valid,
    street,
    -- Military addresses, such as "DPO AE 12345", have no comma
    nullif(regexp_extract(address_line_2, '^(.+), [A-Z]{2} \d{5}$', 1), '') as city,
    regexp_extract(address_line_2, '([A-Z]{2}) (\d{5})$', 1) as state,
    regexp_extract(address_line_2, '([A-Z]{2}) (\d{5})$', 2) as zip_code
from validated
