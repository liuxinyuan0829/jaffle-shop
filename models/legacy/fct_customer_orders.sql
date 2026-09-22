with payments as (

    select
        orderid as order_id,
        max(created) as payment_finalized_date,
        sum(amount) / 100.0 as total_amount_paid

    from {{ source('stripe', 'payment') }}
    where status <> 'fail'
    group by orderid

),

paid_orders as (

    select
        o.id as order_id,
        o.user_id as customer_id,
        o.order_date as order_placed_at,
        o.status as order_status,

        p.total_amount_paid,
        p.payment_finalized_date,

        c.first_name as customer_first_name,
        c.last_name as customer_last_name

    from {{ source('jaffle_shop', 'orders') }} o

    left join payments p
        on o.id = p.order_id

    left join {{ source('jaffle_shop', 'customers') }} c
        on o.user_id = c.id

),

customer_order_history as (

    select
        *,

        -- Global transaction sequence
        row_number() over (
            order by order_placed_at, order_id
        ) as transaction_seq,

        -- Order sequence for each customer
        row_number() over (
            partition by customer_id
            order by order_placed_at, order_id
        ) as customer_sales_seq,

        -- Customer order statistics
        min(order_placed_at) over (
            partition by customer_id
        ) as first_order_date,

        max(order_placed_at) over (
            partition by customer_id
        ) as most_recent_order_date,

        count(*) over (
            partition by customer_id
        ) as number_of_orders,

        -- Running customer lifetime value
        sum(coalesce(total_amount_paid, 0)) over (
            partition by customer_id
            order by order_placed_at, order_id
            rows between unbounded preceding and current row
        ) as customer_lifetime_value

    from paid_orders

)

select
    *,
    
    case
        when customer_sales_seq = 1 then 'new'
        else 'return'
    end as nvsr,

    first_order_date as fdos

from customer_order_history

order by order_id