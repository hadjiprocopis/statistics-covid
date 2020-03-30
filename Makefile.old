# This Makefile is for the Statistics::Covid extension to perl.
#
# It was generated automatically by MakeMaker version
# 7.44 (Revision: 74400) from the contents of
# Makefile.PL. Don't edit this file, edit Makefile.PL instead.
#
#       ANY CHANGES MADE HERE WILL BE LOST!
#
#   MakeMaker ARGV: ()
#

#   MakeMaker Parameters:

#     ABSTRACT_FROM => q[lib/Statistics/Covid.pm]
#     AUTHOR => [q[Andreas Hadjiprocopis <bliako@cpan.org> / <andreashad2@gmail.com>]]
#     BUILD_REQUIRES => { Test::Harness=>q[0], Test::More=>q[0] }
#     CONFIGURE_REQUIRES => { ExtUtils::MakeMaker=>q[0] }
#     EXE_FILES => [q[script/statistics-covid-fetch-data-and-store.pl], q[script/db-search-and-make-new-db.pl]]
#     LICENSE => q[artistic_2]
#     MIN_PERL_VERSION => q[5.006]
#     NAME => q[Statistics::Covid]
#     PL_FILES => {  }
#     PREREQ_PM => { Algorithm::CurveFit=>q[1.0], Chart::Clicker=>q[0], DBD::SQLite=>q[1.60], DBI=>q[1.60], DBIx::Class=>q[0.08], Data::Dump=>q[0], DateTime=>q[0], DateTime::Format::Strptime=>q[0], File::Basename=>q[0], File::Copy=>q[0], File::Find=>q[0], File::Path=>q[0], File::Spec=>q[0], File::Temp=>q[0], Getopt::Long=>q[0], HTTP::CookieJar::LWP=>q[0], JSON::Parse=>q[0], LWP::UserAgent=>q[0], Math::Symbolic=>q[0.6], SQL::Translator=>q[0.11019], Storable=>q[0], Test::Harness=>q[0], Test::More=>q[0], Try::Tiny=>q[0] }
#     TEST_REQUIRES => {  }
#     VERSION_FROM => q[lib/Statistics/Covid.pm]
#     clean => { FILES=>q[Statistics-Covid-UK-*] }
#     dist => { COMPRESS=>q[gzip -9f], SUFFIX=>q[gz] }
#     postamble => { BENCHMARK_FILES=>q[xt/benchmarks/*.b], DATABASE_FILES=>q[xt/database/*.d], NETWORK_TEST_FILES=>q[xt/network/*.n] }

# --- MakeMaker post_initialize section:


# --- MakeMaker const_config section:

# These definitions are from config.sh (via /usr/lib64/perl5/Config.pm).
# They may have been overridden via Makefile.PL or on the command line.
AR = ar
CC = gcc
CCCDLFLAGS = -fPIC
CCDLFLAGS = -Wl,--enable-new-dtags -Wl,-z,relro -Wl,--as-needed -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld
DLEXT = so
DLSRC = dl_dlopen.xs
EXE_EXT = 
FULL_AR = /usr/bin/ar
LD = gcc
LDDLFLAGS = -lpthread -shared -Wl,-z,relro -Wl,--as-needed -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -L/usr/local/lib -fstack-protector-strong
LDFLAGS = -Wl,-z,relro -Wl,--as-needed -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -fstack-protector-strong -L/usr/local/lib
LIBC = libc-2.29.so
LIB_EXT = .a
OBJ_EXT = .o
OSNAME = linux
OSVERS = 5.1.16-200.fc29.x86_64
RANLIB = :
SITELIBEXP = /usr/local/share/perl5
SITEARCHEXP = /usr/local/lib64/perl5
SO = so
VENDORARCHEXP = /usr/lib64/perl5/vendor_perl
VENDORLIBEXP = /usr/share/perl5/vendor_perl


