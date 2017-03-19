
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

Details
-------

### Technologies

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

Database updates
----------------

The database schema layout is maintained in the (https://metacpan.org/pod/DBIx::Class)[DBIx::Class] files, under AccessSystem/Schema/Result/*.pm (one per table). To change the database, edit these files (or add new), increment the VERSION in AccessSystem/Schema.pm then:

    perl -Ilib -Mlocal::lib=/usr/src/perl/libs/access_system/perl5/ -MAccessSystem::Schema -le 'AccessSystem::Schema->connect("dbi:SQLite:test.db")->create_ddl_dir(undef, undef, undef, "previous version number")'

This will create a set of AccessSystem-Schema-$OLDVER-$NEWVER-$DATABASE.sql. Use these to update the actual database.

Schema change: If your person table has a concessionary_rate column, then add a new person.concessionary_rate_override as a varchar.  Set it to "legacy" if concessionary_rate is true, then remove the concessionary_rate column.


