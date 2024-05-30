import json
import boto3
from datetime import datetime, timedelta
import os
import urllib3

http = urllib3.PoolManager()
secretsmanager = boto3.client('secretsmanager')
acm = boto3.client('acm')

def get_secret(secret_name):
    response = secretsmanager.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])[secret_name]

def get_certificate_details(cert_arn):
    response = acm.describe_certificate(CertificateArn=cert_arn)
    return response['Certificate']

def send_slack_message(webhook_url, message):
    payload = {
        "channel": os.environ['SLACK_CHANNEL'],
        "text": message
    }
    response = http.request('POST', webhook_url, body=json.dumps(payload), headers={'Content-Type': 'application/json'})
    return response

def lambda_handler(event, context):
    slack_webhook_url = get_secret(os.environ['SLACK_WEBHOOK_URL'])
    region = os.environ['REGION']
    alert_before_days = 30
    certificates = acm.list_certificates(CertificateStatuses=['ISSUED'])
    
    for cert in certificates['CertificateSummaryList']:
        cert_details = get_certificate_details(cert['CertificateArn'])
        not_after = cert_details['NotAfter']
        days_to_expiry = (not_after - datetime.utcnow()).days
        
        if days_to_expiry <= alert_before_days:
            arn = cert_details['CertificateArn']
            san = cert_details['SubjectAlternativeNames']
            exp_date = not_after.strftime('%Y-%m-%d')
            message = (
                f"SSL Certificate is expiring soon!\n"
                f"ARN: {arn}\n"
                f"Region: {region}\n"
                f"Subject Alternative Names: {', '.join(san)}\n"
                f"Expiry Date: {exp_date}\n"
                f"Days to Expiry: {days_to_expiry} days"
            )
            send_slack_message(slack_webhook_url, message)
    
    return {
        'statusCode': 200,
        'body': json.dumps('SSL check completed')
    }