# --- MakeMaker constants section:
AR_STATIC_ARGS = cr
DIRFILESEP = /
DFSEP = $(DIRFILESEP)
NAME = Statistics::Covid
NAME_SYM = Statistics_Covid
VERSION = 0.23
VERSION_MACRO = VERSION
VERSION_SYM = 0_23
DEFINE_VERSION = -D$(VERSION_MACRO)=\"$(VERSION)\"
XS_VERSION = 0.23
XS_VERSION_MACRO = XS_VERSION
XS_DEFINE_VERSION = -D$(XS_VERSION_MACRO)=\"$(XS_VERSION)\"
INST_ARCHLIB = ../blib/arch
INST_SCRIPT = ../blib/script
INST_BIN = ../blib/bin
INST_LIB = ../blib/lib
INST_MAN1DIR = ../blib/man1
INST_MAN3DIR = ../blib/man3
MAN1EXT = 1
MAN3EXT = 3pm
MAN1SECTION = 1
MAN3SECTION = 3
INSTALLDIRS = site
DESTDIR = 
PREFIX = $(SITEPREFIX)
PERLPREFIX = /usr
SITEPREFIX = /usr/local
VENDORPREFIX = /usr
INSTALLPRIVLIB = /usr/share/perl5
DESTINSTALLPRIVLIB = $(DESTDIR)$(INSTALLPRIVLIB)
INSTALLSITELIB = /usr/local/share/perl5
DESTINSTALLSITELIB = $(DESTDIR)$(INSTALLSITELIB)
INSTALLVENDORLIB = /usr/share/perl5/vendor_perl
DESTINSTALLVENDORLIB = $(DESTDIR)$(INSTALLVENDORLIB)
INSTALLARCHLIB = /usr/lib64/perl5
DESTINSTALLARCHLIB = $(DESTDIR)$(INSTALLARCHLIB)
INSTALLSITEARCH = /usr/local/lib64/perl5
DESTINSTALLSITEARCH = $(DESTDIR)$(INSTALLSITEARCH)
INSTALLVENDORARCH = /usr/lib64/perl5/vendor_perl
DESTINSTALLVENDORARCH = $(DESTDIR)$(INSTALLVENDORARCH)
INSTALLBIN = /usr/bin
DESTINSTALLBIN = $(DESTDIR)$(INSTALLBIN)
INSTALLSITEBIN = /usr/local/bin
DESTINSTALLSITEBIN = $(DESTDIR)$(INSTALLSITEBIN)
INSTALLVENDORBIN = /usr/bin
DESTINSTALLVENDORBIN = $(DESTDIR)$(INSTALLVENDORBIN)
INSTALLSCRIPT = /usr/bin
DESTINSTALLSCRIPT = $(DESTDIR)$(INSTALLSCRIPT)
INSTALLSITESCRIPT = /usr/local/bin
DESTINSTALLSITESCRIPT = $(DESTDIR)$(INSTALLSITESCRIPT)
INSTALLVENDORSCRIPT = /usr/bin
DESTINSTALLVENDORSCRIPT = $(DESTDIR)$(INSTALLVENDORSCRIPT)
INSTALLMAN1DIR = /usr/share/man/man1
DESTINSTALLMAN1DIR = $(DESTDIR)$(INSTALLMAN1DIR)
INSTALLSITEMAN1DIR = /usr/local/share/man/man1
DESTINSTALLSITEMAN1DIR = $(DESTDIR)$(INSTALLSITEMAN1DIR)
INSTALLVENDORMAN1DIR = /usr/share/man/man1
DESTINSTALLVENDORMAN1DIR = $(DESTDIR)$(INSTALLVENDORMAN1DIR)
INSTALLMAN3DIR = /usr/share/man/man3
DESTINSTALLMAN3DIR = $(DESTDIR)$(INSTALLMAN3DIR)
INSTALLSITEMAN3DIR = /usr/local/share/man/man3
DESTINSTALLSITEMAN3DIR = $(DESTDIR)$(INSTALLSITEMAN3DIR)
INSTALLVENDORMAN3DIR = /usr/share/man/man3
DESTINSTALLVENDORMAN3DIR = $(DESTDIR)$(INSTALLVENDORMAN3DIR)
PERL_LIB = /usr/share/perl5
PERL_ARCHLIB = /usr/lib64/perl5
PERL_ARCHLIBDEP = /usr/lib64/perl5
LIBPERL_A = libperl.a
FIRST_MAKEFILE = Makefile
MAKEFILE_OLD = Makefile.old
MAKE_APERL_FILE = Makefile.aperl
PERLMAINCC = $(CC)
PERL_INC = /usr/lib64/perl5/CORE
PERL_INCDEP = /usr/lib64/perl5/CORE
PERL = "/usr/bin/perl"
FULLPERL = "/usr/bin/perl"
ABSPERL = $(PERL)
PERLRUN = $(PERL)
FULLPERLRUN = $(FULLPERL)
ABSPERLRUN = $(ABSPERL)
PERLRUNINST = $(PERLRUN) "-I$(INST_ARCHLIB)" "-I$(INST_LIB)"
FULLPERLRUNINST = $(FULLPERLRUN) "-I$(INST_ARCHLIB)" "-I$(INST_LIB)"
ABSPERLRUNINST = $(ABSPERLRUN) "-I$(INST_ARCHLIB)" "-I$(INST_LIB)"
PERL_CORE = 0
PERM_DIR = 755
PERM_RW = 644
PERM_RWX = 755

MAKEMAKER   = /usr/local/share/perl5/ExtUtils/MakeMaker.pm
MM_VERSION  = 7.44
MM_REVISION = 74400

# FULLEXT = Pathname for extension directory (eg Foo/Bar/Oracle).
# BASEEXT = Basename part of FULLEXT. May be just equal FULLEXT. (eg Oracle)
# PARENT_NAME = NAME without BASEEXT and no trailing :: (eg Foo::Bar)
# DLBASE  = Basename part of dynamic library. May be just equal BASEEXT.
MAKE = make
FULLEXT = Statistics/Covid
BASEEXT = Covid
PARENT_NAME = Statistics
DLBASE = $(BASEEXT)
VERSION_FROM = lib/Statistics/Covid.pm
OBJECT = 
LDFROM = $(OBJECT)
LINKTYPE = dynamic
BOOTDEP = 

# Handy lists of source code files:
XS_FILES = 
C_FILES  = 
O_FILES  = 
H_FILES  = 
MAN1PODS = 
MAN3PODS = lib/Statistics/Covid.pm \
	lib/Statistics/Covid/Analysis/Model/Simple.pm \
	lib/Statistics/Covid/Analysis/Plot/Simple.pm \
	lib/Statistics/Covid/Datum.pm \
	lib/Statistics/Covid/Migrator.pm \
	lib/Statistics/Covid/Schema.pm \
	lib/Statistics/Covid/Schema/Result/Datum.pm \
	lib/Statistics/Covid/Schema/Result/Version.pm \
	lib/Statistics/Covid/Utils.pm

# Where is the Config information that we are using/depend on
CONFIGDEP = $(PERL_ARCHLIBDEP)$(DFSEP)Config.pm $(PERL_INCDEP)$(DFSEP)config.h

# Where to build things
INST_LIBDIR      = $(INST_LIB)/Statistics
INST_ARCHLIBDIR  = $(INST_ARCHLIB)/Statistics

INST_AUTODIR     = $(INST_LIB)/auto/$(FULLEXT)
INST_ARCHAUTODIR = $(INST_ARCHLIB)/auto/$(FULLEXT)

