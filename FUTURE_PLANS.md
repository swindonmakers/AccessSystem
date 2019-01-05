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

### Technical changes (code)

Add table for transactions - people_id, description, amount (neg for debit, pos for credit)

Change "update_payments.pl" script to import incoming bank transactions into transactions table, and then add new dues/payments entries for members as necessary (figure out which people paid last exactly a month ago, and have > amount in their "accounts", then add rows), enter matching debit row in the accounts table.

Add API to allow for separate device to record debit transactions, by submitting the members token id, and the item being bought.

Update member profile page(s) to display transactions / current total.

Maybe: Add support for incoming payments via paypal?

### Technical changes (hardware)

We would need a Pi or similar that lives in the kitchen, with an RFID reader, and either some buttons or a barcode scanner (or both). The member would bop their RFID token on the reader, then scan a barcode (we will print a list with code per type of item). The (new) software would attempt to record the transaction, and report (leds? sound?) whether it worked.

### Bonus technology

Phone app!?
