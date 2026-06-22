"""
Receives messages from Cost Anomaly Monitor via SQS subscription to SNS.
Forwards the message to Slack channel #dasg_metrics_and_insights.
"""

from datetime import datetime, timezone
import json
import os
from urllib import request
from urllib.error import URLError
import boto3
from botocore.exceptions import ClientError

SSM_PARAMETER_CACHE = {}

# pylint: disable=too-few-public-methods
class Field:
    """Represents a field object from SNS JSON."""

    def __init__(self, field_type, text, emoji):
        """
        Initialize a Field object.

        Args:
            field_type: The type of the field
            text: Text to be displayed
            emoji: Boolean indicating if emoji should be used
        """
        self.type = field_type
        self.text = text
        self.emoji = emoji

# pylint: disable=too-few-public-methods
class Block:
    """Represents a block object from SNS JSON."""

    def __init__(self, block_type, **kwargs):
        """
        Initialize a Block object.

        Args:
            block_type: The type of the block
            **kwargs: Optional fields (fields, text)
        """
        self.type = block_type
        if kwargs.get("fields"):
            self.fields = kwargs.get("fields")
        if kwargs.get("text"):
            self.text = kwargs.get("text")

# pylint: disable=too-few-public-methods
class Text:
    """Represents a text object from SNS JSON."""

    def __init__(self, text_type, text, **kwargs):
        """
        Initialize a Text object.

        Args:
            text_type: The type of the text
            text: Text to be displayed
            **kwargs: Optional emoji parameter
        """
        self.type = text_type
        self.text = text
        if kwargs.get("emoji"):
            self.emoji = kwargs.get("emoji")


def get_ssm_client():
    """
    Lazy initialization of boto3 SSM client.
    Prevents global instantiation to avoid NoRegionError during tests.

    Returns:
        boto3.client: SSM client instance
    """
    return boto3.client('ssm')


def get_ssm_parameter(name):
    """
    Retrieve an SSM parameter and cache the value to prevent duplicate API calls.
    Caches None if the parameter is not found or an error occurs.

    Args:
        name: The name of the SSM parameter

    Returns:
        str or None: The parameter value or None if not found
    """
    if name not in SSM_PARAMETER_CACHE:
        try:
            ssm_client = get_ssm_client()
            response = ssm_client.get_parameter(Name=name, WithDecryption=True)
            value = response['Parameter']['Value']
            SSM_PARAMETER_CACHE[name] = value
        except ClientError as error:
            print({'msg': f'Error getting SSM parameter {name}: {error}'})
            SSM_PARAMETER_CACHE[name] = None

    return SSM_PARAMETER_CACHE[name]


def is_ignore_ok():
    """
    Return the current value of the IGNORE_OK environment variable.
    This allows tests to patch the environment dynamically.

    Returns:
        bool: True if IGNORE_OK is set to 'true', False otherwise
    """
    return os.environ.get('IGNORE_OK', 'false').lower() == 'true'

# pylint: disable=too-many-locals
def lambda_handler(event, context):
    """
    Parse AWS Cost Anomaly Detection SNS messages
    """
    print(f"Received event: {json.dumps(event)}")

    message = "test"

    try:
        # Handle SQS trigger (SNS messages delivered via SQS)
        if 'Records' in event:
            for record in event['Records']:
                # Extract SNS message from SQS
                if 'body' in record:
                    body = json.loads(record['body'])

                    # Check if it's an SNS message
                    if 'Message' in body:
                        sns_message = json.loads(body['Message'])
                        message = process_cost_anomaly(sns_message)
                    else:
                        print("No SNS Message found in SQS body")

        # Handle direct SNS trigger
        elif 'Records' in event and event['Records'][0].get('EventSource') == 'aws:sns':
            for record in event['Records']:
                sns_message = json.loads(record['Sns']['Message'])
                message = process_cost_anomaly(sns_message)

        # Handle direct invocation with message
        else:
            message = process_cost_anomaly(event)

        webhook = get_ssm_parameter("/cdap/sensitive/webhook/cost-anomaly")
        send_message_to_slack(webhook,message,0)

        return {
            'statusCode': 200,
            'body': json.dumps('Successfully processed cost anomaly alert')
        }

    except Exception as e:
        print(f"Error processing message: {str(e)}")
        raise

