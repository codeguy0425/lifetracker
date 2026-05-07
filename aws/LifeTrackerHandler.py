import json
import base64
import boto3
from decimal import Decimal

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb')
TABLE_NAME = 'LifeTrackerLogs'
table = dynamodb.Table(TABLE_NAME)

class DecimalEncoder(json.JSONEncoder):
    """Handles Decimal types returned by DynamoDB for JSON serialization."""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def decode_body(event):
    """Extract and parse the JSON body from the API Gateway event.
    Handles both raw and base64-encoded bodies (HTTP API v2).
    """
    body = event.get('body')
    if not body:
        return None
    if event.get('isBase64Encoded', False):
        body = base64.b64decode(body).decode('utf-8')
    return json.loads(body) if isinstance(body, str) else body

def lambda_handler(event, context):
    # 1. Setup CORS Headers (Required for browser-based fetch)
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
        "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS"
    }

    # 2. Identify the HTTP Method
    # Handles both REST API and HTTP API ($default stage) event structures
    method = event.get('requestContext', {}).get('http', {}).get('method') or event.get('httpMethod')

    # 3. Handle Browser Preflight (OPTIONS)
    if method == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'message': 'CORS preflight match'})
        }

    try:
        # --- GET Logic: Fetch All Logs ---
        if method == 'GET':
            response = table.scan()
            items = response.get('Items', [])
            # Frontend expects an object with a 'logs' key[cite: 1]
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({'logs': items}, cls=DecimalEncoder)
            }

        # --- POST/PUT Logic: Create or Update ---
        elif method in ['POST', 'PUT']:
            payload = decode_body(event)
            if not payload:
                return {
                    'statusCode': 400, 
                    'headers': headers, 
                    'body': json.dumps({'error': 'Missing request body'})
                }

            action = payload.get('action')
            item_data = payload.get('data')

            if not item_data:
                return {
                    'statusCode': 400, 
                    'headers': headers, 
                    'body': json.dumps({'error': 'Missing data key'})
                }

            # Handle category saving
            if action == 'saveCategory':
                item_data['id'] = f"CAT_{item_data['name']}"

            # DynamoDB partition key 'id' is String type
            if 'id' in item_data and not isinstance(item_data['id'], str):
                item_data['id'] = str(item_data['id'])
            
            table.put_item(Item=item_data)
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({'message': 'Success'})
            }

        # --- DELETE Logic: Remove an Item ---
        elif method == 'DELETE':
            payload = decode_body(event)
            if not payload:
                return {
                    'statusCode': 400, 
                    'headers': headers, 
                    'body': json.dumps({'error': 'Missing request body'})
                }

            action = payload.get('action')
            if action == 'deleteCategory':
                target_id = f"CAT_{payload.get('name')}" if payload.get('name') else None
            else:
                target_id = payload.get('id')

            if not target_id:
                return {
                    'statusCode': 400, 
                    'headers': headers, 
                    'body': json.dumps({'error': 'Missing id for deletion'})
                }

            table.delete_item(Key={'id': str(target_id)})
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({'message': f'Item {target_id} deleted successfully'})
            }

    except Exception as e:
        # Ensure error responses also carry CORS headers[cite: 1]
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }

    return {
        'statusCode': 405, 
        'headers': headers, 
        'body': json.dumps({'error': f'Method {method} not allowed'})
    }