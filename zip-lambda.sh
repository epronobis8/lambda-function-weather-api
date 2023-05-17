#!/bin/bash
pip install --target ./package2 requests==2.28.1
cd package2
zip -r ../lambda.zip .
cd ..
zip lambda.zip lambda_function.py
