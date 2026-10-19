# Builds the app binaries. Every target delegates to scripts/make.sh, which
# documents the settings, e.g. `make android MODE=debug`.
#
#   make           every platform this host can build
#   make web       grigri_app/build/web/
#   make android   release APK
#   make aab       release bundle for Google Play (needs the upload key)
#   make ios       Runner.app (macOS only; unsigned unless IOS_CODESIGN=1)
#   make ipa       signed .ipa for App Store Connect (macOS only;
#                  specs/app-store.md)
#   make clean     flutter clean

# One build time for every target in a run, so they share a version (see
# scripts/version.sh).
ifndef BUILD_NUMBER
BUILD_NUMBER := $(shell date -u +%s)
endif

export MODE IOS_CODESIGN BUILD_NUMBER VERSION_Z

.PHONY: all web android aab ios ipa clean

all web android aab ios ipa clean:
	@bash scripts/make.sh $@
