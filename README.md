
AccessSystem - Swindon Makerspace
=================================

Overview
--------

A (semi-) automated access system for registering new members and
giving them access to the physical space. It provides a registration
form for new members to sign up, the ability to match RFID tokens to
members, and an API for the door controller to verify if an RFID token
is valid (including whether the owner is uptodate with payments).

We also include, via running RapidApp, a UI for admins to manually
edit the database, to assign tokens to members and trouble shoot
issues.

Technologies
------------

* Perl 

* Catalyst - Perl Web Framework

* RapidApp - CRUD built atop Catalyst

* DBIx::Cass - Perl ORM

* SQLite (or pretty much any database, see above)

* Template Toolkit - Perl templating (in this case for HTML)

* Daemon::Control - init.d style stuff

* JSON - API data send/receive

* SendInBlue - SMTP email sending service - free to low volume

* OneAll.com - social logins

INSTALL
-------

* Install Perl - see http://perl.org, mac/linux style systems will probably have it already.

* Install cpanm, either via https://metacpan.org/pod/App::cpanminus or wget http://xrl.us/cpanm, make the result executable.

* Install local::lib: cpanm local::lib

* Checkout this git repo, cd into the repo directory.

* Install dependencies for this system: cpanm --installdeps .

* Setup local::lib: see eval section of (https://metacpan.org/pod/local::lib#The-bootstrapping-technique)[local::lib docs]

RUN
---

This respository contains two pieces of software, the first is a thin layer over (https://metacpan.org/pod/RapidApp)[RadpiApp]. To run this, use the script:

script/accesssystem_server.pl --port 3001

Which will start a service on http://localhost:3001/admin

To run the API, use the script:

script/accesssystem_api_server.pl --port 3001

Which will start a service on http://localhost:3000/

NB: There is no index page on the API server, see below for details

API/UI
------

The custom parts of the API half of the system are explained here.

### New members

The /register endpoint displays a form to collect data about new members. Included in the form is a checkbox for "add children", if checked on submit the /add_child endpoint is shown - this is the same person details form. Successive children can be added until the "more children" checkbox is not selected.

Each Person row is created as the form is submitted, each child row points back to the parent row with a parent_id.

After all new people have been added, access is added for each new person, to the Door "AccessibleThing".

Finally an email is sent to the new member containing a confirmation and their payment information, the same details are then displayed.

### Verifying members

The /verify endpoint is for access nodes/things, for example the door, to query the status of an access token that was presented to it. Given a token id, and a thing id, we first match the token to its member, then check if a) the members payments are uptodate, b) the member is allowed to access the thing.

The result is a chunk of JSON that contains the person's name, their status as a trainer of the thing, and a key "access" with 1 for yes and 0 for no.

If the result is no, a key "error" with a text message is also included.

### Storing messages

The /msg_log endpoint can be used (by any thing). Given a message and a thing id, the message is stored in the log table.

### Induction

The /induct endpoint allows a thing to store details about a member's induction to itself, by a trainer.

JSON is returned containing either "allowed":1 and the students name, or "allowed":0 and the reason in the "error" key.

### Resending member emails

The /resendemail endpoint sends the given member their confirmation/bank details email again. This is used for sending updated details after changing concessionary status etc.

JSON is returned indicating whether the given member id exists, or that an attempt was made to send an email.

### Reminding expired members

The /nudge_member endpoint is used to email a member asking if/why their payment status isn't valid.

### Membership status review

The /membership_status_update endpoint gathers data about numbers of members, paying, expired, ex, children, concessions etc that exist. The result is emailed to the Makerspace directors, and displayed as JSON.

### Logins

The /login endpoint is under development.

Security
--------

Development/operation
---------------------

### Payment imports

### Database updates

The database schema layout is maintained in the (https://metacpan.org/pod/DBIx::Class)[DBIx::Class] files, under AccessSystem/Schema/Result/*.pm (one per table). To change the database, edit these files (or add new), increment the VERSION in AccessSystem/Schema.pm then:

    perl -Ilib -Mlocal::lib=/usr/src/perl/libs/access_system/perl5/ -MAccessSystem::Schema -le 'AccessSystem::Schema->connect("dbi:SQLite:test.db")->create_ddl_dir(undef, undef, undef, "previous version number")'

This will create a set of AccessSystem-Schema-$OLDVER-$NEWVER-$DATABASE.sql. Use these to update the actual database.

Schema change: If your person table has a concessionary_rate column, then add a new person.concessionary_rate_override as a varchar.  Set it to "legacy" if concessionary_rate is true, then remove the concessionary_rate column.


