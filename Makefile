.PHONY: webserver
PROJECT := pyaptly
GIT_HUB := "https://github.com/adfinis-sygroup/pyaptly"

include pyproject/Makefile

PYTHON26 := $(shell echo $(PYTHON_VERSION) | grep -Eq 2.6 && echo True 2> /dev/null)

# not all comprehensions are supported in 2.6 therefore
# need to disable linter for such
DEVNULL := $(shell touch .deps/flake8_comprehensions)

ifeq ($(PYTHON26),True)
	# disable installation of hypothesis on python version <2.7
	DEVNULL := $(shell touch .deps/hypothesis .deps/hypothesispytest)
endif

test-local:
	source testenv; \
	make webserver && \
	make test

.gnupg:
	bash -c '[[ "$$HOME" == *"pyaptly"* ]]'
	gpg -k
	gpg --batch --import < vagrant/key.pub
	gpg --batch --import < vagrant/key.sec
	gpg --batch --no-default-keyring --keyring trustedkeys.gpg --import < vagrant/key.pub
	cat vagrant/*.key | gpg --batch --no-default-keyring --keyring trustedkeys.gpg --import
	gpg -k

.aptly:
	aptly repo create -architectures="amd64" fakerepo01
	aptly repo create -architectures="amd64" fakerepo02
	aptly repo add fakerepo01 vagrant/*.deb
	aptly repo add fakerepo02 vagrant/*.deb

.aptly/public: .aptly .gnupg
	aptly publish repo -gpg-key="650FE755" -distribution="main" fakerepo01 fakerepo01; true
	aptly publish repo -gpg-key="650FE755" -distribution="main" fakerepo02 fakerepo02; true
	touch .aptly/public

webserver: .aptly/public
	pkill -f -x "python -m SimpleHTTPServer 8421"; true
	pkill -f -x "python -m http.server 8421"; true
	cd .aptly/public && python -m SimpleHTTPServer 8421 > /dev/null 2> /dev/null &
	cd .aptly/public && python -m http.server 8421 > /dev/null 2> /dev/null &

remote-test:
	vagrant up
	vagrant ssh -c "cd /vagrant && make test"
