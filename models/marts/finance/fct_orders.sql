with payments as
( 
    select * from {{ ref('stg_stripe__payments') }} 
)
,
orders as
(
    select * from {{ ref('stg_jaffle_shop__orders') }}
),
order_payments as 
(
    select order_id
    , sum(amount) as amount
    from payments 
    where payment_status = 'success'
    group by order_id
),
final as
(
    select o.*
    , coalesce (p.amount, 0) as amount
    from orders o
    left join order_payments p using (order_id)
)
select * from final