INST_STATIC      = 
INST_DYNAMIC     = 
INST_BOOT        = 

# Extra linker info
EXPORT_LIST        = 
PERL_ARCHIVE       = 
PERL_ARCHIVEDEP    = 
PERL_ARCHIVE_AFTER = 


TO_INST_PM = lib/Statistics/Covid.pm \
	lib/Statistics/Covid/Analysis/Model/Simple.pm \
	lib/Statistics/Covid/Analysis/Plot/Simple.pm \
	lib/Statistics/Covid/DataProvider/Base.pm \
	lib/Statistics/Covid/DataProvider/UK/BBC.pm \
	lib/Statistics/Covid/DataProvider/UK/GOVUK.pm \
	lib/Statistics/Covid/DataProvider/World/JHU.pm \
	lib/Statistics/Covid/Datum.pm \
	lib/Statistics/Covid/Datum/IO.pm \
	lib/Statistics/Covid/Datum/Table.pm \
	lib/Statistics/Covid/IO/Base.pm \
	lib/Statistics/Covid/IO/DualBase.pm \
	lib/Statistics/Covid/Migrator.pm \
	lib/Statistics/Covid/Schema.pm \
	lib/Statistics/Covid/Schema/Result/Datum.pm \
	lib/Statistics/Covid/Schema/Result/Version.pm \
	lib/Statistics/Covid/Utils.pm \
	lib/Statistics/Covid/Version.pm \
	lib/Statistics/Covid/Version/IO.pm \
	lib/Statistics/Covid/Version/Table.pm


# --- MakeMaker platform_constants section:
MM_Unix_VERSION = 7.44
PERL_MALLOC_DEF = -DPERL_EXTMALLOC_DEF -Dmalloc=Perl_malloc -Dfree=Perl_mfree -Drealloc=Perl_realloc -Dcalloc=Perl_calloc


# --- MakeMaker tool_autosplit section:
# Usage: $(AUTOSPLITFILE) FileToSplit AutoDirToSplitInto
AUTOSPLITFILE = $(ABSPERLRUN)  -e 'use AutoSplit;  autosplit($$$$ARGV[0], $$$$ARGV[1], 0, 1, 1)' --



# --- MakeMaker tool_xsubpp section:


# --- MakeMaker tools_other section:
SHELL = /bin/sh
CHMOD = chmod
CP = cp
MV = mv
NOOP = $(TRUE)
NOECHO = @
RM_F = rm -f
RM_RF = rm -rf
TEST_F = test -f
TOUCH = touch
UMASK_NULL = umask 0
DEV_NULL = > /dev/null 2>&1
MKPATH = $(ABSPERLRUN) -MExtUtils::Command -e 'mkpath' --
EQUALIZE_TIMESTAMP = $(ABSPERLRUN) -MExtUtils::Command -e 'eqtime' --
FALSE = false
TRUE = true
ECHO = echo
ECHO_N = echo -n
UNINST = 0
VERBINST = 0
MOD_INSTALL = $(ABSPERLRUN) -MExtUtils::Install -e 'install([ from_to => {@ARGV}, verbose => '\''$(VERBINST)'\'', uninstall_shadows => '\''$(UNINST)'\'', dir_mode => '\''$(PERM_DIR)'\'' ]);' --
DOC_INSTALL = $(ABSPERLRUN) -MExtUtils::Command::MM -e 'perllocal_install' --
UNINSTALL = $(ABSPERLRUN) -MExtUtils::Command::MM -e 'uninstall' --
WARN_IF_OLD_PACKLIST = $(ABSPERLRUN) -MExtUtils::Command::MM -e 'warn_if_old_packlist' --
MACROSTART = 
MACROEND = 
USEMAKEFILE = -f
FIXIN = $(ABSPERLRUN) -MExtUtils::MY -e 'MY->fixin(shift)' --
CP_NONEMPTY = $(ABSPERLRUN) -MExtUtils::Command::MM -e 'cp_nonempty' --


# --- MakeMaker makemakerdflt section:
makemakerdflt : all
	$(NOECHO) $(NOOP)


# --- MakeMaker dist section skipped.

# --- MakeMaker macro section:


# --- MakeMaker depend section:


# --- MakeMaker cflags section:


# --- MakeMaker const_loadlibs section:


# --- MakeMaker const_cccmd section:


# --- MakeMaker post_constants section:


# --- MakeMaker pasthru section:

PASTHRU = LIBPERL_A="$(LIBPERL_A)"\
	LINKTYPE="$(LINKTYPE)"\
	PREFIX="$(PREFIX)"\
	PASTHRU_DEFINE='$(DEFINE) $(PASTHRU_DEFINE)'\
	PASTHRU_INC='$(INC) $(PASTHRU_INC)'


# --- MakeMaker special_targets section:
.SUFFIXES : .xs .c .C .cpp .i .s .cxx .cc $(OBJ_EXT)

.PHONY: all config static dynamic test linkext manifest blibdirs clean realclean disttest distdir pure_all subdirs clean_subdirs makemakerdflt manifypods realclean_subdirs subdirs_dynamic subdirs_pure_nolink subdirs_static subdirs-test_dynamic subdirs-test_static test_dynamic test_static



# --- MakeMaker c_o section:


# --- MakeMaker xs_c section:


# --- MakeMaker xs_o section:


# --- MakeMaker top_targets section:
all :: pure_all manifypods
	$(NOECHO) $(NOOP)

pure_all :: config pm_to_blib subdirs linkext
	$(NOECHO) $(NOOP)

	$(NOECHO) $(NOOP)

subdirs :: $(MYEXTLIB)
	$(NOECHO) $(NOOP)

config :: $(FIRST_MAKEFILE) blibdirs
	$(NOECHO) $(NOOP)

