select 
    id as payment_id
    , orderid as order_id
    , status as payment_status
    , amount
from raw.stripe.payment