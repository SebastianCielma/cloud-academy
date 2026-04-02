import boto3
import os
import json
from datetime import datetime, timedelta

ec2 = boto3.client('ec2')
cw = boto3.client('cloudwatch')
sns = boto3.client('sns')

SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

THRESHOLDS = {
    'cpu_utilization': 80,
    'cpu_iowait': 20,
    'disk_used': 85,
    'net_bytes_out': 500_000_000  
}


def get_metric_value(instance_id, metric_name, namespace, stat='Average', extra_dimensions=None):
    """Pull a single metric's latest value from the last 5 minutes using GetMetricData."""
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(minutes=5)

    dimensions = [{'Name': 'InstanceId', 'Value': instance_id}]
    if extra_dimensions:
        dimensions.extend(extra_dimensions)

    response = cw.get_metric_data(
        MetricDataQueries=[{
            'Id': 'metric_query',
            'MetricStat': {
                'Metric': {
                    'Namespace': namespace,
                    'MetricName': metric_name,
                    'Dimensions': dimensions
                },
                'Period': 300,
                'Stat': stat
            },
            'ReturnData': True
        }],
        StartTime=start_time,
        EndTime=end_time
    )

    values = response['MetricDataResults'][0]['Values']
    return values[0] if values else None


def is_sustained_stress(instance_id):
    """Check if ALL 4 metrics exceed thresholds simultaneously (sustained stress)."""
    cpu_util = get_metric_value(instance_id, 'CPUUtilization', 'AWS/EC2')
    cpu_iowait = get_metric_value(instance_id, 'cpu_usage_iowait', 'CWAgent')
    disk_used = get_metric_value(
        instance_id, 'disk_used_percent', 'CWAgent',
        extra_dimensions=[{'Name': 'path', 'Value': '/'}]
    )
    net_bytes = get_metric_value(
        instance_id, 'net_bytes_sent', 'CWAgent',
        extra_dimensions=[{'Name': 'interface', 'Value': 'eth0'}]
    )

    results = {
        'cpu_utilization': cpu_util,
        'cpu_iowait': cpu_iowait,
        'disk_used': disk_used,
        'net_bytes_out': net_bytes
    }
    print(f"Instance {instance_id} metrics: {results}")

    if any(v is None for v in results.values()):
        print(f"Instance {instance_id}: missing metric data, skipping")
        return False

    return (
        cpu_util > THRESHOLDS['cpu_utilization']
        and cpu_iowait > THRESHOLDS['cpu_iowait']
        and disk_used > THRESHOLDS['disk_used']
        and net_bytes > THRESHOLDS['net_bytes_out']
    )


def lambda_handler(event, context):
    response = ec2.describe_instances(Filters=[
        {'Name': 'tag:Env', 'Values': ['prod']},
        {'Name': 'tag:AutoAlert', 'Values': ['true']},
        {'Name': 'instance-state-name', 'Values': ['running']}
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

    print(f"Discovered app groups: { {k: len(v) for k, v in app_groups.items()} }")

    alerts_sent = []

    for app, instances in app_groups.items():
        if len(instances) < 2:
            print(f"App '{app}' has only {len(instances)} instance(s), skipping quorum check")
            continue

        stressed_instances = []

        for inst_id in instances:
            try:
                if is_sustained_stress(inst_id):
                    stressed_instances.append(inst_id)
                    print(f"Instance {inst_id} in app '{app}' is under sustained stress")
            except Exception as e:
                print(f"Error evaluating instance {inst_id}: {str(e)}")

        if len(stressed_instances) >= 2:
            message = (
                f"SYSTEM STRESS ALERT\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"App Group: {app}\n"
                f"Stressed Instances: {len(stressed_instances)}/{len(instances)}\n"
                f"Instance IDs: {', '.join(stressed_instances)}\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"Conditions met (ALL 4 simultaneously):\n"
                f"  • CPUUtilization > {THRESHOLDS['cpu_utilization']}%\n"
                f"  • cpu_usage_iowait > {THRESHOLDS['cpu_iowait']}%\n"
                f"  • disk_used_percent > {THRESHOLDS['disk_used']}%\n"
                f"  • net_bytes_out > {THRESHOLDS['net_bytes_out'] / 1_000_000:.0f} MB\n"
                f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                f"Action: Investigate immediately\n"
            )

            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=f"AWS Stress Alert: App '{app}' - Quorum Reached",
                Message=message
            )
            alerts_sent.append(app)
            print(f"Alert sent for app '{app}' ({len(stressed_instances)} stressed)")

    return {
        'statusCode': 200,
        'body': json.dumps({
            'alerts_sent': alerts_sent,
            'groups_evaluated': list(app_groups.keys())
        })
    }