help :
	perldoc ExtUtils::MakeMaker


# --- MakeMaker blibdirs section:
blibdirs : $(INST_LIBDIR)$(DFSEP).exists $(INST_ARCHLIB)$(DFSEP).exists $(INST_AUTODIR)$(DFSEP).exists $(INST_ARCHAUTODIR)$(DFSEP).exists $(INST_BIN)$(DFSEP).exists $(INST_SCRIPT)$(DFSEP).exists $(INST_MAN1DIR)$(DFSEP).exists $(INST_MAN3DIR)$(DFSEP).exists
	$(NOECHO) $(NOOP)

# Backwards compat with 6.18 through 6.25
blibdirs.ts : blibdirs
	$(NOECHO) $(NOOP)

$(INST_LIBDIR)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_LIBDIR)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_LIBDIR)
	$(NOECHO) $(TOUCH) $(INST_LIBDIR)$(DFSEP).exists

$(INST_ARCHLIB)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_ARCHLIB)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_ARCHLIB)
	$(NOECHO) $(TOUCH) $(INST_ARCHLIB)$(DFSEP).exists

$(INST_AUTODIR)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_AUTODIR)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_AUTODIR)
	$(NOECHO) $(TOUCH) $(INST_AUTODIR)$(DFSEP).exists

$(INST_ARCHAUTODIR)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_ARCHAUTODIR)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_ARCHAUTODIR)
	$(NOECHO) $(TOUCH) $(INST_ARCHAUTODIR)$(DFSEP).exists

$(INST_BIN)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_BIN)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_BIN)
	$(NOECHO) $(TOUCH) $(INST_BIN)$(DFSEP).exists

$(INST_SCRIPT)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_SCRIPT)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_SCRIPT)
	$(NOECHO) $(TOUCH) $(INST_SCRIPT)$(DFSEP).exists

$(INST_MAN1DIR)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_MAN1DIR)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_MAN1DIR)
	$(NOECHO) $(TOUCH) $(INST_MAN1DIR)$(DFSEP).exists

$(INST_MAN3DIR)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_MAN3DIR)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_MAN3DIR)
	$(NOECHO) $(TOUCH) $(INST_MAN3DIR)$(DFSEP).exists



# --- MakeMaker linkext section:

linkext :: dynamic
	$(NOECHO) $(NOOP)


# --- MakeMaker dlsyms section:


# --- MakeMaker dynamic_bs section:

BOOTSTRAP =


# --- MakeMaker dynamic section:

dynamic :: $(FIRST_MAKEFILE) config $(INST_BOOT) $(INST_DYNAMIC)
	$(NOECHO) $(NOOP)


# --- MakeMaker dynamic_lib section:


# --- MakeMaker static section:

## $(INST_PM) has been moved to the all: target.
## It remains here for awhile to allow for old usage: "make static"
static :: $(FIRST_MAKEFILE) $(INST_STATIC)
	$(NOECHO) $(NOOP)


# --- MakeMaker static_lib section:


# --- MakeMaker manifypods section:

POD2MAN_EXE = $(PERLRUN) "-MExtUtils::Command::MM" -e pod2man "--"
POD2MAN = $(POD2MAN_EXE)


manifypods : pure_all config  \
	lib/Statistics/Covid.pm \
	lib/Statistics/Covid/Analysis/Model/Simple.pm \
	lib/Statistics/Covid/Analysis/Plot/Simple.pm \
	lib/Statistics/Covid/Datum.pm \
	lib/Statistics/Covid/Migrator.pm \
	lib/Statistics/Covid/Schema.pm \
	lib/Statistics/Covid/Schema/Result/Datum.pm \
	lib/Statistics/Covid/Schema/Result/Version.pm \
	lib/Statistics/Covid/Utils.pm
	$(NOECHO) $(POD2MAN) --section=$(MAN3SECTION) --perm_rw=$(PERM_RW) -u \
	  lib/Statistics/Covid.pm $(INST_MAN3DIR)/Statistics::Covid.$(MAN3EXT) \
	  lib/Statistics/Covid/Analysis/Model/Simple.pm $(INST_MAN3DIR)/Statistics::Covid::Analysis::Model::Simple.$(MAN3EXT) \
	  lib/Statistics/Covid/Analysis/Plot/Simple.pm $(INST_MAN3DIR)/Statistics::Covid::Analysis::Plot::Simple.$(MAN3EXT) \
	  lib/Statistics/Covid/Datum.pm $(INST_MAN3DIR)/Statistics::Covid::Datum.$(MAN3EXT) \
	  lib/Statistics/Covid/Migrator.pm $(INST_MAN3DIR)/Statistics::Covid::Migrator.$(MAN3EXT) \
	  lib/Statistics/Covid/Schema.pm $(INST_MAN3DIR)/Statistics::Covid::Schema.$(MAN3EXT) \
	  lib/Statistics/Covid/Schema/Result/Datum.pm $(INST_MAN3DIR)/Statistics::Covid::Schema::Result::Datum.$(MAN3EXT) \
	  lib/Statistics/Covid/Schema/Result/Version.pm $(INST_MAN3DIR)/Statistics::Covid::Schema::Result::Version.$(MAN3EXT) \
	  lib/Statistics/Covid/Utils.pm $(INST_MAN3DIR)/Statistics::Covid::Utils.$(MAN3EXT) 




# --- MakeMaker processPL section:


# --- MakeMaker installbin section:

EXE_FILES = script/db-search-and-make-new-db.pl script/statistics-covid-fetch-data-and-store.pl

pure_all :: $(INST_SCRIPT)/db-search-and-make-new-db.pl $(INST_SCRIPT)/statistics-covid-fetch-data-and-store.pl
	$(NOECHO) $(NOOP)

