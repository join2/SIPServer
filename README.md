README for Open NSIP 3M-SIP Server
==================================

DEPENDENCIES
------------

SIPServer is written entirely in Perl, but it require these CPAN perl modules to run:

- `Cache::Memcached`
- `Inline::Python` - for Invenio interaction. This interface relies on `libSIP_join2.py` and `libILS_join2.py`
- `Net::Server` - The SIP server is a Net::Server::Prefork server
- `UNIVERSAL::require` - for loading the correct ILS interface module Clone - for running the test cases
- `XML::LibXML`
- `XML::LibXML` depends on the C library libxml2
- `XML::Parser`
- `XML::Simple` - for parsing the config file

On RedHat 6.x upwards use

```bash
$ sudo yum install perl-Cache-Memcached   \
                   perl-Inline-Python     \
                   perl-Net-Server        \
                   perl-UNIVERSAL-require \
                   perl-XML-LibXML        \
                   perl-XML-Parser        \
                   perl-XML-Simple
```

On Debian

```bash
$ sudo apt-get install libcache-memcached-perl   \
                       libinline-python-perl     \
                       libnet-server-perl        \
                       libuniversal-require-perl \
                       libxml-perl               \
                       libxml-parser-perl        \
                       libxml-simple-perl
```

Notes:
------

- If `Inline::Python` is not available from the distribution compile at least v0.28 from CPAN. Make sure that it is compiled and linked against the current python binaries. Especially `urandom` is known to cause trouble due to security changes.
- `Inline::Python` uses caching. Make sure to remove the `_Inline` directory on changes to the code.
- `Inline::Python` imports all functions to the _global_ namespace of the application.

LOGGING
-------

SIPServer uses syslog() for status and debugging messages.  All syslog messages are logged using the syslog facility 'local6'.  If you need to change this, because something else on your system is already using that facililty, just change the definition of 'LOG_SIP' at the top of the file SIPServer.pm

Make sure to update your syslog configuration to capture facility 'local6' and record it.
