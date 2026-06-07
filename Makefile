.PHONY: install setup-signing build autostart autostart-uninstall

install:
	@./scripts/install-local.sh

setup-signing:
	@./scripts/setup-signing.sh

build:
	@./scripts/build-release.sh

autostart:
	@./scripts/install-launchagent.sh install

autostart-uninstall:
	@./scripts/install-launchagent.sh uninstall