realclean ::
	$(RM_F) \
	  $(INST_SCRIPT)/db-search-and-make-new-db.pl $(INST_SCRIPT)/statistics-covid-fetch-data-and-store.pl 

$(INST_SCRIPT)/db-search-and-make-new-db.pl : script/db-search-and-make-new-db.pl $(FIRST_MAKEFILE) $(INST_SCRIPT)$(DFSEP).exists $(INST_BIN)$(DFSEP).exists
	$(NOECHO) $(RM_F) $(INST_SCRIPT)/db-search-and-make-new-db.pl
	$(CP) script/db-search-and-make-new-db.pl $(INST_SCRIPT)/db-search-and-make-new-db.pl
	$(FIXIN) $(INST_SCRIPT)/db-search-and-make-new-db.pl
	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_SCRIPT)/db-search-and-make-new-db.pl

$(INST_SCRIPT)/statistics-covid-fetch-data-and-store.pl : script/statistics-covid-fetch-data-and-store.pl $(FIRST_MAKEFILE) $(INST_SCRIPT)$(DFSEP).exists $(INST_BIN)$(DFSEP).exists
	$(NOECHO) $(RM_F) $(INST_SCRIPT)/statistics-covid-fetch-data-and-store.pl
	$(CP) script/statistics-covid-fetch-data-and-store.pl $(INST_SCRIPT)/statistics-covid-fetch-data-and-store.pl
	$(FIXIN) $(INST_SCRIPT)/statistics-covid-fetch-data-and-store.pl
	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_SCRIPT)/statistics-covid-fetch-data-and-store.pl



# --- MakeMaker subdirs section:

# none

# --- MakeMaker clean_subdirs section:
clean_subdirs :
	$(NOECHO) $(NOOP)


# --- MakeMaker clean section:

# Delete temporary files but do not touch installed files. We don't delete
# the Makefile here so a later make realclean still has a makefile to use.

clean :: clean_subdirs
	- $(RM_F) \
	  $(BASEEXT).bso $(BASEEXT).def \
	  $(BASEEXT).exp $(BASEEXT).x \
	  $(BOOTSTRAP) $(INST_ARCHAUTODIR)/extralibs.all \
	  $(INST_ARCHAUTODIR)/extralibs.ld $(MAKE_APERL_FILE) \
	  *$(LIB_EXT) *$(OBJ_EXT) \
	  *perl.core MYMETA.json \
	  MYMETA.yml blibdirs.ts \
	  core core.*perl.*.? \
	  core.[0-9] core.[0-9][0-9] \
	  core.[0-9][0-9][0-9] core.[0-9][0-9][0-9][0-9] \
	  core.[0-9][0-9][0-9][0-9][0-9] lib$(BASEEXT).def \
	  mon.out perl \
	  perl$(EXE_EXT) perl.exe \
	  perlmain.c pm_to_blib \
	  pm_to_blib.ts so_locations \
	  tmon.out 
	- $(RM_RF) \
	  Statistics-Covid-UK-* blib 
	  $(NOECHO) $(RM_F) $(MAKEFILE_OLD)
	- $(MV) $(FIRST_MAKEFILE) $(MAKEFILE_OLD) $(DEV_NULL)


# --- MakeMaker realclean_subdirs section:
# so clean is forced to complete before realclean_subdirs runs
realclean_subdirs : clean
	$(NOECHO) $(NOOP)


# --- MakeMaker realclean section:
# Delete temporary files (via clean) and also delete dist files
realclean purge :: realclean_subdirs
	- $(RM_F) \
	  $(FIRST_MAKEFILE) $(MAKEFILE_OLD) 
	- $(RM_RF) \
	  $(DISTVNAME) 


