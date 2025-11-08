.PHONY: all infra user generate-env delete-infra delete-user cli clean

-include .env

all: generate-env infra user cli

generate-env:
	@if [ ! -f .env ]; then \
		USER_NAME=$$(echo $$USER | tr "[:upper:]" "[:lower:]") && \
		echo "export USER_NAME=$$USER_NAME" > .env && \
		echo "export USER_EMAIL=$$USER_NAME@example.com" >> .env && \
		echo "export USER_DEPARTMENT=IT" >> .env && \
		echo "export USER_PASSWORD=$$(openssl rand -base64 10)" >> .env && \
		echo "export COGNITO_DOMAIN_PREFIX=$$(openssl rand -base64 16 | tr '+/' '-' | tr '[:upper:]' '[:lower:]' | tr -d '=')" >> .env; \
	else \
		echo ".env already exists, skipping generation"; \
	fi

# @touch .venv updates the timestamp so Make knows it's updated
infra/.venv: infra/pyproject.toml infra/uv.lock
	cd infra && uv sync
	@touch infra/.venv

cli/.venv: cli/pyproject.toml cli/uv.lock
	cd cli && uv sync
	@touch cli/.venv

infra: infra/.venv
	cd infra && \
	source .venv/bin/activate && \
	npx cdk deploy --all

delete-infra: infra/.venv
	cd infra && \
	source .venv/bin/activate && \
	npx cdk destroy "*" --force && \
	rm ../cli/.env.infra || true

user:
	set -a && \
	. .env && \
	set +a && \
	cd infra && \
	uv sync && \
	STACK_NAME=$$(source .venv/bin/activate && npx cdk list | grep UserDirectory) && \
	USER_POOL_ID=$$(aws cloudformation describe-stacks --stack-name $$STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='UserDirectoryId'].OutputValue" --output text) && \
	aws cognito-idp admin-create-user \
    --user-pool-id $$USER_POOL_ID \
    --username $$USER_NAME \
    --user-attributes Name=email,Value=$$USER_EMAIL Name=custom:department,Value=$$USER_DEPARTMENT \
    --message-action SUPPRESS && \
	sleep 3 && \
	aws cognito-idp admin-set-user-password \
    --user-pool-id "$$USER_POOL_ID" \
    --username "$$USER_NAME" \
    --password "$$USER_PASSWORD" \
    --permanent && \
	aws cognito-idp admin-add-user-to-group \
    --user-pool-id $$USER_POOL_ID \
    --username $$USER_NAME \
    --group-name $$USER_DEPARTMENT

delete-user: infra/.venv
	cd infra && \
	STACK_NAME=$$(source .venv/bin/activate && npx cdk list | grep UserDirectory) && \
	USER_POOL_ID=$$(aws cloudformation describe-stacks --stack-name $$STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='UserDirectoryId'].OutputValue" --output text) && \
	aws cognito-idp admin-delete-user \
    --user-pool-id $$USER_POOL_ID \
    --username $(USER_NAME)


cli: cli/.venv
	@if [ ! -f cli/.env.infra ]; then \
		source .env && \
		cd infra && \
		STACK_NAME=$$(source .venv/bin/activate && npx cdk list | grep TerminalApp) && \
		CLIENT_ID=$$(aws cloudformation describe-stacks --stack-name $$STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ClientId'].OutputValue" --output text) && \
		USER_DIRECTORY_ID=$$(aws cloudformation describe-stacks --stack-name $$(source .venv/bin/activate && npx cdk list | grep UserDirectory) --query "Stacks[0].Outputs[?OutputKey=='UserDirectoryId'].OutputValue" --output text) && \
		cd ../cli && \
		echo "export CLIENT_ID=\"$$CLIENT_ID\"" > .env && \
		echo "export USER_DIRECTORY_ID=\"$$USER_DIRECTORY_ID\"" >> .env; \
	else \
		echo "cli/.env already exists, skipping generation"; \
	fi
	@echo "http://localhost:35002/login"
	cd cli && \
	source .venv/bin/activate && \
	flask run -p 35002

clean: delete-infra
	rm ../cli/.env.infra || true
	rm .env || true
	rm -rf infra/.venv
	rm -rf cli/.venv