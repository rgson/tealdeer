#!/usr/bin/make -f

SHELL := /bin/sh

srcdir := src

.SUFFIXES:

targets := x86_64-musl i686-musl armv7-musleabihf arm-musleabi arm-musleabihf
version := $(shell sed -n '/^version/ s/.*"\([0-9\.]*\)".*/\1/p' Cargo.toml)
outdir := dist-$(version)
binaries := $(foreach target,$(targets),$(outdir)/tldr-$(target))

target_to_rusttarget = $(subst -,-unknown-linux-,$1)
rusttarget_to_target = $(subst -unknown-linux-,-,$1)

.PHONY: all build clean rebuild sign

all: build

build: $(binaries)

clean:
	rm -rf target $(outdir)

rebuild: clean build

sign: $(foreach binary,$(binaries),$(binary).sig)

target/%/release/tldr: $(wildcard $(srcdir)/*)
	CONTAINER=messense/rust-musl-cross:$(call rusttarget_to_target,$*) && \
		docker pull $$CONTAINER && \
		docker run --rm -it -v "$$(pwd)":/home/rust/src $$CONTAINER \
			cargo build --release

%.sig: %
	gpg -a --output $@ --detach-sig $<

.SECONDEXPANSION:

$(outdir)/tldr-%: target/$$(call target_to_rusttarget,$$*)/release/tldr
	mkdir -p $(dir $@)
	cp $< $@
	CONTAINER=messense/rust-musl-cross:$* && \
		docker pull $$CONTAINER && \
		docker run --rm -it -v "$$(pwd)":/home/rust/src $$CONTAINER \
			musl-strip -s /home/rust/src/$@
