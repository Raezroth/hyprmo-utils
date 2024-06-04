DESTDIR=
PREFIX:=/usr
SYSCONFDIR:=/etc
SHAREDIR=$(PREFIX)/share
MANDIR=$(SHAREDIR)/man

# use $(PREFIX)/lib/systemd/user for systemd integration
SERVICEDIR:=$(PREFIX)/share/superd/services

# Install services for packages outside sxmo
EXTERNAL_SERVICES:=1

SCDOC=scdoc

.PHONY: install test shellcheck shellspec test_legacy_nerdfont

VERSION:=0.01.0

GITVERSION:=$(shell git describe --tags)

OPENRC:=1

CC ?= $(CROSS_COMPILE)gcc
PROGRAMS = \
	programs/hyprmo_aligned_sleep \
	programs/hyprmo_vibrate

DOCS = \
	docs/hyprmo.7

docs/%: docs/%.scd
	$(SCDOC) <$< >$@

all: $(PROGRAMS) $(DOCS)

test: shellcheck shellspec test_legacy_nerdfont

shellcheck:
	find . -type f -name '*.sh' -print0 | xargs -0 shellcheck -x --shell=sh

shellspec:
	shellspec

test_legacy_nerdfont: programs/test_legacy_nerdfont
	programs/test_legacy_nerdfont < configs/default_hooks/hyprmo_hook_icons.sh

programs/test_legacy_nerdfont: programs/test_legacy_nerdfont.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) -o $@ $< $(shell pkg-config --cflags --libs icu-io)

programs/%: programs/%.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -f programs/hyprmo_aligned_sleep programs/hyprmo_vibrate

install: install-hyprland install-scripts install-docs

install-docs: $(DOCS)
	cd docs && find . -type f -name '*.7' -exec install -D -m 0644 "{}" "$(DESTDIR)$(MANDIR)/man7/{}" \; && cd ..

install-hyprland:
	install -D -m 0644 -t $(DESTDIR)$(PREFIX)/share/wayland-sessions/ configs/applications/hyprmo.desktop

install-scripts: $(PROGRAMS)
	cd configs && find . -type f -not -name hyprmo-setpermissions -exec install -D -m 0644 "{}" "$(DESTDIR)$(PREFIX)/share/hyprmo/{}" \; && cd ..

	rm -rf "$(DESTDIR)$(PREFIX)/share/hyprmo/default_hooks/"
	cd configs && find default_hooks -type f -exec install -D -m 0755 "{}" "$(DESTDIR)$(PREFIX)/share/hyprmo/{}" \; && cd ..
	cd configs && find default_hooks -type l -exec cp -R "{}" "$(DESTDIR)$(PREFIX)/share/hyprmo/{}" \; && cd ..

	[ -n "$(GITVERSION)" ] && echo "$(GITVERSION)" > "$(DESTDIR)$(PREFIX)/share/hyprmo/version" || echo "$(VERSION)" > "$(DESTDIR)$(PREFIX)/share/hyprmo/version"

	cd resources && find . -type f -exec install -D -m 0644 "{}" "$(DESTDIR)$(PREFIX)/share/hyprmo/{}" \; && cd ..

	install -D -m 0644 -t $(DESTDIR)$(PREFIX)/lib/udev/rules.d/ configs/udev/*.rules

	install -D -m 0644 -t $(DESTDIR)$(PREFIX)/share/applications/ configs/xdg/mimeapps.list

	install -D -m 0640 -t $(DESTDIR)$(SYSCONFDIR)/doas.d/ configs/doas/hyprmo.conf

	mkdir -p $(DESTDIR)$(SYSCONFDIR)/NetworkManager/dispatcher.d

	install -D -m 0644 -T configs/appcfg/mpv_input.conf $(DESTDIR)$(SYSCONFDIR)/mpv/input.conf

	install -D -m 0755 -T configs/profile.d/hyprmo_init.sh $(DESTDIR)$(SYSCONFDIR)/profile.d/hyprmo_init.sh

	# Migrations
	install -D -t $(DESTDIR)$(PREFIX)/share/hyprmo/migrations migrations/*

	# Bin
	install -D -t $(DESTDIR)$(PREFIX)/bin scripts/*/*.sh

	install -D programs/hyprmo_aligned_sleep $(DESTDIR)$(PREFIX)/bin/
	install -D programs/hyprmo_vibrate $(DESTDIR)$(PREFIX)/bin/

	find $(DESTDIR)$(PREFIX)/share/hyprmo/default_hooks/ -type f -exec ./setup_config_version.sh "{}" \;
	find $(DESTDIR)$(PREFIX)/share/hyprmo/appcfg/ -type f -exec ./setup_config_version.sh "{}" \;

	# Appscripts
	mkdir -p "$(DESTDIR)$(PREFIX)/share/hyprmo/appscripts"
	cd scripts/appscripts && find . -name 'hyprmo_*.sh' | xargs -I{} ln -fs "$(PREFIX)/bin/{}" "$(DESTDIR)$(PREFIX)/share/hyprmo/appscripts/{}" && cd ../..

	mkdir -p "$(DESTDIR)$(SERVICEDIR)"
	install -m 0644 -t "$(DESTDIR)$(SERVICEDIR)" configs/services/*
	if [ "$(EXTERNAL_SERVICES)" = "1" ]; then \
		install -m 0644 -t "$(DESTDIR)$(SERVICEDIR)" configs/external-services/*; \
	fi

	@echo "-------------------------------------------------------------------">&2
	@echo "NOTICE 1: Do not forget to add hyprmo-setpermissions to your init system, e.g. for openrc: rc-update add hyprmo-setpermissions default && rc-service hyprmo-setpermissions start" >&2
	@echo "-------------------------------------------------------------------">&2
	@echo "NOTICE 2: After an upgrade, it is recommended you reboot and when prompted run hyprmo_migrate.sh to check and upgrade your configuration files and custom hooks against the defaults (it will not make any changes unless explicitly told to)" >&2
	@echo "-------------------------------------------------------------------">&2
