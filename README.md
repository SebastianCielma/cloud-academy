# AWS Static Website - Part 1

This repository contains the resources for the manual configuration of the static website task.

**Website URL:** https://dfi9gt8jrgrfd.cloudfront.net

## Infrastructure Details

The infrastructure was provisioned manually via the AWS Console with the following security settings:

* **S3 Bucket:** Configured for static hosting
* **CloudFront:** Serves as the Content Delivery Network.
* **Security:** Access to the S3 bucket is restricted to the CloudFront distribution using Origin Access Control.

 Here is the theoretical description of how to configure a custom domain:

### 4a. Configure ownership of your own domain in AWS
To establish domain ownership and management in AWS:
1.  **Route 53:** Create a Hosted Zone for the domain name.
2.  **Registrar:** Update the Name Servers at the domain registrar to point to the AWS Route 53 name servers.
3.  **ACM:** Request a public SSL certificate in AWS Certificate Manager to verify domain control and enable HTTPS.

### 4b. Redirect your domain name to the CloudFront address
To route traffic from the custom domain to the CloudFront distribution (`dfi9gt8jrgrfd.cloudfront.net`):
1.  **CloudFront Settings:** Add the custom domain to the alternate domain name list in the distribution configuration and attach the ACM certificate.
2.  **DNS Record:** Create an A records in Route 53 with the alias option enabled, targeting the CloudFront distribution domain. This ensures direct routing to the AWS edge network.