# --- MakeMaker metafile section:
metafile : create_distdir
	$(NOECHO) $(ECHO) Generating META.yml
	$(NOECHO) $(ECHO) '---' > META_new.yml
	$(NOECHO) $(ECHO) 'abstract: '\''Fetch, store in DB, retrieve and analyse Covid-19 statistics from data providers'\''' >> META_new.yml
	$(NOECHO) $(ECHO) 'author:' >> META_new.yml
	$(NOECHO) $(ECHO) '  - '\''Andreas Hadjiprocopis <bliako@cpan.org> / <andreashad2@gmail.com>'\''' >> META_new.yml
	$(NOECHO) $(ECHO) 'build_requires:' >> META_new.yml
	$(NOECHO) $(ECHO) '  Test::Harness: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  Test::More: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) 'configure_requires:' >> META_new.yml
	$(NOECHO) $(ECHO) '  ExtUtils::MakeMaker: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) 'dynamic_config: 1' >> META_new.yml
	$(NOECHO) $(ECHO) 'generated_by: '\''ExtUtils::MakeMaker version 7.44, CPAN::Meta::Converter version 2.150010'\''' >> META_new.yml
	$(NOECHO) $(ECHO) 'license: artistic_2' >> META_new.yml
	$(NOECHO) $(ECHO) 'meta-spec:' >> META_new.yml
	$(NOECHO) $(ECHO) '  url: http://module-build.sourceforge.net/META-spec-v1.4.html' >> META_new.yml
	$(NOECHO) $(ECHO) '  version: '\''1.4'\''' >> META_new.yml
	$(NOECHO) $(ECHO) 'name: Statistics-Covid' >> META_new.yml
	$(NOECHO) $(ECHO) 'no_index:' >> META_new.yml
	$(NOECHO) $(ECHO) '  directory:' >> META_new.yml
	$(NOECHO) $(ECHO) '    - t' >> META_new.yml
	$(NOECHO) $(ECHO) '    - inc' >> META_new.yml
	$(NOECHO) $(ECHO) 'requires:' >> META_new.yml
	$(NOECHO) $(ECHO) '  Algorithm::CurveFit: '\''1.0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  Chart::Clicker: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  DBD::SQLite: '\''1.60'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  DBI: '\''1.60'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  DBIx::Class: '\''0.08'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  Data::Dump: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  DateTime: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  DateTime::Format::Strptime: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  File::Basename: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  File::Copy: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  File::Find: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  File::Path: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  File::Spec: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  File::Temp: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  Getopt::Long: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  HTTP::CookieJar::LWP: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  JSON::Parse: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  LWP::UserAgent: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  Math::Symbolic: '\''0.6'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  SQL::Translator: '\''0.11019'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  Storable: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  Try::Tiny: '\''0'\''' >> META_new.yml
	$(NOECHO) $(ECHO) '  perl: '\''5.006'\''' >> META_new.yml
	$(NOECHO) $(ECHO) 'version: '\''0.23'\''' >> META_new.yml
	$(NOECHO) $(ECHO) 'x_serialization_backend: '\''CPAN::Meta::YAML version 0.018'\''' >> META_new.yml
	-$(NOECHO) $(MV) META_new.yml $(DISTVNAME)/META.yml
	$(NOECHO) $(ECHO) Generating META.json
	$(NOECHO) $(ECHO) '{' > META_new.json
	$(NOECHO) $(ECHO) '   "abstract" : "Fetch, store in DB, retrieve and analyse Covid-19 statistics from data providers",' >> META_new.json
	$(NOECHO) $(ECHO) '   "author" : [' >> META_new.json
	$(NOECHO) $(ECHO) '      "Andreas Hadjiprocopis <bliako@cpan.org> / <andreashad2@gmail.com>"' >> META_new.json
	$(NOECHO) $(ECHO) '   ],' >> META_new.json
	$(NOECHO) $(ECHO) '   "dynamic_config" : 1,' >> META_new.json
	$(NOECHO) $(ECHO) '   "generated_by" : "ExtUtils::MakeMaker version 7.44, CPAN::Meta::Converter version 2.150010",' >> META_new.json
	$(NOECHO) $(ECHO) '   "license" : [' >> META_new.json
	$(NOECHO) $(ECHO) '      "artistic_2"' >> META_new.json
	$(NOECHO) $(ECHO) '   ],' >> META_new.json
	$(NOECHO) $(ECHO) '   "meta-spec" : {' >> META_new.json
	$(NOECHO) $(ECHO) '      "url" : "http://search.cpan.org/perldoc?CPAN::Meta::Spec",' >> META_new.json
	$(NOECHO) $(ECHO) '      "version" : 2' >> META_new.json
	$(NOECHO) $(ECHO) '   },' >> META_new.json
	$(NOECHO) $(ECHO) '   "name" : "Statistics-Covid",' >> META_new.json
	$(NOECHO) $(ECHO) '   "no_index" : {' >> META_new.json
	$(NOECHO) $(ECHO) '      "directory" : [' >> META_new.json
	$(NOECHO) $(ECHO) '         "t",' >> META_new.json
	$(NOECHO) $(ECHO) '         "inc"' >> META_new.json
	$(NOECHO) $(ECHO) '      ]' >> META_new.json
	$(NOECHO) $(ECHO) '   },' >> META_new.json
	$(NOECHO) $(ECHO) '   "prereqs" : {' >> META_new.json
	$(NOECHO) $(ECHO) '      "build" : {' >> META_new.json
	$(NOECHO) $(ECHO) '         "requires" : {' >> META_new.json
	$(NOECHO) $(ECHO) '            "Test::Harness" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "Test::More" : "0"' >> META_new.json
	$(NOECHO) $(ECHO) '         }' >> META_new.json
	$(NOECHO) $(ECHO) '      },' >> META_new.json
	$(NOECHO) $(ECHO) '      "configure" : {' >> META_new.json
	$(NOECHO) $(ECHO) '         "requires" : {' >> META_new.json
	$(NOECHO) $(ECHO) '            "ExtUtils::MakeMaker" : "0"' >> META_new.json
	$(NOECHO) $(ECHO) '         }' >> META_new.json
	$(NOECHO) $(ECHO) '      },' >> META_new.json
	$(NOECHO) $(ECHO) '      "runtime" : {' >> META_new.json
	$(NOECHO) $(ECHO) '         "requires" : {' >> META_new.json
	$(NOECHO) $(ECHO) '            "Algorithm::CurveFit" : "1.0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "Chart::Clicker" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "DBD::SQLite" : "1.60",' >> META_new.json
	$(NOECHO) $(ECHO) '            "DBI" : "1.60",' >> META_new.json
	$(NOECHO) $(ECHO) '            "DBIx::Class" : "0.08",' >> META_new.json
	$(NOECHO) $(ECHO) '            "Data::Dump" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "DateTime" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "DateTime::Format::Strptime" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "File::Basename" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "File::Copy" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "File::Find" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "File::Path" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "File::Spec" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "File::Temp" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "Getopt::Long" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "HTTP::CookieJar::LWP" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "JSON::Parse" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "LWP::UserAgent" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "Math::Symbolic" : "0.6",' >> META_new.json
	$(NOECHO) $(ECHO) '            "SQL::Translator" : "0.11019",' >> META_new.json
	$(NOECHO) $(ECHO) '            "Storable" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "Try::Tiny" : "0",' >> META_new.json
	$(NOECHO) $(ECHO) '            "perl" : "5.006"' >> META_new.json
	$(NOECHO) $(ECHO) '         }' >> META_new.json
	$(NOECHO) $(ECHO) '      }' >> META_new.json
	$(NOECHO) $(ECHO) '   },' >> META_new.json
	$(NOECHO) $(ECHO) '   "release_status" : "stable",' >> META_new.json
	$(NOECHO) $(ECHO) '   "version" : "0.23",' >> META_new.json
	$(NOECHO) $(ECHO) '   "x_serialization_backend" : "JSON::PP version 4.04"' >> META_new.json
	$(NOECHO) $(ECHO) '}' >> META_new.json
	-$(NOECHO) $(MV) META_new.json $(DISTVNAME)/META.json


