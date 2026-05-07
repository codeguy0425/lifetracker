# AWS IAM Setup — Life Tracker

## 1. Create Access Key

AWS Console → IAM → Users → your username → Security credentials → Create access key → CLI → check confirmation → Create

Save both **Access Key ID** and **Secret Access Key**.

## 2. Attach Permissions

Your IAM user needs these two permissions for the deploy skill to work:

### S3 upload

AWS Console → IAM → Policies → Create policy → JSON → paste:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::codeguy-life-tracker/*"
        }
    ]
}
```

Click **Next** → name `S3-Upload-LifeTracker` → **Create policy**

### CloudFront invalidation

Same flow, second policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "cloudfront:CreateInvalidation",
            "Resource": "arn:aws:cloudfront::509399121416:distribution/E1EW27NJQU3B33"
        }
    ]
}
```

Name `CloudFront-Invalidate-LifeTracker` → **Create policy**

### Attach both to your user

IAM → Users → your username → **Add permissions** → **Attach policies directly** → search and select both → **Add permissions**

## 3. Configure CLI

```powershell
aws configure
# AWS Access Key ID:     <paste from step 1>
# AWS Secret Access Key: <paste from step 1>
# Default region name:   ap-east-1
# Default output format: json
```

## 4. Verify

```powershell
aws sts get-caller-identity
```
Should show your account ID, user ID, and ARN. No credential errors.
