#!/usr/bin/env python3
import aws_cdk as cdk

from infra_aws_cdk.cat_cloud_stack import CatCloudStack


app = cdk.App()

CatCloudStack(
    app,
    "CatCloudStack",
)

app.synth()