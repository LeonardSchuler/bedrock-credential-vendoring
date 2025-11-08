#!/usr/bin/env python3

import os

from aws_cdk import App, Stack, aws_cognito as cognito, CfnOutput
from constructs import Construct
from dotenv import load_dotenv, find_dotenv

load_dotenv(find_dotenv(".env"))

COGNITO_DOMAIN_PREFIX = os.environ["COGNITO_DOMAIN_PREFIX"]
print(COGNITO_DOMAIN_PREFIX)


class UserDirectory(Stack):
    def __init__(
        self, scope: Construct, construct_id: str, domain_prefix: str, **kwargs
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)
        self.user_directory = cognito.UserPool(
            self,
            "UserDirectory",
            feature_plan=cognito.FeaturePlan.LITE,
            auto_verify=cognito.AutoVerifiedAttrs(email=True),
            self_sign_up_enabled=True,
            sign_in_aliases=cognito.SignInAliases(username=True, email=True),
            # custom_attributes are part of the profile scope
            custom_attributes={
                "department": cognito.StringAttribute(
                    min_len=1, max_len=20, mutable=True
                ),
            },
        )
        self.domain = self.user_directory.add_domain(
            "DomainPrefix",
            cognito_domain=cognito.CognitoDomainOptions(domain_prefix=domain_prefix),
        )
        CfnOutput(
            self, "UserDirectoryDomainUrl", value=self.domain.cloud_front_endpoint
        )
        CfnOutput(self, "UserDirectoryDomainName", value=self.domain.domain_name)
        CfnOutput(self, "UserDirectoryId", value=self.user_directory.user_pool_id)
        CfnOutput(
            self, "UserDirectoryUrl", value=self.user_directory.user_pool_provider_url
        )


class TerminalAppStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        user_pool_arn: str,
        # user_pool_domain_name: str,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)
        user_pool = cognito.UserPool.from_user_pool_arn(
            self, "UserDirectory", user_pool_arn=user_pool_arn
        )
        self.client = user_pool.add_client(
            "TerminalClient",
            o_auth=cognito.OAuthSettings(
                flows=cognito.OAuthFlows(authorization_code_grant=True),
                scopes=[
                    # Cognito includes "cognito:groups" in openid scope and custom attributes in profile scope
                    cognito.OAuthScope.OPENID,
                    cognito.OAuthScope.EMAIL,
                    cognito.OAuthScope.PROFILE,
                ],
                callback_urls=["http://localhost:35002/authorize"],
            ),
        )

        CfnOutput(self, "ClientId", value=self.client.user_pool_client_id)


class DepartmentStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        user_pool_arn: str,
        departments: list[str],
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)
        user_pool = cognito.UserPool.from_user_pool_arn(
            self, "UserDirectory", user_pool_arn=user_pool_arn
        )
        for dep in departments:
            user_pool.add_group(f"Department{dep}", group_name=dep)
        # user_pool.add_client()


APPLICATION_NAME = "BedrockCredentialVendoring"
app = App(analytics_reporting=False)
directory_stack = UserDirectory(
    app, f"{APPLICATION_NAME}UserDirectoryStack", domain_prefix=COGNITO_DOMAIN_PREFIX
)
DEPARTMENTS = ["IT", "Finance", "HR"]

departments_stack = DepartmentStack(
    app,
    f"{APPLICATION_NAME}DepartmentsStack",
    user_pool_arn=directory_stack.user_directory.user_pool_arn,
    departments=DEPARTMENTS,
)

terminal_stack = TerminalAppStack(
    app,
    f"{APPLICATION_NAME}TerminalAppStack",
    user_pool_arn=directory_stack.user_directory.user_pool_arn,
    # user_pool_domain_name=directory_stack.domain.domain_name,
)

app.synth()
