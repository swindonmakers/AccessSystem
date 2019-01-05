Future Plans / Ideas
====================

Pre-pay accounts
----------------

### General idea/reasoning

Some members do not carry much cash, thus have issues with the current payment method for snacks + drinks, which is "bung this small amount of change in the box".

### Suggested method

Members pre-pay (bank, maybe Paypal if we add), an amount to the space account which is credited to them as an "account total" or similar. These are added as credit transactions to a table connected to the member.

When getting snacks/drinks, members use their token on a device and then choose (somehow) an item they are getting. The system adds a debit transaction to the (same table as before).

Current total available / transactions can be viewed (somehow).

### Caveats / thoughts

Members pre-paying will need to indicate which member they are paying for (eg SM0001), AND that the amount is for prepay..

OR

We change the whole system such that any payment made for a member (SM0001 etc) goes into the "account transactions" list, and separately deduct (as a debit transaction) the membership payment amount, at regular (monthly) intervals.

### Technical changes

Add table for transactions - people_id, description, amount (neg for debit, pos for credit)

Change "update_payments.pl" script to import incoming bank transactions into transactions table, and then add new dues/payments entries for members as necessary (figure out which people paid last exactly a month ago, and have > amount in their "accounts", then add rows), enter matching debit row in the accounts table.

Maybe: Add support for incoming payments via paypal?
