
AccessSystem - Swindon Makerspace
=================================

Overview
--------

A (semi-) automated access system for registering new members and
giving them access to the physical space. It provides a registration
form for new members to sign up, the ability to match RFID tokens to
members, and an API for the controllers (eg the Door) to verify if an
RFID token is valid (including whether the owner is uptodate with
payments).

We also include, via running RapidApp, a UI for admins to manually
edit the database, to assign tokens to members and troubleshoot
issues.

Technologies
------------

* [Perl](https://perl.org)

* [Catalyst](https://metacpan.org/pod/Catalyst) - Perl Web Framework

* [RapidApp](https://metacpan.org/pod/RadpiApp) - CRUD built atop Catalyst

* [DBIx::Class](https://metacpan.org/pod/DBIx::Class) - Perl ORM

* [SQLite](https://sqlite.org) (or pretty much any database, see above)

* [Template Toolkit](https://metacpan.org/pod/Template) - Perl templating (in this case for HTML)

* [Daemon::Control](https://metacpan.org/pod/Daemon::Control) - init.d style stuff (live system)

* [JSON](https://www.json.org) - API data send/receive

* [Brevo](https://www.brevo.com/) (formerly SendInBlue) - SMTP email sending service - free to low volume (live system)

* [OneAll.com](https://oneall.com) - social logins

* [Barclayscrape](https://github.com/carpii/barclayscrape) - Pull current transactions from a Barclays bank account

* [Telegram::Bot::Brain](https://metacpan.org/pod/Telegram::Bot::Brain) - Telegram Bot system in Perl (inductions et al)

INSTALL
-------

* Install Perl - see http://perl.org, mac/linux style systems will probably have it already.

* Install cpanm, either via [App::cpanminus](https://metacpan.org/pod/App::cpanminus) or wget [cpanm](http://xrl.us/cpanm), make the result executable.

* Install carton: cpanm -S Carton

* Checkout this git repo, cd into the repo directory.

* Install Perl dependencies for this system: carton install --cached

SETUP
-----

* Database: To run any of the system parts you will need a database, in `sql/` you will find SQL files for the latest database schema, install the highest version available for your database. Eg for SQLite:

`sqlite db/test.db < sql/AccessSystem-Schema-11.0-SQLite.sql`

* Configuration: Copy the file `accesssystem_api_local.conf.example` to `accesssystem_api_local.conf` the following variables are available:

    * Database:

        * dsn - [DBI](https://metacpan.org/pod/DBI) connect string
        * user - database user if any, remove line for sqlite
        * password - database password if any, remove line for sqlite

    * OneAll: only needed for `/login` and `/profile`

        * subdomain - oneall subdomain setting
        * domain - oneall domain setting
        * public_key
        * private_key

    * Authen Cookie: secure cookies

        * name - cookie name
        * mac_secret - any old waffle

    * Root: Root controller settings
    
        * namespace - empty for the root of your host, else enter the path under which you are running the application, ensures generated links are correct
        
    * Sendinblue: key for the sendinblue script to update contacts
    
        * api-key - create a key and put it here if using sendinblue.pl
        
    * base_url: full base link (including namespace) for script generated links

RUN
---

This respository contains two main pieces of software, the first is a thin layer over [RapidApp - a web database view](https://metacpan.org/pod/RapidApp). To run this, use the script:

`CATALYST_HOME=$PWD carton exec perl script/accesssystem_server.pl --port 3001`

Which will start a service on http://localhost:3001/admin

To run the API, use the script:

`CATALYST_HOME=$PWD carton exec perl script/accesssystem_api_server.pl --port 3000`

Which will start a service on http://localhost:3000/

NB: There is no index page on the API server, see below for details

There are more scripts and tools, the main one you might want to work on is the Telegram bot, to start that run:

`BOT_HOME=$PWD carton exec perl script/access_telegram.pl &`

DATABASE
--------

The database tables are defined in a series of Perl classes under the path `/lib/AccessSystem/Schema/Result/`, each class is a table. See each file for documentation of that table.

API/UI
------

The custom parts of the API half of the system are explained here. The code for these can be found in the file `lib/AccessSystem/API/Controller/Root.pm`.

### New members

The GET `/register` endpoint displays a form to collect data about new members.

After all new people have been added, access is added for each new person, to the Door "AccessibleThing".

Finally an email is sent to the new member containing a confirmation and their payment information, the same details are then displayed.

### Verifying members

The GET `/verify` endpoint is for access nodes/things, for example the door, to query the status of an access token that was presented to it. Given a `token` id, and a `thing` id, we first match the token to its member, then check if a) the members payments are uptodate, b) the member is allowed to access the thing.

The result is a chunk of JSON that contains the person's name, their status as a trainer of the thing, and a key "access" with 1 for yes and 0 for no.

Eg:

`{ 'access': 1, 'trainer': 0 }`

If the result is no, a key "error" with a text message is also included.

Eg:

`{ 'access': 0, 'error': "You can't do that Dave" }`

### Storing messages

The `/msg_log` endpoint can be used (by any Thing). Given a `msg` and a `thing` id, the message is stored in the `message_log` table.

### Induction

The GET|POST `/induct` endpoint allows a thing to store details about a member's induction to itself, by a trainer. Needs to be passed the trainers token in `token_t`, the student's token in `token_s` and a `thing` id.

JSON is returned containing either "allowed":1 and the students name, or "allowed":0 and the reason in the "error" key. Eg:

`{'allowed': 1, 'person': <person name> }`

### Resending member emails

The GET `/resendemail` endpoint sends the given member their confirmation/bank details email again. This is used for sending updated details after changing concessionary status etc.

JSON is returned indicating whether the given member id exists, or that an attempt was made to send an email.

### Reminding expired members

The GET `/nudge_member` endpoint is used to email a member asking if they stopped paying on purpose.

### Membership status review

The GET `/membership_status_update` endpoint gathers data about numbers of members, paying, expired, ex, children, concessions etc that exist. The result is emailed to the Makerspace directors, and displayed as JSON.

### Logins

The GET `/login` endpoint allows members to login, currently Github and Google are supported as social login methods, more are easily added via OneAll. The member must use an account with an email address that matches their registered email address, this is how the login is mapped to a member. This stores a cookie.

The GET `/logout` endpoint removes the cookie.

The GET `/profile` endpoint displays the logged in member their details, including last known payment date. Some details link to the `/editme` endpoint.

The GET|POST `/editme` endpoint displays the same form as the `/register` endpoint, but loads + saves the membership details for the logged in user.

### Bot/App endpoints

The POST `transaction` endpoint records a (debit) transaction row for a member, given a user `hash` or `token`, an `amount`, and a `reason` string.

Responds with json, success:1|0, error:'Nope!', balance: <member's current balance>

The GET `get_transactions/:count/:user_hash` returns \$count of json containing the member's transactions containing the date, reason and amount fields, together with their balance.

The GET `user_guid_request` endpoint sends the given `userid` (ref or pure number) an email containing their user hash. This is for entering on the App.

The GET `confirm_telegram` endpoint given an `email`, `chatid` and `username` is called from the telegram bot `identify` command, this emails the user with this email address (if they exist), an email to confirm they wish to link their telegram and makerspace accounts. The chatid and username are put in temporary storage until the email link is clicked on.

The GET `confirm_email` endpoint confirms+stores the telegram chatid/username into the member's people database row. This is the link emailed by `confirm_telegram`.

The GET `induction_acceptance` endpoint, given a `tool` id and a `person` id, sets "pending acceptance" to false, for that combination of tool and person, in the `allowed` table.

Security & DPA
--------------

### Personal data

The RapidApp part of the system allows access to all the data,
including personal data. It is protected by a login system. All
default views in RapidApp are altered so that any admins using it do
not see any personal data other than names, without expressly asking
for it.

### Mis-use of /verify, /induct etc

The database stores an expected IP for each Thing controller, these
are assigned as fixed IPs to the controllers by the main network
router. The API verifies that the IP of an incoming request matches
the expected IP for the claimed thing controller id.

### Personal logins

Cookies for personal logins are hashed to guard against content
guessing (entire cookie stealing is not prevented). Members will have
access only to their own data, and some shared items such as the door
codes.

Development/operation
---------------------

### Payment management

Each member is considered valid if they have a matching payment row in
the database that covers the current date. Payment rows have an added
date and an expiry date.

Member payments are preferred to be via Standing Order, and contain a
reference built from the member's id, eg member #1 will have to send a
ref of SM0001 in their payment.

A script `script/from_bank.pl` is run daily to import transactions from barclays bank using [barclayscrape](https://github.com/russss/barclayscrape). Any transaction matching SM\d+ is taken to be a payment for that member. A new transaction row is added. 

A separate script `script/membership_payments` runs daily. It checks for each member, if they are expired/invalid, or about to expire, whether they have paid in enough (transactions balance) to cover another monthly payment. If they have and the member is currently valid, a new payment row is created with an expiry date later than their current expiry date by a month. If they are invalid, the new row expires ($amount\_paid / $amount\_due) months from the current date. (This has to be a whole number, else the entire payment is rejected).

Payments may cover more than one month at a time. Monthly dues are calculated  starting with the standard rate (£25) and adjusting for circumstances -  if the member is a member of another hackspace the value is reduced to £5, for members with concessions the value is then divided by 2. The minimum value is set to £5 in case all of these apply.

If the amount available covers 12\*monthly\_amount\*0.9 then their expiry date is updated by a year (10% off for paying a year at a time).

Otherwise, the value paid is then divided by this calculated amount, and that number of months is added to the member's expiry date.

As of April 2018 - members may also specify the preference to pay more than their calculated amount, if the stored amount for this field is more than the calculated amount (described above), then the stored amount is used instead.

To allow for bank oddities and other mishaps, an overlap of 14 days is allowed between payments.

### Database updates

The database schema layout is maintained in the [DBIx::Class](https://metacpan.org/pod/DBIx::Class) files, under AccessSystem/Schema/Result/*.pm (one per table). To change the database, edit these files (or add new), increment the VERSION in AccessSystem/Schema.pm then:

    perl -Ilib -Mlocal::lib=./local/ -MAccessSystem::Schema -le 'AccessSystem::Schema->connect("dbi:SQLite:test.db")->create_ddl_dir(undef, undef, undef, "previous version number")'

This will create a set of AccessSystem-Schema-\$OLDVER-\$NEWVER-\$DATABASE.sql. Use these to update the actual database.

Schema change: If your person table has a concessionary\_rate column, then add a new person.concessionary\_rate\_override as a varchar.  Set it to "legacy" if concessionary\_rate is true, then remove the concessionary\_rate column.


Assigning access tokens etc
---------------------------

Please see the Makerspace "Operating Procedures" document.


Future Plans / Ideas
--------------------

See FUTURE_PLANS.md
