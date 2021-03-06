SHELL:=/bin/bash
AWS_DEFAULT_REGION?=ap-southeast-2

ifneq (, $(shell which docker))
TERRAFORM_VERSION=0.13.4
TERRAFORM=docker run --rm -v "${PWD}:/work" -v "${HOME}:/root" -e AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) -e http_proxy=$(http_proxy) --net=host -w /work hashicorp/terraform:$(TERRAFORM_VERSION)
else
TERRAFORM=terraform
endif

TERRAFORM_DOCS=docker run --rm -v "${PWD}:/work" tmknom/terraform-docs

CHECKOV=docker run --rm -v "${PWD}:/work" bridgecrew/checkov

TFSEC=docker run --rm -v "${PWD}:/work" liamg/tfsec

DIAGRAMS=docker run -v "${PWD}:/work" figurate/diagrams python

EXAMPLE=$(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))

.PHONY: all clean validate test docs format

all: validate test docs format

clean:
	rm -rf .terraform/

validate:
	$(TERRAFORM) init && $(TERRAFORM) validate && \
		$(TERRAFORM) init modules/codecommit && $(TERRAFORM) validate modules/codecommit && \
		$(TERRAFORM) init modules/health && $(TERRAFORM) validate modules/health

test: validate
	$(CHECKOV) -d /work
	$(TFSEC) /work

diagram:
	$(DIAGRAMS) diagram.py

docs: diagram
	$(TERRAFORM_DOCS) markdown ./ >./README.md && \
		$(TERRAFORM_DOCS) markdown ./modules/codecommit >./modules/codecommit/README.md && \
		$(TERRAFORM_DOCS) markdown ./modules/health >./modules/health/README.md

format:
	$(TERRAFORM) fmt -list=true ./ && \
		$(TERRAFORM) fmt -list=true ./modules/codecommit && \
		$(TERRAFORM) fmt -list=true ./modules/health

example:
	$(TERRAFORM) init -upgrade examples/$(EXAMPLE) && $(TERRAFORM) plan -input=false examples/$(EXAMPLE)
