#!/usr/bin/env python3


from aws_cdk import App, Stack, aws_cognito as cognito, CfnOutput
from constructs import Construct


class UserDirectory(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        self.user_directory = cognito.UserPool(
            self,
            "UserDirectory",
            feature_plan=cognito.FeaturePlan.LITE,
            auto_verify=cognito.AutoVerifiedAttrs(email=True),
            self_sign_up_enabled=True,
            sign_in_aliases=cognito.SignInAliases(username=True, email=True),
            custom_attributes={
                "department": cognito.StringAttribute(
                    min_len=1, max_len=20, mutable=True
                ),
            },
        )
        CfnOutput(self, "UserDirectoryId", value=self.user_directory.user_pool_id)
        CfnOutput(
            self, "UserDirectoryUrl", value=self.user_directory.user_pool_provider_url
        )


class TerminalApp(Stack):
    def __init__(
        self, scope: Construct, construct_id: str, user_pool: cognito.UserPool, **kwargs
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)
        # user_pool.add_client()


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
    app,
    f"{APPLICATION_NAME}UserDirectoryStack",
)
DEPARTMENTS = ["IT", "Finance", "HR"]

departments_stack = DepartmentStack(
    app,
    f"{APPLICATION_NAME}DepartmentsStack",
    user_pool_arn=directory_stack.user_directory.user_pool_arn,
    departments=DEPARTMENTS,
)

app.synth()
