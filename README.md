[![Build Status](https://travis-ci.org/rfdrake/cibh.svg?branch=master)](https://travis-ci.org/rfdrake/cibh)
[![Coverage](https://coveralls.io/repos/rfdrake/cibh/badge.png?branch=master)](https://coveralls.io/r/rfdrake/cibh)

# CIBH

This is used to take SNMP usage information from routers and convert it to
maps.  The maps are drawn using xfig.

I fear you won't get very far if you've never used this before.  I need to
include example .fig files to show how the interfaces are tied to lines and
how those lines are colored with usage data.

# Names

CIBH was originally called the barn because it reminded Pete of the old barns
in wyoming that were held together by rotting wood and bailing wire.  I'm not
sure how it got the name cows in black helicopters, except that there was a
transition at some point from a bird into a beast (cow) and the meancow got
put up as the index page.

You might also see this code referred to as snowbeast.  That was the name
given to the sun server at Sprint that hosted it.  Before that it was run from
a smaller sun box called snowbird.

# What's New?

Graphviz support for maps.  d3 charting.

I had to rewrite the support for 64-bit counters because we didn't
have it anymore.  I also modernized some of the perl because of the changes to
the language in the last 12 years or so.

I don't touch the core code very much except to move it around or clean it up.
I'm mainly extending in new directions.  Adding support for new datasource
backends is my current objective.

# Why run it?

There are several reasons you might still be interested in this:

* It's very reliable
* Despite how hard it is to use, there still aren't many comperable programs out there
* Flexibility.  Since the code is small it's possible to add features without spending tons of time on it

# Authors

All principal code is from Pete Whiting <pete@whitings.org> and was originally
written probably somewhere around 1998?

The updates for modern perl and reimplementing 64bit counters were done by me, Robert Drake <rfdrake@gmail.com>


I've updated the documentation somewhat.  I still don't anticipate anyone who
hasn't run it before from being able to figure it out, but I'm trying to cater
right now to people familiar with it, but who may have forgotten some of the
features it has.

# Step 1: Build the other tools

I suggest you run this on a modern linux box, or freebsd if you insist.  Whichever you choose, use a package manager to install the dependencies.

To run cibh you need to install many packages and all of their dependencies.  The minimal set includes:

* gd: library for building png images
* GD.pm: Perl module for accessing gd
* ucd-snmp: snmp library
* SNMP.pm: Perl library for accessing ucd-snmp
* Graphviz: (optional) to support graphviz input/output
* libmojolicious-perl: for the newer Mojolicious based web pages, including the
* D3 charting page.

Some of these may require you to install other packages (gd, for example, requires libpng, zlib and libjpeg.)

## Easy mode:

    sudo apt-get install libgd-gd2-perl libsnmp-perl libnet-snmp-perl parallel graphviz snmp-mibs-downloader libmojolicious-perl libmodule-install-perl libtest-most-perl
    sudo cpanm AnyEvent::SNMP

# Step 2: Install the perl modules

Once you get the above packages built and installed you should be
ready to run with cibh. CIBH is broken into two main parts - the
perl modules and the scripts. The modules are not good examples
of generic perl modules. They were relatively quick hacks to get
this working. To install them run the following commands:

    perl Makefile.PL
    make
    sudo make install

The last step requires you to have write access to your to the
perl library subdirs so you may need to run "sudo" or be root.

If you don't have root access, you can use the local::lib package to install
into a local directory structure, or you can use "carton" to run everything
based off of the cpanfile.

## Optional Dependencies

If you run rancid, you might put a copy of "par" in the path.
Alternatively, if you've installed GNU parallel, it will be
used.

  O. Tange (2011): GNU Parallel - The Command-Line Power Tool,
  ;login: The USENIX Magazine, February 2011:42-47.


# Step 3: Get the target directories ready

For sizing your disk you might consider how many mibs you think
you will be polling and how frequent you want to poll. I grab
about 2000 mibs every 5 minutes. Each sample takes up 12 bytes
of data, so do a little math and make a partition to store the
data.

The tool is currently set up to make separate directories for
each router. This helps keep the number of entries in a single
directory of manageable size. Further, it tries to maintain the
concept of separate networks as well, so if you manage more than
one network, they can be kept separate.

Most of the scripts will use a configuration file.  A sample of
this file, dot.cibhrc.sample, is included.  Copy it to /etc/cibhrc.

If you need to change the location of the file there are several
options.  By default you can use /usr/local/etc/cibhrc, or
/opt/cibh/etc/cibhrc, or you can override it completely by setting
the CIBHRC enviornment variable.

If none of these options work for you, you can change the
CIBH::Config module to point to the new location directly.

Once you've decided where it should go, you need to edit the cibhrc file.

Notice where it thinks it should store the snmp polled
data. Using my structure this will be in /data/ittc/snmp. The
other directory, map_path, is where it will store xfig files
which have been recolored according to network utilization.
More on that later. If you have multiple networks then set the
network variable to be equal to the NETWORK shell variable. This
will allow you to set the NETWORK shell variable in a script
(running out of cron, for example) and get consistent behavior
in all of the tools. All of the options in the .cibhrc file can
be overridden on the command line, so take a look at them and
tweak as needed. Some of the command line options do not appear
in the cibhrc file - I haven't yet gone through and documented
everything, so take a look at the first few lines of the code.
The names should pretty much explain what they are for.

You may also need to modify the cibh/scripts/collect script and set
the proper path for usage2fig to find the xfigs in.  If you don't have
any xfigs just comment out the line that says usage2fig.

# Step 4: Put the router names in the 'database'

no more database.  Put your router names in a file -
use whatever file collect points at.

For instance:

    data/<network>/routers

or an example:

    data/mynet/routers

# Step 5: Build your snmp mibs

This is the real configuration step.  The file build-snmp-config
is the one I use to do this.  You could do it by hand, if you
are sufficiently patient and have a small network, but I
don't see that happening.  The mib info table has four columns,
the hostname, the mib, the command to run once the mib has been
collected and a filename.  The command can be anything that eval
can handle in perl.  I have provided three that I find useful:

1. Store - stores the mib value in the file with .text appended to the filename.
2. GaugeAppend - append the data with a timestamp and the value to the filename. The data is stored as integers in network order, 4 byte timestamp and 4 byte value.
3. CounterAppend - append the data in a similar way, but assume this data is coming from a counter, so get the last sample (stored in the file) and figure out the difference and store that - this makes a counter look like a gauge.

You can combine these. I usually store interface gauges as
GaugeAppend,Store. If you do CounterAppend,Store, the value
stored by Store will be the "gauge-like" value, not the counter.
This allows it to work with the mapping tools.

build-snmp-config tries to figure out what kind of box it is
going against, and if it is a cisco it uses some special cisco
mibs for things like the cpu utilization.  You may want to add
your own oids for other router types.

When build-snmp-configs runs, it looks for descriptions on the
interfaces so it knows how to connect two sites.  In some cases
it can also use IPs, but it needs a coherent description to
make sense of things.  The format for the description looks like
this:

    description To bb1-jbert, Gig1/5 <extra info here like circuit ID>

If need be, the format can be completely changed in .cibhrc by
modifying the destination and accept lines.


# Step 6: Poll your network

You should now be ready to poll.  Try it with the poll command:

    snmp-poll

Without the -quiet option you should see some status fly by.
The first time through it will create the directories needed
(pay attention to your data_path setting in .cibhrc.) You should
be able to go look in the directories. Any file that ends in
.text should be human readable. The files that are the result of
counters will take three runs to get something valid stored in
them.

Set up a job to poll from cron.  I have included a sample script
that does this: scripts/collect.  I run it from cron with:

    */5 * * * * cibh/scripts/collect ittc

If I were monitoring multiple networks I would use:

    */5 * * * * cibh/scripts/collect net1 net2 net3 ...

You will probably also want to automate the rebuilding of snmp
configs nightly, in case of changes to the routers.

    # run build-snmp-configs at 3am
    0 3 * * * cibh/scripts/build-snmp-configs data/<network>/routers 2>/dev/null


# Step 7: Charting and Mapping in xfig

If you look at the provided example core.fig and sanfran.fig
you'll see a simple network setup.

xfig is not a very user friendly application so you'll probably
use it mostly for positioning things and grouping them, but
hand edit the files for common changes.

Some conventions:

Any ## is replaced with usage information looked up based on another line in the compound object.

If it's looking up cpu usage for a host the line might say #routername/cpu1.m or for lines connecting two routers it might say #bb1-rtr-name--bb2-rtr-name

These lines are regex so in some advanced cases you might have a line that says bb(\d+)-houston--bb(\d+)-dallas if you wanted to match any and all routers between houston and dallas.

Sometimes you want to break out links between routers into separate lines.  To do this you can change the description to create a unique name for each link.

    int fa0/2
     description To gw1-router_0_5, Primary Link
    int fa0/3
     description To gw1-router_0_6, Backup Link

Then in your .fig file you would make two links like this:

    #bb1-big-rtr--gw1-router_0_5
    #bb1-big-rtr--gw1-router_0_6

# Special note about the 3d script

This script takes the normal boxes and adds a bezeled border
around the edges.  If you want to make it work you'll need
to make sure the script_path is correct in cibhrc then
toggle it for a page by putting &td=1 for the parameters.

If you decide you like it you could turn it on globally.