def process_cost_anomaly(message):
    """
    Process and parse the cost anomaly detection message
    """
    print("Processing cost anomaly message")

    # Extract key information
    account_id = message.get('accountId', 'Unknown')
    anomaly_id = message.get('anomalyId', 'Unknown')
    anomaly_score = message.get('anomalyScore', 0)

    # Get impact details
    impact = message.get('impact', {})
    max_impact = impact.get('maxImpact', 0)
    total_impact = impact.get('totalImpact', 0)

    # Get date information
    anomaly_start = message.get('anomalyStartDate', 'Unknown')
    anomaly_end = message.get('anomalyEndDate', 'Unknown')

    # Get root causes
    root_causes = message.get('rootCauses', [])

    # Get dimension details
    dimension_value = message.get('dimensionValue', 'Unknown')

    # Format the parsed data
    parsed_data = {
        'account_id': account_id,
        'anomaly_id': anomaly_id,
        'anomaly_score': anomaly_score,
        'max_impact': max_impact,
        'total_impact': total_impact,
        'start_date': anomaly_start,
        'end_date': anomaly_end,
        'dimension_value': dimension_value,
        'root_causes': root_causes,
        'severity': get_severity(anomaly_score),
        'timestamp': datetime.utcnow().isoformat()
    }

    print(f"Parsed anomaly data: {json.dumps(parsed_data, indent=2)}")

    # Format alert message
    alert_message = format_alert_message(parsed_data)
    print(f"Alert message:\n{alert_message}")


    return parsed_data

def get_severity(score):
    """
    Determine severity based on anomaly score
    """
    if score["currentScore"] >= 80:
        return "CRITICAL"
    elif score["currentScore"] >= 60:
        return "HIGH"
    elif score["currentScore"] >= 40:
        return "MEDIUM"
    else:
        return "LOW"

def format_alert_message(data):
    """
    Format a human-readable alert message
    """
    message = f"""
🚨 AWS Cost Anomaly Detected

Severity: {data['severity']}
Anomaly Score: {data['anomaly_score']}

💰 Financial Impact:
- Max Impact: ${data['max_impact']:.2f}
- Total Impact: ${data['total_impact']:.2f}

📅 Time Period:
- Start: {data['start_date']}
- End: {data['end_date']}

🔍 Details:
- Account ID: {data['account_id']}
- Anomaly ID: {data['anomaly_id']}
- Dimension: {data['dimension_value']}

📊 Root Causes:
"""

    for i, cause in enumerate(data['root_causes'], 1):
        service = cause.get('service', 'Unknown')
        region = cause.get('region', 'Unknown')
        usage_type = cause.get('usageType', 'Unknown')
        message += f"\n  {i}. Service: {service}"
        message += f"\n     Region: {region}"
        message += f"\n     Usage Type: {usage_type}"

    return message

def send_message_to_slack(webhook, message, message_id):
    """
    Call the Slack webhook with the formatted message.

    Args:
        webhook: Slack webhook URL
        message: Message content to send
        message_id: Identifier for the message

    Returns:
        bool: True if successful, False otherwise
    """
    if not webhook:
        print({
            'msg': 'Unable to send to Slack as webhook URL is not set',
            'messageId': message_id
        })
        return False

    jsondata = json.dumps(message)
    jsondataasbytes = jsondata.encode('utf-8')
    req = request.Request(webhook)
    req.add_header('Content-Type', 'application/json; charset=utf-8')
    req.add_header('Content-Length', str(len(jsondataasbytes)))

    try:
        with request.urlopen(req, jsondataasbytes) as resp:
            if resp.status == 200:
                print({
                    'msg': 'Successfully sent message to Slack',
                    'messageId': message_id
                })
                return True
            print({
                'msg': f'Unsuccessful attempt to send message to Slack ({resp.status})',
                'messageId': message_id
            })
            return False
    except URLError as error:
        print({
            'msg': f'Unsuccessful attempt to send message to Slack ({error.reason})',
            'messageId': message_id
        })
        return False