# --- MakeMaker signature section:
signature :
	cpansign -s


# --- MakeMaker dist_basics section skipped.

# --- MakeMaker dist_core section skipped.

# --- MakeMaker distdir section skipped.

# --- MakeMaker dist_test section skipped.

# --- MakeMaker dist_ci section skipped.

# --- MakeMaker distmeta section:
distmeta : create_distdir metafile
	$(NOECHO) cd $(DISTVNAME) && $(ABSPERLRUN) -MExtUtils::Manifest=maniadd -e 'exit unless -e q{META.yml};' \
	  -e 'eval { maniadd({q{META.yml} => q{Module YAML meta-data (added by MakeMaker)}}) }' \
	  -e '    or die "Could not add META.yml to MANIFEST: $${'\''@'\''}"' --
	$(NOECHO) cd $(DISTVNAME) && $(ABSPERLRUN) -MExtUtils::Manifest=maniadd -e 'exit unless -f q{META.json};' \
	  -e 'eval { maniadd({q{META.json} => q{Module JSON meta-data (added by MakeMaker)}}) }' \
	  -e '    or die "Could not add META.json to MANIFEST: $${'\''@'\''}"' --



# --- MakeMaker distsignature section:
distsignature : distmeta
	$(NOECHO) cd $(DISTVNAME) && $(ABSPERLRUN) -MExtUtils::Manifest=maniadd -e 'eval { maniadd({q{SIGNATURE} => q{Public-key signature (added by MakeMaker)}}) }' \
	  -e '    or die "Could not add SIGNATURE to MANIFEST: $${'\''@'\''}"' --
	$(NOECHO) cd $(DISTVNAME) && $(TOUCH) SIGNATURE
	cd $(DISTVNAME) && cpansign -s



# --- MakeMaker install section skipped.

# --- MakeMaker force section:
# Phony target to force checking subdirectories.
FORCE :
	$(NOECHO) $(NOOP)


# --- MakeMaker perldepend section:


# --- MakeMaker makefile section:
# We take a very conservative approach here, but it's worth it.
# We move Makefile to Makefile.old here to avoid gnu make looping.
$(FIRST_MAKEFILE) : Makefile.PL $(CONFIGDEP)
	$(NOECHO) $(ECHO) "Makefile out-of-date with respect to $?"
	$(NOECHO) $(ECHO) "Cleaning current config before rebuilding Makefile..."
	-$(NOECHO) $(RM_F) $(MAKEFILE_OLD)
	-$(NOECHO) $(MV)   $(FIRST_MAKEFILE) $(MAKEFILE_OLD)
	- $(MAKE) $(USEMAKEFILE) $(MAKEFILE_OLD) clean $(DEV_NULL)
	$(PERLRUN) Makefile.PL 
	$(NOECHO) $(ECHO) "==> Your Makefile has been rebuilt. <=="
	$(NOECHO) $(ECHO) "==> Please rerun the $(MAKE) command.  <=="
	$(FALSE)



# --- MakeMaker staticmake section:

# --- MakeMaker makeaperl section ---
MAP_TARGET    = ../perl
FULLPERL      = "/usr/bin/perl"
MAP_PERLINC   = "-I../blib/arch" "-I../blib/lib" "-I/usr/lib64/perl5" "-I/usr/share/perl5"


