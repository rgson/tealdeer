#!/usr/bin/make -f

SHELL := /bin/sh

srcdir := src
prefix := /usr/local
exec_prefix := $(prefix)
bindir := $(exec_prefix)/bin

.SUFFIXES:

targets := x86_64-musl i686-musl armv7-musleabihf arm-musleabi arm-musleabihf
version := $(shell sed -n '/^version/ s/.*"\([0-9\.]*\)".*/\1/p' Cargo.toml)
outdir := dist-$(version)
binaries := $(foreach target,$(targets),$(outdir)/tldr-$(target))

target_to_rusttarget = $(subst -,-unknown-linux-,$1)
rusttarget_to_target = $(subst -unknown-linux-,-,$1)

.PHONY: all build clean rebuild sign install

all: build

build: $(binaries)

clean:
	rm -rf target $(outdir)

rebuild: clean build

sign: $(foreach binary,$(binaries),$(binary).sig)

install: $(DESTDIR)$(bindir)/tldr

target/%/release/tldr: $(wildcard $(srcdir)/*)
	CONTAINER=messense/rust-musl-cross:$(call rusttarget_to_target,$*) && \
		docker pull $$CONTAINER && \
		docker run --rm -it -v "$$(pwd)":/home/rust/src $$CONTAINER \
			cargo build --release

%.sig: %
	gpg -a --output $@ --detach-sig $<

ifeq ($(words $(targets)),1)
$(DESTDIR)$(bindir)/tldr: $(outdir)/tldr-$(targets)
	mkdir -p $(dir $@)
	install -m 0755 $< $@
else
$(DESTDIR)$(bindir)/tldr:
	@echo 'Installation requires a single architecture, e.g.'
	@echo '  make install targets=x86_64-musl'
	@echo
	@exit 1
endif

.SECONDEXPANSION:

$(outdir)/tldr-%: target/$$(call target_to_rusttarget,$$*)/release/tldr
	mkdir -p $(dir $@)
	cp $< $@
	CONTAINER=messense/rust-musl-cross:$* && \
		docker pull $$CONTAINER && \
		docker run --rm -it -v "$$(pwd)":/home/rust/src $$CONTAINER \
			musl-strip -s /home/rust/src/$@
