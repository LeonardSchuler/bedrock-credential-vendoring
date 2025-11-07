.PHONY: all infra user generate-env delete-infra delete-user cli

all: generate-env infra user

generate-env:
	$(eval USER_NAME := $(shell echo $$USER | tr "[:upper:]" "[:lower:]"))
	@echo "export USER_NAME=\"$(USER_NAME)\"" > .env
	@echo "export USER_EMAIL=\"$(USER_NAME)@example.com\"" >> .env
	@echo "export USER_DEPARTMENT=\"IT\"" >> .env
	@echo "export USER_PASSWORD=\"$$(openssl rand -base64 10)\"" >> .env
	@echo "export COGNITO_DOMAIN_PREFIX=\"$$(openssl rand -base64 16 | tr '+/' '-' | tr '[:upper:]' '[:lower:]' | tr -d '=')\"" >> .env

infra:
	cd infra && \
	source .venv/bin/activate && \
	npx cdk deploy --all && \
	STACK_NAME=$$(npx cdk list | grep TerminalApp) && \
	CLIENT_ID=$$(aws cloudformation describe-stacks --stack-name $$STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ClientId'].OutputValue" --output text) && \
	USER_DIRECTORY_ID=$$(aws cloudformation describe-stacks --stack-name $$(npx cdk list | grep UserDirectory) --query "Stacks[0].Outputs[?OutputKey=='UserDirectoryId'].OutputValue" --output text) && \
	cd ../cli && \
	echo "export CLIENT_ID=\"$$CLIENT_ID\"" > .env && \
	echo "export USER_DIRECTORY_ID=\"$$USER_DIRECTORY_ID\"" >> .env

delete-infra:
	cd infra && \
	source .venv/bin/activate && \
	npx cdk destroy "*"

user:
	cd infra && \
	STACK_NAME=$$(source .venv/bin/activate && npx cdk list | grep UserDirectory) && \
	USER_POOL_ID=$$(aws cloudformation describe-stacks --stack-name $$STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='UserDirectoryId'].OutputValue" --output text) && \
	aws cognito-idp admin-create-user \
    --user-pool-id $$USER_POOL_ID \
    --username $(USER_NAME) \
    --user-attributes Name=email,Value=$(USER_EMAIL) Name=custom:department,Value=$(USER_DEPARTMENT) \
    --message-action SUPPRESS && \
	sleep 3 && \
	aws cognito-idp admin-set-user-password \
    --user-pool-id "$$USER_POOL_ID" \
    --username "$(USER_NAME)" \
    --password "$(USER_PASSWORD)" \
    --permanent && \
	aws cognito-idp admin-add-user-to-group \
    --user-pool-id $$USER_POOL_ID \
    --username $(USER_NAME) \
    --group-name $(USER_DEPARTMENT)

delete-user:
	cd infra && \
	STACK_NAME=$$(source .venv/bin/activate && npx cdk list | grep UserDirectory) && \
	USER_POOL_ID=$$(aws cloudformation describe-stacks --stack-name $$STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='UserDirectoryId'].OutputValue" --output text) && \
	aws cognito-idp admin-delete-user \
    --user-pool-id $$USER_POOL_ID \
    --username $(USER_NAME)


cli:
	@echo "http://localhost:35002/login"
	cd cli && \
	flask run -p 35002