# --- MakeMaker test section:
TEST_VERBOSE=0
TEST_TYPE=test_$(LINKTYPE)
TEST_FILE = test.pl
TEST_FILES = t/*.t
TESTDB_SW = -d

testdb :: testdb_$(LINKTYPE)
	$(NOECHO) $(NOOP)

test :: $(TEST_TYPE)
	$(NOECHO) $(NOOP)

# Occasionally we may face this degenerate target:
test_ : test_dynamic
	$(NOECHO) $(NOOP)

subdirs-test_dynamic :: dynamic pure_all

test_dynamic :: subdirs-test_dynamic
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-MExtUtils::Command::MM" "-MTest::Harness" "-e" "undef *Test::Harness::Switches; test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')" $(TEST_FILES)

testdb_dynamic :: dynamic pure_all
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) $(TESTDB_SW) "-I$(INST_LIB)" "-I$(INST_ARCHLIB)" $(TEST_FILE)

subdirs-test_static :: static pure_all

test_static :: subdirs-test_static
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-MExtUtils::Command::MM" "-MTest::Harness" "-e" "undef *Test::Harness::Switches; test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')" $(TEST_FILES)

testdb_static :: static pure_all
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) $(TESTDB_SW) "-I$(INST_LIB)" "-I$(INST_ARCHLIB)" $(TEST_FILE)



# --- MakeMaker ppd section:
# Creates a PPD (Perl Package Description) for a binary distribution.
ppd :
	$(NOECHO) $(ECHO) '<SOFTPKG NAME="Statistics-Covid" VERSION="0.23">' > Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '    <ABSTRACT>Fetch, store in DB, retrieve and analyse Covid-19 statistics from data providers</ABSTRACT>' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '    <AUTHOR>Andreas Hadjiprocopis &lt;bliako@cpan.org&gt; / &lt;andreashad2@gmail.com&gt;</AUTHOR>' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '    <IMPLEMENTATION>' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <PERLCORE VERSION="5,006,0,0" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Algorithm::CurveFit" VERSION="1.0" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Chart::Clicker" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="DBD::SQLite" VERSION="1.60" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="DBI::" VERSION="1.60" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="DBIx::Class" VERSION="0.08" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Data::Dump" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="DateTime::" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="DateTime::Format::Strptime" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="File::Basename" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="File::Copy" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="File::Find" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="File::Path" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="File::Spec" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="File::Temp" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Getopt::Long" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="HTTP::CookieJar::LWP" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="JSON::Parse" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="LWP::UserAgent" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Math::Symbolic" VERSION="0.6" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="SQL::Translator" VERSION="0.11019" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Storable::" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Try::Tiny" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <ARCHITECTURE NAME="x86_64-linux-thread-multi-5.28" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '        <CODEBASE HREF="" />' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '    </IMPLEMENTATION>' >> Statistics-Covid.ppd
	$(NOECHO) $(ECHO) '</SOFTPKG>' >> Statistics-Covid.ppd


# --- MakeMaker pm_to_blib section:

pm_to_blib : $(FIRST_MAKEFILE) $(TO_INST_PM)
	$(NOECHO) $(ABSPERLRUN) -MExtUtils::Install -e 'pm_to_blib({@ARGV}, '\''$(INST_LIB)/auto'\'', q[$(PM_FILTER)], '\''$(PERM_DIR)'\'')' -- \
	  'lib/Statistics/Covid.pm' '../blib/lib/Statistics/Covid.pm' \
	  'lib/Statistics/Covid/Analysis/Model/Simple.pm' '../blib/lib/Statistics/Covid/Analysis/Model/Simple.pm' \
	  'lib/Statistics/Covid/Analysis/Plot/Simple.pm' '../blib/lib/Statistics/Covid/Analysis/Plot/Simple.pm' \
	  'lib/Statistics/Covid/DataProvider/Base.pm' '../blib/lib/Statistics/Covid/DataProvider/Base.pm' \
	  'lib/Statistics/Covid/DataProvider/UK/BBC.pm' '../blib/lib/Statistics/Covid/DataProvider/UK/BBC.pm' \
	  'lib/Statistics/Covid/DataProvider/UK/GOVUK.pm' '../blib/lib/Statistics/Covid/DataProvider/UK/GOVUK.pm' \
	  'lib/Statistics/Covid/DataProvider/World/JHU.pm' '../blib/lib/Statistics/Covid/DataProvider/World/JHU.pm' \
	  'lib/Statistics/Covid/Datum.pm' '../blib/lib/Statistics/Covid/Datum.pm' \
	  'lib/Statistics/Covid/Datum/IO.pm' '../blib/lib/Statistics/Covid/Datum/IO.pm' \
	  'lib/Statistics/Covid/Datum/Table.pm' '../blib/lib/Statistics/Covid/Datum/Table.pm' \
	  'lib/Statistics/Covid/IO/Base.pm' '../blib/lib/Statistics/Covid/IO/Base.pm' \
	  'lib/Statistics/Covid/IO/DualBase.pm' '../blib/lib/Statistics/Covid/IO/DualBase.pm' \
	  'lib/Statistics/Covid/Migrator.pm' '../blib/lib/Statistics/Covid/Migrator.pm' \
	  'lib/Statistics/Covid/Schema.pm' '../blib/lib/Statistics/Covid/Schema.pm' \
	  'lib/Statistics/Covid/Schema/Result/Datum.pm' '../blib/lib/Statistics/Covid/Schema/Result/Datum.pm' \
	  'lib/Statistics/Covid/Schema/Result/Version.pm' '../blib/lib/Statistics/Covid/Schema/Result/Version.pm' \
	  'lib/Statistics/Covid/Utils.pm' '../blib/lib/Statistics/Covid/Utils.pm' \
	  'lib/Statistics/Covid/Version.pm' '../blib/lib/Statistics/Covid/Version.pm' \
	  'lib/Statistics/Covid/Version/IO.pm' '../blib/lib/Statistics/Covid/Version/IO.pm' \
	  'lib/Statistics/Covid/Version/Table.pm' '../blib/lib/Statistics/Covid/Version/Table.pm' 
	$(NOECHO) $(TOUCH) pm_to_blib


# --- MakeMaker selfdocument section:

# here so even if top_targets is overridden, these will still be defined
# gmake will silently still work if any are .PHONY-ed but nmake won't

static ::
	$(NOECHO) $(NOOP)

dynamic ::
	$(NOECHO) $(NOOP)

config ::
	$(NOECHO) $(NOOP)


# --- MakeMaker postamble section:
BENCHMARK_FILES=xt/benchmarks/*.b
TEST_D = $(ABSPERLRUN) -MExtUtils::Command -e test_d --

bench :: $(BENCHMARK_FILES)
	prove --blib $(INST_LIB) --blib $(INST_ARCHLIB) --verbose $^

bench2 :: $(BENCHMARK_FILES)
	$(TEST_D) xt && $(MAKE) test TEST_FILES='$(BENCHMARK_FILES)'
NETWORK_TEST_FILES=xt/network/*.n
network :: $(NETWORK_TEST_FILES)
	prove --blib $(INST_LIB) --blib $(INST_ARCHLIB) --verbose $^

network2 :: $(NETWORK_TEST_FILES)
	$(TEST_D) xt && $(MAKE) test TEST_FILES='$(NETWORK_TEST_FILES)'
DATABASE_FILES=xt/database/*.d
database :: $(DATABASE_FILES)
	prove --blib $(INST_LIB) --blib $(INST_ARCHLIB) --verbose $^

database2 :: $(DATABASE_FILES)
	$(TEST_D) xt && $(MAKE) test TEST_FILES='$(DATABASE_FILES)'


# End.
