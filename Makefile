.PHONY: all infra user generate-env delete-infra delete-user

all: generate-env infra user

generate-env:
	$(eval USER_NAME := $(shell echo $$USER | tr "[:upper:]" "[:lower:]"))
	@echo "export USER_NAME=\"$(USER_NAME)\"" > .env
	@echo "export USER_EMAIL=\"$(USER_NAME)@example.com\"" >> .env
	@echo "export USER_DEPARTMENT=\"IT\"" >> .env
	@echo "export USER_PASSWORD=\"$$(openssl rand -base64 10)\"" >> .env

infra:
	cd infra && \
	source .venv/bin/activate && \
	npx cdk deploy --all

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
	STACK_NAME=$$(npx cdk list | grep UserDirectory) && \
	USER_POOL_ID=$$(aws cloudformation describe-stacks --stack-name $$STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='UserDirectoryId'].OutputValue" --output text) && \
	aws cognito-idp admin-delete-user \
    --user-pool-id $$USER_POOL_ID \
    --username $(USER_NAME)

