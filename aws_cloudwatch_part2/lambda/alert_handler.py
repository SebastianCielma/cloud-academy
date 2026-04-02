import boto3
import os
import json
from datetime import datetime, timedelta

ec2 = boto3.client('ec2')
cw = boto3.client('cloudwatch')
sns = boto3.client('sns')

SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

def lambda_handler(event, context):
    
    response = ec2.describe_instances(Filters=[
        {'Name': 'tag:Env', 'Values': ['prod']},
        {'Name': 'tag:AutoAlert', 'Values': ['true']}
    ])
    
    app_groups = {}
    for reservation in response.get('Reservations', []):
        for inst in reservation.get('Instances', []):
            tags = {t['Key']: t['Value'] for t in inst.get('Tags', [])}
            app_name = tags.get('App', 'unknown')
            instance_id = inst['InstanceId']
            
            if app_name not in app_groups:
                app_groups[app_name] = []
            app_groups[app_name].append(instance_id)

    alerts_sent = []
    
    for app, instances in app_groups.items():
        if len(instances) < 2:
            continue 
            
        stressed_instances = 0
        problematic_ids = []
        
        for inst_id in instances:
            alarm_name = f"StressAlarm-{app}-1" 
            try:
                alarm_state = cw.describe_alarms(AlarmNames=[alarm_name])
                for alarm in alarm_state.get('MetricAlarms', []):
                    if alarm['StateValue'] == 'ALARM':
                        stressed_instances += 1
                        problematic_ids.append(inst_id)
            except Exception as e:
                print(f"Error: {str(e)}")

        if stressed_instances >= 2:
            message = (
                f"ALERT!\n"
                f"App: {app}\n"
                f"Description: Stress alert (CPU/Disk/Network/IOWait) "
                f"on {stressed_instances} instances.\n"
            )
            
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=f"AWS Alert: '{app}'",
                Message=message
            )
            alerts_sent.append(app)

    return {
        'statusCode': 200,
        'body': json.dumps(f"Alerts send to: {alerts_sent}")
    }