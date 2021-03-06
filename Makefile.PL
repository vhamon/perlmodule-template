use inc::Module::Install;
use English qw(-no_match_vars);

name 'Perlmodule-Template';
include 'Module::AutoInstall';
abstract 'Experimental equitable time distribution task scheduling solution for Linux and Windows';
license 'gpl';
repository 'https://github.com/vhamon/perlmodule-template';
version_from 'lib/Perlmodule/Template.pm';
perl_version '5.008';
authors 'Valentin Hamon';

requires 'Getopt::Long'       => '0';
requires 'Pod::Usage'         => '0';
requires 'Try::Tiny'          => '0';

test_requires 'Test::Compile'       => '0';
test_requires 'Test::More'          => '0';
test_requires 'Test::Perl::Critic'  => '0';
test_requires 'Test::Code::TidyAll' => '0';

install_script 'bin/perlmodule-template';

resources
	homepage   => "https://github.com/vhamon/perlmodule-template",
	bugtracker => "https://github.com/vhamon/perlmodule-template/issues",
	repository => "https://github.com/vhamon/perlmodule-template",
	IRC        => "http://webchat.freenode.net/";

makemaker_args(
	test => {
		TESTS => join ' ',
		map {glob}
			qw(
			t/*.t
			t/*/*.t
			t/*/*/*.t
			t/*/*/*/*.t
			t/*/*/*/*/*.t
			)
	},
	INSTALLMAN3DIR => 'none'
);

WriteAll;

# substitute prefix everywhere
$MY::variables{SYSCONFDIR} =~ s/\$\(PREFIX\)/$MY::variables{PREFIX}/;
$MY::variables{DATADIR} =~ s/\$\(PREFIX\)/$MY::variables{PREFIX}/;
$MY::variables{LOCALSTATEDIR} =~ s/\$\(PREFIX\)/$MY::variables{PREFIX}/;

# look for already existing configuration file
my $config_file_message
	= -f "$MY::variables{SYSCONFDIR}/perlmodule-template.cfg"
	? "previous configuration file found, new one will be installed as perlmodule-template.cfg.new"
	: "no previous configuration file found, new one will be installed as perlmodule-template.cfg";

print <<EOF;

Installation summary
--------------------
prefix: $MY::variables{PREFIX}
configuration installation directory: $MY::variables{SYSCONFDIR}
constant data installation directory: $MY::variables{DATADIR}
variable data installation directory: $MY::variables{LOCALSTATEDIR}

$config_file_message
EOF

package MY;

use English qw(-no_match_vars);

our %variables;

# force a perl-independant prefix for everything
sub constants {
	my ($self) = @_;

	# for some reason, initialising variables from the global scope doesn't work
	%variables = (
		PREFIX               => '/usr/local',
		INSTALLSCRIPT        => '$(PREFIX)/bin',
		INSTALLSITESCRIPT    => '$(PREFIX)/bin',
		INSTALLVENDORSCRIPT  => '$(PREFIX)/bin',
		INSTALLLIB           => '$(DATADIR)/lib',
		INSTALLSITELIB       => '$(DATADIR)/lib',
		INSTALLVENDORLIB     => '$(DATADIR)/lib',
		INSTALLMAN1DIR       => '$(PREFIX)/share/man/man1',
		INSTALLSITEMAN1DIR   => '$(PREFIX)/share/man/man1',
		INSTALLVENDORMAN1DIR => '$(PREFIX)/share/man/man1',
		INSTALLMAN3DIR       => '$(PREFIX)/share/man/man3',
		INSTALLSITEMAN3DIR   => '$(PREFIX)/share/man/man3',
		INSTALLVENDORMAN3DIR => '$(PREFIX)/share/man/man3',
		SYSCONFDIR           => '$(PREFIX)/etc/perlmodule-template',
		DATADIR              => '$(PREFIX)/share/perlmodule-template',
		LOCALSTATEDIR        => '$(PREFIX)/var/perlmodule-template',
	);

	# allow variables defined on command line to override defaults
	foreach my $name ( keys %variables ) {
		$variables{$name} = $self->{ARGS}->{$name} if $self->{ARGS}->{$name};
	}

	# get all standard MM variables definitions, and override them if needed
	my @code = split( /\n/, $self->SUPER::constants(@_) );
	foreach my $line (@code) {

		# Skip comments
		next if $line =~ /^\s*#/;

		# Skip everything which isn't a var assignment.
		next unless $line =~ /^([A-Z0-9_]+) =/;
		my $name = $1;

		# skip variables we're not interested
		next unless $variables{$name};

		$line = "$name = $variables{$name}";
	}

	# add out own variables
	foreach my $name (qw/SYSCONFDIR DATADIR LOCALSTATEDIR/) {
		push @code, "$name = $variables{$name}";
	}

	return join( "\n", @code );
}

sub install {
	my ($self) = @_;
	my $install = $self->SUPER::install(@_);

	# add dependency on data and configuration installation targets, and remove
	# dependency on perlocal installation target
	# depending on MakeMaker version, the line to match changes
	$install =~ s/install :: pure_install doc_install/install :: pure_install config_install data_install/;
	$install =~ s/install :: all pure_install doc_install/install :: all pure_install config_install data_install/;

	# suppress all lines related to packlist file installation
	$install =~ s/.*\.packlist \\\n//g;

	# add data and configuration installation targets
	$install .= <<'EOF';

config_install :
	install -d -m 755 $(DESTDIR)$(SYSCONFDIR)
	if [ -f $(DESTDIR)/$(SYSCONFDIR)/perlmodule-template.cfg ]; then \
	    install -m 644 etc/perlmodule-template.cfg $(DESTDIR)$(SYSCONFDIR)/perlmodule-template.cfg.new; \
	else \
	    install -m 644 etc/perlmodule-template.cfg $(DESTDIR)$(SYSCONFDIR)/perlmodule-template.cfg; \
	fi

data_install :
	install -d -m 755 $(DESTDIR)$(DATADIR)
EOF
	return $install;
}

# ensure binaries get modified to use configured directories (on Unix only)
sub installbin {
	my ($self) = @_;
	my $installbin = $self->SUPER::installbin(@_);

	return $installbin if $OSNAME eq 'MSWin32';

	$installbin =~ s|\t\$\(FIXIN\) (.*)\n|\t\$(FIXIN) $1\n\t\$(FINALIZE) $1\n|g;

	$installbin .= <<'EOF';
FINALIZE = $(ABSPERLRUN) -pi \
    -e 's|use lib .*|use lib "$(DATADIR)/lib";|;' \
    -e 's|confdir => .*|confdir => "$(SYSCONFDIR)",|;' \
    -e 's|datadir => .*|datadir => "$(DATADIR)",|;' \
    -e 's|libdir  => .*|libdir  => "$(DATADIR)/lib",|;' \
    -e 's|vardir  => .*|vardir  => "$(LOCALSTATEDIR)",|' \
    --
EOF
	return $installbin;
}
