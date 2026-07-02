.PHONY: validate deploy deploy-network deploy-vm status test

validate:
	python -m terraops.main validate --cloud aws --env staging

deploy: deploy-network deploy-vm

deploy-network:
	python -m terraops.main deploy --cloud aws --env staging --stack network

deploy-vm:
	python -m terraops.main deploy --cloud aws --env staging --stack vm

status:
	python -m terraops.main status --cloud aws --env staging

test:
	python -m pytest
