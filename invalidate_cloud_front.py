import boto3
import time
import os

def handle_s3_change(event, context):
    paths = []
    for items in event["Records"]:
        key = items["s3"]["object"]["key"]
        if key.endswith("index.html"):
            paths.append("/" + key[:-10])
        paths.append("/" + key)
    print("Invalidating " + str(paths))

    client = boto3.client('cloudfront')
    batch = {
        'Paths': {
            'Quantity': len(paths),
            'Items': paths
        },
        'CallerReference': str(time.time())
    }
    invalidation = client.create_invalidation(
        DistributionId=os.environ['CLOUDFRONT_DISTRIBUTION_ID'],
        InvalidationBatch=batch,
    )
    return batch
